package org.dromara.sports.identity;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.identity.ParticipantEntry;
import org.dromara.sports.identity.domain.SportsAccount;
import org.dromara.sports.identity.domain.SportsConsent;
import org.dromara.sports.identity.domain.SportsLoginIdentity;
import org.dromara.sports.identity.mapper.SportsAccountMapper;
import org.dromara.sports.identity.mapper.SportsConsentMapper;
import org.dromara.sports.identity.mapper.SportsLoginIdentityMapper;
import org.dromara.sports.api.CallerContext;
import org.dromara.sports.identity.service.IdentityService;
import org.dromara.system.domain.SysUser;
import org.dromara.system.mapper.SysUserMapper;
import org.dromara.web.service.ParticipantRegisterService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;
import org.dromara.common.redis.utils.RedisUtils;
import org.dromara.sports.event.ai.OperationsChatStore;
import java.time.Duration;
import java.util.ArrayList;
import java.util.UUID;

import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * M1.1 身份规则。仅专用集成测试库运行，事务回滚，不保留测试档案。
 */
@SpringBootTest
@ActiveProfiles("local")
@Tag("integration-local")
@Transactional
class IdentitySliceTest {

    @Autowired
    private IdentityService identityService;
    @Autowired
    private SportsConsentMapper consentMapper;
    @Autowired
    private SportsLoginIdentityMapper loginIdentityMapper;
    @Autowired
    private SportsAccountMapper accountMapper;
    @Autowired
    private ParticipantRegisterService registerService;
    @Autowired
    private SysUserMapper userMapper;
    @Autowired
    private OperationsChatStore operationsChats;

    /** 必须通过隔离入口运行，防止直接启用测试组时误写共用库/Redis。 */
    @org.junit.jupiter.api.BeforeEach
    void requireIsolatedInfrastructure() {
        assertTrue(System.getenv("POSTGRES_DB").matches("aisports_verify_identity_[a-f0-9]{32}"));
        assertTrue(System.getProperty("redisson.keyPrefix", "").matches("aisports:verify:[a-f0-9]{32}:"));
    }

    @Test
    @DisplayName("真实Redis暂存24小时，追加不续期，账号与组织隔离，删除正文和索引")
    void realRedisSessionBoundaries() {
        var first = operationsChats.remember(-601, -201, null, "隔离测试", "隔离回复");
        assertTrue(first.retained());
        String key = "sports:ai:ops:-601:-201:" + first.sessionId();
        try {
            long ttl = RedisUtils.getTimeToLive(key);
            assertTrue(ttl > Duration.ofHours(23).toMillis() && ttl <= Duration.ofHours(24).toMillis());
            var next = operationsChats.remember(-601, -201, first.sessionId(), "继续", "回复");
            assertEquals(first.expiresAt(), next.expiresAt());
            assertEquals(4, next.turns().size());
            assertNull(operationsChats.read(-602, -201, first.sessionId()));
            assertNull(operationsChats.read(-601, -202, first.sessionId()));
            operationsChats.discard(-601, -201, first.sessionId());
            assertNull(operationsChats.read(-601, -201, first.sessionId()));
            assertTrue(operationsChats.list(-601, -201).isEmpty());
            assertFalse(RedisUtils.isExistsObject(key));
        } finally {
            RedisUtils.deleteObject(key);
            RedisUtils.deleteObject("sports:ai:ops:-601:-201:index");
        }
    }

