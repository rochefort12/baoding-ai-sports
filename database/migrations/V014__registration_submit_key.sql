-- 已完成的报名提交请求键。不改写已应用迁移。
-- 已有报名若名单版本大于 0，当前请求键已经完成过一次提交，回填一行。
-- 回填主键沿用报名主键：历史数据每个报名最多一个已完成请求键。新提交仍由应用分配雪花 ID。

COMMENT ON TABLE asp_registration IS '竞赛单元报名。草稿不占名额；已提交和已通过占名额；撤回回到草稿；来源：母版 D05；同一提交人在同一单元只有一条报名。代表队伍的报名按 team_id 识别当前可办理的那一条，不另加一队一单元的唯一约束。已经完成提交的请求键只重放该次事实，不第二次占名额，撤回后也不复活报名。名额排队使用通用锁，used_count 只做上限。';
COMMENT ON COLUMN asp_registration.request_key IS '当前办理请求键。尚未完成提交时沿用创建键；完成后的重放不再占用，主动重提更换新键';

CREATE TABLE asp_registration_submit_key (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    registration_id bigint NOT NULL,
    submitter_account_id bigint NOT NULL,
    request_key varchar(128) NOT NULL,
    roster_revision integer NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (roster_revision > 0),
    CHECK (length(tenant_id) > 0),
    CHECK (roster_revision >= 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_registration_submit_key IS '已经完成的报名提交请求键。撤回或拒绝后重放旧键不得再次占用；来源：母版 D05；同一提交人的一个请求键只完成一次提交。主动重提使用新键并另记一行，对应这次的名单版本和独立付款义务。未完成提交的创建键不记入本表。';
COMMENT ON COLUMN asp_registration_submit_key.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_registration_submit_key.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_registration_submit_key.registration_id IS '报名';
COMMENT ON COLUMN asp_registration_submit_key.submitter_account_id IS '提交人';
COMMENT ON COLUMN asp_registration_submit_key.request_key IS '已经完成一次提交的请求键';
COMMENT ON COLUMN asp_registration_submit_key.roster_revision IS '这次提交冻结的名单版本';
COMMENT ON COLUMN asp_registration_submit_key.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_registration_submit_key.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_registration_submit_key.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_registration_submit_key.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_registration_submit_key.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_registration_submit_key.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE INDEX ix_asp_registration_submit_key_48c5af2b13 ON asp_registration_submit_key (tenant_id, registration_id);
CREATE INDEX ix_asp_registration_submit_key_6abb4d96f7 ON asp_registration_submit_key (submitter_account_id);
CREATE UNIQUE INDEX uq_asp_registration_submit_key_1f6ecc624c ON asp_registration_submit_key (tenant_id, submitter_account_id, request_key);
CREATE UNIQUE INDEX uq_asp_registration_submit_key_e7847965a9 ON asp_registration_submit_key (tenant_id, registration_id, roster_revision);
ALTER TABLE asp_registration_submit_key ADD CONSTRAINT fk_asp_registration_submit_key_48c5af2b13 FOREIGN KEY (tenant_id, registration_id) REFERENCES asp_registration (tenant_id, id);
ALTER TABLE asp_registration_submit_key ADD CONSTRAINT fk_asp_registration_submit_key_6abb4d96f7 FOREIGN KEY (submitter_account_id) REFERENCES asp_account (id);

INSERT INTO asp_registration_submit_key (
    id, tenant_id, registration_id, submitter_account_id, request_key, roster_revision, create_time, update_time, version
)
SELECT id, tenant_id, id, submitter_account_id, request_key, roster_revision, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0
FROM asp_registration
WHERE roster_revision > 0;
