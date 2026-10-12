-- 参赛声明可由赛事要求成员本人点击确认。确认只记录当时文本和图片的摘要，不是证件核验，也不是电子签章。
ALTER TABLE asp_event
    ADD COLUMN declaration_ack_required boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN asp_event.declaration_ack_required IS '参赛声明是否必须由成员本人点击确认。不是证件核验，也不是电子签章；来源V026';

CREATE TABLE asp_declaration_ack (
    id bigint NOT NULL,
    tenant_id varchar(20) NOT NULL,
    registration_member_id bigint NOT NULL,
    account_id bigint NOT NULL,
    event_id bigint NOT NULL,
    content_digest varchar(64) NOT NULL,
    acknowledged_at timestamptz NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by bigint,
    update_time timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version integer NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (registration_member_id),
    CHECK (length(tenant_id) > 0),
    CHECK (length(content_digest) = 64),
    CHECK (version >= 0)
);
COMMENT ON TABLE asp_declaration_ack IS '成员本人对当时参赛声明的点击确认。队长不能代确认；来源V026';
COMMENT ON COLUMN asp_declaration_ack.content_digest IS '确认时声明文字和文件的摘要。声明变化后需重新确认';
COMMENT ON COLUMN asp_declaration_ack.acknowledged_at IS '本人点击确认的时间';
CREATE INDEX ix_asp_declaration_ack_event ON asp_declaration_ack (tenant_id, event_id);
