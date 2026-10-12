-- M1.3 赛事公开。发布状态和举办状态分开。公开查询不改租户拦截器。

ALTER TABLE asp_event ALTER COLUMN name DROP NOT NULL;
ALTER TABLE asp_event ADD COLUMN location varchar(200);
ALTER TABLE asp_event ADD COLUMN project_name varchar(200);
ALTER TABLE asp_event ADD COLUMN fee_description varchar(1000);
ALTER TABLE asp_event ADD COLUMN cancel_reason varchar(1000);
ALTER TABLE asp_event ADD COLUMN sport_code varchar(32) NOT NULL DEFAULT 'badminton';
ALTER TABLE asp_event ADD COLUMN publication_status varchar(32) NOT NULL DEFAULT 'draft';
ALTER TABLE asp_event ADD COLUMN holding_status varchar(32) NOT NULL DEFAULT 'normal';
ALTER TABLE asp_event ADD CONSTRAINT ck_asp_event_registration_before_start
    CHECK (registration_closes_at IS NULL OR starts_at IS NULL OR registration_closes_at <= starts_at);
ALTER TABLE asp_event ADD CONSTRAINT ck_asp_event_sport_code CHECK (sport_code = 'badminton');
ALTER TABLE asp_event ADD CONSTRAINT ck_asp_event_publication_status CHECK (publication_status IN ('draft', 'published', 'offline'));
ALTER TABLE asp_event ADD CONSTRAINT ck_asp_event_holding_status CHECK (holding_status IN ('normal', 'cancelled'));
COMMENT ON TABLE asp_event IS '赛事容器。M1.3 的发布和举办状态分开，时间阶段按北京时间计算';
COMMENT ON COLUMN asp_event.name IS '赛事名称。草稿可空，发布时必填';
COMMENT ON COLUMN asp_event.location IS '比赛地点。公开文字，不引用场馆';
COMMENT ON COLUMN asp_event.project_name IS '赛事项目。公开文字，不建竞赛单元';
COMMENT ON COLUMN asp_event.fee_description IS '收费方式或收费说明。公开文字，不产生付款';
COMMENT ON COLUMN asp_event.cancel_reason IS '取消原因。可空，有内容时出现在公开详情';
COMMENT ON COLUMN asp_event.sport_code IS '运动编码。本期只能是 badminton';
COMMENT ON COLUMN asp_event.publication_status IS '发布状态：draft published offline。已发布不能直接改公开信息';
COMMENT ON COLUMN asp_event.holding_status IS '举办状态：normal cancelled。取消不等于下架，已结束不能取消';
COMMENT ON COLUMN asp_event.visibility IS '旧可见性列。M1.3 公开与否不看它';

CREATE TABLE asp_event_command (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_id bigint NOT NULL,
    action varchar(32) NOT NULL,
    request_key varchar(128) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (length(tenant_id) > 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_event_command IS '赛事写操作幂等。同一租户、同一动作、同一请求键只生效一次';
COMMENT ON COLUMN asp_event_command.event_id IS '已经处理过的赛事';
COMMENT ON COLUMN asp_event_command.action IS '动作。本期只有 publish';
COMMENT ON COLUMN asp_event_command.request_key IS '客户端幂等键';
CREATE INDEX ix_asp_event_command_b779acfd64 ON asp_event_command (tenant_id, event_id);
CREATE UNIQUE INDEX uq_asp_event_command_7ec862025f ON asp_event_command (tenant_id, action, request_key);
ALTER TABLE asp_event_command ADD CONSTRAINT fk_asp_event_command_b779acfd64 FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);

INSERT INTO sys_menu
    (menu_id, menu_name, parent_id, order_num, path, component, is_frame, is_cache,
     menu_type, visible, status, perms, icon, create_time, remark)
VALUES
    (2106100000000000017, '赛事', 2106100000000000013, 2, 'events', 'sports/event/index', '1', '0',
     'C', '0', '0', 'sports:event:list', 'form', CURRENT_TIMESTAMP,
     '组织内的羽毛球赛事。公开页不在这个菜单。');

UPDATE sys_tenant_package
SET menu_ids = menu_ids || ',2106100000000000017'
WHERE package_id = 2106100000000000012
  AND position('2106100000000000017' in menu_ids) = 0;

INSERT INTO sys_role_menu (role_id, menu_id)
SELECT DISTINCT rm.role_id, 2106100000000000017
FROM sys_role_menu rm
WHERE rm.menu_id = 2106100000000000014
  AND NOT EXISTS (
      SELECT 1 FROM sys_role_menu existing
      WHERE existing.role_id = rm.role_id AND existing.menu_id = 2106100000000000017
  );
