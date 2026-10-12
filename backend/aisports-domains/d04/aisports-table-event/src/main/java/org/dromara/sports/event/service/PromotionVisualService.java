package org.dromara.sports.event.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.api.OrganizationSessionApi;
import org.dromara.sports.event.ai.SportsEventAiProperties;
import org.dromara.sports.event.ai.SportsEventCallAiGatewayClient;
import org.dromara.sports.event.domain.SportsEventPoster;
import org.dromara.sports.event.mapper.SportsEventPosterMapper;
import org.redisson.api.RedissonClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.List;
import java.util.Objects;

/** 网络生图在事务外，短事务复核归属/名称项目后写宣传材料；不覆盖公开赛事封面。 */
@Service
@RequiredArgsConstructor
public class PromotionVisualService {
    private final EventPublicationService events;
    private final EventPromotionService promotion;
    private final SportsEventPosterMapper posters;
    private final SportsEventCallAiGatewayClient gateway;
    private final SportsEventAiProperties properties;
    private final StoredObjectApi files;
    private final OrganizationSessionApi sessions;
    private final PlatformTransactionManager transactionManager;
    private final RedissonClient redis;

    public EventPromotionService.PromotionView generate(Long eventId, boolean consent, String style, String audience, String keywords) {
        if (!consent) throw new ServiceException("请先同意将必要赛事信息用于生成主视觉");
        if (!List.of("competitive", "junior", "community").contains(Objects.toString(style, "")) || audience == null || audience.length() > 80 || keywords == null || keywords.length() > 200) throw new ServiceException("请检查视觉风格、受众和关键词");
        var event = events.managed(eventId); // 跨组织在锁/模型/文件写入前拒绝。
        String tenant = org.dromara.sports.platform.core.BusinessIdentity.getTenantId();
        Long ownerAccountId = sessions.managedOrganization(org.dromara.sports.platform.core.BusinessIdentity.getUserId())
            .filter(organization -> Objects.equals(tenant, organization.tenantId()))
            .map(OrganizationSessionApi.ManagedOrganization::accountId)
            .orElseThrow(() -> new ServiceException("当前账号不能为这个组织保存宣传图片"));
        var lock = redis.getLock("aisports:promotion-visual:" + tenant + ":" + eventId);
        if (!lock.tryLock()) throw new ServiceException("这场赛事正在生成主视觉，请稍后查看");
        try {
            var row = poster(eventId);
            String subject = subjectDigest(event.name(), event.projectName());
            String request = digest(Objects.toString(properties.getImageModel(), "") + "\n" + subject + "\n" + style + "\n" + audience + "\n" + keywords);
            if (row != null && row.getVisualFileId() != null && request.equals(row.getVisualRequestDigest())) return promotion.current(eventId);
            if (!properties.imageConfigured()) throw new ServiceException("主视觉生成服务暂未配置，可以使用赛事宣传图");
            byte[] image = gateway.createPromotionVisual(event.name(), event.projectName(), audience, keywords, style);
            new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
                var current = events.managed(eventId);
                if (!subject.equals(subjectDigest(current.name(), current.projectName()))) throw new ServiceException("赛事名称或项目刚被修改，请按新信息生成主视觉");
                var held = posters.selectOne(Wrappers.<SportsEventPoster>lambdaQuery().eq(SportsEventPoster::getEventId, eventId).eq(SportsEventPoster::getChannelName, EventPromotionService.POSTER).last("FOR UPDATE"));
                if (held == null) held = promotion.prepareVisualPoster(eventId, tenant);
                // 行版本在对象存储写入前固定；Redis串行同赛事生图，数据库版本兜住其他更新。
                long fileId = files.keepImage(ownerAccountId, tenant, StoredObjectApi.EVENT_BANNER, image);
                held.setVisualFileId(fileId); held.setVisualSubjectDigest(subject); held.setVisualRequestDigest(request); held.setVisualStyle(style);
                if (posters.updateById(held) != 1) throw new ServiceException("宣传材料刚被更新，请重新查看");
            });
            return promotion.current(eventId);
        } finally { if (lock.isHeldByCurrentThread()) lock.unlock(); }
    }

    private SportsEventPoster poster(Long eventId) {
        var row = posters.selectOne(Wrappers.<SportsEventPoster>lambdaQuery().eq(SportsEventPoster::getEventId, eventId).eq(SportsEventPoster::getChannelName, EventPromotionService.POSTER));
        return row;
    }
    static String subjectDigest(String name, String project) { return digest("flat-sports-v2\n" + Objects.toString(name, "") + "\n" + Objects.toString(project, "")); }
    private static String digest(String text) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(text.getBytes(StandardCharsets.UTF_8))); }
        catch (java.security.NoSuchAlgorithmException impossible) { throw new IllegalStateException(impossible); }
    }
}
