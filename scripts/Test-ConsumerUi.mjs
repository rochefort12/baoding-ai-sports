import { createFixtureAudit } from './lib/UiFixtureAudit.mjs';
const fixtureAudit=createFixtureAudit();
import { createRequire } from 'node:module';
import path from 'node:path';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const require=createRequire(path.join(process.argv[2],'_resolve.cjs'));
const {chromium}=require('playwright');
const base=process.argv[3]?.startsWith('http')?process.argv[3]:'http://127.0.0.1:'+(process.argv[3]||5173),out=path.resolve('.local','consumer-ui-20261007','validation');await fs.mkdir(out,{recursive:true});
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true});
const errors=[],shots=[],metrics=[],writes=[];let passed=0;
const check=(ok,name)=>{assert.ok(ok,name);passed++;console.log('PASS '+name)};
const watch=p=>p.on('pageerror',e=>errors.push(e.message));
const snap=async(p,name)=>{await p.screenshot({path:path.join(out,name+'.png'),fullPage:true});shots.push(name+'.png')};
const event={id:'901',name:'保定城市运动交流赛（视觉样例）',location:'保定 · 城市运动馆（视觉样例）',projectName:'羽毛球',feeDescription:'按参赛项目整单收费',startsAt:'2026-10-24T09:00:00',endsAt:'2026-10-25T18:00:00',registrationOpensAt:'2026-10-01T09:00:00',registrationClosesAt:'2026-10-18T18:00:00',holdingStatus:'normal',publicationStatus:'published',phase:'registration',bannerFileId:null,rulesText:'各成员独立填写并确认参赛资料。',noticeText:null,routeText:null,declarationText:null};
const entry={id:'701',eventId:'901',unitId:'501',unitName:'男子双打（视觉样例）',entryType:'pair',status:'submitted',requestKey:'fixture',rosterRevision:1,requestKeyConsumed:true,submittedAt:'2026-10-07T10:18:00',members:[{id:'401',accountId:'201',status:'confirmed',selfMember:true,legalName:'林一（虚构）',inviteToken:null},{id:'402',accountId:'202',status:'confirmed',selfMember:false,legalName:'周宁（虚构）',inviteToken:null}],teamId:null,teamName:null,canManage:true,feeAmount:120,paymentMode:'offline',obligationStatus:'open',payInstruction:'按承办方公开联系渠道核对付款。',obligationId:'801',paymentDeclared:true,pendingActionId:null,eventHolding:'normal',eventPublication:'published'};
const identity={accountId:'201',displayName:'林一（视觉样例）',loginPhone:'13900000000',self:{personId:'301',legalName:'林一（虚构）',birthDate:'2000-06-18',gender:'male',mobile:'13900000000',boundToMe:true}};
const teams={memberships:[{teamId:'601',name:'周末运动队（视觉样例）',teamStatus:'active',role:'captain',membershipStatus:'active',endReason:null},{teamId:'602',name:'春日运动队（视觉样例）',teamStatus:'active',role:'member',membershipStatus:'ended',endReason:'member_left'}],myApplications:[],myInvitations:[],incomingApplications:[]};
const team={id:'601',name:'周末运动队（视觉样例）',status:'active',myRole:'captain',myMembershipStatus:'active',myEndReason:null,captain:true,canLeave:false,members:[{id:'411',personId:'301',accountId:'201',legalName:'林一（虚构）',role:'captain',status:'active',endReason:null,selectable:true},{id:'412',personId:'302',accountId:'202',legalName:'周宁（虚构）',role:'member',status:'ended',endReason:'member_left',selectable:false}],applications:[],invitations:[]};
let cancelled=false,feeMissing=false,deniedTeam=false,empty=false,long=false,confirmedInvite=false,teamInviteStatus='pending';
try{
 // 真实公开接口：不使用账号，不执行任何写入。
 const publicContext=await browser.newContext({viewport:{width:1440,height:900}}),p=await publicContext.newPage();watch(p);
 await p.goto(base+'/');await p.waitForSelector('.platform-hero');check(p.url().includes('/portal/home'),'正式站点根入口到 C00');check(await p.locator('.header-login').isVisible()&&await p.locator('.account-avatar').count()===0,'真实访客首页不显示假登录账号');await p.waitForSelector('.home-events .event-card,.home-events .consumer-state');await snap(p,'actual-home-desktop');
 for(const width of [390,375,320]){await p.setViewportSize({width,height:844});await p.goto(base+'/portal/home');await p.waitForSelector('.home-events .event-card,.home-events .consumer-state');check(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'真实首页 '+width+'px 无横向溢出');const box=await p.locator('.home-events .event-card').first().boundingBox();if(box){const bottom=await p.locator('.consumer-mobile-nav').evaluate(e=>e.getBoundingClientRect().top);metrics.push({width,firstEventBottom:box.y+box.height,bottomNavTop:bottom});const command=await p.locator('.c-hero-command').boundingBox();check(command.y+command.height<=bottom,'真实首页 '+width+'px AI 参赛入口在底栏之上')}await snap(p,'actual-home-'+width)}
 await p.goto(base+'/portal/teams/invitations/611');await p.waitForURL(/portal\/login/);check(decodeURIComponent(p.url()).includes('/portal/teams/invitations/611'),'未登录入队深链登录回跳保留');await p.goto(base+'/portal/registration');await p.waitForURL(/portal\/login/);check(decodeURIComponent(p.url()).includes('/portal/registration'),'真实守卫保留我的参赛目标');await snap(p,'actual-login-mobile');
 await p.setViewportSize({width:1440,height:900});await p.goto(base+'/portal/login');check(await p.locator('input[placeholder="请输入手机号"]').inputValue()===''&&await p.locator('input[placeholder="请输入密码"]').inputValue()==='','真实登录空表单');await p.getByRole('button',{name:'登录',exact:true}).click();await p.waitForSelector('.el-form-item__error');check(await p.locator('.el-form-item__error').count()>0,'真实登录空提交被校验阻断');check(await p.locator('.auth-story').isVisible(),'桌面认证使用品牌两列布局');await snap(p,'actual-login-desktop');
 for(const page of ['register','forgot']){await p.goto(base+'/portal/'+page);await p.waitForSelector('.consumer-auth');await p.setViewportSize({width:320,height:844});check(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'真实 '+page+' 320px 无溢出');await snap(p,'actual-'+page+'-mobile')}
 await publicContext.close();
 // 以下仅隔离的网络视觉夹具。假token和读取数据不进入真实业务后端。
 const context=await browser.newContext({viewport:{width:1440,height:900}});
 await context.addInitScript(()=>{localStorage.setItem('Admin-Token','consumer-ui-fixture-only');localStorage.setItem('Platform-Token','consumer-ui-fixture-only')});
 await context.route('**/*',async route=>{
  const req=route.request(),url=new URL(req.url()),u=url.pathname;
  if(!['xhr','fetch'].includes(req.resourceType()))return route.continue();
  let data=[],code=200,msg='视觉夹具';
  if(req.method()!=='GET'){writes.push({method:req.method(),path:u});return route.fulfill({json:{code:403,msg:'视觉测试禁止业务写入',data:null}})}
  if(u.endsWith('/system/user/getInfo'))data={user:{userId:'201',tenantId:'900001',userName:'fixture',nickName:identity.displayName,avatar:''},roles:['participant'],permissions:[]};
  else if(u.endsWith('/system/menu/getRouters'))data=[];
  else if(u.endsWith('/auth/code'))data={captchaEnabled:false};
  else if(u.endsWith('/sports/c/registrations/701/fields'))data=[];
  else if(u.endsWith('/sports/c/organization/application'))data={applicationId:null,status:null,name:null,contactName:null,contactMethod:null,statement:null,files:[],reviewReason:null,organizationId:null,canEnter:false,versions:[]};
  else if(u.endsWith('/sports/c/identity'))data=identity;
  else if(u.endsWith('/sports/public/events/901/fees'))data={organizationName:'保定运动社（视觉样例）',contactName:'赛事联系人（虚构）',contactMethod:'示例联系渠道',refundNote:'依本次冻结规则核对退款。',units:[{unitId:'501',unitName:'男子双打（视觉样例）',amount:feeMissing?null:120,paymentMode:feeMissing?null:'offline',payInstruction:'示例付款说明'}]};
  else if(u.endsWith('/sports/public/events/901'))data={...event,holdingStatus:cancelled?'cancelled':'normal',phase:cancelled?'finished':'registration'};
  else if(u.endsWith('/sports/public/events'))data=empty?[]:[{...event,name:long?'较长赛事标题'.repeat(20):event.name}];
  else if(u.endsWith('/sports/c/registrations/units'))data=[{id:'501',eventId:'901',name:'男子双打（视觉样例）',entryType:'pair',minMembers:2,maxMembers:2,usedCount:8,limitCount:24}];
  else if(u.endsWith('/sports/c/registrations/received'))data=[];
  else if(u.endsWith('/sports/c/registrations'))data=empty?[]:[{...entry,unitName:long?'较长参赛项目'.repeat(20):entry.unitName,eventHolding:cancelled?'cancelled':'normal'}];
  else if(u.endsWith('/sports/c/teams/601')){if(deniedTeam){code=403;data=null;msg='当前账号无权查看队伍详情'}else data=team;}
  else if(u.endsWith('/sports/c/teams'))data=empty?{memberships:[],myApplications:[],myInvitations:[],incomingApplications:[]}:teams;
  else if(u.endsWith('/sports/c/notices'))data=empty?[]:[{id:'911',purpose:'event_cancelled',title:'交流赛安排更新（视觉样例）',body:'赛事通知会在这里保留。资格、资金与短信送达分别记录。',businessType:'event',businessId:'901',read:false}];
  else if(u.endsWith('/sports/c/results'))data=empty?[]:[{matchCode:'A01',unitName:'男子双打',eventName:event.name,eventCancelled:true,summary:'21 : 18',outcomeA:'win',outcomeB:'loss',games:'21:18|18:21|21:17',sideA:'林一 / 周宁（虚构）',sideB:'王南 / 陈北（虚构）'}];
  else if(u.endsWith('/sports/c/proofs'))data=empty?[]:[{honorId:'921',awardKey:'first',eventName:event.name,unitName:'男子双打',title:'男子双打冠军',names:'林一、周宁（均为虚构）',awardedAt:'2026-10-07T15:30:00',self:true}];
  else if(u.endsWith('/sports/c/teams/invitations/611'))data={id:'611',teamId:'601',teamName:team.name,status:teamInviteStatus,personName:'林一（虚构）'};
  else if(u.includes('/registrations/invites/'))data={registrationId:'701',eventId:'901',eventName:event.name,unitName:'男子双打',entryType:'pair',registrationStatus:'draft',memberStatus:confirmedInvite?'confirmed':'pending_confirmation',canRespond:!confirmedInvite,members:confirmedInvite?[{legalName:'周宁（虚构）',status:'confirmed',selfMember:false},{legalName:'林一（虚构）',status:'confirmed',selfMember:true}]:[]};
  else return fixtureAudit.reject(route);
  return route.fulfill({json:{code,msg,data}});
 });
 const c=await context.newPage();watch(c);
 const cases=[['identity','/portal/identity','.profile-layout'],['orders','/portal/registration','.order-card'],['apply','/portal/registration/apply?eventId=901&unitId=501','.unit-option'],['detail','/portal/registration/detail/701','.registration-overview'],['teams','/portal/teams','.team-card'],['team-detail','/portal/teams/601','.el-tabs'],['notices','/portal/notices','.notice-card'],['results','/portal/results','.result-card'],['proofs','/portal/proofs','.proof-card'],['feedback','/portal/feedback','.feedback-form'],['invite','/portal/registration/invite/fixture','.status-cells'],['event-detail','/public/events/901','.unit-row']];
 for(const [name,url,selector] of cases){for(const width of [1440,390,320]){await c.setViewportSize({width,height:width===1440?900:844});await c.goto(base+url);await c.waitForSelector(selector).catch(async e=>{console.log(JSON.stringify({url:c.url(),errors,writes,body:await c.locator('main').innerText()}));await snap(c,'failure-'+name);throw e});check(await c.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'样例 '+name+' '+width+'px 无整页溢出');if(width!==320)await snap(c,'fixture-'+name+'-'+width)}check(!(await c.locator('main').innerText()).includes('测试时按这个顺序走'),'样例 '+name+' 无测试导航')}
 await c.goto(base+'/portal/results');await c.waitForSelector('.result-card');check((await c.locator('.result-card').innerText()).includes('获胜')&&(await c.locator('.result-card').innerText()).includes('第3局 21:17'),'本人赛果显示中文胜负与各局比分');
 await c.goto(base+'/portal/teams/601');await c.getByRole('tab',{name:'加入/退出记录'}).click();check((await c.locator('.el-tabs__content').innerText()).includes('周宁')&&await c.getByRole('button',{name:'移除',exact:true}).count()===0,'历史成员不呈现当前成员管理动作');await snap(c,'fixture-team-history');
 await c.goto(base+'/portal/teams');await c.waitForSelector('.history-block').catch(async e=>{console.log({url:c.url(),errors,body:await c.locator('body').innerText()});throw e});await c.locator('summary').filter({hasText:'本人加入'}).click();check((await c.locator('.history-block').innerText()).includes('春日运动队')&&await c.locator('.history-block a').count()===0,'本人历史摘要不恢复完整队伍入口');
 deniedTeam=true;await c.goto(base+'/portal/teams/601');await c.waitForSelector('.consumer-state[role=alert]');check((await c.locator('main').innerText()).includes('权限')&&await c.locator('.participant-item').count()===0,'拒绝查看队伍时不呈现成员数据');deniedTeam=false;
 await c.goto(base+'/portal/registration/detail/701');await c.waitForSelector('.registration-overview .status-cells');check(await c.locator('.status-cells>div').count()===3&&(await c.locator('.status-cells').innerText()).includes('待核对到账'),'资格/声明/资金三个状态区分');await c.getByRole('button',{name:'撤回整单报名'}).click();await c.getByRole('button',{name:'暂不撤回'}).click();check(writes.length===0,'取消撤回确认没有发送写请求');
 cancelled=true;await c.goto(base+'/portal/registration/detail/701');await c.waitForSelector('.registration-overview');check(await c.getByRole('button',{name:'查看付款指引／我已付款',exact:true}).count()===0&&await c.getByRole('button',{name:'撤回整单报名',exact:true}).count()===0,'取消历史关闭正常付款与撤回入口');await c.goto(base+'/public/events/901');await c.waitForSelector('.unit-row');check(await c.locator('a').filter({hasText:'报名此项目'}).count()===0,'取消公开详情不显示报名按钮');
 cancelled=false;feeMissing=true;await c.reload();await c.waitForSelector('.unit-row');check((await c.locator('.unit-row').innerText()).includes('待公布')&&!(await c.locator('.unit-row').innerText()).includes('免费')&&await c.locator('.unit-row a').count()===0,'缺收费配置不显示免费，也不开放报名');feeMissing=false;
 empty=true;for(const [name,url] of [['orders','/portal/registration'],['notices','/portal/notices'],['results','/portal/results'],['proofs','/portal/proofs']]){await c.goto(base+url);await c.waitForSelector('.consumer-state:not(.is-loading)');check(await c.locator('.consumer-state').isVisible(),'样例 '+name+' 真实空态结构');await snap(c,'fixture-empty-'+name)}empty=false;
 long=true;await c.setViewportSize({width:320,height:844});await c.goto(base+'/portal/registration');await c.waitForSelector('.order-card');check(await c.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'长项目名称320px不溢出');await snap(c,'fixture-long-orders');long=false;
 check(writes.length===0,'隔离视觉检查未发出任何业务写入');fixtureAudit.assertClean();check(errors.length===0,'所有页面无浏览器脚本异常');
 // 新邀请页和返回：隔离只读响应，不加入任何真实队伍。
 confirmedInvite=true;for(const width of [1440,390,320]){
  await c.setViewportSize({width,height:844});await c.goto(base+'/portal/registration/invite/fixture');await c.waitForSelector('.invitation-roster');check((await c.locator('.invitation-roster').innerText()).includes('周宁（虚构）'),'已确认未提交显示伙伴 '+width);check(await c.getByRole('button',{name:'确认参加',exact:true}).count()===0,'确认后不重复办理 '+width);await snap(c,'confirmed-invite-'+width);
  await c.goto(base+'/portal/teams/invitations/611');await c.waitForSelector('.consumer-card');check(await c.getByRole('button',{name:'接受邀请',exact:true}).count()===1,'入队深链显示本人办理 '+width);check(await c.getByRole('link',{name:'返回我的队伍',exact:true}).count()===1,'入队深链保留返回 '+width);check(await c.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'邀请页无横向溢出 '+width);await snap(c,'team-invitation-'+width);
 }
 teamInviteStatus='revoked';await c.goto(base+'/portal/teams/invitations/611');await c.waitForSelector('.consumer-card');check(await c.getByRole('button',{name:'接受邀请',exact:true}).count()===0,'撤回邀请不再允许接受');
 await c.goto(base+'/portal/registration/detail/701');await c.waitForSelector('.registration-overview');await c.getByRole('link',{name:'返回我的参赛',exact:true}).click();await c.waitForURL(/portal\/registration$/);check(true,'报名详情顶部返回本人列表');
 await c.getByRole('button',{name:'当前报名',exact:true}).click();await c.getByRole('link',{name:'查看报名',exact:true}).click();await c.waitForSelector('.registration-overview');await c.getByRole('link',{name:'返回我的参赛',exact:true}).click();await c.waitForSelector('.order-card');check(await c.getByRole('button',{name:'当前报名',exact:true}).getAttribute('aria-pressed')==='true','详情返回保留当前报名筛选');
 check(writes.length===0,'新增邀请页面检查未写真实业务');fixtureAudit.assertClean();check(errors.length===0,'新增邀请页面无浏览器异常');
 await fs.writeFile(path.join(out,'results.json'),JSON.stringify({date:new Date().toISOString(),scope:'Public pages use actual API; protected pages use isolated GET fixtures only, not authentication/business acceptance',passed,errors,writes,metrics,screenshots:shots},null,2));console.log('CONSUMER UI PASS '+passed+' checks; '+shots.length+' screenshots');await context.close();
}finally{await browser.close()}





