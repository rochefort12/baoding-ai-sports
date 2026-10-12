// Actual ordinary-account 5192 UI. No force, response stubs or direct database writes.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import assert from 'node:assert/strict';
import {testHarness,hashFile} from './lib/badminton-participant-test.mjs';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=require('playwright');
const h=testHarness('participant-ui');
const {context,people,progress,api,check,reference}=h;
const stage=process.argv[3]||'probe';
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
const contexts=[];let page;
h.report.pageErrors=[];h.report.uiWrites=[];
async function open(actor,width=390) {
  const ctx=await browser.newContext({viewport:{width,height:width<600?844:1000},reducedMotion:'reduce'});contexts.push(ctx);
  await ctx.addInitScript(token=>{localStorage.setItem('Admin-Token',token);localStorage.setItem('Platform-Token',token);},actor.token);
  const p=await ctx.newPage();p.on('pageerror',()=>h.report.pageErrors.push(actor.label+' script error'));
  p.on('request',req=>{if(!['GET','HEAD'].includes(req.method()))h.report.uiWrites.push({actor:actor.label,method:req.method(),path:new URL(req.url()).pathname.replace(/(\/invites\/)[^/]+/,'$1{private-invite}')});});
  page=p;return {page:p,context:ctx,actor};
}
async function navigate(tab,route) {page=tab.page;await page.goto(context.frontend+route,{waitUntil:'domcontentloaded'});await page.locator('div.consumer-app').first().waitFor({timeout:60000});await page.locator('.consumer-state.loading').waitFor({state:'hidden'}).catch(()=>{});}
async function shot(name) {await page.locator('.consumer-state.loading').waitFor({state:'hidden',timeout:15000}).catch(()=>{});await page.locator('.el-message').first().waitFor({state:'hidden',timeout:5000}).catch(()=>{});await page.evaluate(()=>{document.activeElement?.blur();window.scrollTo(0,0);});const file=path.join(h.out,name+'.png');await page.screenshot({path:file,fullPage:true});h.report.screenshots.push({path:path.relative(process.cwd(),file).replaceAll('\\','/'),sha256:hashFile(file)});}
async function clicked(tab,pathSuffix,button,confirmLabel) {
  const pending=tab.page.waitForResponse(response=>!['GET','HEAD'].includes(response.request().method())&&new URL(response.url()).pathname.endsWith(pathSuffix),{timeout:25000});pending.catch(()=>{});
  await button.click();
  if(pathSuffix.endsWith('/submit')) await tab.page.getByRole('dialog',{name:'确认正式提交报名'}).getByRole('button',{name:'确认提交报名',exact:true}).click();
  if(confirmLabel){const dialog=tab.page.getByRole('dialog');await dialog.getByRole('button',{name:confirmLabel,exact:true}).click();}
  const result=await(await pending).json();assert.equal(result.code,200,'Actual UI action succeeds: '+pathSuffix);return result.data;
}
async function probe() {
  const actor=people[3],tab=await open(actor);
  let id=progress.objects.uiImageEntry;
  // The apply page resumes/creates the selected unit itself; recover an already
  // created draft by its actual unit rather than repeating preparation.
  if(!id){const mine=await api(actor,'/sports/c/registrations');const existing=mine.find(row=>String(row.unitId)===String(progress.objects.units2.soloGeneral));if(existing)id=reference('uiImageEntry',existing.id);}
  if(!id){
    await navigate(tab,'/portal/registration/apply?eventId='+progress.objects.event2+'&unitId='+progress.objects.units2.soloGeneral);
    const article=tab.page.locator('.unit-option').filter({has:tab.page.locator('h3',{hasText:context.prefix+'-参与轮2-soloGeneral'})});
    await Promise.race([article.waitFor(),tab.page.locator('.registration-overview').waitFor()]);
    if(await article.isVisible()){const draft=await clicked(tab,'/sports/c/registrations',article.getByRole('button',{name:'准备报名',exact:true}));id=reference('uiImageEntry',draft.id);}
    else {const mine=await api(actor,'/sports/c/registrations');id=reference('uiImageEntry',mine.find(row=>String(row.unitId)===String(progress.objects.units2.soloGeneral)).id);}
  }
  await navigate(tab,'/portal/registration/detail/'+id);
  await tab.page.locator('.registration-overview').waitFor();
  const actual=await h.entry(actor,id);
  check('UP01','Actual image-only entry requires declaration confirmation without text',actual.declarationConfirmRequired===true&&!actual.declarationText&&actual.declarationAcknowledged===false);
  await tab.page.locator('[data-testid="entry-declaration-image"]').waitFor();
  await tab.page.waitForFunction(()=>{const image=document.querySelector('[data-testid="entry-declaration-image"]');return image?.complete&&image.naturalWidth>0;});
  await shot('mobile-image-only-declaration');
  check('UP02','Image-only declaration has a visible readable image and personal acknowledgement',await tab.page.locator('[data-testid="entry-declaration-image"]').count()===1&&await tab.page.getByRole('button',{name:'我已阅读并确认',exact:true}).isVisible());
}
async function inviteProbe() {
  const actor=people[3],manager=people[2],tab=await open(actor);
  const actual=await h.entry(manager,progress.objects.recruitEntry1);
  const member=actual.members.find(row=>String(row.accountId)===String(actor.id));assert.ok(member?.inviteToken);
  await navigate(tab,'/portal/registration/invite/'+member.inviteToken);
  await tab.page.getByRole('heading',{name:context.prefix+'-参与轮1（模拟比赛与声明）',exact:true}).waitFor();
  const fields=await api(actor,'/sports/c/registrations/'+actual.id+'/fields');
  check('UPI01','Actual invited member has four own required fields on this entry',fields.length===4&&fields.every(row=>row.required));
  await shot('mobile-member-own-fields');
  check('UPI02','Invited ordinary member can reach four personal fields through the actual invitation UI',await tab.page.locator('[data-testid="invite-personal-fields"] .el-form-item').count()===4);
}
async function uiAction(tab,code,button,confirm=false){
  return clicked(tab,'/actions/'+code+'/execute',button,confirm?'确认':undefined);
}
async function formFields(tab,id,scope){
  const fields=await api(tab.actor,'/sports/c/registrations/'+id+'/fields');
  for(const field of fields){
    const item=scope.locator('.el-form-item').filter({hasText:field.label});assert.equal(await item.count(),1);
    if(field.valueType==='enum'){await item.locator('.el-select__wrapper').click();await tab.page.getByRole('option',{name:'右手',exact:true}).click();}
    else{const input=item.locator('input');await input.fill(({text:'模拟本人通过真实页面填写 '+tab.actor.label,number:'4',date:'2026-10-11'})[field.valueType]);await input.press('Tab');}
  }
  return fields;
}
async function layout(tab,id){
  check(id,'Actual ordinary page fits the viewport',await tab.page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
}
async function standard(){
  const E=people[4],F=people[5],tabs={E:await open(E,390),F:await open(F,1440)},unit=progress.objects.units2.race,eventId=progress.objects.event2;
  const route='/portal/rooms?unitId='+unit+'&eventId='+eventId;
  for(const actor of [E,F])await navigate(tabs[actor.label],route);
  const first=await h.once('UI.match.E',()=>uiAction(tabs.E,'room.match',tabs.E.page.getByRole('button',{name:'自动匹配',exact:true})));
  if(!progress.checks.some(row=>row.id==='US01'))check('US01','First ordinary matcher waits without manufacturing a joined room',first.result.status==='waiting');
  const second=await h.once('UI.match.F',()=>uiAction(tabs.F,'room.match',tabs.F.page.getByRole('button',{name:'自动匹配',exact:true})));
  reference('uiOffer',second.result.offerId);
  const unitName=context.prefix+'-参与轮2-race';
  for(const actor of [E,F])await navigate(tabs[actor.label],route);
  for(const actor of [E,F]){
    const offer=tabs[actor.label].page.locator('.match-offers article').filter({hasText:unitName});
    if(!progress.operations['UI.accept.'+actor.label]?.completed){await offer.waitFor();check('US02.'+actor.label,'Both ordinary users see a real invitation countdown before joining',Number((await offer.locator('.offer-timer').innerText()).replace(/\D/g,''))>0);}
    const accepted=await h.once('UI.accept.'+actor.label,()=>uiAction(tabs[actor.label],'room.answer',offer.getByRole('button',{name:'接受邀请',exact:true}),true));
    if(actor.label==='E'&&!progress.checks.some(row=>row.id==='US03'))check('US03','First personal acceptance waits for the partner',accepted.result.status==='waiting_partner');
    if(accepted.result.roomId)reference('uiMatchRoom',accepted.result.roomId);
  }
  const roomId=progress.objects.uiMatchRoom;assert.ok(roomId);
  for(const actor of [E,F]){
    const tab=tabs[actor.label];await navigate(tab,'/portal/rooms/'+roomId);await tab.page.locator('.room-stage').waitFor();
    check('US04.'+actor.label,'Both joined users see exactly two real seats including the host',await tab.page.locator('.room-seats .sports-avatar').count()===2&&(await h.room(actor,roomId)).members.length===2);
    await h.once('UI.ready.'+actor.label,()=>uiAction(tab,'room.ready',tab.page.getByRole('button',{name:'确认准备',exact:true})));
    await layout(tab,'US05.'+actor.label);await shot(actor.label==='E'?'mobile-matched-room':'desktop-matched-room');
  }
  await navigate(tabs.E,'/portal/rooms/'+roomId);
  const ready=await h.room(E,roomId);check('US06','Separate ordinary prepare clicks produce two personally ready members',ready.members.every(row=>row.ready===true));
  const manager=String(ready.room.host_account_id)===String(E.id)?E:F,member=manager===E?F:E;
  const managerTab=tabs[manager.label],memberTab=tabs[member.label];
  await managerTab.page.setViewportSize({width:390,height:844});await memberTab.page.setViewportSize({width:1440,height:1000});
  await navigate(managerTab,'/portal/rooms/'+roomId);await managerTab.page.locator('.room-stage').waitFor();
  const draft=await h.once('UI.prepare',()=>uiAction(managerTab,'room.prepare',managerTab.page.getByRole('button',{name:'生成报名',exact:true}),true));
  const id=reference('uiStandardEntry',draft.result.registrationId);
  await navigate(managerTab,'/portal/registration/detail/'+id);await managerTab.page.locator('.registration-overview').waitFor();
  const own=await h.entry(manager,id),partner=own.members.find(row=>String(row.accountId)===String(member.id));assert.ok(partner?.inviteToken);
  if(!progress.checks.some(row=>row.id==='US07'))check('US07','Generated draft remains unsubmitted until each member confirms their own material',own.status==='draft'&&partner.status==='pending_confirmation');
  await h.once('UI.managerfields',async()=>{await formFields(managerTab,id,managerTab.page.locator('.field-block'));return clicked(managerTab,'/'+id+'/fields',managerTab.page.getByRole('button',{name:'保存草稿资料',exact:true}));});
  await managerTab.page.locator('[data-testid="entry-declaration-image"]').waitFor();
  await managerTab.page.waitForFunction(()=>{const image=document.querySelector('[data-testid="entry-declaration-image"]');return image?.complete&&image.naturalWidth>0;});
  check('US08','Image-only declaration is actually decoded before acknowledgement',await managerTab.page.locator('[data-testid="entry-declaration-image"]').evaluate(img=>img.complete&&img.naturalWidth>0));
  await managerTab.page.getByRole('button',{name:'放大参赛声明图片',exact:true}).click();await managerTab.page.getByRole('dialog',{name:'参赛声明图片',exact:true}).waitFor();
  await shot('mobile-declaration-zoom');await managerTab.page.getByRole('dialog',{name:'参赛声明图片',exact:true}).locator('.el-dialog__headerbtn').click();
  await h.once('UI.managerack',()=>clicked(managerTab,'/'+id+'/declaration-ack',managerTab.page.getByRole('button',{name:'我已阅读并确认',exact:true})));
  await navigate(memberTab,'/portal/registration/invite/'+partner.inviteToken);await memberTab.page.locator('[data-testid="invite-personal-fields"] .el-form-item').first().waitFor();
  await h.once('UI.memberconfirm',async()=>{await formFields(memberTab,id,memberTab.page.locator('[data-testid="invite-personal-fields"]'));return clicked(memberTab,'/confirm',memberTab.page.getByRole('button',{name:'我已阅读并确认参加',exact:true}));});
  check('US09','Invited ordinary member’s real UI saves all personal mandatory answers',(await api(member,'/sports/c/registrations/'+id+'/fields')).every(row=>row.valueText));
  await layout(memberTab,'US10');await shot('desktop-member-confirmed');
  await navigate(managerTab,'/portal/registration/detail/'+id);await managerTab.page.locator('.registration-overview').waitFor();
  await h.once('UI.submit',()=>clicked(managerTab,'/'+id+'/submit',managerTab.page.getByRole('button',{name:'正式提交报名',exact:true})));
  const submitted=await h.entry(manager,id);check('US11','Ordinary captain’s actual submit freezes both confirmed members and one roster',submitted.status==='submitted'&&submitted.rosterRevision===1&&submitted.members.every(row=>row.status==='confirmed'));
  await layout(managerTab,'US12');await shot('mobile-registration-submitted');
  await navigate(memberTab,'/portal/registration/invite/'+partner.inviteToken);await memberTab.page.locator('[data-testid="invite-personal-fields"] .el-form-item').first().waitFor();
  check('US13','Invited member’s submitted field inputs become read-only',await memberTab.page.locator('[data-testid="invite-personal-fields"] input:not([type="hidden"])').evaluateAll(inputs=>inputs.every(input=>input.disabled)));
  await shot('desktop-member-readonly');
}
async function teamsUi(){
  const C=people[2],D=people[3],tabs={C:await open(C,390),D:await open(D,1440)};
  const name=context.prefix+'-页面长期队伍';
  let id=progress.objects.uiTeam;
  if(!id){await navigate(tabs.C,'/portal/teams');await tabs.C.page.getByRole('textbox',{name:'新队伍名称',exact:true}).fill(name);const team=await clicked(tabs.C,'/sports/c/teams',tabs.C.page.getByRole('button',{name:'创建队伍',exact:true}));id=reference('uiTeam',team.id);}
  await navigate(tabs.D,'/portal/teams');
  await h.once('UI.team.Dapply',async()=>{await tabs.D.page.getByRole('textbox',{name:'申请加入的队伍编号',exact:true}).fill(id);await tabs.D.page.getByRole('button',{name:'查找队伍',exact:true}).click();return clicked(tabs.D,'/'+id+'/applications',tabs.D.page.getByRole('button',{name:'申请加入',exact:true}));});
  let team=await api(C,'/sports/c/teams/'+id);check('UT01','Ordinary application does not immediately add a permanent teammate',team.members.filter(row=>row.status==='active').length===1);
  await navigate(tabs.C,'/portal/teams/'+id);
  await h.once('UI.team.Capprove',()=>clicked(tabs.C,'/approve',tabs.C.page.getByRole('button',{name:'同意',exact:true})));
  team=await api(C,'/sports/c/teams/'+id);check('UT02','Captain approval creates two real long-term active members',team.members.filter(row=>row.status==='active').length===2);
  await layout(tabs.C,'UT03');await shot('mobile-long-team-members');
  const unit=progress.objects.units2.timeout;
  await navigate(tabs.C,'/portal/rooms?eventId='+progress.objects.event2+'&unitId='+unit+'&teamId='+id);
  await tabs.C.page.getByRole('textbox',{name:'房间名称',exact:true}).fill(context.prefix+'-页面长期队参赛房间');
  const made=await h.once('UI.team.room',()=>uiAction(tabs.C,'room.create',tabs.C.page.getByRole('button',{name:'创建双打房间',exact:true})));
  const roomId=reference('uiTeamRoom',made.result.roomId);
  const actual=await h.room(C,roomId);
  check('UT04','Actual room creation preserves the chosen long-term team ID and counts its host as one seat',String(actual.room.team_id)===String(id)&&actual.members.length===1&&String(actual.room.host_account_id)===String(C.id));
  await navigate(tabs.C,'/portal/rooms/'+roomId);await tabs.C.page.locator('.room-stage').waitFor();await shot('mobile-long-team-room');
  await tabs.C.page.getByText('房间管理',{exact:true}).click();
  await h.once('UI.team.roomleave',()=>uiAction(tabs.C,'room.leave',tabs.C.page.getByRole('button',{name:'退出房间',exact:true}),true));
  check('UT05','Closing an unregistered last-member room does not dissolve the long-term team',(await api(C,'/sports/c/teams/'+id)).status==='active');
  await navigate(tabs.C,'/portal/teams/'+id);await tabs.C.page.getByRole('button',{name:'转让队长',exact:true}).waitFor();
  await h.once('UI.team.transfer',()=>clicked(tabs.C,'/'+id+'/captain',tabs.C.page.getByRole('button',{name:'转让队长',exact:true}),'确认转让'));
  await navigate(tabs.D,'/portal/teams/'+id);await tabs.D.page.getByRole('button',{name:'保存队名',exact:true}).waitFor();
  team=await api(D,'/sports/c/teams/'+id);check('UT06','Real transfer click gives the named teammate a single captain role',team.members.filter(row=>row.status==='active'&&row.role==='captain').length===1&&String(team.members.find(row=>row.status==='active'&&row.role==='captain').accountId)===String(D.id));
  await layout(tabs.D,'UT07');await shot('desktop-long-team-captain');
  await navigate(tabs.C,'/portal/teams/'+id);await tabs.C.page.getByRole('button',{name:'退出队伍',exact:true}).waitFor();
  await h.once('UI.team.Cleave',()=>clicked(tabs.C,'/'+id+'/leave',tabs.C.page.getByRole('button',{name:'退出队伍',exact:true}),'确认退出'));
  check('UT08','Former captain’s real exit leaves an ended membership record',(await api(C,'/sports/c/teams')).memberships.some(row=>String(row.teamId)===String(id)&&row.membershipStatus!=='active'));
  await navigate(tabs.D,'/portal/teams/'+id);await tabs.D.page.getByRole('button',{name:'解散队伍',exact:true}).waitFor();
  await h.once('UI.team.disband',()=>clicked(tabs.D,'/'+id+'/disband',tabs.D.page.getByRole('button',{name:'解散队伍',exact:true}),'确定'));
  check('UT09','Captain can disband an unrelated team with no registration or financial obligations',(await api(D,'/sports/c/teams')).memberships.some(row=>String(row.teamId)===String(id)&&row.teamStatus==='disbanded'&&row.membershipStatus!=='active'));
}
async function presentation(){
  // Capture the current advanced state; never replay the now-completed UI acts.
  const D=people[3],E=people[4],F=people[5],B=people[1];
  const phone=await open(F,390),desktop=await open(E,1440);
  await navigate(phone,'/portal/registration/detail/'+progress.objects.uiStandardEntry);await phone.page.locator('.registration-overview').waitFor();
  check('UV01','Current phone entry is still formally submitted after later responsibility tests',(await h.entry(F,progress.objects.uiStandardEntry)).status==='submitted');
  await layout(phone,'UV02');await shot('mobile-current-registration-submitted');
  const current=await h.entry(F,progress.objects.uiStandardEntry),member=current.members.find(row=>String(row.accountId)===String(E.id));
  await navigate(desktop,'/portal/registration/invite/'+member.inviteToken);await desktop.page.locator('[data-testid="invite-personal-fields"] .el-form-item').first().waitFor();
  check('UV03','Current invited member fields are locked to the formally submitted roster',await desktop.page.locator('[data-testid="invite-personal-fields"] input:not([type="hidden"])').evaluateAll(inputs=>inputs.every(input=>input.disabled)));
  await layout(desktop,'UV04');await shot('desktop-current-member-readonly');
  await navigate(phone,'/portal/rooms/'+progress.objects.uiMatchRoom);await phone.page.locator('.room-stage').waitFor();const matched=await h.room(F,progress.objects.uiMatchRoom);check('UV05','Actual matched room keeps both ready participants after formal registration',matched.members.length===2&&matched.members.every(row=>row.ready));await shot('mobile-current-matched-room');
  const captain=await open(B,1440);await navigate(captain,'/portal/teams/'+progress.objects.team1);await captain.page.getByRole('button',{name:'保存队名',exact:true}).waitFor();
  check('UV06','New captain still has management while the original member has left',String((await api(B,'/sports/c/teams/'+progress.objects.team1)).members.find(row=>row.status==='active'&&row.role==='captain').accountId)===String(B.id));await shot('desktop-current-team-captain');
  check('UV07','Readonly presentation did not trigger new business writes',h.report.uiWrites.length===0);
}
async function handoverVisibility(){
  const solo=await open(people[2],390),paired=await open(people[5],1440),id=progress.objects.personalDraftBoundaryEntry;
  assert.ok(id);const detail=await api(solo.actor,'/sports/entry-management/'+id);assert.equal(detail.candidates.length,0);
  const pending=await api(solo.actor,'/sports/entry-management/pending');
  const loaded=solo.page.waitForResponse(r=>r.request().method()==='GET'&&new URL(r.url()).pathname.endsWith('/sports/entry-management/'+id));
  loaded.catch(()=>{});await navigate(solo,'/portal/registration/detail/'+id);await loaded;await solo.page.locator('.registration-overview').waitFor();
  check('UH01','Actual single-person draft has no invented candidate selector or unusable handover form',await solo.page.getByRole('button',{name:'邀请对方接任',exact:true}).count()===0&&await solo.page.locator('input[placeholder="选择一名已确认成员"]').count()===0);
  check('UH02','Responsibility panel is absent without candidates or pending personal tasks',pending.length>0||await solo.page.getByTestId('entry-responsibility-handover').count()===0);
  await shot('mobile-draft-without-empty-handover');
  await navigate(paired,'/portal/registration/detail/'+progress.objects.uiStandardEntry);const panel=paired.page.getByTestId('entry-responsibility-handover');await panel.waitFor();
  const candidates=(await api(paired.actor,'/sports/entry-management/'+progress.objects.uiStandardEntry)).candidates;
  check('UH03','Actual confirmed pair retains its legitimate personal handover form',candidates.length===1&&await panel.getByRole('heading',{name:'报名责任交接',exact:true}).isVisible()&&await panel.getByRole('button',{name:'邀请对方接任',exact:true}).isDisabled());
  await panel.locator('.el-select').click();const options=paired.page.getByRole('option',{name:candidates[0].nickname,exact:true});await options.waitFor();
  check('UH04','Candidate menu exposes the actual other confirmed member without inventing a manager',await options.count()===1);await paired.page.keyboard.press('Escape');
  await shot('desktop-confirmed-pair-handover');check('UH05','The visibility and candidate inspection emits no business writes',h.report.uiWrites.length===0);
}
try{await h.preflight();if(stage==='probe')await probe();else if(stage==='invite-probe')await inviteProbe();else if(stage==='standard')await standard();else if(stage==='teams-ui')await teamsUi();else if(stage==='presentation')await presentation();else if(stage==='handover-visibility')await handoverVisibility();else throw new Error('Unknown participant UI stage');check('UI00','No browser script error',h.report.pageErrors.length===0);h.report.passed=true;}
catch(error){h.report.failures.push({id:stage,reason:error.message});if(page)await shot('failure').catch(()=>{});process.exitCode=1;}
finally{for(const ctx of contexts)await ctx.close();await browser.close();h.final({stage,sourceFiles:['scripts/Test-BadmintonParticipantUI.mjs','scripts/lib/badminton-participant-test.mjs','plus-ui/src/views/sports/registration/enter.vue','plus-ui/src/views/sports/registration/invite.vue','plus-ui/src/components/consumer/EntryDeclaration.vue','plus-ui/src/components/consumer/EntryPersonalFields.vue','plus-ui/src/components/consumer/EntryHandover.vue','plus-ui/src/api/sports/registration.ts','plus-ui/src/views/portal/rooms.vue','plus-ui/src/views/portal/team.vue'].map(file=>({path:file,sha256:hashFile(file)}))});}
