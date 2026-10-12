package org.dromara.sports.api;

import java.util.List;

/**
 * 在当前办赛事务里建立竞赛项目与名额。
 * 调用方负责赛事草稿和事务边界。这里不发布、不写收款码、不接收客户端传来的金额。
 */
public interface CompetitionSetupApi {

    /**
     * 个人和双打的人数由报名规则固定。团体必须自带上下限。名额至少为 1。
     * AI 候选只建立项目和名额，不猜测金额；人工确认收费版本后才能发布/报名。
     */
    long placeUnpricedUnit(long eventId, String name, String entryType, Integer minMembers, Integer maxMembers, int limitCount);

    /** 仅调用方已经明确确认免费时使用；固定金额 0、方式 free。 */
    long placeFreeUnit(long eventId, String name, String entryType, Integer minMembers, Integer maxMembers, int limitCount);

    /**
     * 调用方同一事务中读取本人组织、从未发布且没有报名业务历史的草稿项目。
     * 顺序按原项目编号；编号用于后续同步，不以名称猜测或重建目录。
     */
    List<DraftUnit> currentDraftUnits(long eventId);

    /**
     * 发布核对使用的实际完整目录快照，按项目编号升序，包含停用项目/容量的现有配置。
     * 加入调用方短事务并锁本人组织赛事；正常的草稿、已发布或下线赛事均可读取。
     * 不套用空草稿历史限制，不修改项目或名额；发布动作据此核对形式、人数和当前报名上限。
     */
    List<DraftUnit> publicationUnits(long eventId);

    /**
     * 在调用方事务内修改空草稿的同一项目及容量；保留项目、名额编号，不新增或删除目录。
     * 复核赛事锁、组织归属及历史；一期只开放单打 1 人与双打 2 人。
     */
    void updateUnusedDraftUnit(long eventId, long unitId, String name, String entryType,
                               Integer minMembers, Integer maxMembers, int limitCount);

    record DraftUnit(Long unitId, String name, String entryType, Integer minMembers,
                     Integer maxMembers, int limitCount, String status, String capacityStatus) {
        /** 兼容既有候选/测试构造；正式数据库快照必须填写实际项目和容量状态。 */
        public DraftUnit(Long unitId, String name, String entryType, Integer minMembers,
                         Integer maxMembers, int limitCount) {
            this(unitId, name, entryType, minMembers, maxMembers, limitCount, null, null);
        }
    }

    /**
     * 删除未发布赛事上的空项目、名额和采集项。
     * 已有报名、名额占用或资金历史时拒绝；未使用的收费配置随草稿删除，不释放资金、不删除正式报名。
     */
    void discardEmptyDraftUnits(long eventId);
}
