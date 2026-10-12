-- 已发布赛事的宣传资料和按日打开次数。原文件不在工作区，按已应用的库结构回写。
-- 不记录账号、地址或浏览器标识。来源编号只用于汇总打开次数。

CREATE TABLE asp_event_poster (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    event_id bigint NOT NULL,
    channel_name varchar(40) NOT NULL,
    format varchar(32) NOT NULL,
    source_code varchar(16) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (format IN ('wechat_group', 'moments', 'a4')),
    CHECK (length(tenant_id) > 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_event_poster IS '已发布赛事的一份宣传资料。来源编号只汇总打开次数，不关联账号；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_event_poster.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_event_poster.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_event_poster.event_id IS '赛事';
COMMENT ON COLUMN asp_event_poster.channel_name IS '承办方填写的渠道名称';
COMMENT ON COLUMN asp_event_poster.format IS '资料版式：wechat_group moments a4';
COMMENT ON COLUMN asp_event_poster.source_code IS '公开链接上的来源编号。不包含个人信息';
COMMENT ON COLUMN asp_event_poster.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_event_poster.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_event_poster.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_event_poster.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_event_poster.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_event_poster.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE INDEX ix_asp_event_poster_2f80715835 ON asp_event_poster (tenant_id, event_id);
CREATE UNIQUE INDEX uq_asp_event_poster_6804b38f56 ON asp_event_poster (tenant_id, source_code);
CREATE UNIQUE INDEX uq_asp_event_poster_c9f68599d0 ON asp_event_poster (tenant_id, event_id, channel_name);

CREATE TABLE asp_event_poster_stat (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    poster_id bigint NOT NULL,
    stat_date date NOT NULL,
    hit_count integer NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (tenant_id, id),
    CHECK (hit_count >= 0),
    CHECK (length(tenant_id) > 0),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_event_poster_stat IS '宣传资料按日打开次数。不记录账号、地址或浏览器标识；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_event_poster_stat.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN asp_event_poster_stat.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN asp_event_poster_stat.poster_id IS '宣传资料';
COMMENT ON COLUMN asp_event_poster_stat.stat_date IS '统计日。按上海时区的日期累计';
COMMENT ON COLUMN asp_event_poster_stat.hit_count IS '当日打开次数';
COMMENT ON COLUMN asp_event_poster_stat.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN asp_event_poster_stat.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN asp_event_poster_stat.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN asp_event_poster_stat.update_by IS '最近更新操作主体';
COMMENT ON COLUMN asp_event_poster_stat.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN asp_event_poster_stat.version IS '乐观并发版本；不替代业务规则/名单版本';
CREATE INDEX ix_asp_event_poster_stat_34cbfeb820 ON asp_event_poster_stat (tenant_id, poster_id);
CREATE UNIQUE INDEX uq_asp_event_poster_stat_d5e92612f6 ON asp_event_poster_stat (tenant_id, poster_id, stat_date);

ALTER TABLE asp_event_poster ADD CONSTRAINT fk_asp_event_poster_2f80715835 FOREIGN KEY (tenant_id, event_id) REFERENCES asp_event (tenant_id, id);
ALTER TABLE asp_event_poster_stat ADD CONSTRAINT fk_asp_event_poster_stat_34cbfeb820 FOREIGN KEY (tenant_id, poster_id) REFERENCES asp_event_poster (tenant_id, id);
