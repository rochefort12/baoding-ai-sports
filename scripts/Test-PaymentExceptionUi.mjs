// Actual ordinary organizer UI only. Opening, editing and cancelling the review form
// must not send a business write; completion itself is tested by the isolated HTTP script.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=require('playwright');
const contextPath=process.argv[process.argv.indexOf('--context')+1];
assert.ok(process.argv.includes('--context'));
const root=fs.realpathSync(path.resolve('.local/business-regression-20261011'));
assert.ok(fs.realpathSync(contextPath).startsWith(root+path.sep));
const c=JSON.parse(fs.readFileSync(contextPath,'utf8').replace(/^\uFEFF/,''));
assert.equal(c.frontend,'http://127.0.0.1:5192');assert.equal(c.backend,'http://127.0.0.1:8082');
const round2=process.argv.includes('--round2'),resolved=process.argv.includes('--resolved'),historical=process.argv.includes('--history');
const state=JSON.parse(fs.readFileSync(path.join(c.out,historical?'historical-funds.private.json':round2?'funds-competition-fixed-state.json':'funds-competition-state.json'),'utf8'));
if(historical) { state.partialEntry=state.registrationId; state.partialEntryObligation=state.v1; }
assert.equal(state.runId,c.runId);
const out=path.join(c.out,'payment-exception-ui-'+crypto.randomUUID());fs.mkdirSync(out);
const report={at:new Date().toISOString(),runId:c.runId,scope:'Actual isolated ordinary organizer desktop/mobile UI, no response stubs, model calls, login or business writes.',mode:resolved?'resolved-history':'open-review-form',historical,round2,checks:[],writes:[],errors:[],screenshots:[],passed:false};
if(process.env.AISPORTS_REGRESSION_JAR_PATH){
  const jar=process.env.AISPORTS_REGRESSION_JAR_PATH;
  assert.ok(fs.realpathSync(jar).startsWith(fs.realpathSync(process.cwd())+path.sep));
  report.jarSha256=crypto.createHash('sha256').update(fs.readFileSync(jar)).digest('hex');assert.equal(report.jarSha256,process.env.AISPORTS_REGRESSION_JAR_SHA256);
  report.runtimePid=Number(process.env.AISPORTS_REGRESSION_RUNTIME_PID);
}
const sources=['scripts/Test-PaymentExceptionUi.mjs','plus-ui/src/components/business/PaymentExceptionPanel.vue','plus-ui/src/views/sports/registration/review.vue'];
report.sourceFiles=Object.fromEntries(sources.map(file=>[file,crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')]));
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
let currentPage;
const check=(name,condition,details={})=>{report.checks.push({name,passed:Boolean(condition),...details});assert.ok(condition,name);console.log('PASS '+name);};
const fit=page=>page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1);
async function shot(page,file){await page.screenshot({path:path.join(out,file),fullPage:true});report.screenshots.push(file);}
try{
  for(const [device,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}]]){
    const session=await browser.newContext({viewport,reducedMotion:'reduce'});
    await session.addInitScript(({token})=>localStorage.setItem('Admin-Token',token),{token:c.organizer.token});
    session.on('request',request=>{if(!['GET','HEAD'].includes(request.method()))report.writes.push({method:request.method(),path:new URL(request.url()).pathname});});
    const page=await session.newPage();currentPage=page;page.on('pageerror',error=>report.errors.push({name:error.name}));
    await page.goto(c.frontend+`/org-desk/workspace/${state.eventId}?task=registrations`);
    await page.getByRole('button',{name:/^全部 ·/}).waitFor();await page.getByRole('button',{name:/^全部 ·/}).click();
    await page.getByPlaceholder('搜索姓名或报名编号').fill(state.partialEntry);
    const view=page.getByRole('button',{name:'查看办理',exact:true});await view.waitFor();check(device+' real selection narrows to the requested registration',await view.count()===1);
    await view.click();const drawer=page.getByRole('dialog',{name:'报名详情与办理',exact:true});await drawer.waitFor();
    const history=drawer.getByTestId('fund-history');await history.waitFor();
    const optionsResponse=await fetch(c.backend+`/sports/b/fees/registrations/${state.partialEntry}/history`,{headers:{clientid:c.clientId,Authorization:'Bearer '+c.organizer.token}});
    const actual=(await optionsResponse.json()).data;assert.ok(Array.isArray(actual));
    const original=actual.find(duty=>duty.obligationId===state.partialEntryObligation);assert.ok(original);
    const selector=history.getByRole('combobox',{name:'付款记录版本',exact:true});
    await selector.waitFor();
    // Element's readonly search input is covered by its selected-label hit area.
    // A pointer user clicks the real visible wrapper; do not force-click the input.
    await history.locator('.el-select__wrapper').click();
    const optionLabel=original.rosterRevision==null?'原付款 ·':'提交版本 '+original.rosterRevision;
    const option=page.getByRole('option').filter({hasText:optionLabel});
    // Legacy duties may share their minute label. Select by actual displayed history order, never invent a revision.
    await option.nth(actual.filter(duty=>duty.rosterRevision==null?optionLabel==='原付款 ·':('提交版本 '+duty.rosterRevision)===optionLabel).findIndex(duty=>duty.obligationId===original.obligationId)).click();
    check(device+' actual original duty remains selectable after withdrawal or resubmission',await history.getByText('正在查看原付款义务',{exact:false}).count()===(original.current?0:1));
    if(historical){
      check(device+' both actual numbered submission versions remain in history',actual.length===2&&actual.some(d=>d.rosterRevision===1)&&actual.some(d=>d.rosterRevision===2));
      check(device+' closed original duty does not ask for a new payment',await history.getByText('该付款义务已关闭，无需再次付款',{exact:false}).count()===1);
      check(device+' original duty cannot accidentally receive the new submission payment',await drawer.getByRole('button',{name:'登记实际到账',exact:true}).count()===0&&await drawer.getByRole('button',{name:'补记其他实际收款',exact:true}).count()===0);
      check(device+' exception pending marker follows the actual selected original duty',await history.getByText('此版本仍有资金待办',{exact:false}).count()===(resolved?0:1));
    }
    const panel=drawer.locator('.fund-exceptions');await panel.waitFor();
    check(device+' original drawer shows the actual persisted duplicate exception',await panel.getByText('重复请求与原收款不一致',{exact:true}).count()===1);
    check(device+' explanation keeps fund and qualification responsibility separate',await panel.getByText('核对异常不改变原收款、退款或报名资格。',{exact:true}).count()===1);
    check(device+' registration drawer has no horizontal viewport overflow',await fit(page));
    if(resolved){
      await panel.getByText('已核对结案',{exact:true}).waitFor();
      check(device+' resolved history preserves the original human explanation',await panel.getByText(historical?'合成历史核对：原付款100元':'合成核对：复查本轮原收款与分配记录',{exact:false}).count()===1);
      check(device+' resolved history offers no second closing action',await panel.getByRole('button',{name:'核对后结案',exact:true}).count()===0);
      await panel.scrollIntoViewIfNeeded();
      await shot(page,device+'-resolved-history.png');
    }else{
      await panel.getByRole('button',{name:'核对后结案',exact:true}).click();
      const dialog=page.getByRole('dialog',{name:'核对重复收款请求',exact:true});await dialog.waitFor();
      const submit=dialog.getByRole('button',{name:'确认核对并结案',exact:true});
      check(device+' empty explanation cannot submit',await submit.isDisabled());
      const explanation=dialog.getByRole('textbox',{name:'实际核对依据与处理说明',exact:true});await explanation.fill('只读交互验收草稿，不提交、不改变本轮异常。');
      check(device+' complete explanation enables a concrete confirmation',await submit.isEnabled());
      const geometry=await dialog.boundingBox();check(device+' review dialog fits the actual viewport',Boolean(geometry)&&geometry.x>=-1&&geometry.x+geometry.width<=viewport.width+1);
      await shot(page,device+'-review-draft.png');
      await dialog.getByRole('button',{name:'继续核对',exact:true}).click();await dialog.waitFor({state:'hidden'});
      check(device+' cancelling returns to the unchanged original exception',await panel.getByText('待人工核对',{exact:true}).count()===1);
      await panel.getByRole('button',{name:'核对后结案',exact:true}).click();await dialog.waitFor();
      check(device+' a new review clears the discarded explanation',await explanation.inputValue()==='');
      await page.keyboard.press('Escape');await dialog.waitFor({state:'hidden'});
      check(device+' Escape safely closes a review without a business submission',await panel.getByText('待人工核对',{exact:true}).count()===1);
    }
    await session.close();
  }
  check('all actual browser requests were read only',report.writes.length===0,{count:report.writes.length});
  check('no page script error occurred',report.errors.length===0,{count:report.errors.length});
  check('source remained stable during the actual UI check',sources.every(file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')===report.sourceFiles[file]));
  report.passed=true;
}catch(error){report.failure={name:error.name,message:String(error.message).slice(0,800)};process.exitCode=1;if(currentPage&&!currentPage.isClosed())try{await shot(currentPage,'failed.png');}catch{}}
finally{await browser.close();report.finishedAt=new Date().toISOString();fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,mode:report.mode,receipt:path.relative(process.cwd(),path.join(out,'receipt.json')).replaceAll('\\','/')}));}
