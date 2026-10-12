// Actual public/saved-task UI. Guides choose intent; user drafts remain unchanged.
// GET/HEAD only. An attempted write is blocked and causes test failure.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import os from 'node:os';
import {createRequire} from 'node:module';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=require('playwright');
const out=path.resolve('.local/product-release-20261011','floating-assistant-'+Date.now());fs.mkdirSync(out,{recursive:true});
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const state=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8'));
const runtime=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8'));
const progress=JSON.parse(fs.readFileSync('.local/agent-playbook-20261011/read-facts-progress.json','utf8'));
assert.equal(runtime.port,8082);assert.match(runtime.database,/^aisports_verify_phase1_[a-f0-9]{32}$/);assert.equal(runtime.database,state.database);
const sources=['scripts/Test-FloatingSportsAssistant.mjs','plus-ui/src/components/consumer/ConsumerAssistant.vue','plus-ui/src/components/consumer/AgentPanel.vue','plus-ui/src/components/consumer/AssistantWindow.vue','plus-ui/src/assets/styles/sports-assistant.scss','plus-ui/src/assets/styles/sport-controls.scss','plus-ui/src/assets/styles/consumer.scss','plus-ui/src/assets/styles/design-system.scss'];
const report={timestamp:new Date().toISOString(),host:os.hostname(),isolatedJarSHA256:runtime.jarSHA256,scope:'Actual main/rehearsal anonymous chat and isolated ordinary participant saved task. Guide chips, empty default, preserved user drafts, single composer focus boundary, keyboard-open panel focus, pointer/keyboard geometry and factual history. Reduced motion. GET/HEAD only, no response stubs; any attempted write fails.',passed:false,checks:[],failures:[],pageErrors:[],writeRequests:[],focusStates:[],panelFocusStates:[],screenshots:[],sourceFiles:sources.map(file=>({path:file,sha256:sha(file)}))};
let page;const contexts=[];
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
report.browserVersion=browser.version();
function check(name,value){assert.ok(value,name);report.checks.push(name);}
async function shot(name){const file=path.join(out,name+'.png');await page.screenshot({path:file,fullPage:false});report.screenshots.push({path:path.relative(process.cwd(),file).replaceAll('\\','/'),sha256:sha(file)});}
async function open(base,width,actor){
 const context=await browser.newContext({viewport:{width,height:width<600?844:1000},reducedMotion:'reduce'});contexts.push(context);
 if(actor)await context.addInitScript(token=>{localStorage.setItem('Admin-Token',token);localStorage.setItem('Platform-Token',token);},actor.token);
 page=await context.newPage();page.on('pageerror',()=>report.pageErrors.push(base+'/'+width));
 await context.route('**/*',route=>{if(!['GET','HEAD'].includes(route.request().method())){report.writeRequests.push({path:new URL(route.request().url()).pathname,method:route.request().method()});return route.abort('blockedbyclient');}return route.continue();});
 await page.goto(base+'/portal/home',{waitUntil:'domcontentloaded'});await page.locator('.assistant-bubble').waitFor({timeout:60000});return context;
}
async function fit(window,width){const b=await window.boundingBox();return b&&b.x>=7&&b.y>=7&&b.x+b.width<=width-7&&b.y+b.height<=(width<600?844:1000)-7;}
async function selectGuide(window,card,input,label,prefix){
 const draft=await input.inputValue(),before=report.writeRequests.length;await card.click();const chip=window.locator('.assistant-guidance-chip');await chip.waitFor();
 check(prefix+' selects intended topic chip',(await chip.innerText()).includes(label));
 check(prefix+' never fills or overwrites composer',await input.inputValue()===draft);
 check(prefix+' never starts model or business write',report.writeRequests.length===before);
}
async function singleFocusBoundary(input,label){
 await input.focus();
 const actual=await input.evaluate(node=>{
  const wrapper=node.closest('.agent-input-box')||node.parentElement;
  const projection=element=>{const style=getComputedStyle(element);return {borders:[style.borderTopWidth,style.borderRightWidth,style.borderBottomWidth,style.borderLeftWidth].map(parseFloat),styles:[style.borderTopStyle,style.borderRightStyle,style.borderBottomStyle,style.borderLeftStyle],outlineStyle:style.outlineStyle,outlineWidth:parseFloat(style.outlineWidth),shadow:style.boxShadow};};
  return {focused:document.activeElement===node,focusWithin:wrapper.matches(':focus-within'),input:projection(node),wrapper:projection(wrapper)};
 });
 report.focusStates.push({label,...actual});
 check(label+' focused composer has one solid 1px wrapper boundary',actual.focused&&actual.focusWithin&&actual.wrapper.borders.every(width=>width===1)&&actual.wrapper.styles.every(style=>style==='solid'));
 check(label+' inner textarea adds no second border',actual.input.borders.every(width=>width===0));
 check(label+' focus adds no input or wrapper outline/halo',!hasPaintedOutline(actual.input)&&!hasPaintedOutline(actual.wrapper)&&actual.input.shadow==='none'&&actual.wrapper.shadow==='none');
}
// CSS may retain a nonzero outline-width while outline-style:none draws no line.
function hasPaintedOutline(style){return style.outlineWidth>0&&!['none','hidden'].includes(style.outlineStyle);}
async function panelKeyboardFocus(window,label){
 // AssistantWindow already focuses its panel when opened; retaining that same
 // programmatic focus after a real Enter activation exposes container CSS.
 await window.focus();
 const actual=await window.evaluate(node=>{const style=getComputedStyle(node);return {active:document.activeElement===node,keyboard:node.matches(':focus-visible'),outlineStyle:style.outlineStyle,outlineWidth:parseFloat(style.outlineWidth),outlineOffset:style.outlineOffset,shadow:style.boxShadow};});
 report.panelFocusStates.push({label,...actual});
 check(label+' keyboard-open panel has no extra outer focus frame',actual.active&&actual.keyboard&&!hasPaintedOutline(actual));
 const button=window.getByRole('button',{name:'关闭聊天窗口',exact:true});await button.focus();
 const buttonFocus=await button.evaluate(node=>{const style=getComputedStyle(node);return {active:document.activeElement===node,keyboard:node.matches(':focus-visible'),outlineStyle:style.outlineStyle,outlineWidth:parseFloat(style.outlineWidth),shadow:style.boxShadow};});
 report.panelFocusStates.push({label:label+'/close-button',...buttonFocus});
 check(label+' window controls still retain a visible keyboard focus cue',buttonFocus.active&&buttonFocus.keyboard&&(hasPaintedOutline(buttonFocus)||buttonFocus.shadow!=='none'));
}
try{
 for(const port of [5190,5192])for(const width of [390,730,1440]){
  const context=await open('http://127.0.0.1:'+port,width),label=port+'/'+width,bubble=page.locator('.assistant-bubble');await bubble.waitFor();const b=await bubble.boundingBox();
  check(label+' one bounded bubble',await bubble.count()===1&&b.width===64&&b.height===76);
  check(label+' no duplicate account assistant',await page.locator('.header-ai-entry,.home-advisor,.consumer-mobile-ai').count()===0);
  check(label+' bubble image cannot drag',await bubble.locator('img').evaluate(i=>!i.draggable&&i.getBoundingClientRect().width===54));
  await bubble.focus();await bubble.press('Enter');const window=page.locator('.assistant-window');await window.waitFor();await panelKeyboardFocus(window,label);check(label+' window fits',await fit(window,width));
  check(label+' three public guides remain',await window.locator('.assistant-feature-card').count()===3);
  const input=window.getByRole('textbox',{name:'发给 AI 的消息',exact:true});
  check(label+' default empty and send disabled',await input.inputValue()===''&&await window.getByRole('button',{name:'发送消息',exact:true}).isDisabled());
  await selectGuide(window,window.locator('[data-testid="assistant-public-events"]'),input,'找适合我的比赛',label+'/events');
  await selectGuide(window,window.locator('[data-testid="assistant-public-rules"]'),input,'看懂赛事规程',label+'/rules');
  await selectGuide(window,window.locator('[data-testid="assistant-entry-preparation"]'),input,'第一次参赛怎么准备',label+'/first-entry');
  check(label+' three real bounded guide illustrations',await window.locator('.assistant-feature-icon img').evaluateAll(images=>images.length===3&&images.every(i=>i.complete&&i.naturalWidth>0&&!i.draggable&&i.getBoundingClientRect().width<=80)));
  const draft='周末上午想找双打，先保留我的这句话';await input.fill(draft);await singleFocusBoundary(input,label+'/public-composer');
  await selectGuide(window,window.locator('[data-testid="assistant-public-rules"]'),input,'看懂赛事规程',label+'/existing-draft');
  await window.getByRole('button',{name:'取消当前引导',exact:true}).click();check(label+' cancel topic preserves draft',await window.locator('.assistant-guidance-chip').count()===0&&await input.inputValue()===draft);
  await input.press('End');await input.press('Shift+Enter');const multiline=await input.inputValue();check(label+' Shift+Enter preserves unsent multiline draft',multiline===draft+'\n');
  await window.getByRole('button',{name:'放大聊天窗口',exact:true}).click();check(label+' expanded window fits',await fit(window,width));
  await window.getByRole('button',{name:'缩小聊天窗口',exact:true}).click();const previous=await window.boundingBox();
  await window.getByRole('button',{name:'调整聊天窗口尺寸，方向键调整',exact:true}).press('ArrowLeft');check(label+' keyboard resize stays bounded',(await window.boundingBox()).width<previous.width||width===390&&previous.width<=330);
  const heading=window.locator('.assistant-window-heading');await heading.focus();await heading.press('ArrowDown');check(label+' keyboard moves window safely',await fit(window,width));
  if(width===1440){const before=await window.boundingBox();await page.mouse.move(before.x+110,before.y+24);await page.mouse.down();await page.mouse.move(before.x+10,before.y+94,{steps:8});await page.mouse.up();check(label+' pointer drag moves window',Math.abs((await window.boundingBox()).x-before.x)>50);}
  await shot(label.replace('/','-')+'-chat');await window.getByRole('button',{name:'关闭聊天窗口',exact:true}).click();await window.waitFor({state:'hidden'});
  await bubble.focus();const old=await bubble.boundingBox();await bubble.press('ArrowLeft');check(label+' keyboard moves bubble',(await bubble.boundingBox()).x<old.x);
  if(width===1440){const before=await bubble.boundingBox();await page.mouse.move(before.x+25,before.y+25);await page.mouse.down();await page.mouse.move(before.x-140,before.y-90,{steps:8});await page.mouse.up();check(label+' bubble drag does not open chat',await window.count()===0&&(await bubble.boundingBox()).x<before.x-80);}
  await bubble.click();await window.waitFor();check(label+' reopening retains exact multiline draft',await window.getByRole('textbox',{name:'发给 AI 的消息',exact:true}).inputValue()===multiline);
  await window.press('Escape');await window.waitFor({state:'hidden'});await page.goto('http://127.0.0.1:'+port+'/portal/login');await page.getByPlaceholder('请输入手机号',{exact:true}).waitFor();check(label+' auth has no assistant',await page.locator('.assistant-bubble').count()===0);await context.close();
 }
 for(const width of [390,1440]){
  const context=await open('http://127.0.0.1:5192',width,state.people[0]),label='participant/'+width;
  await page.locator('.assistant-bubble').click();const window=page.locator('.assistant-window.product-agent');await window.waitFor();await window.locator('.agent-welcome').waitFor();
  check(label+' six real task guides remain',await window.locator('.agent-welcome .assistant-feature-card').count()===6);
  const input=window.getByRole('textbox',{name:'发给体育助手的消息',exact:true});check(label+' default composer empty',await input.inputValue()==='');
  for(const id of ['agent-feature-growth','agent-feature-rules','agent-feature-materials']){const card=window.locator('[data-testid="'+id+'"]');await selectGuide(window,card,input,await card.locator('strong').innerText(),label+'/'+id);}
  check(label+' first organizing guidance remains',await window.locator('[data-testid="agent-feature-materials"] strong').innerText()==='第一次办赛怎么准备');
  const draft='我想先看看现有记录，这句话还没发送';await input.fill(draft);await singleFocusBoundary(input,label+'/participant-composer');const rules=window.locator('[data-testid="agent-feature-rules"]');
  await selectGuide(window,rules,input,await rules.locator('strong').innerText(),label+'/existing-draft');
  await window.getByRole('button',{name:'取消当前引导',exact:true}).click();check(label+' cancel participant intent preserves draft',await input.inputValue()===draft&&await window.locator('.assistant-guidance-chip').count()===0);
  await window.getByRole('button',{name:'查看任务记录',exact:true}).click();const target=progress.runs['personal-facts'],list=window.locator('.agent-history>button');await list.first().waitFor();
  await list.filter({hasText:target.goal}).first().click();await window.locator('.agent-message.assistant').last().waitFor();
  check(label+' saved task preserves user draft',await input.inputValue()===draft);check(label+' actual factual guidance renders',await window.locator('.agent-question,.agent-guidance,.agent-checklist').count()>0);
  check(label+' floating Agent fits',await fit(window,width)&&await page.locator('.el-overlay').count()===0);
  const layout=await window.evaluate(el=>{const c=el.querySelector('.agent-composer').getBoundingClientRect(),t=el.querySelector('.agent-thread').getBoundingClientRect();return {okay:t.bottom<=c.top+1&&c.bottom<=el.getBoundingClientRect().bottom+1,overflow:el.scrollWidth>el.clientWidth+2};});
  check(label+' independent scroll and composer',layout.okay&&!layout.overflow);await shot('participant-'+width+'-saved');
  await window.getByRole('button',{name:'关闭聊天窗口',exact:true}).click();await window.waitFor({state:'hidden'});await page.locator('.assistant-bubble').click();await window.waitFor();
  check(label+' close/reopen restores task and unsent draft',await window.locator('.agent-message.assistant').count()>0&&await window.getByRole('textbox',{name:'发给体育助手的消息',exact:true}).inputValue()===draft);await context.close();
 }
 check('zero page errors and attempted writes',report.pageErrors.length===0&&report.writeRequests.length===0);
 check('tested source and composer/control styles remained unchanged during verification',report.sourceFiles.every(file=>sha(file.path)===file.sha256));report.passed=true;
}catch(error){report.failures.push({reason:error.name==='AssertionError'?error.message:'UI did not complete',path:page?new URL(page.url()).pathname:undefined,errorType:error.name});await page?.screenshot({path:path.join(out,'failure.png'),fullPage:false}).catch(()=>{});process.exitCode=1;}
finally{for(const context of contexts)await context.close();await browser.close();const file=path.join(out,'receipt.json'),fd=fs.openSync(file,'wx');try{fs.writeFileSync(fd,JSON.stringify(report,null,2)+'\n');fs.fsyncSync(fd);}finally{fs.closeSync(fd);}console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,failures:report.failures,receipt:path.relative(process.cwd(),file).replaceAll('\\','/'),sha256:sha(file)}));}
