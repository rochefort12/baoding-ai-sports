package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.stereotype.Component;
import org.springframework.beans.factory.annotation.Value;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

/**
 * 只把任务编号和已解析文本交给本机网关。密钥留在网关进程里。
 */
@Component
public class SportsEventCallAiGatewayClient {

    private final SportsEventAiProperties properties;
    private final ObjectMapper objectMapper;
    @Value("${server.port:8080}")
    private int serverPort = 8080;
    private final HttpClient httpClient = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3)).build();

    public SportsEventCallAiGatewayClient(SportsEventAiProperties properties, ObjectMapper objectMapper) {
        this.properties = properties;
        this.objectMapper = objectMapper;
    }

    public Reply run(long taskId, String extraction) {
        if (!properties.keyConfigured()) {
            return Reply.failed("KEY_ABSENT");
        }
        if (!properties.tokenConfigured()) {
            return Reply.failed("INTERNAL_TOKEN_MISSING");
        }
        try {
            String body = objectMapper.createObjectNode()
                .put("taskId", Long.toString(taskId))
                .put("progressEnabled",true)
                .put("scene", AiTaskPolicy.SCENE)
                .put("currentTime", java.time.OffsetDateTime.now(java.time.ZoneId.of("Asia/Shanghai")).toString())
                .put("timeZone", "Asia/Shanghai")
                .put("javaBase", callbackBase(serverPort))
                .put("extraction", extraction == null ? "" : extraction)
                .toString();
            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(trim(properties.getGatewayUrl()) + "/internal/run"))
                .timeout(Duration.ofSeconds(290))
                .header("Content-Type", "application/json")
                .header("X-Ai-Internal-Token", properties.getInternalToken())
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 500) {
                return Reply.failed(codeOf(response.body(), "MODEL_FAILED"));
            }
            JsonNode node = objectMapper.readTree(response.body());
            List<CallNote> notes = new ArrayList<>();
            for (JsonNode item : node.path("invocations")) {
                notes.add(new CallNote(text(item, "kind", "model"), text(item, "toolName", ""),
                    text(item, "modelName", ""), text(item, "status", "succeeded"), text(item, "errorCode", "")));
            }
            return new Reply(node.path("ok").asBoolean(false), text(node,"errorCode",""), node.path("proposal").isMissingNode() ? "" : node.path("proposal").toString(), notes, text(node,"field",""));
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            return Reply.failed("MODEL_TIMEOUT");
        } catch (Exception exception) {
            return Reply.failed("GATEWAY_UNAVAILABLE");
        }
    }

    public DiscussReply discuss(long taskId, String draft, List<DiscussTurn> history, String message) {
        if (!properties.keyConfigured()) {
            return DiscussReply.failed("KEY_ABSENT");
        }
        if (!properties.tokenConfigured()) {
            return DiscussReply.failed("INTERNAL_TOKEN_MISSING");
        }
        try {
            ObjectNode bodyNode = objectMapper.createObjectNode();
            bodyNode.put("taskId", Long.toString(taskId));
            var now = java.time.OffsetDateTime.now(java.time.ZoneId.of("Asia/Shanghai"));
            bodyNode.put("currentTime", now.toString());
            bodyNode.put("timeZone", "Asia/Shanghai");
            var saturday = now.toLocalDate().with(java.time.temporal.TemporalAdjusters.next(java.time.DayOfWeek.SATURDAY));
            bodyNode.put("futureWeekendStartsAt", saturday + " 09:00:00");
            bodyNode.put("futureWeekendEndsAt", saturday.plusDays(1) + " 18:00:00");
            bodyNode.put("javaBase", callbackBase(serverPort));
            bodyNode.put("draft", draft == null || draft.isBlank() ? "{}" : draft);
            bodyNode.put("message", message == null ? "" : message);
            bodyNode.set("history", objectMapper.valueToTree(history == null ? List.of() : history));
            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(trim(properties.getGatewayUrl()) + "/internal/discuss"))
                .timeout(Duration.ofSeconds(90))
                .header("Content-Type", "application/json")
                .header("X-Ai-Internal-Token", properties.getInternalToken())
                .POST(HttpRequest.BodyPublishers.ofString(bodyNode.toString()))
                .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                return DiscussReply.failed(codeOf(response.body(), "MODEL_FAILED"));
            }
            JsonNode node = objectMapper.readTree(response.body());
            if (!node.path("ok").asBoolean(false) || !node.path("proposal").isObject()) {
                return DiscussReply.failed(text(node, "errorCode", "MODEL_FAILED"));
            }
            return new DiscussReply(true, "", node.path("proposal").toString());
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            return DiscussReply.failed("MODEL_TIMEOUT");
        } catch (Exception exception) {
            return DiscussReply.failed("GATEWAY_UNAVAILABLE");
        }
    }

    private String codeOf(String body, String fallback) {
        try {
            JsonNode node = objectMapper.readTree(body == null ? "" : body);
            String code = node.path("errorCode").asText("");
            return code.isBlank() ? fallback : code;
        } catch (Exception exception) {
            return fallback;
        }
    }

    /** 数据由 Java 重新授权读取；网关只输出纯文本，不执行写入工具。 */
    public String assist(String message, JsonNode context) {
        if (!properties.keyConfigured() || !properties.tokenConfigured()) {
            throw new org.dromara.common.core.exception.ServiceException("AI 服务未配置，请使用手动操作");
        }
        try {
            ObjectNode body = objectMapper.createObjectNode().put("message", message);
            body.set("context", context);
            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(trim(properties.getGatewayUrl()) + "/internal/assist"))
                .timeout(Duration.ofSeconds(65)).header("Content-Type", "application/json")
                .header("X-Ai-Internal-Token", properties.getInternalToken())
                .POST(HttpRequest.BodyPublishers.ofString(body.toString())).build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            JsonNode node = objectMapper.readTree(response.body());
            if (response.statusCode() != 200 || !node.path("ok").asBoolean() || node.path("reply").asText().isBlank()) {
                throw new org.dromara.common.core.exception.ServiceException("助手暂时没有完成回答，请重试；业务数据没有修改");
            }
            return node.path("reply").asText();
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new org.dromara.common.core.exception.ServiceException("AI 回答超时，请重试；业务数据没有修改");
        } catch (org.dromara.common.core.exception.ServiceException exception) { throw exception; }
        catch (Exception exception) { throw new org.dromara.common.core.exception.ServiceException("AI 服务暂不可用，请重试；业务数据没有修改"); }
    }

    /** 参赛引导。账号编号只随内部回调走，不放进模型可见的参数。 */
    public GuideReply guide(String message, JsonNode history, Long viewingEventId, Long accountId) {
        if (!properties.keyConfigured() || !properties.tokenConfigured()) {
            throw new org.dromara.common.core.exception.ServiceException("AI 服务未配置，请直接查看赛事");
        }
        try {
            ObjectNode body = objectMapper.createObjectNode().put("message", message == null ? "" : message);
            body.put("javaBase", callbackBase(serverPort));
            if (viewingEventId != null) {
                body.put("viewingEventId", viewingEventId.toString());
            }
            if (accountId != null) {
                // 内部网关也经过JavaScript，Long必须以字符串传递，否则本人查询会变成另一编号。
                body.put("accountId", accountId.toString());
            }
            body.set("history", history == null ? objectMapper.createArrayNode() : history);
            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(trim(properties.getGatewayUrl()) + "/internal/guide"))
                .timeout(Duration.ofSeconds(90))
                .header("Content-Type", "application/json")
                .header("X-Ai-Internal-Token", properties.getInternalToken())
                .POST(HttpRequest.BodyPublishers.ofString(body.toString()))
                .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            JsonNode node = objectMapper.readTree(response.body());
            if (response.statusCode() != 200 || !node.path("ok").asBoolean() || node.path("reply").asText().isBlank()) {
                throw new org.dromara.common.core.exception.ServiceException("助手暂时没有完成回答，请重试或直接查看赛事");
            }
            List<String> eventIds = new ArrayList<>();
            for (JsonNode item : node.path("eventIds")) {
                String id = item.asText("");
                if (!id.isBlank() && !eventIds.contains(id)) {
                    eventIds.add(id);
                }
            }
            return new GuideReply(node.path("reply").asText(), eventIds, node.path("hasMore").asBoolean(false));
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new org.dromara.common.core.exception.ServiceException("AI 回答超时，请重试或直接查看赛事");
        } catch (org.dromara.common.core.exception.ServiceException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new org.dromara.common.core.exception.ServiceException("AI 服务暂不可用，请重试或直接查看赛事");
        }
    }

    /** 文案与无字主视觉分开请求；图像失败不撤销已保存文案。 */
    public JsonNode composePromotion(JsonNode facts, String note) {
        if (!properties.keyConfigured() || !properties.tokenConfigured()) {
            throw new org.dromara.common.core.exception.ServiceException("AI 服务未配置，宣传画面仍可用赛事信息排版");
        }
        try {
            ObjectNode body = objectMapper.createObjectNode();
            body.put("note", note == null ? "" : note);
            body.set("facts", facts);
            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(trim(properties.getGatewayUrl()) + "/internal/promote"))
                .timeout(Duration.ofSeconds(65))
                .header("Content-Type", "application/json")
                .header("X-Ai-Internal-Token", properties.getInternalToken())
                .POST(HttpRequest.BodyPublishers.ofString(body.toString()))
                .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            JsonNode node = objectMapper.readTree(response.body());
            if (response.statusCode() != 200 || !node.path("ok").asBoolean() || !node.path("copy").isObject()) {
                throw new org.dromara.common.core.exception.ServiceException("宣传文案这次没写好，材料没有保存");
            }
            return node.path("copy");
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new org.dromara.common.core.exception.ServiceException("宣传文案超时，材料没有保存");
        } catch (org.dromara.common.core.exception.ServiceException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new org.dromara.common.core.exception.ServiceException("AI 服务暂不可用，材料没有保存");
        }
    }

    /** 独立图像端点，不向图像供应商发送时间、费用、联系人或报名资料。 */
    public byte[] createPromotionVisual(String name, String project, String audience, String keywords, String style) {
        if (!properties.imageConfigured()) throw new org.dromara.common.core.exception.ServiceException("主视觉生成服务暂未配置，可以使用赛事宣传图");
        try {
            ObjectNode body = objectMapper.createObjectNode().put("name", name).put("project", project).put("audience", audience).put("keywords", keywords).put("style", style);
            HttpRequest request = HttpRequest.newBuilder().uri(URI.create(trim(properties.getGatewayUrl()) + "/internal/visual"))
                .timeout(Duration.ofSeconds(190)).header("Content-Type", "application/json").header("X-Ai-Internal-Token", properties.getInternalToken())
                .POST(HttpRequest.BodyPublishers.ofString(body.toString())).build();
            HttpResponse<java.io.InputStream> response = httpClient.send(request, HttpResponse.BodyHandlers.ofInputStream());
            byte[] json;
            try (var stream = response.body()) { json = stream.readNBytes(8 * 1024 * 1024 + 1); }
            if (json.length > 8 * 1024 * 1024 || response.statusCode() != 200) throw new IllegalArgumentException("IMAGE_FAILED");
            JsonNode result = objectMapper.readTree(json);
            if (!result.path("ok").asBoolean()) throw new IllegalArgumentException("IMAGE_FAILED");
            byte[] image = java.util.Base64.getDecoder().decode(result.path("imageBase64").asText());
            if (image.length < 32 || image.length > 5 * 1024 * 1024) throw new IllegalArgumentException("IMAGE_INVALID");
            // 在解码像素前读取尺寸，避免异常压缩图片占满内存。
            try (var input = javax.imageio.ImageIO.createImageInputStream(new java.io.ByteArrayInputStream(image))) {
                var readers = javax.imageio.ImageIO.getImageReaders(input);
                if (!readers.hasNext()) throw new IllegalArgumentException("IMAGE_INVALID");
                var reader = readers.next();
                try { reader.setInput(input); int w = reader.getWidth(0), h = reader.getHeight(0); if (w < 512 || h < 512 || w > 3840 || h > 3840 || (long) w * h > 8294400) throw new IllegalArgumentException("IMAGE_INVALID"); }
                finally { reader.dispose(); }
            }
            return image;
        } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt(); throw new org.dromara.common.core.exception.ServiceException("主视觉生成已中断，原材料仍可用");
        } catch (org.dromara.common.core.exception.ServiceException rejected) { throw rejected; }
        catch (Exception unavailable) { throw new org.dromara.common.core.exception.ServiceException("主视觉这次没有生成成功，原图片和文案仍可用"); }
    }

    /** Organizer documents only: the gateway cannot publish notices or alter event rules. */
    public JsonNode composeMaterial(JsonNode facts, String kind, String note) {
        if (!properties.keyConfigured() || !properties.tokenConfigured()) {
            throw new org.dromara.common.core.exception.ServiceException("AI 文稿服务尚未配置；手稿已保留，可用基础模板继续编辑");
        }
        try {
            ObjectNode body = objectMapper.createObjectNode().put("kind", kind).put("note", note == null ? "" : note);
            body.set("facts", facts);
            HttpRequest request = HttpRequest.newBuilder().uri(URI.create(trim(properties.getGatewayUrl()) + "/internal/material"))
                .timeout(Duration.ofSeconds(65)).header("Content-Type", "application/json")
                .header("X-Ai-Internal-Token", properties.getInternalToken())
                .POST(HttpRequest.BodyPublishers.ofString(body.toString())).build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            JsonNode result = objectMapper.readTree(response.body());
            if (response.statusCode() != 200 || !result.path("ok").asBoolean() || !result.path("material").isObject()) {
                throw new org.dromara.common.core.exception.ServiceException("AI 这次没有完成文稿；原手稿保留，请重试或继续手动编辑");
            }
            return result.path("material");
        } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt();
            throw new org.dromara.common.core.exception.ServiceException("AI 文稿生成已中断，原手稿保留");
        } catch (org.dromara.common.core.exception.ServiceException rejected) { throw rejected; }
        catch (Exception unavailable) { throw new org.dromara.common.core.exception.ServiceException("AI 文稿暂不可用，原手稿保留"); }
    }

    private String text(JsonNode node, String field, String fallback) {
        String value = node.path(field).asText("");
        return value.isBlank() ? fallback : value;
    }

    /** The server chooses its own port; neither uploads nor model output may select a host. */
    static String callbackBase(int port) {
        if (port < 1 || port > 65535) throw new IllegalArgumentException("Invalid local server port");
        return "http://127.0.0.1:" + port;
    }

    private String trim(String url) {
        if (url == null || url.isBlank()) {
            return "http://127.0.0.1:8091";
        }
        return url.endsWith("/") ? url.substring(0, url.length() - 1) : url;
    }

    public record CallNote(String kind, String toolName, String modelName, String status, String errorCode) {
    }

    public record Reply(boolean ok, String errorCode, String proposal, List<CallNote> invocations, String field) {
        public Reply(boolean ok,String errorCode,String proposal,List<CallNote> invocations){this(ok,errorCode,proposal,invocations,"");}
        static Reply failed(String errorCode) {
            return new Reply(false, errorCode, "", List.of());
        }
    }

    public record DiscussChoice(String label, String value) {
    }

    public record DiscussTurn(String role, String text) {
    }

    public record DiscussReply(boolean ok, String errorCode, String agentJson) {
        static DiscussReply failed(String errorCode) {
            return new DiscussReply(false, errorCode, "");
        }
    }

    public record GuideReply(String reply, List<String> eventIds, boolean hasMore) {
    }
}
