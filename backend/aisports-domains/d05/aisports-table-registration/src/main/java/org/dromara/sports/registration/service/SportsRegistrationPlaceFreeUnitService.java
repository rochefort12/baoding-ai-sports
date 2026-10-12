package org.dromara.sports.registration.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import lombok.RequiredArgsConstructor;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.api.CompetitionSetupApi;
import org.dromara.sports.api.CompetitionTypeApi;
import org.dromara.sports.api.EventRegistrationApi;
import org.dromara.sports.api.EventRegistrationApi.EventRegistrationGate;
import org.dromara.sports.api.FeeApi;
import org.dromara.sports.registration.RegistrationRules;
import org.dromara.sports.registration.domain.SportsCapacityPool;
import org.dromara.sports.registration.domain.SportsCompetitionUnit;
import org.dromara.sports.registration.domain.SportsEntryFieldValue;
import org.dromara.sports.registration.domain.SportsEventField;
import org.dromara.sports.registration.domain.SportsRegistration;
import org.dromara.sports.registration.domain.SportsSport;
import org.dromara.sports.registration.domain.DraftRevisionEvent;
import org.dromara.sports.registration.mapper.SportsCapacityPoolMapper;
import org.dromara.sports.registration.mapper.SportsCompetitionUnitMapper;
import org.dromara.sports.registration.mapper.SportsEntryFieldValueMapper;
import org.dromara.sports.registration.mapper.SportsEventFieldMapper;
import org.dromara.sports.registration.mapper.SportsRegistrationMapper;
import org.dromara.sports.registration.mapper.SportsSportMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.dromara.sports.platform.core.BusinessIdentity;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.ArrayList;
import java.util.Objects;

/**
 * 创建候选项目与名额；免费必须由调用方明确选择。加入已有事务，不自己提交。
 */
@Service
@RequiredArgsConstructor
public class SportsRegistrationPlaceFreeUnitService implements CompetitionSetupApi {

    static final BigDecimal FREE_AMOUNT = new BigDecimal("0.00");
    static final String FREE_MODE = "free";
    private static final ZoneOffset SHANGHAI = ZoneOffset.ofHours(8);

    private final EventRegistrationApi eventRegistrationApi;
    private final FeeApi feeApi;
    private final SportsCompetitionUnitMapper unitMapper;
    private final SportsCapacityPoolMapper poolMapper;
    private final SportsSportMapper sportMapper;
    private final SportsRegistrationMapper registrationMapper;
    private final SportsEventFieldMapper eventFieldMapper;
    private final SportsEntryFieldValueMapper fieldValueMapper;
    private final CompetitionTypeApi competitionTypes;

