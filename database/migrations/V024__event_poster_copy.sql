-- 宣传材料正文和生成时的事实摘要。来源编号仍只用于以后统计打开次数。
-- 不改已应用的 V021。图像生成密钥留空时不产生图片列。

ALTER TABLE asp_event_poster ADD COLUMN copy_headline varchar(80) NOT NULL DEFAULT '';
ALTER TABLE asp_event_poster ADD COLUMN copy_invitation varchar(300) NOT NULL DEFAULT '';
ALTER TABLE asp_event_poster ADD COLUMN copy_body varchar(2000) NOT NULL DEFAULT '';
ALTER TABLE asp_event_poster ADD COLUMN fact_digest varchar(64) NOT NULL DEFAULT '';
ALTER TABLE asp_event_poster ADD COLUMN link_path varchar(240) NOT NULL DEFAULT '';

COMMENT ON COLUMN asp_event_poster.copy_headline IS '模型写的标题。金额和日期由页面按赛事事实另画';
COMMENT ON COLUMN asp_event_poster.copy_invitation IS '模型写的邀请句';
COMMENT ON COLUMN asp_event_poster.copy_body IS '群消息正文或朋友圈短句。海报行可为空';
COMMENT ON COLUMN asp_event_poster.fact_digest IS '生成时的赛事事实摘要。对不上当前赛事则材料过期';
COMMENT ON COLUMN asp_event_poster.link_path IS '已发布时的公开路径，含来源编号。未发布为空';
