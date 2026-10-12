// Fresh labelled synthetic invitations only. Run after final package activation; never write SQL or replay old success fixtures.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {context,request,key,iso,readSql,createEvidence} from './lib/BusinessRegression.mjs';

const trial=createEvidence('registration-invite-experience');
const {check,evidence,directory,save}=trial;
const privateFile=path.join(directory,'state.private.json');
const state={steps:{},keys:{}};
const privateSave=()=>fs.writeFileSync(privateFile,JSON.stringify(state,null,2));
const session=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8').replace(/^\uFEFF/,''));
evidence.jarSha256=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8').replace(/^\uFEFF/,'')).jarSHA256;
evidence.scope='Actual isolated ordinary-role HTTP and desktop/mobile browser invitation exercise; all identities and events are synthetic. No real SMS or user-event acceptance.';
save();
const call=async(actor,route,method='GET',body)=>{
  const response=await request(actor,route,method,body);
  assert.equal(response.code,200,method+' business request rejected; inspect the protected fixture.');
  return response.data;
};
const login=async(phone,password)=>({token:(await call(null,'/auth/login','POST',{username:phone,password,grantType:'platform',tenantId:'900001',clientId:context.clientId})).access_token});
const noticeCount=(member,kind)=>{
  assert.ok(/^\d+$/.test(String(member.id))&&/^\d+$/.test(String(member.accountId)));
  assert.ok(['registration-invite','registration-roster-removed'].includes(kind));
  return Number(readSql(`SELECT count(*) FROM asp_notification WHERE business_type='${kind}' AND business_id=${member.id} AND recipient_account_id=${member.accountId};`));
};
const screenshot=async(page,name)=>{
  await page.evaluate(()=>{for(const animation of document.getAnimations()) if(animation.effect?.getTiming().iterations!==Infinity) animation.finish();});
  await page.waitForFunction(()=>!document.querySelector('.el-message'),{},{timeout:10000});
  await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
  const output=path.join(directory,name+'.png');await page.screenshot({path:output});
  evidence.screenshots??=[];evidence.screenshots.push(output);save();
};
const {chromium}=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json')('playwright');
let browser;
const loginPage=async(phone,password,viewport)=>{
  const browserContext=await browser.newContext({viewport});const page=await browserContext.newPage();
  await page.goto(context.frontend+'/portal/login');
  await page.getByPlaceholder('请输入手机号').fill(phone);await page.getByPlaceholder('请输入密码').fill(password);
  await page.getByRole('button',{name:'登录',exact:true}).click();await page.waitForURL(url=>!url.pathname.includes('/login'));
  return {browserContext,page};
};
try{
  const owner=await login(session.people[0].phone,session.password);
  const organizer={token:(await call(owner,'/auth/organization/enter','POST',{})).access_token};
  const [host,recipient,stranger]=await Promise.all(context.people.slice(0,3).map(person=>login(person.phone,context.password)));
  const [hostIdentity,recipientIdentity]=await Promise.all([host,recipient].map(actor=>call(actor,'/sports/c/identity')));
  const eventName='报名邀请与名单提醒（模拟）'+path.basename(directory).slice(-8);
  state.event=await call(organizer,'/sports/b/events','POST',{name:eventName,location:'隔离模拟球馆',projectName:'羽毛球',feeDescription:'免费模拟验证',registrationOpensAt:iso(-1),registrationClosesAt:iso(23),startsAt:iso(24),endsAt:iso(27),registrationReview:'manual',rulesText:'本地合成通知验证，不举行真实赛事。',noticeText:'模拟人物与参赛名单。',declarationText:''});privateSave();
  for(const name of ['按手机号邀请（模拟）','队伍首返通知（模拟）']){
    const unit=await call(organizer,'/sports/b/registrations/units','POST',{eventId:state.event.id,name,entryType:'pair',minMembers:2,maxMembers:2,limitCount:8,charged:false,amount:0,paymentMode:'free',requestKey:key()});
    if(!state.generalUnit)state.generalUnit=unit;else state.teamUnit=unit;privateSave();
  }
  await call(organizer,'/sports/b/events/'+state.event.id+'/publish','POST',{requestKey:key(),contactConfirmed:true,contactName:'模拟负责人',contactMethod:'仅本地测试'});state.steps.published=true;privateSave();
  state.entry=await call(host,'/sports/c/registrations','POST',{unitId:state.generalUnit.id,requestKey:key()});privateSave();
  state.invitedEntry=await call(host,'/sports/c/registrations/'+state.entry.id+'/members','POST',{phone:context.people[1].phone,requestSms:false});
  state.member=state.invitedEntry.members.find(member=>member.accountId===recipientIdentity.accountId);privateSave();assert.ok(state.member);
  const member=state.member;
  check('First invitation response identifies the intended account without pretending it has confirmed',member.invitationName===recipientIdentity.self.legalName&&member.mobileTail===context.people[1].phone.slice(-4)&&member.legalName===null&&member.status==='pending_confirmation'&&!!member.inviteToken);
  check('First invitation response reports actual persistent inbox delivery',member.notice?.inboxStatus==='delivered'&&noticeCount(member,'registration-invite')===1);
  const duplicate=await call(host,'/sports/c/registrations/'+state.entry.id+'/members','POST',{phone:context.people[1].phone,requestSms:false});
  const reminders=await Promise.all([1,2].map(()=>call(host,`/sports/c/registrations/${state.entry.id}/members/${member.id}/remind`,'POST')));
  check('Repeated and concurrent pending-invite reminders keep one same notification',duplicate.members.find(row=>row.id===member.id)?.inviteToken===member.inviteToken&&reminders.every(row=>row.members.find(item=>item.id===member.id)?.notice?.inboxStatus==='delivered')&&noticeCount(member,'registration-invite')===1);
  check('Invite detail rejects a different account without exposing recipient identity',(await request(stranger,'/sports/c/registrations/invites/'+member.inviteToken)).code!==200);
  check('An invited member cannot remind others on behalf of the booking manager',(await request(recipient,`/sports/c/registrations/${state.entry.id}/members/${member.id}/remind`,'POST')).code!==200);
  const recipientNotices=await call(recipient,'/sports/c/notices');
  const invitationNotice=recipientNotices.find(row=>row.businessType==='registration-invite'&&row.businessId===member.id);
  check('Only intended recipient sees the invitation and its exact private target',invitationNotice?.targetPath==='/portal/registration/invite/'+member.inviteToken&&invitationNotice.body.includes(eventName)&&invitationNotice.body.includes(hostIdentity.self.legalName)&&!(await call(stranger,'/sports/c/notices')).some(row=>row.businessType==='registration-invite'&&row.businessId===member.id));
  state.steps.initialHttpAccepted=true;privateSave();

  state.team=await call(host,'/sports/c/teams','POST',{name:'邀请首返队伍（模拟）'+path.basename(directory).slice(-8)});privateSave();
  const applicationHome=await call(recipient,'/sports/c/teams/'+state.team.id+'/applications','POST');
  const application=applicationHome.myApplications.find(row=>row.teamId===state.team.id&&row.status==='pending');assert.ok(application);
  await call(host,'/sports/c/teams/applications/'+application.id+'/approve','POST');
  state.teamEntry=await call(host,'/sports/c/registrations','POST',{unitId:state.teamUnit.id,teamId:state.team.id,requestKey:key()});privateSave();
  state.teamAdded=await call(host,'/sports/c/registrations/'+state.teamEntry.id+'/roster','POST',{accountId:recipientIdentity.accountId});privateSave();
  const teamMember=state.teamAdded.members.find(row=>row.accountId===recipientIdentity.accountId);
  check('Adding a current teammate returns delivery after notice commit',teamMember?.notice?.inboxStatus==='delivered'&&teamMember.invitationName===recipientIdentity.self.legalName&&noticeCount(teamMember,'registration-invite')===1);
  check('A member from another booking cannot be reminded through this booking',(await request(host,`/sports/c/registrations/${state.entry.id}/members/${teamMember.id}/remind`,'POST')).code!==200);

  browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
  let desktopRecipient;
  for(const [device,viewport]of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}]]){
    const {browserContext,page}=await loginPage(context.people[1].phone,context.password,viewport);
    await page.goto(context.frontend+'/portal/notices');
    const row=page.locator('.notice-card').filter({hasText:eventName}).filter({hasText:'收到参赛邀请'}).filter({hasText:state.generalUnit.name});
    await row.waitFor();await row.getByRole('button',{name:'查看邀请',exact:true}).click();
    await page.waitForURL(url=>url.pathname==='/portal/registration/invite/'+member.inviteToken);
    await page.getByTestId('invited-person-summary').waitFor();
    check(device+' persistent invitation click opens the correct person and project',await page.getByTestId('invited-person-summary').innerText().then(text=>text.includes(recipientIdentity.self.legalName)&&text.includes(context.people[1].phone.slice(-4))&&text.includes(hostIdentity.self.legalName))&&(await page.locator('main').innerText()).includes(state.generalUnit.name));
    check(device+' invitation form adapts to the viewport without horizontal overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
    await screenshot(page,'registration-invite-'+device);
    if(device==='desktop')desktopRecipient={browserContext,page};else await browserContext.close();
  }
  const personPage=desktopRecipient.page;
  const confirmed=personPage.waitForResponse(response=>response.url().endsWith('/confirm')&&response.request().method()==='POST');
  await personPage.getByRole('button',{name:'确认参加',exact:true}).click();
  const confirmation=await(await confirmed).json();assert.equal(confirmation.code,200,'Personal invite confirmation rejected');state.steps.memberConfirmed=true;privateSave();
  check('Invited person actually confirms through the notification entry',confirmation.data.memberStatus==='confirmed'&&!confirmation.data.canRespond);
  const {browserContext:hostContext,page:hostPage}=await loginPage(context.people[0].phone,context.password,{width:1440,height:1000});
  await hostPage.goto(context.frontend+'/portal/registration/detail/'+state.entry.id);
  const recipientRow=hostPage.locator('.participant-item').filter({hasText:recipientIdentity.self.legalName});await recipientRow.waitFor();
  check('Confirmed recipient retains frozen name and no stale copy-link action',!(await recipientRow.innerText()).includes('邀请链接')&&(await recipientRow.innerText()).includes('已确认'));
  await recipientRow.getByRole('button',{name:'移除',exact:true}).click();await hostPage.getByRole('button',{name:'移出并通知本人',exact:true}).waitFor();
  await screenshot(hostPage,'registration-remove-confirmation');
  const removed=hostPage.waitForResponse(response=>response.url().endsWith('/members/'+member.id)&&response.request().method()==='DELETE');
  await hostPage.getByRole('button',{name:'移出并通知本人',exact:true}).click();assert.equal((await(await removed).json()).code,200,'Roster removal rejected');state.steps.memberRemoved=true;privateSave();
  check('Manager removal writes exactly one durable notice for that recipient',noticeCount(member,'registration-roster-removed')===1&&(await call(recipient,'/sports/c/notices')).some(row=>row.businessType==='registration-roster-removed'&&row.businessId===member.id&&row.targetPath==='/portal/registration'&&row.body.includes(state.generalUnit.name)));
  check('Repeating removed-member request cannot create another removal notice',(await request(host,`/sports/c/registrations/${state.entry.id}/members/${member.id}`,'DELETE')).code!==200&&noticeCount(member,'registration-roster-removed')===1);
  check('Old invitation becomes unusable after roster removal',(await request(recipient,'/sports/c/registrations/invites/'+member.inviteToken)).code!==200);
  await personPage.goto(context.frontend+'/portal/notices');
  const removedNotice=personPage.locator('.notice-card').filter({hasText:eventName}).filter({hasText:state.generalUnit.name}).filter({hasText:'参赛名单已调整'});await removedNotice.waitFor();
  await screenshot(personPage,'registration-removal-notice');await removedNotice.getByRole('button',{name:'查看我的报名',exact:true}).click();await personPage.waitForURL(url=>url.pathname==='/portal/registration');
  check('Removed person can follow the notice to their own booking list without a forbidden detail page',personPage.url().endsWith('/portal/registration'));
  await hostContext.close();await desktopRecipient.browserContext.close();
  evidence.objects={eventId:state.event.id,unitIds:[state.generalUnit.id,state.teamUnit.id],registrationIds:[state.entry.id,state.teamEntry.id],memberId:member.id,teamId:state.team.id};
  trial.finish();
}catch(error){
  // Route tokens and credentials stay in private state even when a browser/API assertion fails.
  evidence.failure=String(error.message).replace(/\/portal\/registration\/invite\/[a-zA-Z0-9-]+/g,'/portal/registration/invite/[private]').replace(/\/sports\/c\/registrations\/invites\/[a-zA-Z0-9-]+/g,'/sports/c/registrations/invites/[private]').replaceAll(context.password,'[private]').replaceAll(session.password,'[private]');
  save();privateSave();throw new Error('Registration invitation exercise failed; preserved receipt and private fixture identify the incomplete step.');
}finally{await browser?.close();}