    @Override
    @Transactional(propagation = Propagation.MANDATORY, rollbackFor = Exception.class)
    public long placeFreeUnit(long eventId, String name, String entryType, Integer minMembers, Integer maxMembers, int limitCount) {
        return placeUnit(eventId, name, entryType, minMembers, maxMembers, limitCount, true);
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY, rollbackFor = Exception.class)
    public long placeUnpricedUnit(long eventId, String name, String entryType, Integer minMembers, Integer maxMembers, int limitCount) {
        return placeUnit(eventId, name, entryType, minMembers, maxMembers, limitCount, false);
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY, rollbackFor = Exception.class)
    public List<DraftUnit> currentDraftUnits(long eventId) {
        DraftRevisionEvent event = requireUnusedDraft(eventId);
        List<DraftUnit> current = new ArrayList<>();
        for (SportsCompetitionUnit unit : unitMapper.selectList(Wrappers.<SportsCompetitionUnit>lambdaQuery()
            .eq(SportsCompetitionUnit::getEventId, eventId).orderByAsc(SportsCompetitionUnit::getId))) {
            requireDraftUnit(event, unit);
            SportsCapacityPool pool = draftPool(event, unit.getId());
            current.add(new DraftUnit(unit.getId(), unit.getName(), unit.getEntryType(),
                unit.getMinMembers(), unit.getMaxMembers(), pool.getLimitCount(), unit.getStatus(), pool.getStatus()));
        }
        return List.copyOf(current);
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY, rollbackFor = Exception.class)
    public List<DraftUnit> publicationUnits(long eventId) {
        EventRegistrationGate gate = eventRegistrationApi.managedGate(eventId)
            .orElseThrow(() -> new ServiceException("赛事不存在"));
        if (!Objects.equals(BusinessIdentity.getTenantId(), gate.tenantId())) throw new ServiceException("组织会话不匹配");
        DraftRevisionEvent event = unitMapper.lockDraftEvent(gate.tenantId(), eventId);
        if (event == null || !Objects.equals(gate.tenantId(), event.getTenantId())
            || !Objects.equals(gate.organizationId(), event.getOrganizationId())) throw new ServiceException("赛事不存在");
        if (!"normal".equals(event.getHoldingStatus())
            || !List.of("draft", "published", "offline").contains(event.getPublicationStatus())) {
            throw new ServiceException("当前赛事不能核对发布目录");
        }
        List<DraftUnit> catalog = new ArrayList<>();
        for (SportsCompetitionUnit unit : unitMapper.selectList(Wrappers.<SportsCompetitionUnit>lambdaQuery()
            .eq(SportsCompetitionUnit::getEventId, eventId).orderByAsc(SportsCompetitionUnit::getId))) {
            if (!Objects.equals(eventId, unit.getEventId()) || !Objects.equals(gate.tenantId(), unit.getTenantId())) {
                throw new ServiceException("赛事项目归属不匹配，请刷新后核对");
            }
            // 既有目录写入口均先锁赛事；此处不锁容量，不把已有占用或停用状态当成缺项。
            SportsCapacityPool pool = poolMapper.selectOne(Wrappers.<SportsCapacityPool>lambdaQuery()
                .eq(SportsCapacityPool::getUnitId, unit.getId()));
            if (pool == null || !Objects.equals(eventId, pool.getEventId())
                || !Objects.equals(gate.tenantId(), pool.getTenantId()) || pool.getLimitCount() == null) {
                throw new ServiceException("项目报名上限未配置，请刷新后核对");
            }
            catalog.add(new DraftUnit(unit.getId(), unit.getName(), unit.getEntryType(),
                unit.getMinMembers(), unit.getMaxMembers(), pool.getLimitCount(), unit.getStatus(), pool.getStatus()));
        }
        return List.copyOf(catalog);
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY, rollbackFor = Exception.class)
    public void updateUnusedDraftUnit(long eventId, long unitId, String name, String entryType,
                                      Integer minMembers, Integer maxMembers, int limitCount) {
        if (limitCount < 1) throw new ServiceException("请填写至少 1 个名额");
        String unitName = required(name);
        RegistrationRules.MemberBounds bounds = RegistrationRules.bounds(entryType, minMembers, maxMembers);
        if (!"individual".equals(entryType) && !"pair".equals(entryType)) {
            throw new ServiceException("一期开放羽毛球单打1人和双打2人，其他类型待规则验证后开放");
        }
        DraftRevisionEvent event = requireUnusedDraft(eventId);
        SportsCompetitionUnit unit = unitMapper.selectOne(Wrappers.<SportsCompetitionUnit>lambdaQuery()
            .eq(SportsCompetitionUnit::getId, unitId).last("FOR UPDATE"));
        requireDraftUnit(event, unit);
        SportsCapacityPool pool = draftPool(event, unitId);
        Long duplicated = unitMapper.selectCount(Wrappers.<SportsCompetitionUnit>lambdaQuery()
            .eq(SportsCompetitionUnit::getEventId, eventId)
            .eq(SportsCompetitionUnit::getStatus, "open").ne(SportsCompetitionUnit::getId, unitId)
            .apply("lower(btrim(name)) = lower({0})", unitName));
        if (duplicated != null && duplicated > 0) throw new ServiceException("这个赛事里已经有同名项目");
        Long typeId = competitionTypes.supported(unit.getSportId(), entryType, bounds.min(), bounds.max())
            .orElseThrow(() -> new ServiceException("一期开放羽毛球单打1人和双打2人，其他类型待规则验证后开放"));
        // 更新现有编号而非重建项目。费用、报名和 AI 候选继续指向同一项目。
        if (!unitName.equals(unit.getName()) || !entryType.equals(unit.getEntryType())
            || !Objects.equals(bounds.min(), unit.getMinMembers()) || !Objects.equals(bounds.max(), unit.getMaxMembers())
            || !Objects.equals(typeId, unit.getCompetitionTypeId())) {
            unit.setName(unitName);
            unit.setEntryType(entryType);
            unit.setMinMembers(bounds.min());
            unit.setMaxMembers(bounds.max());
            unit.setCompetitionTypeId(typeId);
            if (unitMapper.updateById(unit) != 1) throw new ServiceException("项目刚被更新，请刷新后再保存");
        }
        if (!Objects.equals(limitCount, pool.getLimitCount())) {
            pool.setLimitCount(limitCount);
            if (poolMapper.updateById(pool) != 1) throw new ServiceException("名额刚被更新，请刷新后再保存");
        }
    }

