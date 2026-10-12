import fs from 'node:fs/promises';
import path from 'node:path';
/** 独立访客上下文验证，不继承旧测试的示例登录夹具。 */
export async function verifyAuth({browser,base,out,check,watch}){
 const context=await browser.newContext({viewport:{width:1440,height:900}}),p=await context.newPage();watch(p);
 const shots=[],dir=path.join(out,'auth');await fs.mkdir(dir,{recursive:true});
 const capture=async(name)=>{await p.screenshot({path:path.join(dir,name+'.png'),fullPage:true});shots.push('auth/'+name+'.png')};
 const go=async(hash)=>{await p.goto(base+'/index.html'+hash)};
 const reset=async()=>{await go('#home');await p.evaluate(()=>{sessionStorage.clear();localStorage.clear()});await p.reload()};
 const fillLogin=async()=>{await p.locator('#auth-phone').fill('13900000000');await p.locator('#auth-password').fill('Test5678');await p.locator('[data-auth="captcha"]').click()};
 const submit=async()=>p.locator('#auth-form button[type="submit"]').click();
 try{
 await reset();check(await p.locator('.platform-hero').isVisible()&&await p.locator('.consumer-header .avatar').count()===0&&await p.locator('.auth-header-login').isVisible(),'访客首次进入 C00，顶栏没有示例登录身份');await capture('guest-desktop');
 await p.locator('.auth-header-login').click();check(await p.locator('#auth-phone').inputValue()===''&&await p.locator('#auth-password').inputValue()==='','C03 手机号与密码均为空，不预填管理员账号');
 check(await p.locator('#auth-form select').count()===0&&!(await p.locator('#main').innerText()).includes('RuoYi'),'C端登录不展示租户/社交/记住密码/语言/若依品牌');await capture('login-desktop');
 await submit();check((await p.locator('#auth-error').innerText()).includes('手机号'),'空输入不完成模拟登录');
 await p.locator('#auth-phone').fill('13900000000');await p.locator('#auth-password').fill('Test5678');await submit();check((await p.locator('#auth-error').innerText()).includes('安全验证'),'安全验证未完成时阻止模拟登录');
 await p.locator('[data-auth="captcha"]').click();await submit();await p.waitForSelector('.platform-hero');check(await p.locator('.consumer-header .avatar').isVisible()&&!p.url().includes('identity'),'普通登录默认 C00，不统一跳档案');
 await p.reload();check(await p.locator('.consumer-header .avatar').isVisible(),'刷新保留本标签页的虚构会话');
 await go('#me');await p.locator('[data-auth="logout"]').click();await p.waitForSelector('.platform-hero');check(await p.locator('.auth-header-login').isVisible(),'退出登录回 C00 并恢复访客顶栏');
 await go('#orders');await p.waitForSelector('#auth-form');check(p.url().includes('returnTo=orders')&&await p.locator('.order-list-card').count()===0,'访客直接访问个人记录先登录，不渲染个人数据');await fillLogin();await submit();await p.waitForSelector('.order-list-card');check(p.url().endsWith('#orders'),'登录返回原个人记录任务');
 await reset();await go('#detail');await p.locator('[name="project"][value="double"]').check();await p.getByRole('button',{name:'填写报名资料'}).click();await p.waitForSelector('#auth-form');check(decodeURIComponent(p.url()).includes('register?event=demo-autumn&unit=double'),'报名登录保留赛事及选择的双打项目');
 await p.locator('.auth-links a').filter({hasText:'注册账号'}).click();check(await p.getByRole('heading',{name:'注册',exact:true}).isVisible(),'C03 注册标题为注册，不限定参赛者');await capture('signup-desktop');
 await p.locator('#auth-phone').fill('13900000000');await p.locator('#auth-password').fill('Test5678');await p.locator('#auth-confirm').fill('Other5678');await p.locator('[data-auth="send-code"]').click();check((await p.locator('#auth-error').innerText()).includes('安全验证'),'获取短信前必须安全验证');
 await p.locator('[data-auth="captcha"]').click();await p.locator('[data-auth="send-code"]').click();check(await p.locator('#send-code').isDisabled()&&(await p.locator('#sms-status').innerText()).includes('未发送真实短信'),'模拟短信提示与重试限频明确');await p.locator('#auth-sms').fill('123456');await submit();check((await p.locator('#auth-error').innerText()).includes('不一致'),'两次密码不一致时保留任务并提示');
 await p.locator('#auth-confirm').fill('Test5678');await p.locator('#auth-sms').fill('111111');await submit();check((await p.locator('#auth-error').innerText()).includes('验证码错误'),'错误验证码不注册');
 await p.locator('#auth-sms').fill('123456');await submit();await p.waitForSelector('#auth-profile');check(p.url().includes('#login?')&&decodeURIComponent(p.url()).includes('unit=double')&&await p.locator('#auth-profile').inputValue()==='missing'&&await p.locator('#auth-password').inputValue()==='','注册成功回登录，保留原赛事，不自动登录或保留密码');
 await fillLogin();await submit();await p.waitForSelector('[data-auth="profile"]');check(p.url().includes('#identity?')&&await p.locator('#terms').count()===0,'新账号在报名动作时进入档案前置，不自动提交');await capture('profile-prerequisite');
 await p.locator('[data-auth="profile"]').click();await p.waitForSelector('#self-confirm');check((await p.locator('#main').innerText()).includes('男子双打报名')&&(await p.evaluate(()=>UI.myOrders().length))===1,'虚构档案补齐后返回同一赛事双打填写，未新增报名或付款');
 check(await p.evaluate(()=>{const data=sessionStorage.getItem('aisports-ui-auth-demo-v1');return !data.includes('13900000000')&&!data.includes('Test5678')&&!data.includes('123456')&&!localStorage.getItem('password')}),'浏览器存储仅含演示标记，没有手机号密码验证码');
 await reset();await go('#login?returnTo='+encodeURIComponent('register?event=demo-autumn&unit=female'));await p.locator('.auth-links a').filter({hasText:'忘记密码'}).click();await capture('forgot-desktop');
 await p.locator('#auth-phone').fill('13900000000');await p.locator('#auth-password').fill('Test5678');await p.locator('#auth-confirm').fill('Test5678');await p.locator('[data-auth="captcha"]').click();await p.locator('[data-auth="send-code"]').click();await p.locator('#auth-sms').fill('123456');await submit();await p.waitForSelector('#auth-form');check(p.url().includes('#login?')&&decodeURIComponent(p.url()).includes('unit=female')&&!(await p.evaluate(()=>Auth.loggedIn)),'密码恢复成功回登录并保留原任务，不自动认证');
 for(const value of ['https://example.com','//example.com','javascript:alert(1)','../business.html','%2F%2Fevil.test','orders?token=secret']){await go('#login?returnTo='+encodeURIComponent(value));check(await p.evaluate(()=>Auth.target())===(value.startsWith('orders?')?'orders':'home'),'安全返回任务过滤：'+value)}
 for(const scenario of ['failure','expired','limited']){await go('#login?returnTo=orders');await fillLogin();await p.locator('#auth-profile').selectOption(scenario);await submit();check(!await p.evaluate(()=>Auth.loggedIn)&&(await p.locator('#auth-error').innerText()).length>0,'登录 '+scenario+' 给出明确反馈并保留任务')}
 await reset();await go('#home');await p.locator('a[href="organizer.html#apply"]').click();await p.waitForSelector('#auth-form');check(decodeURIComponent(p.url()).includes('organization/apply'),'访客办赛入口先登录平台账号');await fillLogin();await p.locator('#auth-profile').selectOption('missing');await submit();await p.waitForURL(/organizer\.html#apply/);check(await p.locator('.b-route-tabs').isVisible()&&!p.url().includes('identity'),'办赛登录返回 B16，共用B端框架且不要求参赛档案');
 await p.setViewportSize({width:390,height:844});await go('#home');await p.evaluate(()=>Auth.logout());await p.waitForSelector('.platform-hero');await capture('guest-mobile');
 for(const route of ['login','signup','forgot']){for(const width of [390,375,320]){await p.setViewportSize({width,height:844});await go('#'+route);check(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'C端 '+route+' '+width+'px 无横向溢出')}await p.setViewportSize({width:390,height:844});await capture(route+'-mobile');if(route==='login'){check(await p.locator('.auth-links').evaluate(e=>e.getBoundingClientRect().bottom<=innerHeight)&&await p.locator('.mobile-nav').isHidden(),'手机登录首屏可见注册/恢复入口，认证页不受固定底栏遮挡')}}
 await go('#admin-entry');check(await p.getByRole('heading',{name:'管理员登录入口'}).isVisible()&&await p.locator('#auth-form').count()===0,'管理员入口指明若依 /login，不在原型伪造管理员认证');
 return shots;
 }finally{await context.close()}
}
