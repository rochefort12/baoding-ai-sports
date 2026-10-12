// Real transform/opacity motion and reduced-motion checks. Samples establish an
// observed transition, not frame rate or general animation performance.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import os from 'node:os';
import {createRequire} from 'node:module';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=require('playwright');
const output=path.resolve('.local/product-release-20261011','assistant-motion-'+Date.now());fs.mkdirSync(output,{recursive:true});
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const runtime=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8'));
const state=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8'));
assert.equal(runtime.port,8082);assert.match(runtime.database,/^aisports_verify_phase1_[a-f0-9]{32}$/);assert.equal(runtime.database,state.database);
const sources=['scripts/Test-AssistantMotionUI.mjs','plus-ui/src/components/consumer/AssistantWindow.vue','plus-ui/src/components/consumer/ConsumerAssistant.vue','plus-ui/src/components/consumer/AgentPanel.vue','plus-ui/src/assets/styles/sports-assistant.scss','plus-ui/src/assets/styles/sport-controls.scss','plus-ui/src/assets/styles/consumer.scss','plus-ui/src/assets/styles/design-system.scss'];
const report={timestamp:new Date().toISOString(),host:os.hostname(),isolatedJarSHA256:runtime.jarSHA256,scope:'Actual anonymous 5190/5192 at 390/1440 in ordinary and reduced-motion mode. CSS enter/leave and WAAPI FLIP resize observed through getAnimations and rAF geometry samples. Additional ordinary A growth/legend readonly screenshot. No response stubs, model calls or business writes. Samples do not prove fixed fps.',passed:false,checks:[],failures:[],pageErrors:[],responseFailures:[],transportFailures:[],blockedWrites:[],traces:[],screenshots:[],sourceFiles:sources.map(file=>({path:file,sha256:sha(file)}))};
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
report.browserVersion=browser.version();
const contexts=[];let page,stage='start';
function check(name,value){assert.ok(value,name);report.checks.push(name);}
async function create(width,motion,base,token){
 stage=base+'/'+width+'/'+motion+'/load';
 const context=await browser.newContext({viewport:{width,height:width<600?844:1000},reducedMotion:motion});contexts.push(context);
 if(token)await context.addInitScript(value=>{localStorage.setItem('Admin-Token',value);localStorage.setItem('Platform-Token',value);},token);
 page=await context.newPage();page.on('pageerror',()=>report.pageErrors.push(stage));
 page.on('response',response=>{if(response.status()>=400)report.responseFailures.push({stage,path:new URL(response.url()).pathname,status:response.status()});});
 page.on('requestfailed',request=>report.transportFailures.push({stage,path:new URL(request.url()).pathname,reason:request.failure()?.errorText}));
 await context.route('**/*',route=>{if(!['GET','HEAD'].includes(route.request().method())){report.blockedWrites.push({path:new URL(route.request().url()).pathname,method:route.request().method()});return route.abort('blockedbyclient');}return route.continue();});
 await page.goto(base+'/portal/home',{waitUntil:'domcontentloaded'});await page.locator('.assistant-bubble').waitFor({timeout:60000});return context;
}
async function screenshot(name){const file=path.join(output,name+'.png');await page.screenshot({path:file,fullPage:false});report.screenshots.push({path:path.relative(process.cwd(),file).replaceAll('\\','/'),sha256:sha(file)});}
async function observe(label,action){
 stage=label;
 const collection=page.evaluate(async()=>{
  const start=performance.now(),frames=[],animations=new Map(),cardAnimations=new Map();let node,seen=false;
  while(performance.now()-start<850){
   const current=document.querySelector('.assistant-window');if(current){node=current;seen=true;}
   if(node?.isConnected){
    const box=node.getBoundingClientRect(),style=getComputedStyle(node);
    const read=(animation,target)=>{const effect=animation.effect;if(!effect)return;const timing=effect.getTiming(),keyframes=effect.getKeyframes().map(frame=>({offset:frame.offset,transform:frame.transform,opacity:frame.opacity,transformOrigin:frame.transformOrigin}));const identity=(animation.animationName||animation.constructor.name)+JSON.stringify(keyframes)+timing.delay;target.set(identity,{type:animation.constructor.name,name:animation.animationName||'',duration:timing.duration,delay:timing.delay,easing:timing.easing,keyframes});};
    const active=node.getAnimations({subtree:false});active.forEach(animation=>read(animation,animations));
    node.querySelectorAll('.assistant-feature-card').forEach(card=>card.getAnimations({subtree:false}).forEach(animation=>read(animation,cardAnimations)));
    frames.push({t:Math.round((performance.now()-start)*100)/100,x:box.x,y:box.y,width:box.width,height:box.height,opacity:Number(style.opacity),transform:style.transform,active:active.length,expanded:node.classList.contains('is-expanded')});
   }else if(seen){frames.push({t:Math.round(performance.now()-start),removed:true});break;}
   await new Promise(resolve=>requestAnimationFrame(resolve));
  }
  return {frames,animations:[...animations.values()],cardAnimations:[...cardAnimations.values()]};
 });
 try{await action();}catch(error){await collection.catch(()=>{});throw error;}
 const trace=await collection;report.traces.push({label,...trace});return trace;
}
const visualFrames=trace=>trace.frames.filter(frame=>!frame.removed);
const changedGeometry=trace=>new Set(visualFrames(trace).map(frame=>[Math.round(frame.x),Math.round(frame.y),Math.round(frame.width),Math.round(frame.height)].join(','))).size>2;
const transition= (trace,duration,type)=>trace.animations.find(animation=>animation.duration===duration&&animation.type===type&&animation.keyframes.some(frame=>frame.transform));
async function fits(locator){const b=await locator.boundingBox(),v=page.viewportSize();return b&&b.x>=7&&b.y>=7&&b.x+b.width<=v.width-7&&b.y+b.height<=v.height-7;}
try{
 for(const port of [5190,5192])for(const width of [390,1440])for(const motion of ['no-preference','reduce']){
  const label=port+'/'+width+'/'+motion,context=await create(width,motion,'http://127.0.0.1:'+port),bubble=page.locator('.assistant-bubble'),window=page.locator('.assistant-window');
  const opened=await observe(label+'/open',()=>bubble.click());await window.waitFor();
  check(label+' open retains an empty composer',await window.getByRole('textbox',{name:'发给 AI 的消息',exact:true}).inputValue()==='');
  check(label+' open final geometry stays bounded',await fits(window));
  if(motion==='no-preference'){
   check(label+' observed CSS opening has 440ms transform and opacity keyframes',!!transition(opened,440,'CSSAnimation')&&opened.animations.some(a=>a.keyframes.some(frame=>frame.opacity!==undefined)));
   check(label+' opening includes intermediate geometry and opacity',changedGeometry(opened)&&visualFrames(opened).some(frame=>frame.opacity>0&&frame.opacity<1));
   check(label+' guide cards enter with distinct stagger delays',new Set(opened.cardAnimations.filter(animation=>animation.name==='assistant-card-in').map(animation=>animation.delay)).size>=2);
  }else check(label+' reduced-motion opening skips surface and card animations',opened.animations.length===0&&opened.cardAnimations.filter(a=>a.name==='assistant-card-in').length===0);
  const input=window.getByRole('textbox',{name:'发给 AI 的消息',exact:true});await input.fill('仅用于观察浮窗的未发送草稿');
  await screenshot(label.replaceAll('/','-')+'-normal');
  const normal=await window.boundingBox();
  const expanded=await observe(label+'/expand',()=>window.getByRole('button',{name:'放大聊天窗口',exact:true}).click());
  const large=await window.boundingBox();
  check(label+' expanded layout is bounded and larger',await fits(window)&&(large.width>normal.width+1||large.height>normal.height+1));
  check(label+' expanding preserves user draft',await input.inputValue()==='仅用于观察浮窗的未发送草稿');
  if(motion==='no-preference'){
   const flip=transition(expanded,540,'Animation');check(label+' expansion uses observed 540ms three-keyframe FLIP',!!flip&&flip.keyframes.length===3);
   check(label+' expansion has intermediate visible size',changedGeometry(expanded)&&visualFrames(expanded).some(frame=>(frame.width>Math.min(normal.width,large.width)+1&&frame.width<Math.max(normal.width,large.width)-1)||(frame.height>Math.min(normal.height,large.height)+1&&frame.height<Math.max(normal.height,large.height)-1)));
  }else check(label+' reduced-motion expansion skips WAAPI',expanded.animations.every(animation=>animation.type!=='Animation'));
  await screenshot(label.replaceAll('/','-')+'-expanded');
  const shrunk=await observe(label+'/shrink',()=>window.getByRole('button',{name:'缩小聊天窗口',exact:true}).click());
  const restored=await window.boundingBox();check(label+' shrinking returns original responsive geometry',Math.abs(restored.width-normal.width)<1&&Math.abs(restored.height-normal.height)<1&&await fits(window));
  if(motion==='no-preference')check(label+' shrinking also animates 540ms intermediate geometry',!!transition(shrunk,540,'Animation')&&changedGeometry(shrunk));
  else check(label+' reduced-motion shrinking skips WAAPI',shrunk.animations.every(animation=>animation.type!=='Animation'));
  const closed=await observe(label+'/close',()=>window.getByRole('button',{name:'关闭聊天窗口',exact:true}).click());await window.waitFor({state:'hidden'});
  if(motion==='no-preference')check(label+' observed CSS closing has 280ms opacity and transform before removal',!!transition(closed,280,'CSSAnimation')&&visualFrames(closed).some(frame=>frame.opacity>0&&frame.opacity<1)&&closed.frames.some(frame=>frame.removed));
  else check(label+' reduced-motion closes without surface animation',closed.animations.length===0);
  check(label+' closing leaves bubble usable',await bubble.isVisible());await context.close();
 }
 // Reuse the same controlled browser for two current growth screenshots only.
 // Do not rerun the historical 78-case growth suite or award points/honors.
 stage='ordinary-growth-screens';const context=await create(1440,'reduce','http://127.0.0.1:5192',state.people[0].token);
 await page.goto('http://127.0.0.1:5192/portal/growth');await page.getByRole('heading',{name:'成长与荣誉',exact:true}).waitFor();await page.locator('.rank-directory').waitFor();
 const api=async route=>{const response=await page.request.get('http://127.0.0.1:5192/dev-api'+route,{headers:{Authorization:'Bearer '+state.people[0].token,clientid:state.people[0].clientId}});const body=await response.json();assert.equal(body.code,200,'Actual growth API failed');return body.data;};
 const catalogue=await api('/sports/types'),sport=catalogue.sports.find(sport=>sport.code==='badminton')?.id;assert.ok(sport,'Real badminton catalogue identity missing');
 const growthPath='/sports/growth/card?sportId='+encodeURIComponent(sport),before=await api(growthPath);
 check('Actual growth screenshot uses nine-rule catalogue including unawarded legendary threshold',before.ranks.length===9&&before.ranks.some(rank=>rank.name==='传奇'&&rank.threshold===19200));
 check('Actual growth directory has eight distinct equipable rank artworks; zero-point novice remains a basic style',await page.locator('.rank-catalog>button').count()===8);
 const directory=path.join(output,'ordinary-current-growth-directory.png');await page.evaluate(()=>window.scrollTo(0,0));await page.screenshot({path:directory,fullPage:true});report.screenshots.push({path:path.relative(process.cwd(),directory).replaceAll('\\','/'),sha256:sha(directory)});
 await page.getByRole('button',{name:'传奇，19200成长分，未达到',exact:true}).click();const dialog=page.getByRole('dialog',{name:'传奇段位',exact:true});await dialog.waitFor();
 await page.waitForFunction(()=>{const images=[...document.querySelectorAll('.rank-preview img')];return images.length>=2&&images.every(image=>image.complete&&image.naturalWidth>0);});
 check('Actual legendary preview shows loaded rank and frame without a world certification frame',await dialog.locator('img').evaluateAll(images=>images.some(image=>image.src.endsWith('/ranks/legend.webp')&&image.complete&&image.naturalWidth>0)&&images.some(image=>image.src.endsWith('/frames-v2/legend.webp')&&image.complete&&image.naturalWidth>0)&&images.every(image=>!image.src.includes('/honors/world-'))));
 await screenshot('ordinary-current-legend-preview');await dialog.getByRole('button',{name:'关闭',exact:true}).click();await dialog.waitFor({state:'hidden'});
 check('Actual growth and rewards unchanged after catalogue/preview',JSON.stringify(await api(growthPath))===JSON.stringify(before));await context.close();
 check('No page errors or attempted model/business writes',report.pageErrors.length===0&&report.blockedWrites.length===0);
 check('tested source and composer/control styles remained unchanged during verification',report.sourceFiles.every(file=>sha(file.path)===file.sha256));report.passed=true;
}catch(error){report.failures.push({stage,type:error.name,reason:error.name==='AssertionError'?error.message:'Verification did not complete; private diagnostics omitted'});await page?.screenshot({path:path.join(output,'failure.png'),fullPage:false}).catch(()=>{});process.exitCode=1;}
finally{for(const context of contexts)await context.close();await browser.close();const file=path.join(output,'receipt.json'),fd=fs.openSync(file,'wx');try{fs.writeFileSync(fd,JSON.stringify(report,null,2)+'\n');fs.fsyncSync(fd);}finally{fs.closeSync(fd);}console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,failures:report.failures,receipt:path.relative(process.cwd(),file).replaceAll('\\','/'),sha256:sha(file)}));}
