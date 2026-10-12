// Real browser checks against the isolated candidate. Only this round's synthetic documents/awards are edited.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
import {context} from './lib/BusinessRegression.mjs';
const run=process.env.AISPORTS_AWARD_RUN;assert.ok(run);const s=JSON.parse(fs.readFileSync(path.join(run,'state.private.json'),'utf8'));
const out=path.join(run,'ui-'+crypto.randomUUID());fs.mkdirSync(out);
const r={at:new Date().toISOString(),passed:false,scope:'Real organizer and participant browsers; desktop/mobile; synthetic records; no AI/external calls',checks:[],screenshots:[],jarSha256:JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8').replace(/^\uFEFF/,'')).jarSHA256};
const save=()=>fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(r,null,2));const check=(name,ok)=>{r.checks.push({name,passed:!!ok});save();assert.ok(ok,name);console.log('PASS '+name);};
const {chromium}=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json')('playwright');
const session=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8').replace(/^\uFEFF/,''));
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
let activePage;
async function login(phone,password,viewport){const ctx=await browser.newContext({viewport});const page=await ctx.newPage();page.on('dialog',d=>d.dismiss());await page.goto(context.frontend+'/portal/login');await page.getByPlaceholder('请输入手机号').fill(phone);await page.getByPlaceholder('请输入密码').fill(password);await page.getByRole('button',{name:'登录',exact:true}).click();await page.waitForURL(url=>!url.pathname.includes('/login'));return {ctx,page};}
async function screenshot(page,name){const target=path.join(out,name+'.png');await page.screenshot({path:target,fullPage:false});r.screenshots.push(target);save();}
const fixture='# Markdown 排版验证\n\n> 合成草稿，仅用于本地测试。\n\n## 赛事信息\n\n| 项目 | 内容 |\n| --- | --- |\n| 赛事 | 模拟羽毛球赛 |\n| 费用 | 免费 |\n\n### 执行清单\n\n- **报到**：核对名单\n- 裁判确认场次\n\n1. 确认结果\n2. 核实奖项\n\n~~~text\n01,A,win,2:1\n~~~\n\n[不安全链接](javascript:window.__markdownInjected=1)\n<img src="https://invalid.example/fixture.png" onerror="window.__markdownInjected=1">\n<script>window.__markdownInjected=1</script>';
try{
 for(const [device,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}]]){
  const organizer=await login(session.people[0].phone,session.password,viewport);const p=organizer.page;activePage=p;
  await p.goto(context.frontend+'/portal/organization?tab=status');await p.getByRole('button',{name:'进入办赛工作台'}).click();await p.waitForURL(url=>url.pathname.startsWith('/org-desk'));
  await p.goto(context.frontend+'/org-desk/workspace/'+s.event.id+'?task=closure');await p.getByRole('heading',{name:'获奖证明复核'}).waitFor();
  await p.locator('.el-switch').click();await p.locator('.honor-review-cards article').filter({hasText:'单打项目甲（模拟）'}).first().waitFor();
  check(device+' review groups one placing and independent special/project awards',await p.locator('.honor-review-cards article').count()===3);
  const card=p.locator('.honor-review-cards article').filter({hasText:'单打项目甲（模拟）'}).filter({hasText:'最终名次'});
  await card.getByRole('button',{name:'核实奖项并签发'}).click();await p.getByRole('dialog',{name:'核实奖项与证明'}).waitFor();const dialog=p.locator('.honor-review-dialog');
  check(device+' review dialog names project and current basis versions',await dialog.locator('.honor-basis-list article').count()===(s.m4?3:2)&&(await dialog.innerText()).includes('最终名次'));
  await dialog.getByPlaceholder('说明采用哪些正式赛果，以及最终奖项的核实结论。').fill('本轮界面合成核实：采用最新正式赛果，最终名次仍为第二名。');
  await screenshot(p,'honor-review-'+device);
  check(device+' review dialog fits the screen',await dialog.evaluate(el=>el.getBoundingClientRect().width<=innerWidth&&document.documentElement.scrollWidth<=innerWidth+1));
  if(device==='desktop'&&!s.uiDesktopSigned){
   const response=p.waitForResponse(r=>r.url().endsWith('/honor.resolve/execute')&&r.request().method()==='POST');await dialog.getByRole('button',{name:'核对后签发'}).click();await p.locator('.el-message-box').getByRole('button',{name:'确认',exact:true}).click();const result=await(await response).json();if(result.code===200){s.uiDesktopSigned=true;fs.writeFileSync(path.join(run,'state.private.json'),JSON.stringify(s,null,2));}await p.getByRole('dialog',{name:'核实奖项与证明'}).waitFor({state:'hidden'});check('Organizer completes reissue through actual UI',result.code===200&&await p.locator('.honor-review-cards article').count()===3);
  }else await dialog.getByRole('button',{name:'继续核对'}).click();
  await p.goto(context.frontend+'/org-desk/workspace/'+s.event.id+'?task=materials');await p.locator('[data-testid="material-studio"]').waitFor();
  if(device==='desktop'){
   await p.getByTestId('material-template').click();await p.getByTestId('material-preview').waitFor();check('Template opens rendered preview by default',await p.getByTestId('material-preview').locator('h2').count()>0);
   await p.getByRole('button',{name:'编辑正文',exact:true}).click();await p.getByTestId('material-content').fill(fixture);await p.getByRole('button',{name:'阅读预览',exact:true}).click();
   const preview=p.getByTestId('material-preview');await preview.locator('table').waitFor();
   check('Material preview renders headings, table, ordered/unordered lists, quote and code',await preview.locator('h1').count()===1&&await preview.locator('h2').count()===1&&await preview.locator('table tbody tr').count()===2&&await preview.locator('ul li').count()===2&&await preview.locator('ol li').count()===2&&await preview.locator('blockquote').count()===1&&await preview.locator('pre code').count()===1&&await preview.locator('strong').count()===1);
   check('Untrusted Markdown cannot execute HTML, scripts, image requests or unsafe links',await preview.locator('script,img,iframe').count()===0&&await preview.locator('a[href^="javascript:"]').count()===0&&await p.evaluate(()=>window.__markdownInjected===undefined));
   await p.getByRole('button',{name:'编辑正文',exact:true}).click();check('Preview does not alter Markdown source',await p.getByTestId('material-content').inputValue()===fixture);await p.getByRole('button',{name:'阅读预览',exact:true}).click();
   await p.getByTestId('material-save').click();await p.getByText('已保存到本赛事',{exact:true}).waitFor();await p.reload();await p.getByTestId('material-preview').locator('table').waitFor();check('Saved draft reopens with rendered Markdown',await p.getByTestId('material-content').count()===0);
   for(const kind of ['script','announcement','promotion']){
    await p.getByTestId('material-tab-'+kind).click();await p.getByTestId('material-template').click();await p.getByTestId('material-preview').waitFor();
    check(kind+' shares rendered document layout',await p.getByTestId('material-preview').locator('h2').count()>0);
    await p.getByTestId('material-save').click();await p.getByText('已保存到本赛事',{exact:true}).waitFor();
   }await p.getByTestId('material-tab-plan').click();
  }
  const preview=p.getByTestId('material-preview');await preview.locator('table').waitFor();
  const geometry=await preview.evaluate(el=>({body:getComputedStyle(el).fontSize,heading:getComputedStyle(el.querySelector('h1')).fontSize,scroll:document.documentElement.scrollWidth,width:innerWidth}));r[device+'MarkdownGeometry']=geometry;
  check(device+' Markdown has readable text, heading hierarchy and contained table scrolling',parseFloat(geometry.body)>=15&&parseFloat(geometry.heading)>parseFloat(geometry.body)&&geometry.scroll<=geometry.width+1);
  await screenshot(p,'material-markdown-'+device);await organizer.ctx.close();
  const participant=await login(context.people[0].phone,context.password,viewport);activePage=participant.page;await participant.page.goto(context.frontend+'/portal/proofs');await participant.page.getByRole('tab',{name:/当前有效/}).waitFor();
  const cards=participant.page.locator('.proof-card').filter({hasText:s.label});await cards.first().waitFor();check(device+' participant defaults to three effective independent proofs',await cards.count()===3&&await cards.getByText('当前有效',{exact:true}).count()===3);
  await screenshot(participant.page,'proof-current-'+device);await participant.page.getByRole('tab',{name:/历史记录/}).click();const history=participant.page.locator('.proof-card').filter({hasText:s.label});await history.first().waitFor();
  check(device+' history is labelled and cannot export a valid-looking old proof',await history.count()>=3&&await history.getByRole('button',{name:'保存证明图片'}).count()===0);
  check(device+' proof history has no horizontal page overflow',await participant.page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
  await screenshot(participant.page,'proof-history-'+device);await participant.ctx.close();
 }
 r.passed=true;r.finishedAt=new Date().toISOString();save();console.log('Evidence: '+out);
}catch(e){r.failure=e.message;await activePage?.screenshot({path:path.join(out,'failure.png'),fullPage:false}).catch(()=>{});save();throw e;}finally{await browser.close();}

