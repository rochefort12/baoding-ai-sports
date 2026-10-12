package org.dromara.sports.event.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.common.satoken.utils.LoginHelper;
import org.dromara.sports.api.FeeApi.PublicUnitPrice;
import org.dromara.sports.event.ai.PromotionCopyGuard;
import org.dromara.sports.event.ai.SportsEventAiProperties;
import org.dromara.sports.event.ai.PromotionCopyGuard.Copy;
import org.dromara.sports.event.ai.SportsEventCallAiGatewayClient;
import org.dromara.sports.event.domain.SportsEventPoster;
import org.dromara.sports.event.mapper.SportsEventPosterMapper;
import org.dromara.sports.event.service.EventPublicationService.EventCard;
import org.dromara.sports.event.service.EventPublicationService.PublicFeeView;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.List;

/**
 * 办赛人的宣传材料。模型只写邀请，时间、费用、组织和二维码路径由这里填写。
 */
@Service
@RequiredArgsConstructor
public class EventPromotionService {

    static final String GROUP = "群消息";
    static final String MOMENTS = "朋友圈";
    static final String POSTER = "海报";
    private static final ZoneId SHANGHAI = ZoneId.of("Asia/Shanghai");
    private static final DateTimeFormatter CLOCK = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm").withZone(SHANGHAI);
    private static final String ALPHABET = "23456789abcdefghjkmnpqrstuvwxyz";

    private final EventPublicationService events;
    private final SportsEventPosterMapper posters;
    private final SportsEventCallAiGatewayClient gateway;
    private final ObjectMapper mapper;
    private final SportsEventAiProperties aiProperties;
    private final SecureRandom random = new SecureRandom();

    public PromotionView current(Long eventId) {
        Live live = live(eventId);
        List<SportsEventPoster> rows = rows(eventId);
        return view(live, rows, digestOf(rows));
    }

