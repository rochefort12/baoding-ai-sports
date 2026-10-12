// Continue only the untouched pending team invitation from one successful invitation trial.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
import {context,request,createEvidence} from './lib/BusinessRegression.mjs';
const base=path.resolve(process.env.AISPORTS_REGISTRATION_INVITE_BASE||'');
assert.ok(base.startsWith(path.resolve(context.out)+path.sep),'Choose the protected original invitation evidence.');
const originalFile=path.join(base,'receipt.json');const original=JSON.parse(fs.readFileSync(originalFile,'utf8'));assert.ok(original.passed);
const stateFile=path.join(base,'state.private.json');const state=JSON.parse(fs.readFileSync(stateFile,'utf8'));
assert.ok(state.steps.memberRemoved&&!state.steps.teamMemberRemoved,'Only the untouched second invitation can be removed once.');
const trial=createEvidence('registration-invite-refresh');const {directory,evidence,save,check}=trial;
evidence.jarSha256=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8').replace(/^\uFEFF/,'')).jarSHA256;
evidence.previous={path:originalFile,sha256:crypto.createHash('sha256').update(fs.readFileSync(originalFile)).digest('hex')};
const member=state.teamAdded.members.find(row=>!row.selfMember);assert.ok(member?.id);
const call=async(actor,route,method='GET',body)=>{const result=await request(actor,route,method,body);assert.equal(result.code,200,'Protected request rejected');return result.data;};
const login=async(index)=>({token:(await call(null,'/auth/login','POST',{username:context.people[index].phone,password:context.password,grantType:'platform',tenantId:'900001',clientId:context.clientId})).access_token});
const {chromium}=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json')('playwright');
let browser;
const stable=async page=>{await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));await page.waitForFunction(()=>document.getAnimations().every(animation=>animation.effect?.getTiming().iterations===Infinity||animation.playState!=='running'));await page.waitForFunction(()=>!document.querySelector('.el-message'),{},{timeout:10000});};
const screenshot=async(page,name)=>{await stable(page);const file=path.join(directory,name+'.png');await page.screenshot({path:file});evidence.screenshots??=[];evidence.screenshots.push(file);save();};
async function pageFor(index){const browserContext=await browser.newContext({viewport:{width:1440,height:1000}});const page=await browserContext.newPage();await page.goto(context.frontend+'/portal/login');await page.getByPlaceholder('请输入手机号').fill(context.people[index].phone);await page.getByPlaceholder('请输入密码').fill(context.password);await page.getByRole('button',{name:'登录',exact:true}).click();await page.waitForURL(url=>!url.pathname.includes('/login'));return{page,browserContext};}
try{
 const host=await login(0);const recipient=await login(1);const identity=await call(recipient,'/sports/c/identity');
 const current=(await call(host,'/sports/c/registrations')).find(row=>row.id===state.teamEntry.id);assert.ok(current?.members.find(row=>row.id===member.id&&row.status==='pending_confirmation'),'Do not repeat a successful roster removal.');
 browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
 const receiver=await pageFor(1),manager=await pageFor(0);const receiverPage=receiver.page,hostPage=manager.page;
 await receiverPage.goto(context.frontend+'/portal/notices');await receiverPage.getByRole('heading',{name:'我的消息',exact:true}).waitFor();
 const removedNotice=receiverPage.locator('.notice-card').filter({hasText:state.event.name}).filter({hasText:state.teamUnit.name}).filter({hasText:'参赛名单已调整'});
 check('Recipient initially remains on the message page without a removal notice for the untouched booking',await removedNotice.count()===0);
 await hostPage.goto(context.frontend+'/portal/registration/detail/'+state.teamEntry.id);
 const row=hostPage.locator('.participant-item').filter({hasText:identity.self.legalName});await row.waitFor();await row.getByRole('button',{name:'移除',exact:true}).click();
 await hostPage.getByRole('button',{name:'移出并通知本人',exact:true}).waitFor();await stable(hostPage);
 const appearance=await hostPage.locator('.el-message-box').evaluate(element=>{const css=getComputedStyle(element);const message=element.querySelector('.el-message-box__message');const title=element.querySelector('.el-message-box__title');return{opacity:css.opacity,color:css.color,backgroundColor:css.backgroundColor,messageColor:message?getComputedStyle(message).color:'',titleColor:title?getComputedStyle(title).color:'',finiteAnimations:document.getAnimations().filter(a=>a.effect?.getTiming().iterations!==Infinity).map(a=>a.playState)};});
 evidence.confirmationAppearance=appearance;save();check('Settled removal confirmation is opaque after the actual transition completes',appearance.opacity==='1'&&appearance.finiteAnimations.every(status=>status!=='running'));
 await screenshot(hostPage,'registration-remove-settled-confirmation');
 const started=Date.now();const removed=hostPage.waitForResponse(response=>response.url().endsWith('/members/'+member.id)&&response.request().method()==='DELETE');
 await hostPage.getByRole('button',{name:'移出并通知本人',exact:true}).click();assert.equal((await(await removed).json()).code,200,'Untouched team member removal rejected');state.steps.teamMemberRemoved=true;fs.writeFileSync(stateFile,JSON.stringify(state,null,2));
 // No route change or reload: the already visible recipient message page must refresh itself.
 await removedNotice.waitFor({state:'visible',timeout:31000});const elapsed=Date.now()-started;
 check('A recipient staying on the same message page sees the new removal notice within one refresh interval',elapsed<=31000&&receiverPage.url().endsWith('/portal/notices'));
 evidence.refreshElapsedMs=elapsed;save();await screenshot(receiverPage,'registration-removal-live-refresh');
 await removedNotice.getByRole('button',{name:'查看我的报名',exact:true}).click();await receiverPage.waitForURL(url=>url.pathname==='/portal/registration');
 check('The refreshed removal notice opens an authorized own-list destination',receiverPage.url().endsWith('/portal/registration'));
 const notices=await call(recipient,'/sports/c/notices');check('The persisted notice is independent of whether that original invitation was accepted',notices.filter(notice=>notice.businessType==='registration-roster-removed'&&notice.businessId===member.id).length===1);
 evidence.objects={eventId:state.event.id,registrationId:state.teamEntry.id,removedMemberId:member.id};trial.finish();
}catch(error){evidence.failure=String(error.message).replace(/\/portal\/registration\/invite\/[a-zA-Z0-9-]+/g,'/portal/registration/invite/[private]').replaceAll(context.password,'[private]');save();throw new Error('Invitation refresh continuation failed; retained evidence identifies the incomplete step.');}finally{await browser?.close();}
