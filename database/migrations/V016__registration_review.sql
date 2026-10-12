-- 赛事报名审核方式。默认人工审核。首笔正式提交后锁定，全部撤回也不解锁。
-- 自动通过不写人工审核人，所以审核记录的审核人改为可空。

ALTER TABLE asp_event
    ADD COLUMN registration_review varchar(16) NOT NULL DEFAULT 'manual',
    ADD COLUMN registration_review_locked boolean NOT NULL DEFAULT false;

ALTER TABLE asp_event
    ADD CONSTRAINT ck_asp_event_registration_review CHECK (registration_review IN ('manual', 'none'));

UPDATE asp_event e
SET registration_review_locked = true
WHERE EXISTS (
    SELECT 1
    FROM asp_competition_unit u
    JOIN asp_registration r ON r.tenant_id = u.tenant_id AND r.unit_id = u.id
    WHERE u.tenant_id = e.tenant_id
      AND u.event_id = e.id
      AND r.roster_revision > 0
);

COMMENT ON COLUMN asp_event.registration_review IS '报名资格审核：manual 人工审核，none 无需审核。与赛事发布审批无关';
COMMENT ON COLUMN asp_event.registration_review_locked IS '首笔正式提交后锁定审核方式。全部撤回也不解锁';

ALTER TABLE asp_qualification_review ALTER COLUMN reviewer_id DROP NOT NULL;
COMMENT ON COLUMN asp_qualification_review.reviewer_id IS '审核后台账号。无需审核的自动通过为空，不伪造人工审核人';
