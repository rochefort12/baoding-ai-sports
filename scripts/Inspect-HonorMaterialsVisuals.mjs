// Read-only visual acceptance of existing synthetic records, after all finite UI transitions finish.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
import {context} from './lib/BusinessRegression.mjs';
const run=process.env.AISPORTS_AWARD_RUN;const s=JSON.parse(fs.readFileSync(path.join(run,'state.private.json'),'utf8'));
const out=path.join(run,'visual-'+crypto.randomUUID());fs.mkdirSync(out);
const receipt={at:new Date().toISOString(),passed:false,scope:'Read-only stable desktop/mobile visual inspection of existing synthetic honors and documents',checks:[],screenshots:[],jarSha256:JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8').replace(/^\uFEFF/,'')).jarSHA256};
const save=()=>fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(receipt,null,2));
const check=(name,ok)=>{receipt.checks.push({name,passed:!!ok});save();assert.ok(ok,name);console.log('PASS '+name);};
const {chromium}=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json')('playwright');
const session=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8').replace(/^\uFEFF/,''));
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
async function login(phone,password,viewport){const ctx=await browser.newContext({viewport});const page=await ctx.newPage();await page.goto(context.frontend+'/portal/login');await page.getByPlaceholder('请输入手机号').fill(phone);await page.getByPlaceholder('请输入密码').fill(password);await page.getByRole('button',{name:'登录',exact:true}).click();await page.waitForURL(url=>!url.pathname.includes('/login'));return {ctx,page};}
async function stable(page){await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));await page.waitForFunction(()=>document.getAnimations().every(animation=>animation.effect?.getTiming().iterations===Infinity||animation.playState!=='running'));await page.locator('.el-message').waitFor({state:'hidden'});}
async function capture(page,name){await stable(page);const target=path.join(out,name+'.png');await page.screenshot({path:target});receipt.screenshots.push(target);save();}
let active;
try{
 for(const [device,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}]]){
  const org=await login(session.people[0].phone,session.password,viewport);active=org.page;
  await active.goto(context.frontend+'/portal/organization?tab=status');await active.getByRole('button',{name:'进入办赛工作台'}).click();await active.waitForURL(url=>url.pathname.startsWith('/org-desk'));
  await active.goto(context.frontend+'/org-desk/workspace/'+s.event.id+'?task=closure');await active.getByRole('heading',{name:'获奖证明复核'}).waitFor();await active.locator('.el-switch').click();
  const card=active.locator('.honor-review-cards article').filter({hasText:'单打项目甲（模拟）'}).filter({hasText:'最终名次'});await card.getByRole('button',{name:'核实奖项并签发'}).click();
  const dialog=active.getByRole('dialog',{name:'核实奖项与证明'});await dialog.waitFor();await stable(active);
  const geometry=await dialog.evaluate(el=>{const r=el.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height,viewportWidth:innerWidth,viewportHeight:innerHeight,text:el.innerText};});
  receipt[device+'DialogGeometry']={...geometry,text:undefined};
  check(device+' stable review dialog remains inside viewport with all basis rows and footer',geometry.x>=0&&geometry.y>=0&&geometry.x+geometry.width<=viewport.width+1&&geometry.y+geometry.height<=viewport.height+1&&geometry.text.includes('核对后签发')&&await dialog.locator('.honor-basis-list article').count()===3);
  await capture(active,'honor-review-'+device);await dialog.getByRole('button',{name:'继续核对'}).click();
  await active.goto(context.frontend+'/org-desk/workspace/'+s.event.id+'?task=materials');await active.getByTestId('material-preview').locator('table').waitFor();await stable(active);
  check(device+' default material preview has table and safe Markdown hierarchy',await active.getByTestId('material-preview').locator('h1').count()===1&&await active.getByTestId('material-preview').locator('table tbody tr').count()===2&&await active.getByTestId('material-content').count()===0);
  const typography=await active.getByTestId('material-preview').evaluate(el=>({body:getComputedStyle(el).fontFamily,table:getComputedStyle(el.querySelector('td')).fontFamily,heading:getComputedStyle(el.querySelector('h1')).fontFamily,bodySize:parseFloat(getComputedStyle(el).fontSize),headingSize:parseFloat(getComputedStyle(el.querySelector('h1')).fontSize)}));receipt[device+'Typography']=typography;check(device+' material uses one font and a readable heading hierarchy',typography.body===typography.table&&typography.body===typography.heading&&typography.headingSize>=typography.bodySize+6);
  await active.getByTestId('material-preview').scrollIntoViewIfNeeded();await capture(active,'material-markdown-'+device);await org.ctx.close();
  const person=await login(context.people[0].phone,context.password,viewport);active=person.page;await active.goto(context.frontend+'/portal/proofs');await active.locator('.proof-card').filter({hasText:s.label}).first().waitFor();await stable(active);
  check(device+' current proofs show exactly three independent effective awards',await active.locator('.proof-card').filter({hasText:s.label}).count()===3);await capture(active,'proof-current-'+device);
  await active.getByRole('tab',{name:/历史记录/}).click();await active.locator('.proof-card').filter({hasText:s.label}).first().waitFor();await stable(active);
  check(device+' old proofs remain history with no export button',await active.locator('.proof-card').filter({hasText:s.label}).getByRole('button',{name:'保存证明图片'}).count()===0);await capture(active,'proof-history-'+device);await person.ctx.close();
 }
 receipt.passed=true;receipt.finishedAt=new Date().toISOString();save();console.log('Evidence: '+out);
}catch(cause){receipt.failure=cause.message;save();await active?.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});throw cause;}finally{await browser.close();}
