import {globalHeaders} from '@/utils/request';

export interface VisibleStep { sequence: string | number; name: string; status: string; summary?: string; errorCode?: string; attempt?: number }
export type ProgressConnection = 'connecting' | 'live' | 'reconnecting' | 'unavailable';

/** Read-only SSE: reconnecting retrieves state; it never submits or repeats an agent action. */
export function followAssistantProgress<T>(path: string, receive: (snapshot: T) => void, connection: (state: ProgressConnection) => void) {
  const controller = new AbortController();
  const run = async () => {
    let failures = 0;
    while (!controller.signal.aborted && failures < 4) {
      connection(failures ? 'reconnecting' : 'connecting');
      try {
        const response = await fetch(`${import.meta.env.VITE_APP_BASE_API}${path}`, {headers: {...globalHeaders(), Accept: 'text/event-stream'}, signal: controller.signal});
        if (!response.ok || !response.headers.get('content-type')?.includes('text/event-stream') || !response.body) throw Error('Progress unavailable');
        connection('live');
        const reader = response.body.getReader(), decoder = new TextDecoder();
        let buffer = '', received = false;
        while (!controller.signal.aborted) {
          const {done, value} = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, {stream: true}).replace(/\r\n/g, '\n');
          if (buffer.length > 2 * 1024 * 1024) throw Error('Progress too large');
          let boundary: number;
          while ((boundary = buffer.indexOf('\n\n')) >= 0) {
            const event = buffer.slice(0, boundary); buffer = buffer.slice(boundary + 2);
            if (event.startsWith('event: unavailable')) throw Error('Permission changed');
            if (event.startsWith('event: snapshot')) {
              const data = event.split('\n').filter(line => line.startsWith('data:')).map(line => line.slice(5).trimStart()).join('\n');
              if (!controller.signal.aborted) receive(JSON.parse(data));
              received = true;
            }
          }
        }
        if (received) failures = 0;
        await pause(1000, controller.signal);
      } catch {
        if (controller.signal.aborted) return;
        failures++; connection(failures >= 4 ? 'unavailable' : 'reconnecting');
        await pause(Math.min(5000, failures * 1000), controller.signal);
      }
    }
  };
  void run();
  return () => controller.abort();
}
function pause(ms: number, signal: AbortSignal) { return new Promise<void>(resolve => { if(signal.aborted)return resolve();const finish=()=>{clearTimeout(timer);signal.removeEventListener('abort',finish);resolve();};const timer=setTimeout(finish,ms);signal.addEventListener('abort',finish,{once:true}); }); }
