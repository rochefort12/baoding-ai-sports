// Capture live authorized facts first, then seal only after owned services are stopped.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';
import {context,api,readSql} from './lib/BusinessRegression.mjs';
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),read=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const dir=context.out,record=path.join(dir,'notice-final-live.json');
const references=[
 ['preflight-receipt.json','accepted backup and independent full restore'],
 ['notice-agent-initial.json','original generic run history including budget failure and two strict-phrase failures'],
 ['notice-recovery-1791762705848-6f17f2d2/receipt.json','accepted original-task recovery and semantic recheck; 5 checks'],
 ['notice-ui-1791762761380-32676905/receipt.json','partial actual PNG selection/upload and followup proof; consumer host and unsettled first screenshot superseded'],
 ['notice-ui-1791762970816-0e2fcaa4/receipt.json','accepted proper organizer desktop/mobile reopen; 5 checks'],
 ['notice-six-scans-1791763094068-d82a112c/receipt.json','accepted six real scanned pages; 4 checks'],
 ['notice-draft-ui-1791763384290-fd7ffd01/receipt.json','actual successful UI confirmation; later observation query failed, no write replay'],
 ['notice-draft-accepted-1791763510245-e7c313db/receipt.json','accepted same actual draft read-only verification; 6 checks']
];
const absolute=file=>path.isAbsolute(file)?file:path.join(dir,file);
function artifact(file,role){const name=absolute(file);return {path:path.relative(process.cwd(),name).replaceAll('\\','/'),sha256:hash(fs.readFileSync(name)),role,passed:read(name).passed};}
if(process.argv.includes('--capture')){
 assert.ok(!fs.existsSync(record),'Immutable live capture already exists');
 const original=read(path.join(dir,'notice-agent-initial.json')),image=read(path.join(dir,'notice-ui-1791762761380-32676905/receipt.json')),scan=read(path.join(dir,'notice-six-scans-1791763094068-d82a112c/receipt.json'));
 const ids=[...Object.values(original.cases).map(c=>c.runId),image.objects.runId,scan.objects.runId];assert.equal(new Set(ids).size,8);
 const current=[];
 for(const id of ids){assert.match(id,/^\d+$/);const run=await api(context.organizer,'/sports/agents/runs/'+id);assert.equal(run.status,'waiting_input');assert.equal(readSql(`SELECT tokens_reserved FROM asp_agent_run WHERE id=${id};`),'0');assert.equal(readSql(`SELECT count(*) FROM asp_action_execution WHERE run_id=${id};`),'0');current.push({runId:id,status:run.status,visibleAssistantMessages:run.messages.filter(m=>m.role==='assistant').length,tokensUsed:Number(readSql(`SELECT tokens_used FROM asp_agent_run WHERE id=${id};`))});}
 const definitions=await api(context.admin,'/sports/platform/management'),writes=definitions.activations.filter(a=>a.channel==='agent'&&a.enabled&&definitions.definitions.find(d=>d.definition.code===a.code)?.definition.mutation);assert.equal(writes.length,0);
 const frontend='.local/product-release-20261011/frontend-refinement-574d52fa3c5a4e48bdc75c9fe15cffd8/receipt.json',front=read(frontend);assert.equal(front.passed,true);for(const source of front.sources)assert.equal(hash(fs.readFileSync(source.path)),source.sha256,'Final frontend differs from checked source');
 const gateway='.local/agent-runtime-20261012/build-d06bbb7a4c6b40fc8fb4c69f016edc63/receipt.json';assert.equal(read(gateway).passed,true);
 const runtime=read('.local/phase1-implementation/verification-runtime.json');assert.equal(hash(fs.readFileSync(runtime.jarPath)),runtime.jarSHA256);
 const receipt={at:new Date().toISOString(),scope:'Eight general material tasks with real configured model; one actual human-saved source draft and bounded observer recovery; no publication or money',passed:true,database:context.database,runtimeJarSha256:runtime.jarSHA256,current,enabledAgentWrites:writes.length,artifacts:references.map(([p,r])=>artifact(p,r)),frontend:{path:frontend,sha256:hash(fs.readFileSync(frontend)),passed:true},gateway:{path:gateway,sha256:hash(fs.readFileSync(gateway)),tests:63,passed:true},failedUiHistory:fs.readdirSync(dir).filter(name=>name.startsWith('notice-draft-ui-')).map(name=>artifact(name+'/receipt.json','retained source/test/UI/observer history; not promoted to PASS')),sources:['ai-gateway/agent.mjs','ai-gateway/kernel.mjs','ai-gateway/agent-material.test.mjs','ai-gateway/source-price.test.mjs','plus-ui/src/views/sports/event/from-document.vue','scripts/Test-AgentRuntime.ps1'].map(p=>({path:p,sha256:hash(fs.readFileSync(p))})),limitations:['Government attachment originals did not download; two attributed notice-body extracts are bounded derivatives.','Synthetic notices and prices; no live event publication, registration or bank transaction.','Six scan pages tested; not arbitrary PDFs, spreadsheets, DOCX tables, phone hardware or load acceptance.','Historical failed receipts remain failed; accepted followups keep their original task or draft ID.','Main Java was not started; unchanged installed backend plus new gateway/frontend sources are prepared for next launch.']};
 fs.writeFileSync(record,JSON.stringify(receipt,null,2),{flag:'wx'});console.log('Current eight tasks and final scoped evidence captured');
}else{
 const live=read(record);assert.equal(live.passed,true);for(const source of live.sources)assert.equal(hash(fs.readFileSync(source.path)),source.sha256);
 const shutdownPath=process.env.AISPORTS_NOTICE_SHUTDOWN;assert.ok(shutdownPath);const shutdown=read(shutdownPath);assert.equal(shutdown.passed,true);
 const target='docs/04-verification/办赛通知真实使用验证-20261012.json';assert.ok(!fs.existsSync(target));
 const outputs=['docs/04-verification/办赛通知测试资料-20261012.zip','docs/04-verification/办赛通知阅读测试集-20261012.pdf'];
 fs.writeFileSync(target,JSON.stringify({...live,liveCapture:{path:path.relative(process.cwd(),record).replaceAll('\\','/'),sha256:hash(fs.readFileSync(record))},shutdown:{path:path.relative(process.cwd(),shutdownPath).replaceAll('\\','/'),sha256:hash(fs.readFileSync(shutdownPath)),passed:true},outputs:outputs.map(p=>({path:p,sha256:hash(fs.readFileSync(p))}))},null,2),{flag:'wx'});console.log('Immutable notice acceptance index sealed');
}
