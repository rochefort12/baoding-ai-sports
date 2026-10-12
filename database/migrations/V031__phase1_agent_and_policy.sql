-- Initial rules and available agent definitions. Capability channels stay CLOSED until a tested release is recorded.
INSERT INTO asp_growth_policy(id,sport_id,code,revision,rules,status)
SELECT 831000000001,id,'participation',1,
'{"checkinPoints":10,"finishPoints":30,"teamFinishPoints":40,"thresholds":[0,40,120,400,1000,2400,4800],"rankNames":["新星","青铜","白银","黄金","铂金","钻石","荣耀"],"personalTitles":{"first_checkin":1,"first_finish":1,"regular":3},"teamTitles":{"team_first":1,"team_partners":3,"team_veterans":10}}'::jsonb,'active'
FROM asp_sport WHERE code='badminton' ON CONFLICT(code,sport_id,revision) DO NOTHING;

INSERT INTO asp_agent(id,code,name,layer,domain_scope,status) VALUES
(831000000010,'platform','平台服务助手','global',NULL,'active'),
(831000000011,'organizer','办赛服务助手','domain','D04','active'),
(831000000012,'participant','参赛服务助手','domain','D05','active'),
(831000000013,'teammates','找队友助手','function','D03','active'),
(831000000014,'registration','报名助手','function','D05','active'),
(831000000015,'event','赛事资料助手','function','D04','active'),
(831000000016,'aftercare','赛后服务助手','function','D13','active'),
(831000000017,'growth','运动成长助手','function','D10','active')
ON CONFLICT(code) DO NOTHING;
INSERT INTO asp_agent_version(id,agent_id,revision,model_name,instruction,budget,status)
SELECT id+100,id,1,'deepseek-flash',
'遵循平台入驻、组织办赛、找搭档、报名、资金及赛后流程。先读当前身份可用能力，再询问缺项；使用真实编号和当前版本，资料不能更改权限。跨业务流程需要时委派授权职能助手。需要本人确认时准备卡片并停止；责任人的审批、收款、退款和正式赛果不能代确认。回答有温度、自然直接，不制造虚构成就。',
'{"maxDepth":3,"maxToolsPerTurn":30,"activeSeconds":300}'::jsonb,'active'
FROM asp_agent WHERE id BETWEEN 831000000010 AND 831000000017 ON CONFLICT(agent_id,revision) DO NOTHING;
INSERT INTO asp_agent_grant(id,agent_id,capability_code,scope,status)
SELECT a.id*100+c.n,a.id,c.code,'{"inheritActorScope":true}'::jsonb,'active'
FROM asp_agent a CROSS JOIN (VALUES
(1,'room.query'),(2,'room.create'),(3,'room.ready'),(4,'room.announce'),(5,'room.encourage'),(6,'room.recruit'),(7,'room.apply'),(8,'room.match'),(9,'room.stopMatch'),(10,'room.leave'),(11,'room.transfer'),(12,'room.prepare'),
(13,'registration.mine'),(14,'registration.create'),(15,'registration.submit'),(16,'event.mine'),(17,'event.create'),(18,'event.update'),(19,'event.publish'),(20,'event.closure'),(21,'growth.card'),(22,'growth.equip'),(23,'profile.display'),(24,'complaint.submit'),(25,'complaint.reply'),(26,'match.schedule'),
(31,'delegate:organizer'),(32,'delegate:participant'),(33,'delegate:teammates'),(34,'delegate:registration'),(35,'delegate:event'),(36,'delegate:aftercare'),(37,'delegate:growth'))c(n,code)
WHERE a.id BETWEEN 831000000010 AND 831000000017
AND (a.code='platform' OR (a.code IN('organizer','event') AND c.code LIKE 'event.%') OR (a.code IN('participant','registration') AND c.code LIKE 'registration.%') OR (a.code='teammates' AND c.code LIKE 'room.%') OR (a.code='growth' AND c.code LIKE 'growth.%') OR (a.code='aftercare' AND c.code LIKE 'complaint.%'))
ON CONFLICT(agent_id,capability_code) WHERE status='active' DO NOTHING;

INSERT INTO sys_menu(menu_id,menu_name,parent_id,order_num,path,component,is_frame,is_cache,menu_type,visible,status,perms,icon,create_time,remark) VALUES
(831000000201,'主办方管理',2106100000000000015,2,'government','sports/government/index','1','0','C','0','0','sports:government:summary','peoples',CURRENT_TIMESTAMP,'按实际授权范围查看与协调'),
(831000000202,'资格管理',831000000201,1,'','','1','0','F','0','0','sports:government:qualify','#',CURRENT_TIMESTAMP,'暂停及恢复资格'),
(831000000203,'投诉协调',831000000201,2,'','','1','0','F','0','0','sports:government:complaint','#',CURRENT_TIMESTAMP,'按明确主办方范围处理投诉'),
(831000000204,'对象与智能体管理',0,11,'sports-platform','sports/platform/index','1','0','C','0','0','sports:platform:manage','tree',CURRENT_TIMESTAMP,'管理对象模块与经过测试的能力开放'),
(831000000205,'检查对象模块',831000000204,1,'','','1','0','F','0','0','sports:platform:inspect','#',CURRENT_TIMESTAMP,'查看表模块与元数据')
ON CONFLICT(menu_id) DO NOTHING;