    private DraftRevisionEvent requireUnusedDraft(long eventId) {
        EventRegistrationGate gate = eventRegistrationApi.managedGate(eventId)
            .orElseThrow(() -> new ServiceException("赛事不存在"));
        if (!Objects.equals(BusinessIdentity.getTenantId(), gate.tenantId())) {
            throw new ServiceException("组织会话不匹配");
        }
        DraftRevisionEvent event = unitMapper.lockDraftEvent(gate.tenantId(), eventId);
        if (event == null || !Objects.equals(gate.tenantId(), event.getTenantId())
            || !Objects.equals(gate.organizationId(), event.getOrganizationId())) throw new ServiceException("赛事不存在");
        if (!"draft".equals(event.getPublicationStatus()) || !"normal".equals(event.getHoldingStatus())) {
            throw new ServiceException("只有未发布的办赛草稿可以继续修改项目");
        }
        if (!Objects.equals(0, event.getPublishedRevision()) || Boolean.TRUE.equals(event.getRegistrationReviewLocked())
            || unitMapper.hasDraftBusinessHistory(gate.tenantId(), eventId)) {
            throw new ServiceException("赛事已有发布、报名或资金历史，不能继续修改草稿项目");
        }
        return event;
    }

    private void requireDraftUnit(DraftRevisionEvent event, SportsCompetitionUnit unit) {
        if (unit == null || !Objects.equals(event.getId(), unit.getEventId())
            || !Objects.equals(event.getTenantId(), unit.getTenantId()) || !"open".equals(unit.getStatus())) {
            throw new ServiceException("草稿项目不存在或已停止办理");
        }
    }

    private SportsCapacityPool draftPool(DraftRevisionEvent event, Long unitId) {
        SportsCapacityPool pool = poolMapper.selectOne(Wrappers.<SportsCapacityPool>lambdaQuery()
            .eq(SportsCapacityPool::getUnitId, unitId).last("FOR UPDATE"));
        if (pool == null || !Objects.equals(event.getTenantId(), pool.getTenantId())
            || !Objects.equals(event.getId(), pool.getEventId()) || !"active".equals(pool.getStatus())
            || !"entry".equals(pool.getCapacityUnit()) || !"entry".equals(pool.getDedupeScope())
            || pool.getLimitCount() == null || pool.getLimitCount() < 1
            || pool.getUsedCount() == null || pool.getUsedCount() != 0) {
            throw new ServiceException("草稿名额不存在或已有占用，请刷新后核对");
        }
        return pool;
    }

    private long placeUnit(long eventId, String name, String entryType, Integer minMembers, Integer maxMembers, int limitCount, boolean confirmedFree) {
        if (limitCount < 1) {
            throw new ServiceException("请填写至少 1 个名额");
        }
        String unitName = required(name);
        RegistrationRules.MemberBounds bounds = RegistrationRules.bounds(entryType, minMembers, maxMembers);
        EventRegistrationGate gate = eventRegistrationApi.managedGate(eventId)
            .orElseThrow(() -> new ServiceException("赛事不存在"));
        // 和发布预览核对共用赛事行锁；目录、容量及初始配价均在调用方同一事务提交。
        DraftRevisionEvent event = unitMapper.lockDraftEvent(gate.tenantId(), eventId);
        if (event == null || !Objects.equals(gate.tenantId(), event.getTenantId())
            || !Objects.equals(gate.organizationId(), event.getOrganizationId())) throw new ServiceException("赛事不存在");
        if (!"normal".equals(event.getHoldingStatus())) {
            throw new ServiceException("已取消的赛事不能建立竞赛项目");
        }
        if (event.getEndsAt() != null && !OffsetDateTime.now(SHANGHAI).isBefore(event.getEndsAt())) {
            throw new ServiceException("比赛已经结束，不能建立竞赛项目");
        }
        Long duplicated = unitMapper.selectCount(Wrappers.<SportsCompetitionUnit>lambdaQuery()
            .eq(SportsCompetitionUnit::getEventId, gate.eventId())
            .eq(SportsCompetitionUnit::getStatus, "open")
            .apply("lower(btrim(name)) = lower({0})", unitName));
        if (duplicated != null && duplicated > 0) {
            throw new ServiceException("这个赛事里已经有同名项目");
        }
        SportsCompetitionUnit unit = new SportsCompetitionUnit();
        unit.setTenantId(gate.tenantId());
        unit.setEventId(gate.eventId());
        unit.setSportId(badmintonId());
        unit.setCompetitionTypeId(competitionTypes.supported(unit.getSportId(),entryType,bounds.min(),bounds.max())
            .orElseThrow(() -> new ServiceException("一期开放羽毛球单打1人和双打2人，其他类型待规则验证后开放")));
        unit.setName(unitName);
        unit.setEntryType(entryType);
        unit.setMinMembers(bounds.min());
        unit.setMaxMembers(bounds.max());
        unit.setStatus("open");
        unit.setVersion(0);
        unitMapper.insert(unit);
        SportsCapacityPool pool = new SportsCapacityPool();
        pool.setTenantId(gate.tenantId());
        pool.setEventId(gate.eventId());
        pool.setUnitId(unit.getId());
        pool.setCapacityUnit("entry");
        pool.setDedupeScope("entry");
        pool.setLimitCount(limitCount);
        pool.setUsedCount(0);
        pool.setStatus("active");
        pool.setVersion(0);
        poolMapper.insert(pool);
        // AI 资料中的费用文字不是收费授权，不能自动变为有效的免费版本。
        if (confirmedFree) feeApi.placeInitialPolicy(gate.tenantId(), unit.getId(), FREE_AMOUNT, FREE_MODE, null, null);
        return unit.getId();
    }

