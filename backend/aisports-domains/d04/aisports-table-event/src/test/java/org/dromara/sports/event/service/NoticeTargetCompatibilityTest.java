package org.dromara.sports.event.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.sports.event.domain.SportsNotification;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.Arrays;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 消息历史不重写，只恢复与真实业务编号精确匹配的已知目标。 */
@Tag("local")
class NoticeTargetCompatibilityTest {
    EventCancellationNoticeService service() throws Exception {
        var constructor=EventCancellationNoticeService.class.getDeclaredConstructors()[0];
        return (EventCancellationNoticeService)constructor.newInstance(Arrays.stream(constructor.getParameterTypes()).map(type->type==ObjectMapper.class?new ObjectMapper():mock(type)).toArray());
    }
    String target(String type,String purpose,String content) throws Exception {
        var notice=new SportsNotification();notice.setId(99L);notice.setBusinessId(42L);notice.setBusinessType(type);notice.setPurpose(purpose);notice.setContent(content);
        var method=EventCancellationNoticeService.class.getDeclaredMethod("toCard",SportsNotification.class);method.setAccessible(true);
        return ((EventCancellationNoticeService.NoticeCard)method.invoke(service(),notice)).targetPath();
    }
    @Test void legacyComplaintUsesExactBusinessId() throws Exception { assertEquals("/portal/issues/42",target("complaint","progress","{\"target\":\"/portal/issues/42\"}")); }
    @Test void legacyQualificationKeepsTheExistingTask() throws Exception { assertEquals("/portal/organization",target("organization","qualification","{\"target\":\"/portal/organization\"}")); }
    @Test void unrelatedObjectCannotChooseAnotherComplaint() throws Exception { assertNull(target("complaint","progress","{\"target\":\"/portal/issues/43\"}")); }
    @Test void externalAndUnknownLegacyTargetsAreNotRestored() throws Exception { assertNull(target("complaint","progress","{\"target\":\"https://example.invalid\"}"));assertNull(target("organization","other","{\"target\":\"/portal/organization\"}")); }
    @Test void currentTargetPathDoesNotLoseExistingInvitationSupport() throws Exception { assertEquals("/portal/teams/invitations/42",target("team-invite","invite","{\"targetPath\":\"/portal/teams/invitations/42\"}")); }
}
