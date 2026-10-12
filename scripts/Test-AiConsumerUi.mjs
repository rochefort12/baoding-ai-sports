import { createFixtureAudit } from './lib/UiFixtureAudit.mjs';
const fixtureAudit=createFixtureAudit();
import {createRequire} from 'node:module';
import path from 'node:path';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const {chromium}=createRequire(path.join(process.argv[2],'_resolve.cjs'))('playwright');
const base=process.argv[3]?.startsWith('http')?process.argv[3]:'http://127.0.0.1:'+(process.argv[3]||5173),out=path.resolve('.local/ai-consumer-ui-20261009');await fs.mkdir(out,{recursive:true});
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true});
const errors=[],calls=[],writes=[];let passed=0,fail=false,delay=0;
const check=(ok,name)=>{assert.ok(ok,name);passed++;console.log('PASS '+name)};
const snap=async(p,name)=>p.screenshot({path:path.join(out,name+'.png'),fullPage:true});
const event={id:'901',name:'城市运动交流赛（合成样例）',projectName:'羽毛球',location:'保定 · 示例运动馆',feeDescription:'以参赛项目配置为准',phase:'registration',publicationStatus:'published',holdingStatus:'normal',startsAt:'2026-10-23T16:00:00Z',endsAt:'2026-10-25T10:00:00Z',registrationOpensAt:'2026-10-01T01:00:00Z',registrationClosesAt:'2026-10-18T10:00:00Z',registrationReview:'manual',rulesText:'示例规程：各成员本人确认。',bannerFileId:null};
const entry={id:'701',eventId:'901',unitId:'501',unitName:'双打（合成样例）',entryType:'pair',status:'submitted',members:[{selfMember:true,status:'confirmed'},{selfMember:false,status:'confirmed'}],canManage:true,feeAmount:120,paymentMode:'offline',obligationStatus:'open',paymentDeclared:true,eventHolding:'normal',eventPublication:'published'};
const fixture=async(c,auth=false)=>{
 if(auth)await c.addInitScript(()=>{localStorage.setItem('Admin-Token','fixture-c-only');localStorage.setItem('Platform-Token','fixture-c-only')});
 await c.route('**/*',async route=>{
  const req=route.request(),u=new URL(req.url()).pathname;
  if(!['xhr','fetch'].includes(req.resourceType()))return route.continue();
  let data=[],code=200,msg='隔离夹具';
  if(u.endsWith('/sports/public/ai/assistant')){
   const body=req.postDataJSON();calls.push({body,authorization:Boolean(req.headers().authorization)});if(delay)await new Promise(resolve=>setTimeout(resolve,delay));
   return route.fulfill({json:fail?{code:500,msg:'AI 暂不可用，重试后回答',data:null}:{code,msg,data:{reply:'### 参赛提示\n\n参考：城市运动交流赛的文字规程。<script>window.bad=true</script> 成员需本人确认，120元为本次项目配置。\n\n- **本人确认**\n\n|事项|说明|\n|---|---|\n|价格|以项目配置为准|\n\n[危险链接](javascript:alert(1))',sources:[{eventId:'901',name:event.name,projectName:'羽毛球',phase:'registration',holdingStatus:'normal',location:event.location}],refreshedAt:'2026-10-09T01:00:00Z'}}});
  }
  if(req.method()!=='GET'){console.error('BLOCKED WRITE',req.method(),u);writes.push(u);return route.fulfill({json:{code:403,msg:'测试禁止真实业务写入'}})}
  if(u.endsWith('/system/user/getInfo'))data={user:{userId:'201',tenantId:'900001',userName:'fixture',nickName:'合成用户',avatar:''},roles:['participant'],permissions:[]};
  else if(u.endsWith('/system/menu/getRouters'))data=[];
  else if(u.endsWith('/auth/code'))data={captchaEnabled:false};
  else if(u.endsWith('/sports/c/registrations/701/fields'))data=[];
  else if(u.endsWith('/sports/c/registrations/units'))data=[{id:'501',eventId:'901',name:'双打',entryType:'pair',minMembers:2,maxMembers:2,limitCount:32,usedCount:1}];
  else if(u.endsWith('/sports/c/identity'))data={accountId:'201',displayName:'合成用户',self:{legalName:'合成用户',personId:'301',boundToMe:true,birthDate:'2000-06-18',gender:'male',mobile:'13900000000'}};
  else if(u.endsWith('/sports/c/registrations/received'))data=[];
  else if(u.endsWith('/sports/c/registrations'))data=[entry];
  else if(u.endsWith('/sports/c/organization/application'))data={applicationId:null,status:null,name:null,contactName:null,contactMethod:null,statement:null,files:[],reviewReason:null,organizationId:null,canEnter:false,versions:[]};
  else if(u.endsWith('/sports/public/events/901/fees'))data={organizationName:'示例组织',units:[{unitId:'501',unitName:'双打',amount:120,paymentMode:'offline'}]};
  else if(u.endsWith('/sports/public/events/901'))data=event;
  else if(u.endsWith('/sports/public/events'))data=[event,{...event,id:'902',name:'篮球交流赛（合成样例）',projectName:'篮球'},{...event,id:'903',name:'已取消赛事（合成样例）',holdingStatus:'cancelled'}];
  else if(u.endsWith('/sports/c/teams'))data={memberships:[],myApplications:[],myInvitations:[],incomingApplications:[]};
  else return fixtureAudit.reject(route);
  return route.fulfill({json:{code,msg,data}});
 });
};
try{
 const actual=await browser.newContext({viewport:{width:1440,height:1000}});const a=await actual.newPage();a.on('pageerror',e=>{const detail={page: e.stack||e.message,url:new URL(a.url()).pathname};errors.push(detail);console.error('PAGE ERROR',JSON.stringify(detail));});
 await a.goto(base+'/portal/home');await a.waitForSelector('.home-events .event-card,.home-events .consumer-state');
 check(await a.locator('.c-hero-command').isVisible()&&await a.getByRole('link',{name:'发现赛事'}).isVisible()&&await a.locator('.c-hero-prompt').count()===0,'真实首页显示参赛导航且不再放第二套助手输入');check(await a.locator('.c-ai-launcher').isVisible(),'桌面保留参赛助手悬浮球');
 check(await a.locator('.c-task-welcome').isVisible(),'真实访客无伪造报名进度');
 check(await a.locator('.future-services').count()===0,'未开放能力不占首页');
 await snap(a,'actual-discover-desktop');
 for(const width of [390,320]){await a.setViewportSize({width,height:844});await a.waitForTimeout(100);check(await a.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'真实发现 '+width+'px 无溢出');check(await a.locator('.consumer-mobile-ai').isVisible(),'移动 AI 入口 '+width);const b=await a.locator('.c-hero-command').boundingBox();check(b.y+b.height<780,'首屏 AI 指令可见 '+width);await snap(a,'actual-discover-'+width)}
 await actual.close();
 const c=await browser.newContext({viewport:{width:1440,height:1000}});await fixture(c);const p=await c.newPage();p.on('pageerror',e=>{const detail={page:e.stack||e.message,url:new URL(p.url()).pathname};errors.push(detail);console.error('PAGE ERROR',JSON.stringify(detail));});
 await p.goto(base+'/portal/home');await p.waitForSelector('.home-events .event-card');check(await p.locator('.home-events .event-card').count()===3,'发现使用真实接口结构卡片');await p.waitForFunction(()=>{const e=document.querySelector('.home-events .c-event-placeholder');return e?.complete&&e.naturalWidth>0});check(await p.locator('.home-events .c-event-placeholder').first().evaluate(e=>e.complete&&e.naturalWidth>0),'无赛事封面使用可加载的通用运动插画');check(/2026[-/]10[-/]24/.test(await p.locator('.home-events .event-meta').first().innerText()),'赛事卡片日期按北京时间而非UTC截取');
 await p.locator('.c-feed-filters').getByRole('button',{name:'报名中',exact:true}).click();check(await p.locator('.home-events .event-card').count()===2,'报名中筛选排除取消');
 await p.getByRole('button',{name:'打开 AI 参赛助手',exact:true}).click();await p.waitForSelector('.c-assistant');check(calls.length===0,'悬浮球打开助手不偷偷调用模型');
 check(await p.getByRole('button',{name:'发送消息',exact:true}).isDisabled(),'未同意不发送');
 const box=await p.locator('.c-assistant').boundingBox();check(box.x>900,'C端窗口默认位于右侧');
 const text=p.locator('.c-ai-form textarea');await text.fill('测试输入法');await text.dispatchEvent('keydown',{key:'Enter',isComposing:true});check(calls.length===0&&await text.inputValue()==='测试输入法','输入法确认不发送');await text.press('Shift+Enter');check((await text.inputValue()).includes('\n'),'Shift Enter换行');
 await text.fill('有哪些正在报名的比赛？');await p.locator('.consumer-brand').click({position:{x:10,y:10}});check(await p.locator('.c-assistant').count()===0,'点击窗口外收起');await p.getByRole('button',{name:'打开 AI 参赛助手',exact:true}).click();check(await text.inputValue()==='有哪些正在报名的比赛？','重新打开保留未发送内容');
 const oldUrl=p.url();await p.locator('.c-ai-consent input').check();await text.press('Enter');await p.waitForSelector('.c-ai-source');
 check(p.url()===oldUrl,'聊天不切换路由');check(calls.length===1&&!calls[0].authorization,'公开 AI 请求无身份令牌');
 check(!calls[0].body.history&&!calls[0].body.context&&!calls[0].body.eventId,'客户端不上传伪造事实或私人对话');
 check(await p.evaluate(()=>!window.bad),'模型 HTML 只显示文本');check(await p.locator('.c-ai-source').getAttribute('href')==='/public/events/901','来源为受控本地赛事链接');
 check(await p.locator('.assistant-markdown h3').count()===1&&await p.locator('.assistant-markdown table').count()===1&&await p.locator('.assistant-markdown strong').count()===1,'Markdown标题表格和强调正确渲染');
 check(await p.locator('.assistant-markdown a[href^="javascript:"]').count()===0,'Markdown危险链接不能执行');
 const before=await p.locator('.c-assistant').boundingBox();await p.mouse.move(before.x+220,before.y+25);await p.mouse.down();await p.mouse.move(before.x+120,before.y+95);await p.mouse.up();const after=await p.locator('.c-assistant').boundingBox();check(after.x<before.x-80&&after.y>before.y+50,'聊天窗口可以拖动');
 await p.locator('.c-assistant-heading').focus();const keyBefore=await p.locator('.c-assistant').boundingBox();await p.keyboard.press('ArrowLeft');check((await p.locator('.c-assistant').boundingBox()).x<keyBefore.x,'窗口支持方向键移动');
 await p.locator('.c-ai-shortcuts').getByRole('button',{name:'AI 找赛事'}).click();await p.waitForFunction(()=>document.querySelectorAll('.c-ai-message.user').length===2);await p.waitForFunction(()=>document.querySelectorAll('.c-ai-source').length===2);check(calls.length===2&&calls.at(-1).body.message.includes('查找正在报名的公开赛事'),'同意后的快捷入口发送完整提示词');check(calls.at(-1).body.history.length===2,'连续对话保留历史');
 delay=450;await text.fill('请继续看看其他项目的比赛');await text.press('Enter');await p.waitForFunction(()=>document.querySelectorAll('.c-ai-message.user').length===3);await p.locator('.consumer-brand').click({position:{x:10,y:10}});await p.getByRole('button',{name:'打开 AI 参赛助手',exact:true}).click();await p.waitForFunction(()=>document.querySelectorAll('.c-ai-source').length===3);check(calls.length===3,'生成期间收起再打开，回答继续且不重复调用');delay=0;
 await p.getByRole('button',{name:'放大聊天窗口'}).click();check(await p.locator('.c-assistant.expanded').count()===1,'全局放大');await p.getByRole('button',{name:'恢复聊天窗口'}).click();check(await p.locator('.c-assistant.expanded').count()===0,'还原聊天窗口');
 await p.getByRole('button',{name:'关闭聊天窗口'}).click();const launcher=p.locator('.c-ai-launcher');const lb=await launcher.boundingBox();await p.mouse.move(lb.x+30,lb.y+30);await p.mouse.down();await p.mouse.move(lb.x-70,lb.y-20,{steps:8});await p.mouse.up();check((await launcher.boundingBox()).x<lb.x-70,'C端气泡可拖动');check(await p.locator('.c-assistant').count()===0,'拖动气泡不会误打开窗口');await launcher.click();check(await p.locator('.c-ai-message.user').count()===3,'重开保留会话');await p.waitForFunction(()=>document.querySelector('.c-ai-messages').scrollTop>0);check(await p.locator('.c-ai-messages').evaluate(e=>e.scrollTop>0),'重开定位到最新对话');
 await snap(p,'fixture-ai-chat-desktop');
 await p.locator('.c-ai-source').first().click();await p.waitForURL(/public\/events\/901/);await p.waitForSelector('.c-detail-ai');check(await p.locator('.c-ai-message').count()===0,'切换赛事清除旧依据');
 await p.getByRole('button',{name:'关闭聊天窗口'}).click();await p.getByRole('button',{name:'AI 解读规程'}).click();check(await p.locator('.c-ai-context').innerText().then(t=>t.includes('当前公开赛事')),'读取当前赛事上下文');
 await p.locator('.c-ai-consent input').check();await p.getByRole('button',{name:'发送消息',exact:true}).click();await p.waitForSelector('.c-ai-source');check(calls.at(-1).body.eventId==='901','当前赛事仅传编号并服务端授权读取');
 await p.getByRole('button',{name:'关闭聊天窗口'}).click();await p.getByRole('link',{name:'报名此项目'}).click();await p.waitForURL(/portal\/login/);check(decodeURIComponent(p.url()).includes('unitId=501'),'手动报名保留项目编号登录回跳');await p.locator('.consumer-auth').waitFor();await p.getByText('图形验证码',{exact:true}).waitFor({state:'hidden'});
 await p.goto(base+'/public/events');await p.waitForSelector('.event-card');await p.getByRole('button',{name:'篮球',exact:true}).click();check(await p.locator('.event-card').count()===1,'运动筛选来自真实公开项目');
 await p.getByRole('button',{name:/AI 找赛事/}).first().click();await p.locator('.c-ai-consent input').check();fail=true;await p.getByRole('button',{name:'发送消息',exact:true}).click();await p.waitForSelector('.c-assistant [role=alert]');check(await p.locator('.c-assistant [role=alert]').innerText().then(t=>t.includes('重试')),'模型失败提供明确重试');fail=false;await p.getByRole('button',{name:'重试回答'}).click();await p.waitForSelector('.c-ai-source');check(await p.locator('.c-assistant [role=alert]').count()===0,'重试可恢复');check(await p.locator('.c-ai-message.user').count()===1,'失败重试不重复用户消息');
 for(const width of [768,390,320]){await p.setViewportSize({width,height:844});check(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'助手 '+width+'px 无溢出');const b=await p.locator('.c-assistant').boundingBox();check(b.x>=0&&b.x+b.width<=width+1,'助手 '+width+'px 在屏幕内');await snap(p,'fixture-ai-'+width)}
 await c.close();
 const auth=await browser.newContext({viewport:{width:1440,height:1000}});await fixture(auth,true);const q=await auth.newPage();q.on('pageerror',e=>{const detail={page:e.stack||e.message,url:new URL(q.url()).pathname};errors.push(detail);console.error('PAGE ERROR',JSON.stringify(detail));});await q.goto(base+'/portal/home');await q.waitForSelector('.c-task-members');
 check(await q.locator('.c-task-card').innerText().then(t=>t.includes('实际到账')&&!t.includes('已取得参赛资格')),'真实状态结构：付款声明不冒充资格');
 check(await q.locator('.c-task-members').innerText().then(t=>t.includes('2 / 2')),'成员确认从本人报名读取');
 const modelCalls=calls.length;await q.getByRole('button',{name:'打开 AI 参赛助手',exact:true}).click();await q.locator('.c-ai-shortcuts').getByRole('button',{name:'我的下一步'}).click();await q.locator('.c-ai-consent input').check();await q.getByRole('button',{name:'发送消息',exact:true}).click();await q.waitForSelector('.c-ai-source');check(calls.length===modelCalls+1&&calls.at(-1).authorization,'同一段对话查询本人报名时带上登录态');check(!JSON.stringify(calls.at(-1).body).includes('unitName'),'报名明细不由页面上传');
 await q.getByRole('button',{name:'关闭聊天窗口'}).click();await q.locator('.c-discovery-tasks').getByRole('link',{name:'继续办理'}).click();await q.waitForURL(/registration\/detail\/701/);await q.waitForSelector('.registration-overview');check(await q.locator('.status-cells > div').count()===3,'保留资格、声明和资金状态');
 await snap(q,'fixture-registration-desktop');await q.goto(base+'/portal/registration/apply?eventId=901');await q.getByRole('button',{name:'打开 AI 参赛助手',exact:true}).first().click();await q.waitForSelector('.c-assistant');check((await q.locator('.c-ai-context').innerText()).includes('当前公开赛事'),'填写报名保留对应公开赛事上下文');await q.locator('.unit-option').first().waitFor();await auth.close();
 // 已选项目的深链按现有流程自动创建草稿。只模拟失败，验证页面接住拒绝，不把它当成只读请求。
 const failedDraft=await browser.newContext({viewport:{width:1440,height:1000}});await fixture(failedDraft,true);let draftRequests=0;
 await failedDraft.route('**/sports/c/registrations',async route=>{
  if(route.request().method()!=='POST')return route.fallback();
  draftRequests++;return route.fulfill({json:{code:500,msg:'隔离模拟：报名草稿创建失败',data:null}});
 });
 const d=await failedDraft.newPage();d.on('pageerror',e=>errors.push({page:e.stack||e.message,url:new URL(d.url()).pathname}));
 await d.goto(base+'/portal/registration/apply?eventId=901&unitId=501');await d.getByText('隔离模拟：报名草稿创建失败',{exact:true}).first().waitFor();
 await d.locator('.unit-option').first().waitFor();
 check(new URL(d.url()).pathname==='/portal/registration/apply','自动创建草稿失败不跳转或呈现成功');
 check(draftRequests===1,'自动准备草稿失败不重复请求');
 check(await d.locator('.notice.warn').innerText()==='隔离模拟：报名草稿创建失败','草稿创建失败显示可见提示并保留手动操作');
 await failedDraft.close();
 fixtureAudit.assertClean();if(errors.length)console.error('BROWSER ERRORS',JSON.stringify(errors));check(errors.length===0,'C 端无浏览器脚本异常');check(writes.length===0,'只读路径无写入，草稿失败请求仅本地模拟');
 await fs.writeFile(path.join(out,'results.json'),JSON.stringify({date:new Date().toISOString(),scope:'Actual anonymous public homepage; isolated model/personal API fixtures and one locally rejected draft POST; no real business writes or ordinary-role acceptance',passed,errors,calls,writes,draftRequests},null,2));console.log('AI CONSUMER PASS '+passed);
}finally{await browser.close()}







