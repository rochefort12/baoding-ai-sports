-- M1.5 长期队伍。不改写已应用迁移。申请、邀请和成员状态按冻结稿收束。

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM asp_team
        WHERE status NOT IN ('active', 'disbanded', 'dissolved')
    ) THEN
        RAISE EXCEPTION 'V010 cannot convert asp_team.status';
    END IF;
    IF EXISTS (SELECT 1 FROM asp_team_member WHERE role = 'vice_captain') THEN
        RAISE EXCEPTION 'V010 cannot convert vice_captain';
    END IF;
    IF EXISTS (SELECT 1 FROM asp_team_invitation) THEN
        RAISE EXCEPTION 'V010 requires asp_team_invitation to be empty before dropping link columns';
    END IF;
END $$;

ALTER TABLE asp_team_member ADD COLUMN end_reason varchar(32);

DO $$
DECLARE
    constraint_name text;
BEGIN
    FOR constraint_name IN
        SELECT con.conname
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        WHERE rel.relname = 'asp_team'
          AND con.contype = 'c'
          AND (
              pg_get_constraintdef(con.oid) LIKE '%join_policy%'
              OR (
                  pg_get_constraintdef(con.oid) LIKE '%status%'
                  AND pg_get_constraintdef(con.oid) NOT LIKE '%version%'
              )
          )
    LOOP
        EXECUTE format('ALTER TABLE asp_team DROP CONSTRAINT %I', constraint_name);
    END LOOP;

    FOR constraint_name IN
        SELECT con.conname
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        WHERE rel.relname = 'asp_team_member'
          AND con.contype = 'c'
          AND pg_get_constraintdef(con.oid) NOT LIKE '%version%'
          AND pg_get_constraintdef(con.oid) NOT LIKE '%left_at%'
          AND (
              pg_get_constraintdef(con.oid) LIKE '%role%'
              OR pg_get_constraintdef(con.oid) LIKE '%status%'
          )
    LOOP
        EXECUTE format('ALTER TABLE asp_team_member DROP CONSTRAINT %I', constraint_name);
    END LOOP;

    FOR constraint_name IN
        SELECT con.conname
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        WHERE rel.relname = 'asp_team_join_request'
          AND con.contype = 'c'
          AND pg_get_constraintdef(con.oid) LIKE '%status%'
          AND pg_get_constraintdef(con.oid) NOT LIKE '%version%'
    LOOP
        EXECUTE format('ALTER TABLE asp_team_join_request DROP CONSTRAINT %I', constraint_name);
    END LOOP;

    FOR constraint_name IN
        SELECT con.conname
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        WHERE rel.relname = 'asp_team_invitation'
          AND con.contype = 'c'
          AND pg_get_constraintdef(con.oid) NOT LIKE '%version%'
    LOOP
        EXECUTE format('ALTER TABLE asp_team_invitation DROP CONSTRAINT %I', constraint_name);
    END LOOP;
END $$;

UPDATE asp_team SET status = 'disbanded' WHERE status = 'dissolved';

UPDATE asp_team_member
SET status = 'ended',
    end_reason = CASE status WHEN 'left' THEN 'member_left' WHEN 'removed' THEN 'captain_removed' END,
    left_at = COALESCE(left_at, joined_at)
WHERE status IN ('left', 'removed');

UPDATE asp_team_join_request SET status = 'cancelled' WHERE status = 'withdrawn';

ALTER TABLE asp_team ADD CONSTRAINT ck_asp_team_join_policy
    CHECK (join_policy IN ('open', 'application', 'invitation', 'closed'));
ALTER TABLE asp_team ADD CONSTRAINT ck_asp_team_status
    CHECK (status IN ('active', 'disbanded'));

ALTER TABLE asp_team_member ADD CONSTRAINT ck_asp_team_member_role
    CHECK (role IN ('captain', 'member'));
ALTER TABLE asp_team_member ADD CONSTRAINT ck_asp_team_member_status
    CHECK (status IN ('active', 'ended'));
ALTER TABLE asp_team_member ADD CONSTRAINT ck_asp_team_member_end_reason
    CHECK (end_reason IS NULL OR end_reason IN ('member_left', 'captain_removed', 'team_disbanded'));
ALTER TABLE asp_team_member ADD CONSTRAINT ck_asp_team_member_episode
    CHECK ((status = 'active' AND left_at IS NULL AND end_reason IS NULL)
        OR (status = 'ended' AND left_at IS NOT NULL AND end_reason IS NOT NULL));

