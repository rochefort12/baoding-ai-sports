// Actual profile entry/crop-cancel and unsaved certification editor verification; no uploads or business writes.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=require('playwright');
const state=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8'));
const runtime=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8'));
const room=JSON.parse(fs.readFileSync('.local/product-release-20261011/room-ui-progress.json','utf8'));
assert.equal(runtime.port,8082);assert.match(runtime.database,/^aisports_verify_phase1_[a-f0-9]{32}$/);assert.equal(runtime.database,state.database);
const base='http://127.0.0.1:5192',out=path.resolve('.local/product-release-20261011/profile-entry-'+Date.now());
fs.mkdirSync(out,{recursive:true});
const report={timestamp:new Date().toISOString(),scope:'Actual isolated ordinary profile alias, centralized crop entry and cancel preservation, and unsaved certification editor on desktop/mobile. No upload, certification save/submit, model or business mutation.',checks:[],failures:[],pageErrors:[],writes:[],passed:false};
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
let current;
function check(name,value){assert.ok(value,name);report.checks.push(name);}
async function api(page,route,actor){const res=await page.request.get(base+'/dev-api'+route,{headers:{Authorization:'Bearer '+actor.token,clientid:actor.clientId}});const body=await res.json();assert.equal(body.code,200,'Actual participant API rejected');return body.data;}
async function open(actor,width){const context=await browser.newContext({viewport:{width,height:width<600?844:1000},reducedMotion:'reduce'});if(actor)await context.addInitScript(token=>{localStorage.setItem('Admin-Token',token);localStorage.setItem('Platform-Token',token);},actor.token);const page=await context.newPage();page.on('pageerror',()=>report.pageErrors.push('Page script error'));page.on('request',req=>{const pathname=new URL(req.url()).pathname;if(pathname.startsWith('/dev-api/')&&req.method()!=='GET')report.writes.push({path:pathname,method:req.method()});});current={page,context};return current;}
try{
 for(const [device,width] of [['desktop',1440],['mobile',390]]){
  const {page,context}=await open(state.people[0],width),before=await api(page,'/sports/display',state.people[0]);
  await page.goto(base+'/portal/profile');await page.getByRole('heading',{name:'完善资料',exact:true}).waitFor();
  check(device+'实际资料别名保持原任务地址',new URL(page.url()).pathname==='/portal/profile');
  check(device+'头像上传只放完善资料区域',await page.locator('.profile-avatar-field .sports-avatar-editor').count()===1&&await page.locator('.profile-menu .sports-avatar-editor').count()===0);
  check(device+'资料头像按钮可使用',await page.locator('.profile-avatar-field .avatar-edit-trigger').isEnabled());
  const field=await page.locator('.profile-avatar-field').boundingBox();check(device+'头像编辑区域不撑破页面',field.width<=width&&await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
  await page.locator('.profile-avatar-field input[type="file"]').setInputFiles(path.resolve('plus-ui/public/images/sports/badminton-hero-v1.webp'));
  const dialog=page.getByRole('dialog',{name:'调整运动头像',exact:true});await dialog.waitFor();
  check(device+'真实若依裁剪组件打开',await dialog.locator('.vue-cropper').isVisible());
  await dialog.getByRole('button',{name:'放大头像',exact:true}).click();await dialog.getByRole('button',{name:'缩小头像',exact:true}).click();
  await dialog.getByRole('button',{name:'向左旋转',exact:true}).click();await dialog.getByRole('button',{name:'向右旋转',exact:true}).click();
  await page.screenshot({path:path.join(out,device+'-profile-crop.png'),fullPage:false});
  await dialog.getByRole('button',{name:'取消',exact:true}).click();await dialog.waitFor({state:'hidden'});
  const after=await api(page,'/sports/display',state.people[0]);check(device+'裁剪取消没有上传或改变原头像版本',JSON.stringify(after)===JSON.stringify(before));
  const honorsBefore=await api(page,'/sports/honors/certifications',state.people[0]);
  const approved=await api(page,'/sports/honors/certifications/approved',state.people[0]);
  const selectedSport=await page.locator('.profile-menu .sports-profile-card').getAttribute('data-sport-id');
  const expectedBadgeIds=approved.filter(honor=>honor.worn&&honor.sportId===selectedSport).map(honor=>honor.honorId);
  check(device+'个人名片只展示已认证且本人佩戴的当前运动荣誉，空列表无假奖牌',JSON.stringify(await page.locator('.profile-person .certified-honor-badge').evaluateAll(nodes=>nodes.map(node=>node.getAttribute('data-honor-id'))))===JSON.stringify(expectedBadgeIds));
  const certification=page.locator('[data-testid="honor-certification"]');await certification.waitFor();await page.waitForFunction(()=>document.querySelector('[data-testid="honor-certification"]')?.getAttribute('aria-busy')==='false');
  check(device+'荣誉认证独立读取真实记录，没有冒充成长授予',await certification.isVisible()&&await certification.locator('.honor-cert-error').count()===0&&await certification.locator('.honor-cert-record').count()===honorsBefore.length);
  await certification.getByRole('button',{name:'申请认证',exact:true}).click();const editor=certification.locator('[data-testid="honor-certification-editor"]');await editor.waitFor();
  await editor.locator('[data-testid="honor-event"]').fill('未保存的界面检查');await certification.getByRole('button',{name:'收起',exact:true}).click();
  let confirmation=page.getByRole('dialog',{name:'保留修改',exact:true});await confirmation.waitFor();await confirmation.getByRole('button',{name:'继续编辑',exact:true}).click();
  check(device+'认证未保存内容可以继续编辑，上传按钮仍受草稿前置约束',await editor.locator('[data-testid="honor-event"]').inputValue()==='未保存的界面检查'&&await editor.getByRole('button',{name:'上传证明',exact:true}).isDisabled());
  await certification.getByRole('button',{name:'收起',exact:true}).click();confirmation=page.getByRole('dialog',{name:'保留修改',exact:true});await confirmation.waitFor();await confirmation.getByRole('button',{name:'放弃修改',exact:true}).click();await editor.waitFor({state:'hidden'});
  check(device+'认证草稿放弃后收起界面，没有伪造申请或授予',JSON.stringify(await api(page,'/sports/honors/certifications',state.people[0]))===JSON.stringify(honorsBefore));
  check(device+'荣誉认证表单不撑破页面',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
  await page.evaluate(()=>window.scrollTo(0,0));await page.screenshot({path:path.join(out,device+'-profile.png'),fullPage:true});
  await page.goto(base+'/portal/identity');await page.getByRole('heading',{name:'完善资料',exact:true}).waitFor();check(device+'旧identity入口继续可用',await page.locator('.profile-avatar-field .sports-avatar-editor').count()===1);
  await page.goto(base+'/portal/growth');await page.getByRole('heading',{name:'成长与荣誉',exact:true}).waitFor();
  check(device+'成长页面保留资料入口不重复上传',await page.locator('.sports-avatar-editor').count()===0&&await page.locator('.profile-avatar-link').getAttribute('href')==='/portal/profile');
  await context.close();current=undefined;
 }
 // Recover this actor through its real form instead of treating an old token as
 // proof of a live session. The original room and its prepared members remain.
 const {page,context}=await open(undefined,390);await page.goto(base+'/portal/login?returnTo='+encodeURIComponent('/portal/rooms/'+room.roomId));
 await page.getByPlaceholder('请输入手机号',{exact:true}).fill(state.people[2].phone);await page.getByPlaceholder('请输入密码',{exact:true}).fill(state.password);
 await page.getByRole('button',{name:'登录',exact:true}).click();await page.getByRole('heading',{name:'参赛房间',exact:true}).waitFor();await page.locator('.room-profile-link').waitFor();
 check('房间保留资料入口不重复头像上传',await page.locator('.sports-avatar-editor').count()===0);
 await page.locator('.room-profile-link').click();await page.getByRole('heading',{name:'完善资料',exact:true}).waitFor();
 check('房间资料入口保留回原房间任务',new URL(page.url()).searchParams.get('returnTo')==='/portal/rooms/'+room.roomId);
 await context.close();current=undefined;
 check('补验除恢复登录外没有上传或业务写请求',report.writes.every(write=>write.path==='/dev-api/auth/login'));check('补验没有页面脚本错误',report.pageErrors.length===0);report.passed=true;
}catch(error){report.failures.push({type:error.name,message:error.name==='AssertionError'?error.message:'Verification did not complete; private diagnostics omitted'});process.exitCode=1;if(current)await current.page.screenshot({path:path.join(out,'failure.png'),fullPage:true}).catch(()=>{});}
finally{await browser.close();const file=path.join(out,'receipt.json'),fd=fs.openSync(file,'wx');try{fs.writeFileSync(fd,JSON.stringify(report,null,2)+'\n');fs.fsyncSync(fd);}finally{fs.closeSync(fd);}console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,failures:report.failures,report:path.relative(process.cwd(),file).replaceAll('\\','/')}));}
