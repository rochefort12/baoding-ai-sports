import { createFixtureAudit } from './lib/UiFixtureAudit.mjs';
const fixtureAudit=createFixtureAudit();
const base=process.argv[3]||'http://127.0.0.1:5173';
// 完全隔离的 SDK/短信/注册响应，验证界面生命周期；不请求真实注册或短信服务。
import {createRequire} from 'node:module';import path from 'node:path';import assert from 'node:assert/strict';
const require=createRequire(path.join(process.argv[2],'_resolve.cjs'));const {chromium}=require('playwright');const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true});
let passed=0;const check=(value,label)=>{assert.ok(value,label);passed++;console.log('PASS '+label)};
const context=await browser.newContext({viewport:{width:1440,height:900}});const errors=[],requests=[];
await context.addInitScript(()=>{window.__captchaFixture={destroyed:0,hidden:0};window.initAliyunCaptcha=options=>{const layer=document.createElement('div');layer.id='fixture-captcha-layer';layer.textContent='隔离验证码浮层';document.body.append(layer);options.getInstance({hide:()=>window.__captchaFixture.hidden++,destroyCaptcha:()=>{window.__captchaFixture.destroyed++;layer.remove()}});options.success('isolated-fixture-only');}});
await context.route('**/*',async r=>{const req=r.request(),u=new URL(req.url());if(!['xhr','fetch'].includes(req.resourceType()))return r.continue();requests.push(u.pathname);let data={};if(u.pathname.endsWith('/auth/participant/captcha-config'))data={aliyun:true,region:'cn',prefix:'isolated',sceneId:'fixture'};else if(u.pathname.endsWith('/auth/participant/sms-code'))data={debugCode:'123456'};else if(u.pathname.endsWith('/auth/participant/register'))data={};else if(u.pathname.endsWith('/sports/public/events'))data=[];else if(u.pathname.endsWith('/auth/code'))data={captchaEnabled:false};else return fixtureAudit.reject(r);return r.fulfill({json:{code:200,msg:'isolated fixture',data}})});
const p=await context.newPage();p.on('pageerror',e=>errors.push(e.message));
try{
 await p.goto(base+'/portal/register?returnTo=/public/events/901');await p.waitForSelector('#fixture-captcha-layer');const before=await p.locator('.auth-story').boundingBox();await p.getByPlaceholder('请输入手机号').fill('13900000000');await p.getByRole('button',{name:'获取验证码',exact:true}).click();await p.getByText('本地模拟验证码：',{exact:false}).waitFor();const after=await p.locator('.auth-story').boundingBox();check(Math.abs(before.y-after.y)<1,'短信提示出现后左侧品牌区不下移');
 await p.getByPlaceholder('5到20位').fill('fixture123');await p.getByPlaceholder('再次输入密码').fill('fixture123');await p.getByPlaceholder('6位验证码').fill('123456');await p.getByRole('button',{name:'注册',exact:true}).click();await p.locator('.el-message-box').waitFor();check(await p.locator('#fixture-captcha-layer').count()===0,'成功提示前销毁验证码元素');check(await p.evaluate(()=>window.__captchaFixture.destroyed===1&&window.__captchaFixture.hidden===1),'使用 SDK 隐藏和销毁接口');await p.locator('.el-message-box').getByRole('button',{name:'确定'}).click();await p.waitForURL(/portal\/login/);check(new URL(p.url()).searchParams.get('returnTo')==='/public/events/901','注册后回登录且保留原任务');
 await p.goto(base+'/portal/register');await p.waitForSelector('#fixture-captcha-layer');await p.getByRole('link',{name:'返回首页',exact:true}).last().click();await p.waitForURL(/portal\/home/);check(await p.locator('#fixture-captcha-layer').count()===0,'离开注册页清理验证码浮层');fixtureAudit.assertClean();check(errors.length===0,'隔离认证回归无脚本异常');console.log('AUTH UI PASS '+passed+' checks; all API requests intercepted locally');
}finally{await context.close();await browser.close()}


