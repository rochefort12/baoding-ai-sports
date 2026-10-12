import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';
import {context,api,readSql,createEvidence} from './lib/BusinessRegression.mjs';
const paths=process.argv.slice(2);assert.equal(paths.length,2);
const [failed,accepted]=paths.map(p=>{const real=fs.realpathSync(p);assert.ok(real.startsWith(fs.realpathSync(context.out)+path.sep));return JSON.parse(fs.readFileSync(real,'utf8'));});
assert.equal(accepted.passed,true);assert.equal(accepted.database,context.database);assert.equal(failed.database,context.database);assert.equal(failed.passed,false);
const runId=String(failed.objects.runs.at(-1)),eventId=String(failed.objects.eventId);for(const value of [runId,eventId])assert.match(value,/^\d+$/);
const proof=createEvidence('agent-restart-recovery');const {check,evidence,save}=proof;evidence.objects={runId,eventId};save();
const runtime=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8'));assert.equal(runtime.database,context.database);assert.equal(crypto.createHash('sha256').update(fs.readFileSync(runtime.jarPath)).digest('hex'),runtime.jarSHA256);evidence.runtimeJarSha256=runtime.jarSHA256;save();
const catalog=await api(context.admin,'/sports/platform/management'),definition=catalog.definitions.find(d=>d.definition.code==='unit.create');
const prior=Boolean(catalog.activations.find(a=>a.code==='unit.create'&&a.channel==='agent')?.enabled);
const activate=enabled=>api(context.admin,'/sports/platform/management/release','POST',{code:'unit.create',channel:'agent',enabled,definitionHash:definition.definitionHash,evidenceHash:crypto.createHash('sha256').update(fs.readFileSync(paths[1])).digest('hex')});
const facts=()=>readSql(`SELECT COALESCE(string_agg(id::text,',' ORDER BY id),'') FROM asp_competition_unit WHERE event_id=${eventId};`);
const receipts=()=>Number(readSql(`SELECT count(*) FROM asp_action_execution WHERE run_id=${runId} AND action_code='unit.create' AND status='succeeded';`));
try {
 check('original failed task has one committed business receipt after service restart',receipts()===1);
 assert.equal(readSql(`SELECT name LIKE '${context.prefix.replaceAll("'","''")}%' FROM asp_event WHERE id=${eventId};`),'t');
 const before=facts();await activate(true);
 const previous=await api(context.organizer,'/sports/agents/runs/'+runId);check('ordinary organizer can reopen the original saved task',previous.status==='failed'||previous.status==='waiting_input');evidence.priorTaskStatus=previous.status;
 await api(context.organizer,'/sports/agents/runs/'+runId+'/answer','POST',{message:'服务已恢复。请使用 sports_recovery 读取先前已经成功的 unit.create 办理回执，告诉我原项目编号与下一步即可。禁止再次创建或准备新的确认卡。'});
 let current;const deadline=Date.now()+310000;do{await new Promise(resolve=>setTimeout(resolve,1200));current=await api(context.organizer,'/sports/agents/runs/'+runId);if(current.status==='failed')throw Error('Restart continuation failed: '+current.stopReason);}while(current.status==='running'&&Date.now()<deadline);
 check('real model resumes the same task and preserves the original receipt',current.status==='waiting_input'&&current.messages.some(m=>JSON.parse(m.blocks||'[]').some(b=>b.kind==='receipt')));
 check('restart and failed-round recovery do not replay a committed write',facts()===before&&receipts()===1);
 check('recovered round settles its own allocation',readSql(`SELECT tokens_reserved FROM asp_agent_run WHERE id=${runId};`)==='0');
 evidence.scope='Actual isolated backend process restart, original failed Agent continuation, real model and existing synthetic receipt; no operating-system reboot or new business write.';
}catch(error){evidence.failure=error.message;save();throw error;}
finally{await activate(prior);evidence.agentWriteRestoredToOriginal=prior;save();}
proof.finish();