ALTER TABLE asp_team_join_request ADD CONSTRAINT ck_asp_team_join_request_status
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled', 'invalidated'));

DO $$
DECLARE
    index_name text;
BEGIN
    FOR index_name IN
        SELECT indexrel.relname
        FROM pg_index idx
        JOIN pg_class tbl ON tbl.oid = idx.indrelid
        JOIN pg_class indexrel ON indexrel.oid = idx.indexrelid
        WHERE tbl.relname = 'asp_team_invitation'
          AND pg_get_indexdef(idx.indexrelid) LIKE '%token_hash%'
    LOOP
        EXECUTE format('DROP INDEX %I', index_name);
    END LOOP;
END $$;

ALTER TABLE asp_team_invitation DROP COLUMN token_hash;
ALTER TABLE asp_team_invitation DROP COLUMN expires_at;
ALTER TABLE asp_team_invitation DROP COLUMN max_uses;
ALTER TABLE asp_team_invitation DROP COLUMN used_count;
ALTER TABLE asp_team_invitation ALTER COLUMN target_person_id SET NOT NULL;
ALTER TABLE asp_team_invitation ADD CONSTRAINT ck_asp_team_invitation_status
    CHECK (status IN ('pending', 'accepted', 'declined', 'revoked', 'invalidated'));
CREATE UNIQUE INDEX uq_asp_team_invitation_6300200126
    ON asp_team_invitation (team_id, target_person_id) WHERE status = 'pending';

COMMENT ON TABLE asp_team IS '长期项目队伍。一期只有有效和解散，解散后不恢复，不归属组织；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team.name IS '当前队名。已提交报名使用自己的队名快照';
COMMENT ON COLUMN asp_team.sport_id IS '项目。一期创建时写入羽毛球，之后不改';
COMMENT ON COLUMN asp_team.captain_person_id IS '当前队长档案。解散后保留最后一任，有效队伍还必须有一条有效队长成员';
COMMENT ON COLUMN asp_team.creator_account_id IS '创建人。不代表当前能否代表队伍报名';
COMMENT ON COLUMN asp_team.join_policy IS '一期创建写 open。申请和邀请同时开放，服务不按这列分支：open application invitation closed';
COMMENT ON COLUMN asp_team.visibility IS '一期创建写 members。不做队伍广场，服务不按这列分支：private members public';
COMMENT ON COLUMN asp_team.status IS '独立业务状态；合法值不等于业务已获批准：active disbanded';
COMMENT ON COLUMN asp_team.region IS '活动区域。一期页面不维护';
COMMENT ON COLUMN asp_team.profile IS '非敏感展示资料。一期页面不维护；必须按版本校验结构';

COMMENT ON TABLE asp_team_member IS '队伍成员的一段关系。结束后不重新激活，再次加入另起一行；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team_member.role IS '独立业务状态；合法值不等于业务已获批准：captain member';
COMMENT ON COLUMN asp_team_member.status IS '独立业务状态；合法值不等于业务已获批准：active ended';
COMMENT ON COLUMN asp_team_member.end_reason IS '结束原因。有效成员必须为空：member_left captain_removed team_disbanded';
COMMENT ON COLUMN asp_team_member.join_source IS 'create、application 或 invitation';

COMMENT ON TABLE asp_team_join_request IS '入队申请。待处理不是成员，失效不能记成申请人撤销或队长拒绝；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team_join_request.status IS '独立业务状态；合法值不等于业务已获批准：pending approved rejected cancelled invalidated';
COMMENT ON COLUMN asp_team_join_request.reviewer_account_id IS '处理人。申请人撤销和系统失效时为空';

COMMENT ON TABLE asp_team_invitation IS '队长指定一名用户的入队邀请。必须本人接受，不使用可转发链接；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON COLUMN asp_team_invitation.target_person_id IS '指定受邀人';
COMMENT ON COLUMN asp_team_invitation.status IS '独立业务状态；合法值不等于业务已获批准：pending accepted declined revoked invalidated';

COMMENT ON TABLE asp_team_history IS '队伍改名、转让、解散的事实和快照。不代替成员终止行，也不回写已提交报名；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';
COMMENT ON TABLE asp_team_quota IS '账户建队与入队配额。一期没有已批准数值，服务不读不写；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';

COMMENT ON COLUMN asp_registration.team_id IS '可选长期代表队。空表示个人或临时双打';
COMMENT ON COLUMN asp_registration.team_name_snapshot IS '提交成功时的队名。之后队伍改名不回写';
