package org.dromara.sports.platform.core;

import cn.dev33.satoken.stp.StpUtil;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.function.Supplier;
import java.util.function.Predicate;

/** Authenticated SSE snapshots of already visible state. Connecting never starts or retries work. */
public final class VisibleProgressStream {
    private VisibleProgressStream() { }
    public static <T> void write(HttpServletResponse response,Supplier<T> snapshot,Predicate<T> terminal)throws IOException {
        T first=snapshot.get(); // Authorize before committing a streaming response.
        response.setContentType("text/event-stream;charset=UTF-8");
        response.setHeader("Cache-Control","no-store");response.setHeader("X-Accel-Buffering","no");
        String previous="";long deadline=System.nanoTime()+90_000_000_000L,heartbeat=0;
        try{
            T current=first;
            while(System.nanoTime()<deadline){
                StpUtil.checkLogin();
                String encoded=current.toString();
                if(!encoded.equals(previous)){response.getWriter().write("event: snapshot\ndata: "+encoded+"\n\n");previous=encoded;response.flushBuffer();}
                if(terminal.test(current))return;
                if(System.nanoTime()-heartbeat>10_000_000_000L){response.getWriter().write(": heartbeat\n\n");response.flushBuffer();heartbeat=System.nanoTime();}
                Thread.sleep(750);
                current=snapshot.get(); // Re-check ownership and current permissions each time.
            }
        }catch(InterruptedException e){Thread.currentThread().interrupt();}
        catch(RuntimeException revoked){response.getWriter().write("event: unavailable\ndata: {}\n\n");response.flushBuffer();}
    }
}
