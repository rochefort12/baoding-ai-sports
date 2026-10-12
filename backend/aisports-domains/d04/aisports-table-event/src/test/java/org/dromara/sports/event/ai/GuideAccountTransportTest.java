package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicReference;
import static org.junit.jupiter.api.Assertions.*;

/** 真HTTP序列化检查：18位平台账号不能在Java到Node之间变成浮点数。 */
@Tag("local")
class GuideAccountTransportTest {
    @Test void platformLongTravelsAsExactStringAndNoModelSecretIsSent() throws Exception {
        ObjectMapper mapper = new ObjectMapper();
        AtomicReference<String> received = new AtomicReference<>();
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/internal/guide", exchange -> {
            received.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            byte[] reply = "{\"ok\":true,\"reply\":\"隔离样本\",\"eventIds\":[],\"hasMore\":false}".getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, reply.length); exchange.getResponseBody().write(reply); exchange.close();
        });
        server.start();
        try {
            SportsEventAiProperties properties = new SportsEventAiProperties();
            properties.setApiKey("fixture-only-not-sent"); properties.setInternalToken("fixture-internal");
            properties.setGatewayUrl("http://127.0.0.1:" + server.getAddress().getPort());
            new SportsEventCallAiGatewayClient(properties, mapper).guide("我的报名状态", null, null, 2108399269915426818L);
            var body = mapper.readTree(received.get());
            assertTrue(body.path("accountId").isTextual());
            assertEquals("2108399269915426818", body.path("accountId").asText());
            assertFalse(received.get().contains("fixture-only-not-sent"));
        } finally { server.stop(0); }
    }
}
