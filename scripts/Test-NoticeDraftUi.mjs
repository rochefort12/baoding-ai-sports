// Organizer uploads a notice, edits only the new synthetic name and explicitly saves a reviewed draft.
// No publication, registration, money, or existing business object is changed.
import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
import {context,api,request,readSql,createEvidence} from './lib/BusinessRegression.mjs';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json'),{chromium}=require('playwright');
const proof=createEvidence('notice-draft-ui'),name=context.prefix+'-星河通知草稿验证';
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
let taskId=process.env.AISPORTS_NOTICE_DRAFT_TASK,eventId;
if(taskId)assert.match(taskId,/^\d+$/);
const v=node=>node?.value;
try{
 const session=await browser.newContext({viewport:{width:1440,height:1000},reducedMotion:'reduce'});await session.addInitScript(token=>localStorage.setItem('Admin-Token',token),context.organizer.token);const page=await session.newPage();page.setDefaultTimeout(45000);
 await page.goto(context.frontend+'/org-desk/events/from-document'+(taskId?'/'+taskId:''),{waitUntil:'domcontentloaded'});await page.getByRole('heading',{name:'AI办赛',exact:true}).waitFor();
 if(!taskId){
 await page.locator('.b-document-workspace input[type=file]').setInputFiles(path.resolve('docs/04-verification/notice-fixtures-20261012/01-测试收费双打通知.pdf'));
 await page.locator('.el-checkbox').filter({hasText:'我同意把必要的办赛内容'}).click();
 const uploaded=page.waitForResponse(r=>r.url().includes('/sports/b/ai/tasks?')&&r.request().method()==='POST',{timeout:320000});await page.getByRole('button',{name:'识别上传资料',exact:true}).click();const upload=await (await uploaded).json();assert.equal(upload.code,200);taskId=String(upload.data.id);assert.match(taskId,/^\d+$/);proof.evidence.objects.taskId=taskId;proof.save();
 }else{proof.evidence.objects.taskId=taskId;proof.evidence.recovery='Reuse the original pending source task after test formatting assertion; no repeat upload or recognition';proof.save();}
 let task;const end=Date.now()+310000;do{task=await api(context.organizer,'/sports/b/ai/tasks/'+taskId);if(!['UPLOADED','PROCESSING'].includes(task.status))break;await new Promise(r=>setTimeout(r,1800));}while(Date.now()<end);
 proof.evidence.recognition={status:task.status,errorCode:task.errorCode,version:task.version,proposal:JSON.parse(task.proposal||'{}'),coverage:JSON.parse(task.extraction||'{}')};proof.save();
 proof.check('ordinary organizer uploads the source and receives a pending candidate without an event',task.status==='PENDING_CONFIRMATION'&&!task.resultObjectId,{taskId});
 const p=JSON.parse(task.proposal||'{}');
 proof.check('material candidate carries two explicit whole-order prices and pair seats',p.units.length===2&&p.units.some(u=>Number(v(u.feeAmount))===60&&v(u.entryType)==='pair'&&Number(v(u.minMembers))===2&&Number(v(u.maxMembers))===2&&Number(v(u.limitCount))===12)&&p.units.some(u=>Number(v(u.feeAmount))===30&&Number(v(u.limitCount))===16));
 await page.getByRole('region',{name:'待核对参赛项目'}).waitFor().catch(()=>{});
 if(!process.env.AISPORTS_NOTICE_DRAFT_TASK){
 await page.locator('.composer input').waitFor();await page.locator('.composer input').fill('请把赛事名称改为'+name+'，只修改名称，其他原文内容保持，不保存不发布。');
 const changed=page.waitForResponse(r=>r.url().includes('/sports/b/ai/tasks/'+taskId+'/talk')&&r.request().method()==='POST',{timeout:120000});await page.locator('.composer').getByRole('button',{name:'发送',exact:true}).click();assert.equal((await (await changed).json()).code,200);
 task=await api(context.organizer,'/sports/b/ai/tasks/'+taskId);proof.check('name edit keeps this exact material task and advances its revision',v(JSON.parse(task.proposal).event.name)===name&&task.version>proof.evidence.recognition.version,{version:task.version});
 const oldPayload=await request(context.organizer,'/sports/b/ai/tasks/'+taskId+'/talk','POST',{message:'请确认并保存赛事草稿'});
 proof.check('a save without current version and explicit declaration choice is rejected without creation',oldPayload.code===200&&!oldPayload.data.created&&readSql(`SELECT count(*) FROM asp_event WHERE name='${name}';`)==='0',{reply:oldPayload.data.reply,boundary:'Demonstrates the old dedicated-page payload cannot pass the existing safety contract; no bypass.'});
 }
 if(!v(JSON.parse(task.proposal).event.declarationText)){
  await page.locator('.composer input').waitFor();await page.locator('.composer input').fill('按原通知原文明确参赛声明为：参赛人须自行核对运动适宜性，服从裁判和场馆安排。这里只把原规则作为可阅读声明，不增加免责条款，是否要求确认由我在页面选择；其他内容保持，不保存不发布。');
  const amended=page.waitForResponse(r=>r.url().includes('/sports/b/ai/tasks/'+taskId+'/talk')&&r.request().method()==='POST',{timeout:120000});await page.locator('.composer').getByRole('button',{name:'发送',exact:true}).click();assert.equal((await (await amended).json()).code,200);
 }
 await page.reload({waitUntil:'domcontentloaded'});await page.getByRole('button',{name:'确认保存草稿',exact:true}).waitFor();
 const projects=await page.locator('[aria-label="待核对参赛项目"]').innerText();proof.check('human review displays whole-order prices seats and quotas',/每单30(?:\.0+)?元/.test(projects)&&/每单60(?:\.0+)?元/.test(projects)&&projects.includes('每单2人')&&projects.includes('12单'),{displayedProjects:projects});
 await page.locator('.el-checkbox').filter({hasText:'要求每位参赛成员阅读并确认这份声明'}).click();await page.screenshot({path:path.join(proof.directory,'before-human-save.png'),fullPage:true});
 const saved=page.waitForResponse(r=>r.url().includes('/sports/b/ai/tasks/'+taskId+'/talk')&&r.request().method()==='POST',{timeout:120000});await page.getByRole('button',{name:'确认保存草稿',exact:true}).click();const response=await saved,payload=response.request().postDataJSON(),body=await response.json();proof.evidence.confirmation={expectedVersion:payload.expectedVersion,declarationAckRequired:payload.declarationAckRequired,result:body.data};proof.save();
 proof.check('explicit UI save binds the current version and chosen declaration',Number.isInteger(payload.expectedVersion)&&payload.declarationAckRequired===true&&body.code===200&&body.data.created===true);
 eventId=String(body.data.eventId);assert.match(eventId,/^\d+$/);proof.evidence.objects.eventId=eventId;proof.save();
 const event=await api(context.organizer,'/sports/b/events/'+eventId),rows=JSON.parse(readSql(`SELECT json_agg(json_build_object('name',u.name,'seatsMin',u.min_members,'seatsMax',u.max_members,'quota',c.limit_count,'amount',f.amount,'pricingUnit',f.pricing_unit)) FROM asp_competition_unit u JOIN asp_fee_policy f ON f.unit_id=u.id JOIN asp_capacity_pool c ON c.unit_id=u.id WHERE u.event_id=${eventId};`));
 proof.evidence.persisted={status:event.status,name:event.name,projects:rows};proof.save();
 proof.check('saved event stays a draft and both source order prices reach real fee policies',event.name===name&&readSql(`SELECT publication_status FROM asp_event WHERE id=${eventId};`)==='draft'&&rows.length===2&&rows.some(r=>Number(r.amount)===60&&Number(r.seatsMin)===2&&Number(r.seatsMax)===2&&Number(r.quota)===12)&&rows.some(r=>Number(r.amount)===30&&Number(r.quota)===16));
 const reloaded=await api(context.organizer,'/sports/b/ai/tasks/'+taskId);proof.check('source task links to the single actual draft',reloaded.status==='CREATED'&&String(reloaded.resultObjectId)===eventId&&readSql(`SELECT count(*) FROM asp_event WHERE name='${name}';`)==='1');
 proof.check('draft save creates no registration or actual money obligation',readSql(`SELECT count(*) FROM asp_registration r JOIN asp_competition_unit u ON u.id=r.unit_id WHERE u.event_id=${eventId};`)==='0');
 await page.waitForURL('**/org-desk/workspace/'+eventId);await page.screenshot({path:path.join(proof.directory,'saved-draft.png'),fullPage:false});proof.finish();
}catch(e){proof.evidence.failure=String(e.message).slice(0,400);proof.save();console.log('Notice draft UI failed; preserve task and any existing draft');process.exitCode=1;}
finally{await browser.close();}
