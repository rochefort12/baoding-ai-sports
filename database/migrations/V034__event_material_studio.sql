-- Organizer-only working documents. These are drafts, not published rules or notifications.
ALTER TABLE asp_event ADD COLUMN IF NOT EXISTS operations_materials jsonb NOT NULL DEFAULT '{}'::jsonb;
COMMENT ON COLUMN asp_event.operations_materials IS 'Private plan/script/announcement/promotion drafts; independent revisions, actual origin and up to ten prior revisions; no automatic external publication';
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'asp_event_operations_materials_object') THEN
    ALTER TABLE asp_event ADD CONSTRAINT asp_event_operations_materials_object CHECK (jsonb_typeof(operations_materials) = 'object');
  END IF;
END $$;
