package org.dromara.sports.event.ai;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * 密钥只用来判断要不要把任务交给网关。Java 不拿它请求模型。
 */
@Data
@Component
@ConfigurationProperties(prefix = "aisports.ai")
public class SportsEventAiProperties {

    private String apiKey = "";
    private String imageApiKey = "";
    private String imageEndpoint = "";
    private String imageModel = "";

    public boolean imageConfigured() {
        return imageApiKey != null && !imageApiKey.isBlank() && imageEndpoint != null && imageEndpoint.startsWith("https://") && imageModel != null && !imageModel.isBlank() && tokenConfigured();
    }

    private String gatewayUrl = "http://127.0.0.1:8091";

    private String internalToken = "";

    private int maxScanPages = 15;

    private int dailyTasks = 20;

    /** 每个办赛人同时保留的运营问答段数。小于 1 按 1，大于 50 按 50。 */
    private int opsSessionLimit = 8;

    public int opsSessionLimit() {
        if (opsSessionLimit < 1) {
            return 1;
        }
        return Math.min(opsSessionLimit, 50);
    }

    public boolean keyConfigured() {
        return apiKey != null && !apiKey.isBlank();
    }

    public boolean tokenConfigured() {
        return internalToken != null && !internalToken.isBlank();
    }
}
