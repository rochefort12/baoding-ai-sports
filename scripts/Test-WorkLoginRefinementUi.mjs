// Real local pages only. Apart from work login itself in a separate acceptance
// script, this suite is read-only: no SMS, OAuth, business writes or fake replies.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=require('playwright');
const main=process.argv.includes('--main-only');
const ports=main?[5190]:[5192];
const widths=main?[390,1024,1912]:[390,768,1024,1912];
const out=path.resolve('.local/login-refinement-20261011','ui-'+crypto.randomUUID());fs.mkdirSync(out,{recursive:true});
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const sources=['plus-ui/src/views/login.vue','plus-ui/src/components/consumer/WeChatLoginButton.vue','plus-ui/src/api/wechatLogin.ts','plus-ui/src/assets/styles/design-system.scss','plus-ui/src/components/consumer/ConsumerAuthLayout.vue','plus-ui/public/images/sports/wechat-login.svg'];
const report={at:new Date().toISOString(),passed:false,scope:'Actual anonymous local work/phone/register/reset layouts and work-WeChat unavailability. No credential submission, OAuth, SMS or business writes. Viewports are not physical-device acceptance.',checks:[],screenshots:[],sources:sources.map(file=>({path:file,sha256:hash(file)})),blockedWrites:[],pageErrors:[]};
function check(name,condition){report.checks.push({name,passed:Boolean(condition)});assert.ok(condition,name);}
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});let current;
async function shot(page,name){const file=path.join(out,name+'.png');await page.screenshot({path:file,fullPage:true});report.screenshots.push({path:path.relative(process.cwd(),file).replaceAll('\\','/'),sha256:hash(file)});}
async function alignment(page,label){
 const metric=await page.locator('.sport-auth-layout').evaluate(el=>{
  const box=el.getBoundingClientRect(),left=el.querySelector('.sport-auth-visual').getBoundingClientRect(),right=el.querySelector('.sport-auth-form').getBoundingClientRect(),image=el.querySelector('.sport-auth-image'),photo=image?.getBoundingClientRect();
  return {box:{top:box.top,bottom:box.bottom,left:box.left,right:box.right},left:{top:left.top,bottom:left.bottom,right:left.right},right:{top:right.top,bottom:right.bottom,left:right.left},columns:getComputedStyle(el).display==='grid',imageReady:Boolean(image?.complete&&image?.naturalWidth),photo:photo?{top:photo.top,bottom:photo.bottom}:null};
 });
 check(label+' static photograph loaded',metric.imageReady);
 check(label+' photograph fills its entire panel',Math.abs(metric.photo.top-metric.left.top)<=1&&Math.abs(metric.photo.bottom-metric.left.bottom)<=1);
 if(metric.columns){
  check(label+' both panel tops and bottoms match',Math.abs(metric.left.top-metric.right.top)<=1&&Math.abs(metric.left.bottom-metric.right.bottom)<=1);
  check(label+' no blank strip below photograph',Math.abs(metric.left.bottom-(metric.box.bottom-1))<=1.5);
  check(label+' no horizontal gap at panel seam',Math.abs(metric.left.right-metric.right.left)<=1);
 }else check(label+' mobile photograph joins the form without a gap',Math.abs(metric.left.bottom-metric.right.top)<=1);
 check(label+' no horizontal page overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
}
try{
 for(const port of ports)for(const width of widths){
  const context=await browser.newContext({viewport:{width,height:width<800?844:1000},reducedMotion:'reduce'});const page=await context.newPage();current=page;
  const reads=[];page.on('request',request=>{if(request.method()==='GET')reads.push(new URL(request.url()).pathname);});
  page.on('pageerror',()=>report.pageErrors.push('Login-page script error'));
  await context.route('**/*',route=>{if(!['GET','HEAD'].includes(route.request().method())){report.blockedWrites.push({path:new URL(route.request().url()).pathname,method:route.request().method()});return route.abort('blockedbyclient');}return route.continue();});
  for(const [name,url]of [['work','/login'],['phone','/portal/login?returnTo=/portal/rooms'],['register','/portal/register?returnTo=/portal/rooms'],['reset','/portal/forgot?returnTo=/portal/rooms']]){
   const label=port+'/'+width+'/'+name;await page.goto('http://127.0.0.1:'+port+url,{waitUntil:'domcontentloaded'});await page.locator('.sport-auth-form form').waitFor();
   await page.locator('.sport-auth-image').evaluate(image=>image.complete?Promise.resolve():new Promise(resolve=>{image.addEventListener('load',resolve,{once:true});image.addEventListener('error',resolve,{once:true});}));
   await alignment(page,label);check(label+' no Vite error',await page.locator('vite-error-overlay').count()===0);
   if(name==='work'){
    await shot(page,port+'-'+width+'-'+name);
    const account=page.getByPlaceholder('请输入工作账号',{exact:true}),password=page.getByPlaceholder('请输入密码',{exact:true}),wechat=page.getByRole('button',{name:'使用微信登录',exact:true});
    check(label+' organization selector removed',await page.getByLabel('所属组织').count()===0&&!(await page.locator('body').innerText()).includes('所属组织'));
    check(label+' no tenant-directory request',!reads.includes('/dev-api/auth/tenant/list'));
    check(label+' only visible WeChat alternative remains',await wechat.isVisible()&&await page.locator('details,.lang-select').count()===0&&!/MaxKey|TopIAM|Gitee|GitHub/.test(await page.locator('body').innerText()));
    check(label+' local WeChat icon is visible and cannot drag',await page.locator('.wechat-login-icon img').evaluate(image=>image.complete&&image.naturalWidth>0&&!image.draggable&&getComputedStyle(image).webkitUserDrag==='none'));
    await page.getByRole('button',{name:'登录工作台',exact:true}).click();await page.locator('.sport-work-login .el-form-item.is-error').first().waitFor();
    await alignment(page,label+'/validation');check(label+' empty submit validates without request',report.blockedWrites.length===0);
    await account.fill('ui-layout-check');await password.fill('not-a-real-credential');await wechat.click();await page.getByRole('status').filter({hasText:'微信登录暂不可用，请使用工作账号登录。'}).waitFor();
    check(label+' genuine unavailable channel preserves typed values',await account.inputValue()==='ui-layout-check'&&await password.inputValue()==='not-a-real-credential');
    check(label+' WeChat read occurred without OAuth or QR',reads.includes('/dev-api/auth/work-methods')&&await page.locator('.wechat-login canvas,.wechat-login iframe,.wechat-login img[src*="qrcode"]').count()===0&&new URL(page.url()).pathname==='/login');
    await alignment(page,label+'/feedback');await account.fill('');await password.fill('');await page.locator('h1').click();
   }else check(label+' existing task return link retained',await page.locator('.auth-back').getAttribute('href')==='/portal/rooms');
   if(name==='work'||(name==='register'&&width===1024))await shot(page,port+'-'+width+'-'+name+(name==='work'?'-feedback':''));
  }
  await context.close();current=null;
 }
 check('no attempted mutation or page script error',report.blockedWrites.length===0&&report.pageErrors.length===0);
 check('product sources stayed unchanged',report.sources.every(source=>hash(source.path)===source.sha256));report.passed=true;
}catch(error){report.failure=error.name==='AssertionError'?error.message:'Actual login layout check failed; private diagnostics omitted';if(current)await shot(current,'failure').catch(()=>{});process.exitCode=1;}
finally{await browser.close();report.finishedAt=new Date().toISOString();const file=path.join(out,'receipt.json'),fd=fs.openSync(file,'wx');try{fs.writeFileSync(fd,JSON.stringify(report,null,2));fs.fsyncSync(fd);}finally{fs.closeSync(fd);}console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,failure:report.failure,path:path.relative(process.cwd(),file).replaceAll('\\','/')}));}
