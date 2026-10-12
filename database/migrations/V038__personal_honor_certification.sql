-- External sporting honors are manually verified. No growth points, seeded champions or channel releases.
ALTER TABLE asp_honor ADD COLUMN IF NOT EXISTS applicant_account_id bigint REFERENCES asp_account(id);
ALTER TABLE asp_honor ADD COLUMN IF NOT EXISTS certification_status varchar(32);
ALTER TABLE asp_honor ADD COLUMN IF NOT EXISTS certification_details jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE asp_honor ADD COLUMN IF NOT EXISTS verified_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE asp_honor ADD COLUMN IF NOT EXISTS certification_history jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE asp_honor ADD COLUMN IF NOT EXISTS certification_public boolean NOT NULL DEFAULT false;
ALTER TABLE asp_honor ADD COLUMN IF NOT EXISTS certification_worn boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN asp_honor.applicant_account_id IS 'Authenticated owner of an external honor application; NULL for existing event/growth honors';
COMMENT ON COLUMN asp_honor.certification_status IS 'draft/submitted/correction/approved/rejected/revoked, NULL for historical non-certification honors';
COMMENT ON COLUMN asp_honor.certification_details IS 'Typed applicant claim and private honor-proof file IDs; never publicly returned';
COMMENT ON COLUMN asp_honor.verified_snapshot IS 'Reviewer-confirmed year/event/sport/place/issuer/results source; title is server-derived, no growth award';
COMMENT ON COLUMN asp_honor.certification_history IS 'Append-only submission, correction and decision snapshots; owner/reviewer access only';
COMMENT ON COLUMN asp_honor.certification_public IS 'Owner consent for approved facts; also requires public profile consent';
COMMENT ON COLUMN asp_honor.certification_worn IS 'Only approved verified honors can be worn, one per person/sport';
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='asp_honor_certification_shape') THEN
    ALTER TABLE asp_honor ADD CONSTRAINT asp_honor_certification_shape CHECK (
      jsonb_typeof(certification_details)='object' AND jsonb_typeof(verified_snapshot)='object'
      AND jsonb_typeof(certification_history)='array'
      AND (certification_status IS NULL OR (
        certification_status IN ('draft','submitted','correction','approved','rejected','revoked')
        AND applicant_account_id IS NOT NULL AND person_id IS NOT NULL AND team_id IS NULL
        AND category='self_reported' AND sport_id IS NOT NULL
        AND ((certification_status='approved' AND status='verified' AND verified_snapshot <> '{}'::jsonb)
          OR (certification_status='revoked' AND status='revoked')
          OR (certification_status IN ('draft','submitted','correction','rejected') AND status='pending'))
      ))
      AND (NOT certification_worn OR (certification_status='approved' AND status='verified'))
      AND (NOT certification_public OR (certification_status='approved' AND status='verified'))
    );
  END IF;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS ux_asp_honor_certified_worn
  ON asp_honor(person_id,sport_id) WHERE certification_status='approved' AND certification_worn;
CREATE INDEX IF NOT EXISTS ix_asp_honor_certification_queue
  ON asp_honor(certification_status,update_time) WHERE certification_status IS NOT NULL;
