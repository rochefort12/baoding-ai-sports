// Actual file selection, upload, multi-turn answer and reopen on desktop/mobile.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
import {context,api,readSql,createEvidence} from './lib/BusinessRegression.mjs';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=require('playwright'),proof=createEvidence('notice-ui');
const source=path.resolve('.local/notice-trial-20261012/qa/01-测试收费双打通知-1.png');assert.ok(fs.existsSync(source));
proof.evidence.source={name:path.basename(source),sha256:crypto.createHash('sha256').update(fs.readFileSync(source)).digest('hex'),kind:'PNG rendered from the synthetic charged notice, no text attachment in this test'};
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
const errors=[],forbidden=[];let runId=process.env.AISPORTS_NOTICE_UI_RUN;
if(runId){assert.match(runId,/^\d+$/);proof.evidence.objects.runId=runId;proof.evidence.mode='Reopen the already uploaded task on the proper organizer workspace; no repeat model call';}
async function settled(id){const start=Date.now();while(Date.now()-start<310000){const run=await api(context.organizer,'/sports/agents/runs/'+id);if(!['running','waiting_children'].includes(run.status)&&readSql(`SELECT tokens_reserved FROM asp_agent_run WHERE id=${id};`)==='0')return run;await new Promise(r=>setTimeout(r,1700));}throw Error('UI model round timed out');}
try{
 for(const [device,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}]]){
  const session=await browser.newContext({viewport,reducedMotion:'reduce'});await session.addInitScript(token=>localStorage.setItem('Admin-Token',token),context.organizer.token);const page=await session.newPage();page.setDefaultTimeout(45000);page.on('pageerror',()=>errors.push(device+' page error'));
  await page.route('**/dev-api/sports/**',route=>{const req=route.request();if(req.method()!=='GET'&&!new URL(req.url()).pathname.includes('/sports/agents/runs')){forbidden.push(new URL(req.url()).pathname);return route.abort('blockedbyclient');}return route.continue();});
  await page.goto(context.frontend+'/org-desk/events',{waitUntil:'domcontentloaded'});await page.getByRole('button',{name:'打开 AI 运营助手',exact:true}).click();await page.locator('.b-ai-window').getByRole('button',{name:'其他任务 →',exact:true}).click();const panel=page.locator('.product-agent.assistant-window');await panel.waitFor();
  if(device==='desktop'&&!process.env.AISPORTS_NOTICE_UI_RUN){
   await panel.getByRole('button',{name:'查看任务记录',exact:true}).click();await panel.getByRole('button',{name:'新任务',exact:true}).click();
   const goal='请阅读这张办赛通知图片，告诉我男子单打和混合双打各有多少单、每单几人、每单收费多少，列出比赛与报名日期。只整理，不创建不发布。';
   await panel.locator('input[type=file]').setInputFiles(source);proof.check('desktop selects the actual notice image',await panel.locator('.agent-attachments>div').count()===1);
   await panel.getByRole('textbox',{name:'发给体育助手的消息'}).fill(goal);
   const uploaded=page.waitForResponse(r=>r.url().includes('/sports/agents/runs/materials')&&r.request().method()==='POST',{timeout:130000});await panel.getByRole('button',{name:'发送任务',exact:true}).click();const reply=await (await uploaded).json();assert.equal(reply.code,200);runId=String(reply.data.runId);assert.match(runId,/^\d+$/);proof.evidence.objects.runId=runId;proof.save();
   const first=await settled(runId);proof.evidence.initial={status:first.status,stopReason:first.stopReason,messages:first.messages.map(m=>({role:m.role,content:m.content,blocks:m.blocks}))};proof.save();
   const text=first.messages.filter(m=>m.role==='assistant').at(-1)?.content||'';
   proof.check('actual image recognition returns correct pair seats quotas prices and date',first.status==='waiting_input'&&['16','12','30','60','2','2026年12月19日'].every(n=>text.includes(n)),{runId,status:first.status,stopReason:first.stopReason});
   await panel.locator('.agent-message.assistant').last().waitFor();
   const beforeUsers=first.messages.filter(m=>m.role==='user').length;
   await panel.getByRole('textbox',{name:'发给体育助手的消息'}).fill('我们两人报一单混双，总共应付多少？不要按每人重复算，也不要实际付款。');
   const submitted=page.waitForResponse(r=>r.url().includes('/sports/agents/runs/'+runId+'/answer')&&r.request().method()==='POST');await panel.getByRole('button',{name:'发送任务',exact:true}).click();assert.equal((await (await submitted).json()).code,200);
   const continued=await settled(runId);proof.evidence.continuation={status:continued.status,stopReason:continued.stopReason,messages:continued.messages.map(m=>({role:m.role,content:m.content,blocks:m.blocks}))};proof.save();
   const answer=continued.messages.filter(m=>m.role==='assistant').at(-1)?.content||'';
   proof.check('desktop followup uses the original image task and answers total 60 not 120',continued.status==='waiting_input'&&continued.messages.filter(m=>m.role==='user').length===beforeUsers+1&&/60/.test(answer)&&/(整|总|合计|一单|每单)/.test(answer),{runId});
   await panel.getByRole('button',{name:'关闭聊天窗口',exact:true}).click();await page.locator('.b-ai-window').getByRole('button',{name:'其他任务 →',exact:true}).click();await panel.locator('.agent-message.assistant').last().waitFor();
   proof.check('closing and reopening preserves the actual dialogue',(await panel.innerText()).includes('60'));
  }else{
   await panel.getByRole('button',{name:'查看任务记录',exact:true}).click();await panel.locator('.agent-history>button').filter({hasText:'请阅读这张办赛通知图片'}).first().click();await panel.locator('.agent-message.assistant').nth(1).waitFor();
   proof.check(device+' organizer workspace opens the settled material followup',(await panel.locator('.agent-message.assistant').last().innerText()).includes('60')&&await panel.getByRole('textbox',{name:'发给体育助手的消息'}).isEnabled());
  }
  const box=await panel.boundingBox(),overflow=await panel.evaluate(el=>el.scrollWidth>el.clientWidth+2);proof.check(device+' notice conversation fits viewport',box.x>=-1&&box.width<=viewport.width+1&&!overflow);
  await panel.locator('.agent-thread').evaluate(el=>el.scrollTop=el.scrollHeight);await page.screenshot({path:path.join(proof.directory,device+'.png')});await session.close();
 }
 proof.check('UI issues no business write and produces no page error',forbidden.length===0&&errors.length===0,{forbidden,errors});proof.finish();
}catch(e){proof.evidence.failure=String(e.message).slice(0,400);proof.evidence.errors=errors;proof.evidence.forbidden=forbidden;proof.save();console.log('Notice UI test failed; receipt retained');process.exitCode=1;}
finally{await browser.close();}
