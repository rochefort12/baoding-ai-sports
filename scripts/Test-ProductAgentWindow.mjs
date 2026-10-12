// Actual saved Agent conversation UI. Reads only; never asks the model or executes an action.
import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json'),{chromium}=require('playwright');
const state=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8')),runtime=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8')),progress=JSON.parse(fs.readFileSync('.local/agent-playbook-20261011/progress.json','utf8'));
assert.equal(state.database,runtime.database);assert.match(runtime.database,/^aisports_verify_phase1_[a-f0-9]{32}$/);assert.equal(runtime.port,8082);
const out=path.resolve('.local/product-release-20261011','agent-window-'+Date.now());fs.mkdirSync(out,{recursive:true});
const factsMode=process.argv.includes('--facts'),factsProgress=factsMode?JSON.parse(fs.readFileSync('.local/agent-playbook-20261011/read-facts-progress.json','utf8')):undefined;
const runtimeTask=process.env.AISPORTS_AGENT_UI_RUN;if(runtimeTask)assert.match(runtimeTask,/^\d+$/);
const checks=[],failures=[],pageErrors=[],writeRequests=[];const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
function check(name,condition){assert.ok(condition,name);checks.push(name);}
async function read(actor,route){const response=await fetch('http://127.0.0.1:8082'+route,{headers:{clientid:'e5cd7e4891bf95d1d19206ce24a7b32e',Authorization:'Bearer '+actor.token}});const body=await response.json();assert.equal(body.code,200);return body.data;}
try{
 for(const [device,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}]]){
 const actor=state.people[runtimeTask?1:0],history=await read(actor,'/sports/agents/runs'),target=history.find(run=>run.id===(runtimeTask||(factsMode?factsProgress.runs['personal-facts'].id:progress.steps.participant.id)));assert.ok(target,'Previously verified real conversation required');
 const original=await read(actor,'/sports/agents/runs/'+target.id);
 const context=await browser.newContext({viewport,reducedMotion:'reduce'});await context.addInitScript(token=>localStorage.setItem('Admin-Token',token),actor.token);const page=await context.newPage();page.on('pageerror',()=>pageErrors.push(device+' page error'));
 await context.route('**/dev-api/**',route=>{if(!['GET','HEAD'].includes(route.request().method())){writeRequests.push(new URL(route.request().url()).pathname);return route.abort('blockedbyclient');}return route.continue();});
 await page.goto('http://127.0.0.1:5192/portal/home',{waitUntil:'domcontentloaded'});await page.getByRole('heading',{name:'找到下一场比赛',exact:true}).waitFor();
 await page.locator('.assistant-bubble').click();const drawer=page.locator('.product-agent.assistant-window');await drawer.waitFor();
 await drawer.getByRole('button',{name:'查看任务记录',exact:true}).click();await drawer.locator('.agent-history>button').filter({hasText:target.goal}).first().click();await drawer.locator('.agent-message.assistant').last().waitFor();await page.waitForTimeout(200);
 const bounds=await drawer.boundingBox();check(device+' drawer fits viewport',bounds.width<=viewport.width+1&&bounds.x>=-1&&bounds.x+bounds.width<=viewport.width+1);
 const layout=await drawer.evaluate(el=>{const composer=el.querySelector('.agent-composer').getBoundingClientRect(),thread=el.querySelector('.agent-thread').getBoundingClientRect();return {composerBottom:composer.bottom,threadBottom:thread.bottom,composerTop:composer.top,overflow:el.scrollWidth>el.clientWidth+2};});check(device+' composer remains below independent conversation scroll',!layout.overflow&&layout.composerBottom<=viewport.height+1&&layout.threadBottom<=layout.composerTop+1);
 check(device+' actual model task blocks render as cards',await drawer.locator('.agent-question,.agent-guidance,.agent-checklist').count()>0);
 if(factsMode){const growth=await read(actor,'/sports/growth/card?sportId='+state.sportId);check(device+' latest factual model reply is visible in the saved conversation',(await drawer.locator('.agent-message.assistant').last().innerText()).includes(String(growth.points)));}
 check(device+' no model consent or provider configuration paragraph',!(await drawer.innerText()).includes('当前配置的外部 AI 模型服务')&&!(await drawer.innerText()).includes('MODEL_'));
 check(device+' decorative images stay small and cannot natively drag',await drawer.locator('img').evaluateAll(images=>images.every(image=>!image.draggable&&image.getBoundingClientRect().width<=80)));
 const option=drawer.locator('.agent-question button').first();if(await option.count()){await option.click();check(device+' answering option only prefills editable message',!!await drawer.getByRole('textbox',{name:'发给体育助手的消息'}).inputValue());}
 const textbox=drawer.getByRole('textbox',{name:'发给体育助手的消息'});await textbox.fill('继续原任务');await textbox.press('Shift+Enter');check(device+' Shift Enter inserts newline without submitting',(await textbox.inputValue()).includes('\n'));
 await drawer.getByRole('button',{name:'文件要求',exact:true}).click();check(device+' file requirements are available on demand',await drawer.locator('.agent-file-help').isVisible());
 await drawer.locator('input[type=file]').setInputFiles(Array.from({length:5},(_,index)=>({name:'资料'+index+'.pdf',mimeType:'application/pdf',buffer:Buffer.from('not-uploaded client validation')})));check(device+' oversized attachment count is stopped before upload',await drawer.getByRole('alert').isVisible()&&await drawer.locator('.agent-attachments>div').count()===0);
 await drawer.getByRole('button',{name:'知道了',exact:true}).click();check(device+' attachment hint can dismiss without losing the message',await drawer.getByRole('alert').count()===0&&(await textbox.inputValue()).includes('继续原任务'));
 await drawer.getByRole('button',{name:'文件要求',exact:true}).click();
 await drawer.locator('.agent-thread').evaluate(el=>el.scrollTop=el.scrollHeight);await page.screenshot({path:path.join(out,device+'-saved-conversation.png'),fullPage:false});
 await drawer.getByRole('button',{name:'关闭聊天窗口',exact:true}).click();await drawer.waitFor({state:'hidden'});await page.locator('.assistant-bubble').click();await drawer.waitFor();await drawer.locator('.agent-message.assistant').last().waitFor();check(device+' reopening retains saved task',await drawer.locator('.agent-question,.agent-guidance,.agent-checklist').count()>0);
 const after=await read(actor,'/sports/agents/runs/'+target.id);check(device+' UI inspection changes no durable messages or steps',after.messages.length===original.messages.length&&after.steps.length===original.steps.length);
 await context.close();
 }
 assert.deepEqual(pageErrors,[]);assert.deepEqual(writeRequests,[]);console.log('PASS '+checks.length+' actual saved Agent UI checks');
}catch(error){failures.push({reason:String(error.message).slice(0,500)});console.error('Agent window UI check failed; private evidence retained');process.exitCode=1;}
finally{fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify({timestamp:new Date().toISOString(),scope:'Real saved DeepSeek task UI with isolated synthetic account; no model request or business mutation',passed:failures.length===0,checks,failures,pageErrors,writeRequests},null,2),{flag:'wx'});console.log('Evidence '+path.relative(process.cwd(),out));await browser.close();}
