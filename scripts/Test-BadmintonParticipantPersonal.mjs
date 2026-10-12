// Recoverable ordinary-profile tests against the isolated candidate only.
// Uploaded pictures are synthetic artwork. No awards, passwords, account closure
// or real-world identity facts are created. Original private bytes stay local.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {testHarness,hashFile,atomicJson} from './lib/badminton-participant-test.mjs';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=require('playwright');
const h=testHarness('participant-personal'),{context,people,progress,api,check}=h;
const stage=process.argv[3]||'profile',A=people[0],C=people[2],F=people[5];
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
const contexts=[];let activePage;
h.report.uiWrites=[];h.report.pageErrors=[];h.report.restoration=[];
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
async function open(actor,width=390){
  const ctx=await browser.newContext({viewport:{width,height:width<600?844:1000},reducedMotion:'reduce'});contexts.push(ctx);
  if(actor)await ctx.addInitScript(token=>{localStorage.setItem('Admin-Token',token);localStorage.setItem('Platform-Token',token);},actor.token);
  const page=await ctx.newPage();activePage=page;
  page.on('pageerror',()=>h.report.pageErrors.push((actor?.label||'anonymous')+' script error'));
  page.on('request',req=>{if(!['GET','HEAD'].includes(req.method()))h.report.uiWrites.push({actor:actor?.label||'anonymous',method:req.method(),route:new URL(req.url()).pathname.replace(/(\/invites\/)[^/]+/,'$1{private-invite}')});});
  return {page,actor,context:ctx};
}
async function navigate(tab,route){activePage=tab.page;await tab.page.goto(context.frontend+route,{waitUntil:'domcontentloaded'});await tab.page.locator('div.consumer-app').first().waitFor({timeout:60000});await tab.page.locator('.consumer-state.loading').waitFor({state:'hidden',timeout:15000}).catch(()=>{});}
async function shot(tab,name){activePage=tab.page;await tab.page.locator('.consumer-state.loading').waitFor({state:'hidden',timeout:15000}).catch(()=>{});await tab.page.locator('.el-message').first().waitFor({state:'hidden',timeout:5000}).catch(()=>{});await tab.page.evaluate(()=>{document.activeElement?.blur();window.scrollTo(0,0);});const file=path.join(h.out,name+'.png');await tab.page.screenshot({path:file,fullPage:true,mask:[tab.page.locator('.el-form-item').filter({hasText:'手机号'}),tab.page.locator('input[name="phone"]'),tab.page.locator('input[name="password"]')]});h.report.screenshots.push({path:path.relative(process.cwd(),file).replaceAll('\\','/'),sha256:hashFile(file),redacted:'Private phone/password controls masked where present'});}
async function clickResult(tab,suffix,button){const waiting=tab.page.waitForResponse(r=>r.request().method()!=='GET'&&new URL(r.url()).pathname.endsWith(suffix),{timeout:25000});waiting.catch(()=>{});await button.click();const b=await(await waiting).json();h.report.uiResponses ||= [];h.report.uiResponses.push({route:suffix,code:b.code,...(b.code!==200?{reason:String(b.msg||'').replace(/\b\d{11}\b/g,'{private-phone}').slice(0,180)}:{})});assert.equal(b.code,200,'UI success '+suffix+'; '+String(b.msg||'').replace(/\b\d{11}\b/g,'{private-phone}').slice(0,150));return b.data;}
async function binary(actor,route){
  const start=Date.now(),r=await fetch(context.backend+route,{headers:{clientid:context.clientId,...(actor?{Authorization:'Bearer '+actor.token}:{})}}),bytes=Buffer.from(await r.arrayBuffer()),type=r.headers.get('content-type')||'';
  let code;if(type.includes('json'))code=JSON.parse(bytes.toString('utf8')).code;
  h.report.requests.push({actor:actor?.label||'anonymous',method:'GET',route,status:r.status,code,elapsedMs:Date.now()-start});
  return {r,bytes,type,code};
}
async function publicCard(id){const r=await fetch(context.backend+'/sports/display/public/'+id,{headers:{clientid:context.clientId}}),b=await r.json();h.report.requests.push({actor:'anonymous',method:'GET',route:'/sports/display/public/'+id,status:r.status,code:b.code});return b;}
async function upload(actor,bytes,type,version){const data=new FormData();data.append('file',new Blob([bytes],{type}),type==='image/webp'?'restore.webp':'restore.png');const started=Date.now();const r=await fetch(context.backend+'/sports/display/avatar?expectedVersion='+version,{method:'POST',headers:{clientid:context.clientId,Authorization:'Bearer '+actor.token},body:data}),b=await r.json();h.report.requests.push({actor:actor.label,method:'POST',route:'/sports/display/avatar',status:r.status,code:b.code,elapsedMs:Date.now()-started});return b;}
async function restoreDisplay(actor,original){
  const now=await api(actor,'/sports/display');
  if(['nickname','avatar_style','tagline','public_visible'].some(k=>(now.display[k]??'')!==(original[k]??''))){await h.action(actor,'profile.display',{nickname:original.nickname,avatarStyle:original.avatar_style,tagline:original.tagline||'',publicVisible:original.public_visible,expectedVersion:now.display.version},'personal.restore.display.'+path.basename(h.out));}
  const restored=await api(actor,'/sports/display');assert.ok(['nickname','avatar_style','tagline','public_visible'].every(k=>(restored.display[k]??'')===(original[k]??'')));h.report.restoration.push({actor:actor.label,kind:'display',restored:true,version:restored.display.version});
}
async function profile(){
  const actor=A,original=(await api(actor,'/sports/display')).display;
  assert.equal(original.public_visible,false,'Use the initially private synthetic actor only');
  const oldCard=await api(actor,'/sports/growth/card?sportId='+progress.objects.sportId),originalTitle=oldCard.equipment?.title_code;
  const targetTitle=oldCard.titles.find(t=>t.title_code!==originalTitle);assert.ok(originalTitle&&targetTitle,'Only equip earned titles when an original equipment can be restored');
  const owner=await open(actor,390),anonymous=await open(undefined,1440);
  const recovery=path.join(h.root,'personal-recovery.private.json');atomicJson(recovery,{actorId:actor.id,originalDisplay:original,originalTitle,startedAt:new Date().toISOString()});
  try{
    check('PP01','Private public-card endpoint is denied to an anonymous caller',(await publicCard(actor.id)).code!==200);
    check('PP02','Private avatar public endpoint is denied before consent',(await binary(undefined,'/sports/display/public/'+actor.id+'/avatar')).code!==undefined);
    await navigate(owner,'/portal/growth');await owner.page.locator('.profile-editor').waitFor();
    const editor=owner.page.locator('.profile-editor');
    await editor.locator('.el-form-item').filter({hasText:'运动昵称'}).locator('input').fill(context.prefix+'-资料补验A');
    await editor.locator('.el-form-item').filter({hasText:'运动签名'}).locator('input').fill('本轮模拟运动名片；测试后恢复。');
    await editor.locator('.el-switch__core').click();await clickResult(owner,'/actions/profile.display/execute',editor.getByRole('button',{name:'保存名片',exact:true}));
    const changed=await api(actor,'/sports/display');
    check('PP03','Real mobile save persists nickname/signature and the consent switch',changed.display.nickname===context.prefix+'-资料补验A'&&changed.display.public_visible===true);
    await navigate(anonymous,'/public/athletes/'+actor.id);await anonymous.page.locator('.athlete-card').waitFor();
    check('PP04','Anonymous share displays only the actual public display contract',(await publicCard(actor.id)).data.display.nickname===changed.display.nickname);
    check('PP05','Public contract has no legal name, document, birthdate or contact fields',!/(?:legalName|idNumber|mobile|birthDate|emergencyContact)/.test(JSON.stringify((await publicCard(actor.id)).data)));
    const avatar=await binary(undefined,'/sports/display/public/'+actor.id+'/avatar');
    check('PP06','Public-consent avatar is a real image with no-store response',avatar.type.startsWith('image/')&&avatar.r.headers.get('cache-control')?.includes('no-store'));
    await shot(anonymous,'desktop-public-card-consent');
    await navigate(owner,'/portal/growth');await owner.page.locator('.title-wall').waitFor();
    const titleButton=owner.page.locator('.title-wall>button').filter({hasText:targetTitle.title});
    await clickResult(owner,'/actions/growth.equip/execute',titleButton);
    const equipped=await api(actor,'/sports/growth/card?sportId='+progress.objects.sportId);
    check('PP07','Ordinary user personally wears an already earned title without adding growth',equipped.equipment.title_code===targetTitle.title_code&&equipped.points===oldCard.points&&equipped.facts.length===oldCard.facts.length);
    const worn=owner.page.locator('.growth-passport .sports-title-badge[data-title-code="'+targetTitle.title_code+'"]');await worn.waitFor();
    const frame=owner.page.locator('.growth-passport .avatar-frame'),titleBounds=await worn.boundingBox(),frameBounds=await frame.boundingBox();
    check('PP08','Title appears above the actual avatar and the decoded frame matches the real current bronze rank',titleBounds.y+titleBounds.height<=frameBounds.y+2&&await frame.getAttribute('data-frame')==='bronze'&&await frame.locator('img.avatar-frame-art').evaluate(img=>img.complete&&img.naturalWidth>0));
    await shot(owner,'mobile-earned-title-avatar');
    await h.rejectedAction(F,'growth.equip',{sportId:progress.objects.sportId,titleCode:'first_finish'},'PP09','Unearned title is rejected for the ordinary zero-point actor',/先获得|称号/);
    await h.rejectedAction(C,'growth.equip',{sportId:progress.objects.sportId,titleCode:'team_first',teamId:progress.objects.team1},'PP10','Non-captain cannot equip another team’s title',/队长|权限|成员|仅/);
    await h.rejectedAction(actor,'profile.display',{nickname:'无效过期版本',avatarStyle:'mint',tagline:'',publicVisible:true,expectedVersion:original.version},'PP11','Stale profile version cannot overwrite current public consent',/版本|变化|更新/);
    await navigate(owner,'/portal/growth');await owner.page.locator('.profile-editor').waitFor();await owner.page.locator('.profile-editor .el-switch__core').click();await clickResult(owner,'/actions/profile.display/execute',owner.page.locator('.profile-editor').getByRole('button',{name:'保存名片',exact:true}));
    check('PP12','Turning public consent off invalidates the previously working share URL',(await publicCard(actor.id)).code!==200&&(await binary(undefined,'/sports/display/public/'+actor.id+'/avatar')).code!==undefined);
    await navigate(anonymous,'/public/athletes/'+actor.id);await anonymous.page.getByRole('heading',{name:'这张运动名片暂未公开',exact:true}).waitFor();
    check('PP13','Anonymous page shows the actual closed-share state without stale profile content',await anonymous.page.locator('.athlete-card').count()===0);
    await shot(anonymous,'desktop-share-closed');
  }finally{
    const now=await api(actor,'/sports/growth/card?sportId='+progress.objects.sportId);
    if(now.equipment?.title_code!==originalTitle)await h.action(actor,'growth.equip',{sportId:progress.objects.sportId,titleCode:originalTitle,expectedVersion:now.equipment.version},'personal.restore.title.'+path.basename(h.out));
    const restored=await api(actor,'/sports/growth/card?sportId='+progress.objects.sportId);assert.equal(restored.equipment?.title_code,originalTitle);assert.equal(restored.points,oldCard.points);h.report.restoration.push({actor:actor.label,kind:'earned-title',restored:true,version:restored.equipment.version,growthFactsUnchanged:restored.facts.length===oldCard.facts.length});
    await restoreDisplay(actor,original);atomicJson(recovery,{actorId:actor.id,restored:true,completedAt:new Date().toISOString()});
  }
}
async function avatar(){
  const actor=A,initial=(await api(actor,'/sports/display')).display;assert.ok(initial.avatar_file_id&&!initial.public_visible);
  const original=await binary(actor,'/sports/display/avatar/'+actor.id);assert.ok(original.type.startsWith('image/'));
  const originalFile=path.join(h.root,'avatar-original-A.private.bin');fs.writeFileSync(originalFile,original.bytes);
  const owner=await open(actor,390);let changed=false;
  try{
    check('PA01','Owner’s private actual avatar is no-store and nosniff',original.r.headers.get('cache-control')?.includes('no-store')&&original.r.headers.get('x-content-type-options')==='nosniff');
    check('PA02','Anonymous private-avatar access is refused',(await binary(undefined,'/sports/display/avatar/'+actor.id)).code!==undefined);
    await navigate(owner,'/portal/profile');await owner.page.locator('[data-testid="profile-avatar-field"]').waitFor();
    const input=owner.page.locator('[data-testid="profile-avatar-field"] input[type=file]'),startWrites=h.report.uiWrites.filter(w=>w.route.endsWith('/display/avatar')).length;
    await input.setInputFiles({name:'not-an-image.txt',mimeType:'text/plain',buffer:Buffer.from('synthetic invalid avatar')});await owner.page.getByText('请选择5MB内的JPG、PNG或WebP图片',{exact:true}).waitFor();
    check('PA03','Unsupported file type is rejected before crop or upload',await owner.page.getByRole('dialog',{name:'调整运动头像',exact:true}).count()===0&&h.report.uiWrites.filter(w=>w.route.endsWith('/display/avatar')).length===startWrites);
    await input.setInputFiles({name:'too-large.png',mimeType:'image/png',buffer:Buffer.alloc(5*1024*1024+1)});await owner.page.getByText('请选择5MB内的JPG、PNG或WebP图片',{exact:true}).first().waitFor();
    check('PA04','Over-5MB selection cannot upload or replace the original avatar',h.report.uiWrites.filter(w=>w.route.endsWith('/display/avatar')).length===startWrites&&(await api(actor,'/sports/display')).display.avatar_file_id===initial.avatar_file_id);
    const artwork=path.resolve('plus-ui/public/images/sports/brand-mark-v1.webp');assert.ok(fs.existsSync(artwork));
    await input.setInputFiles(artwork);const dialog=owner.page.getByRole('dialog',{name:'调整运动头像',exact:true});await dialog.waitFor();await dialog.locator('.vue-cropper').waitFor();
    await dialog.getByRole('button',{name:'取消',exact:true}).click();await dialog.waitFor({state:'hidden'});
    check('PA05','Cancelling the real RuoYi crop keeps the original avatar and creates no upload',h.report.uiWrites.filter(w=>w.route.endsWith('/display/avatar')).length===startWrites);
    await input.setInputFiles(artwork);await dialog.waitFor();await dialog.locator('.vue-cropper').waitFor();await dialog.getByRole('button',{name:'向右旋转',exact:true}).click();await dialog.getByRole('button',{name:'放大头像',exact:true}).click();
    await shot(owner,'mobile-actual-avatar-crop');
    const saved=await clickResult(owner,'/sports/display/avatar',dialog.getByRole('button',{name:'保存头像',exact:true}));changed=true;await dialog.waitFor({state:'hidden'});
    const now=(await api(actor,'/sports/display')).display;
    check('PA06','Saving the real crop produces an owned file and advances the display version',now.avatar_file_id===saved.fileId&&saved.fileId!==initial.avatar_file_id&&now.version>initial.version);
    const cropped=await binary(actor,'/sports/display/avatar/'+actor.id);check('PA07','Saved crop is actually readable image bytes, distinct from the original',cropped.type.startsWith('image/')&&sha(cropped.bytes)!==sha(original.bytes));
    check('PA08','Uploading did not silently make the image public',(await binary(undefined,'/sports/display/public/'+actor.id+'/avatar')).code!==undefined&&(await api(actor,'/sports/display')).display.public_visible===false);
    const invalid=await upload(actor,Buffer.from('not PNG even with image filename'),'image/png',now.version);
    check('PA09','Server rejects invalid image content and keeps the successful crop',invalid.code!==200&&(await api(actor,'/sports/display')).display.avatar_file_id===saved.fileId);
    const stale=await upload(actor,original.bytes,original.type.split(';')[0],initial.version);
    check('PA10','Stale avatar version is rejected without replacing the crop',stale.code!==200&&(await api(actor,'/sports/display')).display.avatar_file_id===saved.fileId);
    await navigate(owner,'/portal/profile');await owner.page.locator('[data-testid="profile-avatar-field"]').waitFor();await shot(owner,'mobile-avatar-current-owned');
  }finally{
    const now=(await api(actor,'/sports/display')).display;
    if(changed||now.avatar_file_id!==initial.avatar_file_id){const restored=await upload(actor,original.bytes,original.type.split(';')[0],now.version);assert.equal(restored.code,200);}
    await restoreDisplay(actor,initial);const restored=await binary(actor,'/sports/display/avatar/'+actor.id);assert.equal(sha(restored.bytes),sha(original.bytes));
    h.report.restoration.push({actor:actor.label,kind:'avatar-original-bytes',restored:true,originalBytesSHA256:sha(original.bytes),newFileHistoryRetained:true,version:(await api(actor,'/sports/display')).display.version});
  }
}
async function login(){
  // Root authorizes exactly these real form logins. Merge latest context before
  // replacing one token; never overwrite concurrent definition/role updates.
  const contextFile=path.resolve(process.argv[2]),targetA='/portal/profile';
  async function signIn(actor,target,id){
    const tab=await open(undefined,390);await navigate(tab,'/portal/login?returnTo='+encodeURIComponent(target));
    await tab.page.getByPlaceholder('请输入手机号',{exact:true}).fill(actor.phone);await tab.page.getByPlaceholder('请输入密码',{exact:true}).fill(context.password);
    assert.equal(await tab.page.getByPlaceholder('输入右侧字符',{exact:true}).count(),0,'Candidate login captcha is actually disabled; no bypass');
    const result=await clickResult(tab,'/auth/login',tab.page.getByRole('button',{name:'登录',exact:true}));
    await tab.page.waitForFunction(()=>Boolean(localStorage.getItem('Platform-Token')));
    const newToken=await tab.page.evaluate(()=>localStorage.getItem('Platform-Token'));assert.ok(newToken&&result.access_token===newToken);
    const latest=JSON.parse(fs.readFileSync(contextFile,'utf8')),index=latest.people.findIndex(p=>String(p.id)===String(actor.id));assert.ok(index>=0);latest.people[index]={...latest.people[index],token:newToken};atomicJson(contextFile,latest);actor.token=newToken;context.people[index].token=newToken;
    await tab.page.waitForURL(url=>url.pathname!=='/portal/login',{timeout:20000});
    h.report.authRefresh ||= [];h.report.authRefresh.push({actor:actor.label,scope:'platform participant only',tokenPrinted:false,contextMerged:true});
    check(id,'Real ordinary login resumes the requested safe business task',tab.page.url()===context.frontend+target);
    check(id+'.org','Existing organizer session remains valid after the participant login',Array.isArray(await api(h.organizer,'/sports/b/events')));
    return tab;
  }
  const a=progress.checks.some(row=>row.id==='PL01')?await open(A,390):await signIn(A,targetA,'PL01');
  if(!a.page.url().startsWith(context.frontend))await navigate(a,targetA);
  await a.page.locator('[data-testid="profile-avatar-field"]').waitFor();await shot(a,'mobile-profile-login-return');
  const id=progress.objects.personalDraftBoundaryEntry||progress.objects.declarationPrivateEntry;assert.ok(id);
  const c=await open(C,1440);await navigate(c,'/portal/registration/detail/'+id);await c.page.locator('.field-block').waitFor();
  const fields=await api(C,'/sports/c/registrations/'+id+'/fields'),text=fields.find(f=>f.valueType==='text');assert.ok(text);const partial=context.prefix+'-登录返回草稿';
  await c.page.locator('.field-block .el-form-item').filter({hasText:text.label}).locator('input').fill(partial);await clickResult(c,'/'+id+'/fields',c.page.getByRole('button',{name:'保存草稿资料',exact:true}));
  check('PL02','Incomplete personal draft can be explicitly saved without submitting or occupying a place',(await api(C,'/sports/c/registrations/'+id+'/fields')).find(f=>f.eventFieldId===text.eventFieldId).valueText===partial&&(await h.entry(C,id)).status==='draft');
  const back=await signIn(C,'/portal/registration/detail/'+id,'PL03');await back.page.locator('.field-block').waitFor();
  check('PL04','Saved personal draft remains present after real login and task return',await back.page.locator('.field-block .el-form-item').filter({hasText:text.label}).locator('input').inputValue()===partial);
  await shot(back,'mobile-saved-draft-after-login');
  const hostile=await open(undefined,1440);await navigate(hostile,'/portal/login?returnTo='+encodeURIComponent('https://outside.invalid/steal'));
  const registered=hostile.page.getByRole('link',{name:'注册账号',exact:true});check('PL05','External returnTo is cleaned from the actual registration link',new URL(await registered.getAttribute('href'),context.frontend).searchParams.get('returnTo')==='/portal/home');
  check('PL06','Login and return did not formally submit the preserved draft',(await h.entry(C,id)).status==='draft');
  h.report.contextAfterSHA256=hashFile(contextFile);
}
async function draftBoundary(){
  const quota=()=>api(C,'/sports/c/registrations/units?eventId='+progress.objects.event2).then(rows=>rows.find(row=>String(row.id)===String(progress.objects.units2.soloGeneral)).usedCount);
  const beforeQuota=await quota();
  const made=await h.action(C,'registration.create',{unitId:progress.objects.units2.soloGeneral},'personal.draft.create');
  const id=h.reference('personalDraftBoundaryEntry',made.result.registrationId),tab=await open(C,390);
  await navigate(tab,'/portal/registration/detail/'+id);await tab.page.locator('.field-block').waitFor();
  const fields=await api(C,'/sports/c/registrations/'+id+'/fields'),text=fields.find(f=>f.valueType==='text'),number=fields.find(f=>f.valueType==='number');assert.equal(fields.length,4);assert.ok(text&&number);
  const textInput=tab.page.locator('.field-block .el-form-item').filter({hasText:text.label}).locator('input'),value=context.prefix+'-不完整本人草稿';
  await textInput.fill(value);await clickResult(tab,'/'+id+'/fields',tab.page.getByRole('button',{name:'保存草稿资料',exact:true}));
  let saved=await api(C,'/sports/c/registrations/'+id+'/fields');
  check('PD01','Real phone can save one required answer while other mandatory answers remain empty',saved.find(f=>f.eventFieldId===text.eventFieldId).valueText===value&&saved.filter(f=>f.eventFieldId!==text.eventFieldId).every(f=>!f.valueText));
  await clickResult(tab,'/'+id+'/declaration-ack',tab.page.getByRole('button',{name:'我已阅读并确认',exact:true}));
  await h.rejectedAction(C,'registration.submit',{registrationId:id,expectedVersion:await h.registrationVersion(C,id)},'PD02','The valid one-person, personally acknowledged entry still cannot formally submit missing mandatory answers',/请填写/);
  const entry=await h.entry(C,id);
  check('PD03','Rejected incomplete submit leaves this draft with no roster revision or quota allocation',entry.status==='draft'&&entry.rosterRevision===0&&await quota()===beforeQuota);
  const invalid=await h.call(C,'/sports/c/registrations/'+id+'/fields','PUT',saved.map(f=>({eventFieldId:f.eventFieldId,valueText:f.eventFieldId===number.eventFieldId?'not-a-number':f.valueText||''})));
  check('PD04','Partial save continues to reject nonempty bad numeric format and rolls back the whole answer update',invalid.code!==200&&/数字/.test(invalid.msg||'')&&(await api(C,'/sports/c/registrations/'+id+'/fields')).find(f=>f.eventFieldId===text.eventFieldId).valueText===value);
  await textInput.fill('');await clickResult(tab,'/'+id+'/fields',tab.page.getByRole('button',{name:'保存草稿资料',exact:true}));
  check('PD05','Own required draft answer can be cleared without creating a formal roster',(await api(C,'/sports/c/registrations/'+id+'/fields')).every(f=>!f.valueText)&&(await h.entry(C,id)).rosterRevision===0&&await quota()===beforeQuota);
  await textInput.fill(value);await clickResult(tab,'/'+id+'/fields',tab.page.getByRole('button',{name:'保存草稿资料',exact:true}));await shot(tab,'mobile-partial-draft-saved');
}
async function returnQueries(){
  const anonymous=await open(undefined,390),safe='/portal/profile?eventId='+progress.objects.event2+'&sportId='+progress.objects.sportId;
  await navigate(anonymous,'/portal/login?returnTo='+encodeURIComponent(safe+'&password=discarded&external=https://outside.invalid'));
  await anonymous.page.waitForURL(url=>url.searchParams.get('returnTo')===safe);
  check('PQ01','Profile alias returnTo keeps only permitted numeric business parameters',new URL(anonymous.page.url()).searchParams.get('returnTo')===safe);
  check('PQ02','Actual registration and recovery links preserve the sanitized profile destination',new URL(await anonymous.page.getByRole('link',{name:'注册账号',exact:true}).getAttribute('href'),context.frontend).searchParams.get('returnTo')===safe&&new URL(await anonymous.page.getByRole('link',{name:'忘记密码',exact:true}).getAttribute('href'),context.frontend).searchParams.get('returnTo')===safe);
  for(const [i,target] of ['https://outside.invalid/path','//outside.invalid/path','/sports-platform','/portal/profile?eventId=abc&sportId=1'].entries()){
    await navigate(anonymous,'/portal/login?returnTo='+encodeURIComponent(target));
    const expected=i===3?'/portal/profile?sportId=1':'/portal/home';await anonymous.page.waitForURL(url=>url.searchParams.get('returnTo')===expected);
    check('PQ03.'+i,'External, work-console or malformed business parameters are actually cleaned',new URL(anonymous.page.url()).searchParams.get('returnTo')===expected);
  }
  check('PQ04','ReturnTo sanitization produced no login or business write',h.report.uiWrites.length===0);
}
async function identity(){
  const actor=A,original=(await api(actor,'/sports/c/identity')).self,originalDisplay=(await api(actor,'/sports/display')).display;
  const savedFields=await api(actor,'/sports/c/registrations/'+progress.objects.concurrentSingle1+'/fields');
  const snapshot=path.join(h.root,'identity-original-A.private.json');atomicJson(snapshot,{actorId:actor.id,self:original,startedAt:new Date().toISOString()});
  const keys=['legalName','birthDate','gender','mobile','idDocType','idNumber','city','addressDetail','bloodType','clothingSize','emergencyContactName','emergencyContactPhone'];
  const restorePayload=Object.fromEntries(keys.map(key=>[key,original[key]??'']));
  const tab=await open(actor,1440),city=context.prefix+'-本轮模拟城市';
  try{
    await navigate(tab,'/portal/profile');await tab.page.locator('.profile-form').waitFor();
    check('PI01','Registered phone is read-only in the real ordinary profile form',await tab.page.locator('.profile-form .el-form-item').filter({hasText:'手机号'}).locator('input').isDisabled());
    await tab.page.locator('.optional-fields>summary').click();await tab.page.locator('.profile-form .el-form-item').filter({hasText:'所在城市'}).locator('input').fill(city);
    await clickResult(tab,'/sports/c/identity/self',tab.page.getByRole('button',{name:'保存本人档案',exact:true}));
    const current=(await api(actor,'/sports/c/identity')).self;
    check('PI02','Actual profile save changes only the intended optional city and preserves required identity',current.city===city&&['legalName','birthDate','gender','mobile'].every(key=>current[key]===original[key]));
    check('PI03','Shared profile save preserves the previously submitted personal event fields',JSON.stringify(await api(actor,'/sports/c/registrations/'+progress.objects.concurrentSingle1+'/fields'))===JSON.stringify(savedFields));
    check('PI04','Editing private participant details does not silently publish the public card',(await publicCard(actor.id)).code!==200&&(await api(actor,'/sports/display')).display.public_visible===originalDisplay.public_visible);
    await shot(tab,'desktop-private-profile-optional-city');
  }finally{
    await api(actor,'/sports/c/identity/self','POST',restorePayload);
    const restored=(await api(actor,'/sports/c/identity')).self;assert.ok(keys.every(key=>(restored[key]??'')===(original[key]??'')));h.report.restoration.push({actor:actor.label,kind:'private-identity-fields',restored:true});atomicJson(snapshot,{actorId:actor.id,restored:true,completedAt:new Date().toISOString()});
  }
}
try{await h.preflight();if(stage==='profile')await profile();else if(stage==='avatar')await avatar();else if(stage==='login')await login();else if(stage==='returnto')await returnQueries();else if(stage==='draft')await draftBoundary();else if(stage==='identity')await identity();else throw new Error('Unknown personal stage');check('PX00','Ordinary personal pages report no browser script error',h.report.pageErrors.length===0);h.report.passed=true;}
catch(error){h.report.failures.push({id:stage,reason:error.message});if(activePage)await shot({page:activePage},'failure').catch(()=>{});process.exitCode=1;}
finally{for(const ctx of contexts)await ctx.close();await browser.close();h.final({stage,sourceFiles:['scripts/Test-BadmintonParticipantPersonal.mjs','scripts/lib/badminton-participant-test.mjs','plus-ui/src/views/portal/identity.vue','plus-ui/src/views/portal/growth.vue','plus-ui/src/views/portal/login.vue','plus-ui/src/views/portal/athlete.vue','plus-ui/src/components/consumer/SportsAvatarEditor.vue','plus-ui/src/api/sports/avatar.ts','plus-ui/src/utils/returnTo.ts'].map(file=>({path:file,sha256:hashFile(file)}))});}
