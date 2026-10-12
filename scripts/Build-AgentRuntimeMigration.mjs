// Add a new locked playbook revision. Never rewrite an applied migration or open business channels.
import fs from 'node:fs';
import crypto from 'node:crypto';
const original=JSON.parse(fs.readFileSync('database/seeds/agent-playbook-v2.json','utf8'));
const source=structuredClone(original);
source.tools.entries.splice(6,0,
  {name:'sports_children',purpose:'读取本任务直接委派的可见结果、失败或本人确认状态',arguments:{waitSeconds:'integer 0..10'},usage:'委派后先核对实际结果；等待中的子任务不当作完成，待确认内容由本人在对应任务确认',agentAllowed:true,channel:'controlled-agent-run'},
  {name:'sports_recovery',purpose:'恢复当前仍授权的办理回执、对象版本与原请求编号',arguments:{},usage:'接续前先读取；成功动作不重放，历史事实须核对当前对象权限与版本',agentAllowed:true,channel:'controlled-agent-run'});
const recover=source.skills.entries.find(s=>s.code==='recover-and-guide');
recover.tools=[...new Set([...(recover.tools||[]),'sports_recovery','sports_children'])];
recover.procedure.push('先恢复当前授权的真实办理回执；委派结果分别标明完成本轮、需补充、失败或待本人确认，不把子任务创建当作业务完成');
const canonical=v=>Array.isArray(v)?'['+v.map(canonical).join(',')+']':v&&typeof v==='object'?'{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}':JSON.stringify(v);
const hash=crypto.createHash('sha256').update(canonical(source)).digest('hex');
const q=v=>JSON.stringify(v).replaceAll("'","''");
const budget={maxDepth:3,maxToolsPerTurn:30,activeSeconds:300,maxTokensPerTurn:30000,maxTokensTotal:120000,maxChildren:4};
const sql=`-- V039: bounded durable Agent rounds and result recovery. No capability activation or grants.
ALTER TABLE asp_agent_run ADD COLUMN IF NOT EXISTS tokens_reserved integer NOT NULL DEFAULT 0 CHECK(tokens_reserved>=0);
ALTER TABLE asp_agent_run ADD COLUMN IF NOT EXISTS round_key varchar(64) NOT NULL DEFAULT '';
COMMENT ON COLUMN asp_agent_run.tokens_reserved IS 'Active model round reservation; root-run aggregate enforces the locked total budget';
DO $constraints$ DECLARE c record; BEGIN
FOR c IN SELECT conname FROM pg_constraint WHERE conrelid='asp_agent_run'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%status%' LOOP
EXECUTE format('ALTER TABLE asp_agent_run DROP CONSTRAINT %I',c.conname);
END LOOP;
ALTER TABLE asp_agent_run ADD CONSTRAINT asp_agent_run_status_runtime_check CHECK(status IN('running','waiting_children','waiting_input','waiting_confirmation','completed','failed','stopped'));
END $constraints$;
INSERT INTO asp_agent_version(id,agent_id,revision,model_name,instruction,budget,status,tool_catalog,skill_catalog,business_map,playbook_hash)
SELECT a.id+300,a.id,3,v.model_name,v.instruction||' 接续时先读取sports_recovery，不重放已成功办理。跨职能委派后读取sports_children，分清待补充、失败、待本人确认和已返回的真实结果；不得将创建子任务当作完成。服务端决定身份、预算和原请求键。',
'${q(budget)}'::jsonb,'active','${q(source.tools)}'::jsonb,'${q(source.skills)}'::jsonb,'${q(source.businessMap)}'::jsonb,'${hash}'
FROM asp_agent a JOIN asp_agent_version v ON v.agent_id=a.id AND v.revision=2
WHERE a.id BETWEEN 831000000010 AND 831000000017 ON CONFLICT(agent_id,revision) DO NOTHING;
`;
for(const [file,body] of [['database/seeds/agent-playbook-v3.json',JSON.stringify(source,null,2)+'\n'],['database/migrations/V039__agent_runtime_recovery.sql',sql]]){
 if(fs.existsSync(file)&&fs.readFileSync(file,'utf8')!==body)throw Error('Existing immutable output differs: '+file);
 if(!fs.existsSync(file))fs.writeFileSync(file,body);
}
console.log('V039 and revision 3 prepared; no database writes or channels opened.');
