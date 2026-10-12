package org.dromara.sports.event.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.FeeApi.PublicUnitPrice;
import org.dromara.sports.api.PublicEventGuideApi;
import org.dromara.sports.api.RegistrationGuideApi;
import org.dromara.sports.event.ai.SportsEventAiProperties;
import org.dromara.sports.event.service.EventPublicationService.EventCard;
import org.dromara.sports.event.service.EventPublicationService.PublicFeeView;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

/**
 * 参赛引导的检索工具。身份只用调用方登录态传来的账号，忽略模型参数里的账号。
 */
@Service
@RequiredArgsConstructor
public class ConsumerGuideToolService implements PublicEventGuideApi {

    private final EventPublicationService events;
    private final RegistrationGuideApi registrations;
    private final SportsEventAiProperties properties;
    private final ObjectMapper mapper;

    public String call(Long accountId, String name, JsonNode arguments) {
        JsonNode args = arguments == null || arguments.isNull() ? mapper.createObjectNode() : arguments;
        return switch (name == null ? "" : name) {
            case "search_public_events" -> searchPublic(args.path("text").asText(""), args.path("project").asText(""),
                args.path("phase").asText(""), args.path("includeCancelled").asBoolean(false), args.path("offset").asInt(0));
            case "read_public_event" -> readPublic(args.path("eventId").asLong(0));
            case "read_my_registrations" -> registrations.myStatus(accountId, args.path("offset").asInt(0));
            default -> "{\"refused\":true}";
        };
    }

    @Override
    public String searchPublic(String text, String project, String phase, boolean includeCancelled, int offset) {
        PublicEventSearch.Page page = events.searchPublic(new PublicEventSearch.Query(text, project, phase, includeCancelled, offset));
        ObjectNode root = mapper.createObjectNode();
        root.put("total", page.total());
        root.put("offset", page.offset());
        root.put("limit", page.limit());
        root.put("hasMore", page.hasMore());
        ArrayNode items = root.putArray("events");
        for (EventCard event : page.events()) {
            items.add(summary(event));
        }
        return root.toString();
    }

    @Override
    public String readPublic(long eventId) {
        try {
            EventCard event = events.findPublic(eventId);
            PublicFeeView fees = events.publicFees(eventId);
            ObjectNode root = summary(event);
            root.put("registrationReview", event.registrationReview() == null ? "" : event.registrationReview());
            root.put("rulesText", bound(event.rulesText()));
            root.put("noticeText", bound(event.noticeText()));
            root.put("refundNote", bound(fees.refundNote()));
            root.put("rulesHaveImage", event.rulesFileId() != null);
            root.put("textTruncated", length(event.rulesText()) > 1500 || length(event.noticeText()) > 1500);
            ArrayNode prices = root.putArray("prices");
            for (PublicUnitPrice unit : fees.units()) {
                prices.addObject()
                    .put("name", unit.unitName() == null ? "" : unit.unitName())
                    .put("amount", unit.amount() == null ? "" : unit.amount().toPlainString())
                    .put("paymentMode", unit.paymentMode() == null ? "" : unit.paymentMode());
            }
            return root.toString();
        } catch (ServiceException exception) {
            return "{\"found\":false}";
        }
    }

    private ObjectNode summary(EventCard event) {
        ObjectNode node = mapper.createObjectNode();
        node.put("eventId", event.id() == null ? "" : event.id().toString());
        node.put("name", event.name() == null ? "" : event.name());
        node.put("projectName", event.projectName() == null ? "" : event.projectName());
        node.put("location", event.location() == null ? "" : event.location());
        node.put("phase", event.phase() == null ? "" : event.phase());
        node.put("holdingStatus", event.holdingStatus() == null ? "" : event.holdingStatus());
        node.put("startsAt", event.startsAt() == null ? "" : event.startsAt().toString());
        node.put("registrationClosesAt", event.registrationClosesAt() == null ? "" : event.registrationClosesAt().toString());
        node.put("feeDescription", bound(event.feeDescription()));
        return node;
    }

    public void requireToken(String presented) {
        String expected = properties.getInternalToken();
        byte[] actual = presented == null ? new byte[0] : presented.getBytes(StandardCharsets.UTF_8);
        byte[] wanted = expected == null ? new byte[0] : expected.getBytes(StandardCharsets.UTF_8);
        if (!properties.tokenConfigured() || !MessageDigest.isEqual(wanted, actual)) {
            throw new ServiceException("内部调用未授权");
        }
    }

    private static int length(String value) {
        return value == null ? 0 : value.length();
    }

    private static String bound(String value) {
        if (value == null) {
            return "";
        }
        return value.length() <= 1500 ? value : value.substring(0, 1500);
    }
}
