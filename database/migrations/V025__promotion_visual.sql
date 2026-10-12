-- 无字主视觉属于宣传材料，不修改赛事公开封面或真实业务事实。
ALTER TABLE asp_event_poster
    ADD COLUMN visual_file_id bigint,
    ADD COLUMN visual_subject_digest varchar(64) NOT NULL DEFAULT '',
    ADD COLUMN visual_request_digest varchar(64) NOT NULL DEFAULT '',
    ADD COLUMN visual_style varchar(24) NOT NULL DEFAULT '',
    ADD CONSTRAINT ck_event_poster_visual_style CHECK (visual_style IN ('', 'competitive', 'junior', 'community'));
COMMENT ON COLUMN asp_event_poster.visual_file_id IS '模型生成的无字宣传主视觉，复用event-banner图片用途及组织隔离，不替换赛事封面；来源V025';
COMMENT ON COLUMN asp_event_poster.visual_subject_digest IS '生成时名称与运动项目摘要，变化后主视觉不可复用；来源V025';
COMMENT ON COLUMN asp_event_poster.visual_request_digest IS '名称项目受众关键词风格摘要，相同请求复用不重复生图；来源V025';
COMMENT ON COLUMN asp_event_poster.visual_style IS '主视觉风格competitive junior community，未生成为空；来源V025';
