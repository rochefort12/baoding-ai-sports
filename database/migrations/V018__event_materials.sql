-- 赛事宣传和办赛说明。图片只存文件编号，文件本体在对象存储。
ALTER TABLE asp_event ADD COLUMN banner_file_id bigint;
ALTER TABLE asp_event ADD COLUMN rules_text varchar(4000);
ALTER TABLE asp_event ADD COLUMN rules_file_id bigint;
ALTER TABLE asp_event ADD COLUMN notice_text varchar(4000);
ALTER TABLE asp_event ADD COLUMN notice_file_id bigint;
ALTER TABLE asp_event ADD COLUMN declaration_text varchar(4000);
ALTER TABLE asp_event ADD COLUMN declaration_file_id bigint;
ALTER TABLE asp_event ADD COLUMN route_text varchar(4000);
ALTER TABLE asp_event ADD COLUMN route_file_id bigint;

COMMENT ON COLUMN asp_event.banner_file_id IS '宣传图文件编号。可空，不建外键';
COMMENT ON COLUMN asp_event.rules_text IS '竞赛规程文字。可与图片同时存在';
COMMENT ON COLUMN asp_event.rules_file_id IS '竞赛规程图片文件编号。可空，不建外键';
COMMENT ON COLUMN asp_event.notice_text IS '报名须知文字。可与图片同时存在';
COMMENT ON COLUMN asp_event.notice_file_id IS '报名须知图片文件编号。可空，不建外键';
COMMENT ON COLUMN asp_event.declaration_text IS '参赛声明文字。可与图片同时存在';
COMMENT ON COLUMN asp_event.declaration_file_id IS '参赛声明图片文件编号。可空，不建外键';
COMMENT ON COLUMN asp_event.route_text IS '比赛地点或路线说明。地图嵌入不在本期';
COMMENT ON COLUMN asp_event.route_file_id IS '比赛地点或路线图片文件编号。可空，不建外键';