    @Override
    public void discardEmptyDraftUnits(long eventId) {
        EventRegistrationGate gate = eventRegistrationApi.managedGate(eventId)
            .orElseThrow(() -> new ServiceException("赛事不存在"));
        if (!"draft".equals(gate.publicationStatus()) || !"normal".equals(gate.holdingStatus())) {
            throw new ServiceException("只有未发布的办赛草稿可以删除");
        }
        List<SportsCompetitionUnit> units = unitMapper.selectList(Wrappers.<SportsCompetitionUnit>lambdaQuery()
            .eq(SportsCompetitionUnit::getEventId, gate.eventId()));
        if (units == null) {
            units = List.of();
        }
        for (SportsCompetitionUnit unit : units) {
            Long entries = registrationMapper.selectCount(Wrappers.<SportsRegistration>lambdaQuery()
                .eq(SportsRegistration::getUnitId, unit.getId()));
            if (entries != null && entries > 0) {
                throw new ServiceException("已有报名，不能删除这场办赛草稿");
            }
            SportsCapacityPool pool = poolMapper.selectOne(Wrappers.<SportsCapacityPool>lambdaQuery()
                .eq(SportsCapacityPool::getUnitId, unit.getId()));
            if (pool != null && pool.getUsedCount() != null && pool.getUsedCount() > 0) {
                throw new ServiceException("名额已被占用，不能删除这场办赛草稿");
            }
        }
        List<SportsEventField> fields = eventFieldMapper.selectList(Wrappers.<SportsEventField>lambdaQuery()
            .eq(SportsEventField::getEventId, gate.eventId()));
        if (fields != null) {
            for (SportsEventField field : fields) {
                Long values = fieldValueMapper.selectCount(Wrappers.<SportsEntryFieldValue>lambdaQuery()
                    .eq(SportsEntryFieldValue::getEventFieldId, field.getId()));
                if (values != null && values > 0) {
                    throw new ServiceException("已有报名资料，不能删除这场办赛草稿");
                }
            }
        }
        // 配置金额及收款方式不等于已有付款；资金侧复验全部历史并先清理配置外键。
        // 调用方持有赛事行锁和事务，后续删除失败时价格、名额及赛事一起回滚。
        feeApi.discardUnusedDraftPricing(gate.tenantId(), gate.eventId());
        if (fields != null) {
            for (SportsEventField field : fields) {
                eventFieldMapper.deleteById(field.getId());
            }
        }
        for (SportsCompetitionUnit unit : units) {
            poolMapper.delete(Wrappers.<SportsCapacityPool>lambdaQuery().eq(SportsCapacityPool::getUnitId, unit.getId()));
            unitMapper.deleteById(unit.getId());
        }
    }

    private Long badmintonId() {
        SportsSport sport = sportMapper.selectOne(Wrappers.<SportsSport>lambdaQuery()
            .eq(SportsSport::getCode, "badminton")
            .eq(SportsSport::getStatus, "active"));
        if (sport == null) {
            throw new ServiceException("羽毛球目录未初始化");
        }
        return sport.getId();
    }

    private String required(String name) {
        if (name == null || name.isBlank() || name.trim().length() > 200) {
            throw new ServiceException("请填写项目名称");
        }
        return name.trim();
    }
}
