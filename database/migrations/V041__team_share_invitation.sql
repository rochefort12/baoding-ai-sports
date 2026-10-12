-- User decision 2026-10-12: captain shares a revocable link; the invitee confirms after login and profile completion.
-- Historical direct invitations, members and submitted rosters remain unchanged.
ALTER TABLE asp_team_invitation ALTER COLUMN target_person_id DROP NOT NULL;
ALTER TABLE asp_team_invitation ADD COLUMN invitation_kind varchar(32) NOT NULL DEFAULT 'direct';
ALTER TABLE asp_team_invitation ADD COLUMN inviter_person_id bigint;
ALTER TABLE asp_team_invitation ADD COLUMN invite_token varchar(64);
ALTER TABLE asp_team_invitation ADD COLUMN expires_at timestamptz;
ALTER TABLE asp_team_invitation ADD COLUMN share_invitation_id bigint;
COMMENT ON COLUMN asp_team_invitation.invitation_kind IS 'direct 定向邀请或接受事实；share 队长可转发入队授权';
COMMENT ON COLUMN asp_team_invitation.inviter_person_id IS '分享授权时的队长稳定档案；转让或账号停止后失效';
COMMENT ON COLUMN asp_team_invitation.invite_token IS '256位随机业务分享凭据，仅当前队长回显，不写通知或日志';
COMMENT ON COLUMN asp_team_invitation.expires_at IS '分享链接七天到期；定向邀请为空';
COMMENT ON COLUMN asp_team_invitation.share_invitation_id IS '本人接受分享的来源，同来源同本人一次，离队不复活';
COMMENT ON COLUMN asp_team_invitation.target_person_id IS '定向受邀本人；分享授权为空，接受另插本人事实';
ALTER TABLE asp_team_invitation ADD CONSTRAINT fk_team_share_inviter FOREIGN KEY (inviter_person_id) REFERENCES asp_person(id);
ALTER TABLE asp_team_invitation ADD CONSTRAINT fk_team_share_source FOREIGN KEY (share_invitation_id) REFERENCES asp_team_invitation(id);
ALTER TABLE asp_team_invitation ADD CONSTRAINT ck_team_invitation_kind CHECK (invitation_kind IN ('direct','share'));
ALTER TABLE asp_team_invitation ADD CONSTRAINT ck_team_share_token CHECK (invite_token IS NULL OR invite_token ~ '^[a-f0-9]{64}$');
ALTER TABLE asp_team_invitation ADD CONSTRAINT ck_team_share_shape CHECK (
    (invitation_kind='direct' AND target_person_id IS NOT NULL AND invite_token IS NULL AND expires_at IS NULL)
    OR (invitation_kind='share' AND target_person_id IS NULL AND inviter_person_id IS NOT NULL AND invite_token IS NOT NULL
        AND expires_at IS NOT NULL AND share_invitation_id IS NULL AND status IN ('pending','revoked','invalidated')));
ALTER TABLE asp_team_invitation ADD CONSTRAINT ck_team_share_acceptance CHECK (
    share_invitation_id IS NULL OR (invitation_kind='direct' AND status='accepted' AND share_invitation_id<>id));
CREATE UNIQUE INDEX uq_team_share_token ON asp_team_invitation(invite_token) WHERE invite_token IS NOT NULL;
CREATE UNIQUE INDEX uq_team_pending_share ON asp_team_invitation(team_id) WHERE invitation_kind='share' AND status='pending';
CREATE UNIQUE INDEX uq_team_share_acceptance ON asp_team_invitation(share_invitation_id,target_person_id) WHERE share_invitation_id IS NOT NULL;
CREATE INDEX ix_team_share_inviter ON asp_team_invitation(inviter_person_id);
CREATE INDEX ix_team_share_source ON asp_team_invitation(share_invitation_id);
