-- Append a new growth rule version. Historical facts, scores, honours and rule bytes stay intact.
-- The first seven thresholds/rewards remain unchanged. 9600 is the configurable default for 王者.
COMMENT ON COLUMN asp_growth_policy.rules IS '版本化段位门槛、奖励及称号阈值；兼容历史七级，新星基础级加七段位，王者默认9600分可另发版本调整；必须按版本校验结构';
DO $$
DECLARE
    previous asp_growth_policy%ROWTYPE;
    replacement jsonb;
    policy_id bigint := 835000000001;
BEGIN
    FOR previous IN
        SELECT * FROM asp_growth_policy
        WHERE code='participation' AND status='active'
          AND rules->'rankNames'='["新星","青铜","白银","黄金","铂金","钻石","荣耀"]'::jsonb
          AND rules->'thresholds'='[0,40,120,400,1000,2400,4800]'::jsonb
        ORDER BY sport_id
        FOR UPDATE
    LOOP
        -- Do not silently overwrite a later administrator-published revision.
        IF EXISTS (SELECT 1 FROM asp_growth_policy WHERE sport_id=previous.sport_id
                   AND code=previous.code AND revision>previous.revision) THEN
            CONTINUE;
        END IF;
        replacement := previous.rules || jsonb_build_object(
            'rankNames', '["新星","青铜","白银","黄金","铂金","钻石","星耀","王者"]'::jsonb,
            'thresholds', '[0,40,120,400,1000,2400,4800,9600]'::jsonb);
        WHILE EXISTS (SELECT 1 FROM asp_growth_policy WHERE id=policy_id) LOOP
            policy_id := policy_id + 1;
        END LOOP;
        INSERT INTO asp_growth_policy(id,sport_id,code,revision,rules,status)
        VALUES(policy_id,previous.sport_id,previous.code,previous.revision+1,replacement,'active');
        UPDATE asp_growth_policy SET status='superseded',version=version+1,update_time=CURRENT_TIMESTAMP
        WHERE id=previous.id AND status='active';
        policy_id := policy_id + 1;
    END LOOP;
END $$;
