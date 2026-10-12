// Controlled seed assembly only. This does not connect to a database, apply migrations or open capabilities.
import fs from 'node:fs';
import crypto from 'node:crypto';
const source=JSON.parse(fs.readFileSync('database/seeds/agent-playbook-v2.json','utf8'));
const canonical=value=>Array.isArray(value)?'['+value.map(canonical).join(',')+']':value&&typeof value==='object'?'{'+Object.keys(value).sort().map(k=>JSON.stringify(k)+':'+canonical(value[k])).join(',')+'}':JSON.stringify(value);
const hash=crypto.createHash('sha256').update(canonical(source)).digest('hex'),sql=value=>JSON.stringify(value).replaceAll("'","''");
const instruction='先理解用户真正想办成什么，按本次锁定的技能目录、业务地图和实际能力带着用户推进。先查sports_playbook与当前能力，区分页面可办与助手可办；能从授权事实取得的资料不重复追问。一次优先处理一个最小阻塞项，最多补问三个必要问题，说明为什么需要与补完后会做什么。对新人自然欢迎，对担心和失败先接住具体困难，不夸大成就、不空泛鼓励。引用材料的真实位置和覆盖范围；冲突明确补问，不能猜编号、日期、费用或政府背书。缺权限或能力未开放时说明实际边界，给本人能继续的人工入口。涉及发布、报名及重要变更，用当前版本准备确认卡后停下；真实资金、政府审核、正式结果和荣誉由责任人办理。成功只依据真实业务回执。用户可見业务步骤、补充与回执需要可恢复；不输出或保存隐藏思考、凭据或未经授权的材料。最终答复使用reply与blocks的JSON对象，提供引导、必要问题、待办清单及已登记的下一步入口，避免演示口号和技术配置术语。';
let output=`-- V036: versioned, trusted tools/skills/business map. No capability grant or channel activation.
ALTER TABLE asp_agent_version ADD COLUMN IF NOT EXISTS tool_catalog jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE asp_agent_version ADD COLUMN IF NOT EXISTS skill_catalog jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE asp_agent_version ADD COLUMN IF NOT EXISTS business_map jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE asp_agent_version ADD COLUMN IF NOT EXISTS playbook_hash varchar(64) NOT NULL DEFAULT '';
COMMENT ON COLUMN asp_agent_version.tool_catalog IS 'Versioned controlled MCP tools and invocation contracts; never grants permissions';
COMMENT ON COLUMN asp_agent_version.skill_catalog IS 'Trusted platform skills, not model output or hidden thought';
COMMENT ON COLUMN asp_agent_version.business_map IS 'Versioned role flows and dependencies; availability is checked against live registry';
COMMENT ON COLUMN asp_agent_version.playbook_hash IS 'SHA256 of canonical tools/skills/businessMap JSON bound to the agent revision';
DO $constraints$ BEGIN
`;
for(const field of ['tool_catalog','skill_catalog','business_map'])output+=`IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='asp_agent_version'::regclass AND conname='asp_agent_version_${field}_object') THEN ALTER TABLE asp_agent_version ADD CONSTRAINT asp_agent_version_${field}_object CHECK (jsonb_typeof(${field})='object'); END IF;
`;
output+=`END $constraints$;
INSERT INTO asp_agent_version(id,agent_id,revision,model_name,instruction,budget,status,tool_catalog,skill_catalog,business_map,playbook_hash)
SELECT id+200,id,2,'deepseek-flash','${instruction.replaceAll("'","''")}',
'{"maxDepth":3,"maxToolsPerTurn":30,"activeSeconds":300}'::jsonb,'active',
'${sql(source.tools)}'::jsonb,'${sql(source.skills)}'::jsonb,'${sql(source.businessMap)}'::jsonb,'${hash}'
FROM asp_agent WHERE id BETWEEN 831000000010 AND 831000000017
ON CONFLICT(agent_id,revision) DO NOTHING;
-- Revision 1 remains immutable for existing runs. New runs select the newest active revision.
`;
const target='database/migrations/V036__agent_playbook_catalog.sql';
if(fs.existsSync(target)&&fs.readFileSync(target,'utf8')!==output)throw Error('Existing migration bytes differ; create a new approved revision and migration instead of overwriting V036.');
if(!fs.existsSync(target))fs.writeFileSync(target,output);
console.log('Assembled V036 playbook seed; no database change or capability opening.');