    @Test
    @DisplayName("真实Redis第九段淘汰最旧正文，实际过期后不再返回列表")
    void realRedisLimitAndExpiry() throws InterruptedException {
        var ids = new ArrayList<String>();
        try {
            for (int i = 0; i < operationsChats.sessionLimit() + 1; i++) {
                String id = UUID.randomUUID().toString(); ids.add(id);
                assertTrue(operationsChats.remember(-603, -203, id, "隔离" + i, "回复").retained());
            }
            assertEquals(operationsChats.sessionLimit(), operationsChats.list(-603, -203).size());
            assertNull(operationsChats.read(-603, -203, ids.get(0)));
            assertFalse(RedisUtils.isExistsObject("sports:ai:ops:-603:-203:" + ids.get(0)));
            String newest = ids.get(ids.size() - 1);
            assertTrue(RedisUtils.expire("sports:ai:ops:-603:-203:" + newest, Duration.ofMillis(50)));
            long deadline = System.nanoTime() + Duration.ofSeconds(2).toNanos();
            while (operationsChats.read(-603, -203, newest) != null && System.nanoTime() < deadline) Thread.sleep(20);
            assertNull(operationsChats.read(-603, -203, newest));
            assertEquals(operationsChats.sessionLimit() - 1, operationsChats.list(-603, -203).size());
        } finally {
            for (String id : ids) RedisUtils.deleteObject("sports:ai:ops:-603:-203:" + id);
            RedisUtils.deleteObject("sports:ai:ops:-603:-203:index");
        }
    }

    @Test
    @DisplayName("同名是两份档案，只能操作本人，出生日期不能晚于今天")
    void sameNameStaysSeparateAndBirthDateCannotBeFuture() {
        Long parent = identityService.openAccount("家长", null).getId();
        Long stranger = identityService.openAccount("陌生人", null).getId();
        Long selfId = identityService.bindSelf(parent, "张伟", LocalDate.of(1990, 5, 1), "male", "13800001001").getId();
        Long otherId = identityService.bindSelf(stranger, "张伟", LocalDate.of(1992, 8, 8), "male", "13800001002").getId();
        assertNotEquals(selfId, otherId);
        assertEquals(selfId, identityService.bindSelf(parent, "张伟", LocalDate.of(1990, 5, 1), "male", "13800001009").getId());
        assertTrue(identityService.isSelf(parent, selfId));
        assertFalse(identityService.isSelf(parent, otherId));
        assertFalse(identityService.isSelf(stranger, selfId));
        CallerContext parentCaller = new CallerContext(ParticipantEntry.TENANT_ID, parent, "test");
        assertTrue(identityService.canRegister(parentCaller, selfId));
        assertFalse(identityService.canRegister(parentCaller, otherId));
        assertEquals(1L, consents(selfId, IdentityService.SELF_PROFILE));
        assertThrows(ServiceException.class, () -> identityService.bindSelf(stranger, "张伟", LocalDate.now().plusDays(1), "male", "13800001002"));
    }

    @Test
    @DisplayName("手机号注册只创建登录、平台账号和已验证渠道，重复手机号被拒绝")
    void registerCreatesLoginWithoutPerson() {
        String phone = "13800138000";
        Long userId = registerService.createVerifiedLogin(phone, "pass1234");
        SysUser user = userMapper.selectById(userId);
        assertEquals(ParticipantEntry.TENANT_ID, user.getTenantId());
        assertEquals("app_user", user.getUserType());
        assertEquals(phone, user.getUserName());
        assertEquals(phone, user.getPhonenumber());
        String hash = identityService.phoneHash(phone);
        Long channels = loginIdentityMapper.selectCount(Wrappers.<SportsLoginIdentity>lambdaQuery()
            .eq(SportsLoginIdentity::getChannel, IdentityService.PHONE_CHANNEL)
            .eq(SportsLoginIdentity::getSubjectHash, hash)
            .isNull(SportsLoginIdentity::getValidUntil));
        assertEquals(1L, channels);
        SportsAccount account = accountMapper.selectOne(Wrappers.<SportsAccount>lambdaQuery()
            .eq(SportsAccount::getBackendUserId, userId));
        assertNotNull(account);
        assertNotNull(account.getPasswordHash());
        assertFalse(account.getPasswordHash().isBlank());
        assertThrows(ServiceException.class, () -> registerService.createVerifiedLogin(phone, "pass1234"));
        assertThrows(ServiceException.class, () -> registerService.createVerifiedLogin("12345", "pass1234"));
    }

    private long consents(Long personId, String purpose) {
        Long count = consentMapper.selectCount(Wrappers.<SportsConsent>lambdaQuery()
            .eq(SportsConsent::getPersonId, personId)
            .eq(SportsConsent::getPurpose, purpose));
        return count == null ? 0L : count;
    }
}