    @org.dromara.sports.platform.core.SportsAction(value="legacy.event.event_promotion_service.generate", title="EventPromotionService.generate", reads={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"}, writes={"asp_account","asp_ai_invocation","asp_ai_task","asp_ai_task_file","asp_audit_event","asp_capacity_pool","asp_checkin","asp_competition_type","asp_competition_unit","asp_complaint","asp_declaration_ack","asp_entry_field_value","asp_event","asp_event_command","asp_event_field","asp_event_payment_config","asp_event_poster","asp_execution_command","asp_fee_obligation","asp_fee_policy","asp_growth_policy","asp_growth_profile","asp_growth_record","asp_honor","asp_idempotency","asp_match","asp_match_entry","asp_notification","asp_notification_delivery","asp_org_field","asp_payment","asp_payment_action","asp_payment_allocation","asp_payment_exception","asp_person","asp_profile_display","asp_qualification_review","asp_refund","asp_registration","asp_registration_member","asp_registration_payment_proof","asp_registration_submit_key","asp_result_item","asp_result_version","asp_roster_member","asp_roster_version","asp_sport","asp_stage","asp_team","asp_team_member","asp_team_room","asp_team_room_member","asp_title_equipment"})
    @Transactional(rollbackFor = Exception.class)
    public PromotionView generate(Long eventId, boolean consent, String note) {
        if (!consent) {
            throw new ServiceException("请先同意把这场赛事的公开信息发送到当前模型");
        }
        if (note != null && note.length() > 200) {
            throw new ServiceException("补充说明请控制在200字内");
        }
        Live live = live(eventId);
        JsonNode generated = gateway.composePromotion(live.modelFacts(), note == null ? "" : note.trim());
        Copy copy = PromotionCopyGuard.accept(
            generated.path("headline").asText(""),
            generated.path("invitation").asText(""),
            generated.path("groupBody").asText(""),
            generated.path("momentsCaption").asText(""),
            live.factText(),
            live.cancelled());
        String tenantId = org.dromara.sports.platform.core.BusinessIdentity.getTenantId();
        save(tenantId, eventId, GROUP, "wechat_group", copy.headline(), copy.invitation(), copy.groupBody(), live.digest(), live.published());
        save(tenantId, eventId, MOMENTS, "moments", copy.headline(), copy.invitation(), copy.momentsCaption(), live.digest(), live.published());
        save(tenantId, eventId, POSTER, "a4", copy.headline(), copy.invitation(), "", live.digest(), live.published());
        return view(live, rows(eventId), live.digest());
    }

    private Live live(Long eventId) {
        EventCard event = events.managed(eventId);
        PublicFeeView fees = events.previewFees(eventId);
        String when = clock(event.startsAt()) + (event.endsAt() == null ? "" : " 至 " + clock(event.endsAt()));
        List<FeeLine> lines = new ArrayList<>();
        StringBuilder fact = new StringBuilder();
        fact.append(blank(event.name())).append('\n').append(when).append('\n').append(blank(event.location())).append('\n');
        fact.append(blank(fees.organizationName())).append('\n').append(blank(fees.contactName())).append(' ').append(blank(fees.contactMethod())).append('\n');
        fact.append(blank(event.projectName())).append('\n').append(trim(event.feeDescription(), 500)).append('\n').append(fees.refundNote()).append('\n');
        for (PublicUnitPrice unit : fees.units()) {
            String amount = unit.amount() == null ? "" : unit.amount().setScale(2, java.math.RoundingMode.HALF_UP).toPlainString();
            String mode = modeLabel(unit.paymentMode());
            lines.add(new FeeLine(blank(unit.unitName()), amount, mode));
            fact.append(blank(unit.unitName())).append(' ').append(amount).append(' ').append(mode).append('\n');
        }
        boolean published = "published".equals(event.publicationStatus());
        boolean cancelled = "cancelled".equals(event.holdingStatus());
        fact.append(published ? "已发布" : "未公开").append('\n').append(cancelled ? "已取消" : "正常举办");
        String digest = sha(fact.toString());
        ObjectNode modelFacts = mapper.createObjectNode();
        modelFacts.put("eventId", eventId.toString());
        modelFacts.put("name", blank(event.name()));
        modelFacts.put("when", when);
        modelFacts.put("where", blank(event.location()));
        modelFacts.put("organization", blank(fees.organizationName()));
        modelFacts.put("contact", (blank(fees.contactName()) + " " + blank(fees.contactMethod())).trim());
        modelFacts.put("project", blank(event.projectName()));
        modelFacts.put("feeDescription", trim(event.feeDescription(), 500));
        modelFacts.put("refundNote", fees.refundNote());
        modelFacts.put("published", published);
        modelFacts.put("cancelled", cancelled);
        ArrayNode feeNodes = modelFacts.putArray("fees");
        for (FeeLine line : lines) {
            feeNodes.addObject().put("name", line.name()).put("amount", line.amount()).put("mode", line.mode());
        }
        String banner = event.bannerFileId() == null ? null : Long.toString(event.bannerFileId());
        return new Live(published, cancelled, when, blank(event.location()), blank(fees.organizationName()),
            blank(fees.contactName()), blank(fees.contactMethod()), fees.refundNote(), banner, lines, fact.toString(), digest, modelFacts);
    }

    /** 仅供主视觉短事务建立关联行；不表示文案已生成或赛事已经发布。 */
    SportsEventPoster prepareVisualPoster(Long eventId, String tenantId) {
        SportsEventPoster row = new SportsEventPoster();
        row.setTenantId(tenantId); row.setEventId(eventId); row.setChannelName(POSTER); row.setFormat("a4");
        row.setSourceCode(freshCode()); row.setVersion(0);
        fill(row, "", "", "", "", false);
        if (posters.insert(row) != 1) throw new ServiceException("宣传材料刚被更新，请重新查看");
        return row;
    }

    private void save(String tenantId, Long eventId, String channel, String format, String headline, String invitation,
                      String body, String digest, boolean published) {
        SportsEventPoster row = posters.selectOne(Wrappers.<SportsEventPoster>lambdaQuery()
            .eq(SportsEventPoster::getEventId, eventId)
            .eq(SportsEventPoster::getChannelName, channel));
        if (row == null) {
            row = new SportsEventPoster();
            row.setTenantId(tenantId);
            row.setEventId(eventId);
            row.setChannelName(channel);
            row.setFormat(format);
            row.setSourceCode(freshCode());
            row.setVersion(0);
            fill(row, headline, invitation, body, digest, published);
            posters.insert(row);
            return;
        }
        fill(row, headline, invitation, body, digest, published);
        if (posters.updateById(row) != 1) {
            throw new ServiceException("宣传材料刚被更新，请再生成一次");
        }
    }

    private void fill(SportsEventPoster row, String headline, String invitation, String body, String digest, boolean published) {
        row.setCopyHeadline(headline);
        row.setCopyInvitation(invitation);
        row.setCopyBody(body);
        row.setFactDigest(digest);
        row.setLinkPath(published ? "/public/events/" + row.getEventId() + "?src=" + row.getSourceCode() : "");
    }

    private PromotionView view(Live live, List<SportsEventPoster> rows, String storedDigest) {
        SportsEventPoster group = channel(rows, GROUP);
        SportsEventPoster moments = channel(rows, MOMENTS);
        SportsEventPoster poster = channel(rows, POSTER);
        boolean saved = group != null && moments != null && poster != null;
        boolean stale = saved && !live.digest().equals(storedDigest);
        boolean currentCopy = saved && !stale;
        Copy basic = basicCopy(live.modelFacts().path("name").asText(), live.whenText(), live.location(), live.fees(), live.published(), live.cancelled());
        String basicPath = live.published() && !live.cancelled() ? "/public/events/" + live.modelFacts().path("eventId").asText() : "";
        boolean linkable = currentCopy && live.published() && !live.cancelled();
        boolean visualCurrent = poster != null && poster.getVisualFileId() != null && PromotionVisualService.subjectDigest(live.modelFacts().path("name").asText(), live.modelFacts().path("project").asText()).equals(poster.getVisualSubjectDigest());
        return new PromotionView(saved, stale, live.published(), live.cancelled(), visualCurrent,
            currentCopy ? group.getCopyHeadline() : basic.headline(),
            currentCopy ? group.getCopyInvitation() : basic.invitation(),
            currentCopy ? group.getCopyBody() : basic.groupBody(),
            currentCopy ? moments.getCopyBody() : basic.momentsCaption(),
            linkable ? group.getLinkPath() : basicPath,
            linkable ? moments.getLinkPath() : basicPath,
            linkable ? poster.getLinkPath() : basicPath,
            live.whenText(), live.location(), live.organizationName(), live.contactName(), live.contactMethod(),
            live.refundNote(), live.bannerFileId(), live.fees(), live.digest(), live.modelFacts().path("name").asText(), live.modelFacts().path("project").asText(),
            aiProperties.imageConfigured(), visualCurrent ? Long.toString(poster.getVisualFileId()) : null,
            visualCurrent ? poster.getVisualStyle() : "", poster != null && poster.getVisualFileId() != null && !visualCurrent,
            currentCopy ? "ai" : "basic");
    }

    /** 打开即按当前事实整理，既不调用外部模型也不写宣传行；旧AI文案失效时同样可用。 */
    static Copy basicCopy(String name, String when, String location, List<FeeLine> fees, boolean published, boolean cancelled) {
        String title = blank(name).isEmpty() ? "赛事信息" : blank(name);
        String invitation = cancelled ? "赛事已取消，请联系承办方了解后续安排。"
            : published ? "欢迎了解赛事安排，选择适合自己的项目报名。" : "赛事正在筹备，具体报名安排以正式发布为准。";
        StringBuilder body = new StringBuilder(title).append('\n').append(invitation);
        if (!blank(when).isEmpty()) body.append("\n比赛时间：").append(when);
        if (!blank(location).isEmpty()) body.append("\n比赛地点：").append(location);
        for (FeeLine fee : fees) {
            body.append('\n').append(fee.name()).append("：")
                .append("free".equals(fee.mode()) || "免费".equals(fee.mode()) ? "免费" : blank(fee.amount()).isEmpty() ? "费用待确认" : fee.amount() + "元／单");
        }
        return new Copy(title, invitation, body.toString(), title + "\n" + invitation);
    }

    private List<SportsEventPoster> rows(Long eventId) {
        return posters.selectList(Wrappers.<SportsEventPoster>lambdaQuery().eq(SportsEventPoster::getEventId, eventId));
    }

    private String digestOf(List<SportsEventPoster> rows) {
        SportsEventPoster group = channel(rows, GROUP);
        return group == null ? "" : blank(group.getFactDigest());
    }

    private SportsEventPoster channel(List<SportsEventPoster> rows, String name) {
        for (SportsEventPoster row : rows) {
            if (name.equals(row.getChannelName())) {
                return row;
            }
        }
        return null;
    }

    private String freshCode() {
        for (int attempt = 0; attempt < 5; attempt++) {
            StringBuilder code = new StringBuilder(8);
            for (int i = 0; i < 8; i++) {
                code.append(ALPHABET.charAt(random.nextInt(ALPHABET.length())));
            }
            String value = code.toString();
            Long existing = posters.selectCount(Wrappers.<SportsEventPoster>lambdaQuery().eq(SportsEventPoster::getSourceCode, value));
            if (existing == null || existing == 0) {
                return value;
            }
        }
        throw new ServiceException("暂时发不出宣传来源编号，请再试一次");
    }

    private static String clock(OffsetDateTime time) {
        return time == null ? "" : CLOCK.format(time.toInstant());
    }

    private static String modeLabel(String mode) {
        return switch (mode == null ? "" : mode) {
            case "free" -> "免费";
            case "offline" -> "线下收款";
            case "organizer_qr" -> "承办方收款码";
            case "event" -> "赛事统一收款";
            default -> mode == null ? "" : mode;
        };
    }

    private static String blank(String value) {
        return value == null ? "" : value.trim();
    }

    private static String trim(String value, int max) {
        String text = blank(value);
        return text.length() <= max ? text : text.substring(0, max);
    }

    private static String sha(String text) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(text.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (Exception exception) {
            throw new ServiceException("宣传事实暂时整理不了");
        }
    }

    private record Live(boolean published, boolean cancelled, String whenText, String location,
                        String organizationName, String contactName, String contactMethod, String refundNote,
                        String bannerFileId, List<FeeLine> fees, String factText, String digest, ObjectNode modelFacts) {
    }

    public record FeeLine(String name, String amount, String mode) {
    }

    public record PromotionView(boolean saved, boolean stale, boolean published, boolean cancelled, boolean imageAvailable,
                                String headline, String invitation, String groupBody, String momentsCaption,
                                String groupPath, String momentsPath, String posterPath, String whenText, String location,
                                String organizationName, String contactName, String contactMethod, String refundNote,
                                String bannerFileId, List<FeeLine> fees, String factDigest, String eventName, String projectName,
                                boolean imageEnabled, String visualFileId, String visualStyle, boolean visualStale, String copySource) {
    }
}
