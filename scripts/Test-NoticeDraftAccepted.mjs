// Read-only continuation after a test evidence query failed following an already successful UI save.
// Never replay the upload, model dialogue, confirmation or successful draft transaction.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
import {context,api,request,readSql,createEvidence} from './lib/BusinessRegression.mjs';
const source=path.join(context.out,'notice-draft-ui-1791763384290-fd7ffd01/receipt.json'),before=JSON.parse(fs.readFileSync(source,'utf8')),proof=createEvidence('notice-draft-accepted');
proof.evidence.priorReceiptSha256=crypto.createHash('sha256').update(fs.readFileSync(source)).digest('hex');
const {taskId,eventId}=before.objects;assert.match(taskId,/^\d+$/);assert.match(eventId,/^\d+$/);assert.equal(before.confirmation.result.created,true);
proof.evidence.objects={taskId,eventId};proof.save();
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json'),{chromium}=require('playwright');
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
try{
 const task=await api(context.organizer,'/sports/b/ai/tasks/'+taskId),event=await api(context.organizer,'/sports/b/events/'+eventId);
 const rows=JSON.parse(readSql(`SELECT json_agg(json_build_object('name',u.name,'seatsMin',u.min_members,'seatsMax',u.max_members,'quota',c.limit_count,'amount',f.amount,'pricingUnit',f.pricing_unit,'used',c.used_count)) FROM asp_competition_unit u JOIN asp_fee_policy f ON f.unit_id=u.id JOIN asp_capacity_pool c ON c.unit_id=u.id WHERE u.event_id=${eventId};`));
 proof.evidence.persisted={eventId,name:event.name,publication:readSql(`SELECT publication_status FROM asp_event WHERE id=${eventId};`),rows};proof.save();
 proof.check('original UI actually confirmed the current candidate version and chosen declaration',before.checks.some(c=>c.name==='explicit UI save binds the current version and chosen declaration'&&c.passed)&&before.confirmation.declarationAckRequired===true,{boundary:'Uses the retained actual successful UI response; prior SQL evidence failure remains failed.'});
 proof.check('the same source task links to exactly one saved draft',task.status==='CREATED'&&String(task.resultObjectId)===eventId&&event.name===context.prefix+'-星河通知草稿验证'&&readSql(`SELECT count(*) FROM asp_event WHERE name='${context.prefix}-星河通知草稿验证';`)==='1');
 proof.check('two source whole-order prices quotas and seats persist in real separate tables',rows.length===2&&rows.some(r=>Number(r.amount)===30&&Number(r.quota)===16&&Number(r.seatsMin)===1)&&rows.some(r=>Number(r.amount)===60&&Number(r.quota)===12&&Number(r.seatsMin)===2&&Number(r.seatsMax)===2));
 proof.check('event remains unpublished with chosen declaration and no occupied registration',proof.evidence.persisted.publication==='draft'&&readSql(`SELECT declaration_ack_required FROM asp_event WHERE id=${eventId};`)==='t'&&rows.every(r=>Number(r.used)===0)&&readSql(`SELECT count(*) FROM asp_registration r JOIN asp_competition_unit u ON u.id=r.unit_id WHERE u.event_id=${eventId};`)==='0');
 proof.check('another ordinary participant cannot read the private source task',(await request(context.people[5],'/sports/b/ai/tasks/'+taskId)).code!==200);
 const session=await browser.newContext({viewport:{width:1440,height:1000},reducedMotion:'reduce'});await session.addInitScript(token=>localStorage.setItem('Admin-Token',token),context.organizer.token);const page=await session.newPage();
 await page.route('**/dev-api/sports/**',route=>route.request().method()==='GET'?route.continue():route.abort('blockedbyclient'));
 await page.goto(context.frontend+'/org-desk/workspace/'+eventId,{waitUntil:'domcontentloaded'});await page.getByText(event.name,{exact:true}).first().waitFor();await page.screenshot({path:path.join(proof.directory,'saved-draft.png'),fullPage:false});
 proof.check('organizer can reopen the saved event workbench',page.url().endsWith('/org-desk/workspace/'+eventId));proof.finish();
}catch(e){proof.evidence.failure=String(e.message).slice(0,400);proof.save();process.exitCode=1;console.log('Read-only draft continuation failed; no transaction replay');}
finally{await browser.close();}
