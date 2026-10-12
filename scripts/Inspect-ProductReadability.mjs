// Read-only UI inspection of existing synthetic fixtures. No signup, invitation,
// roster, event, result or financial business actions are performed.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {context,createEvidence} from './lib/BusinessRegression.mjs';

const trial=createEvidence('product-readability');
const {directory,evidence,check,save}=trial;
const state=JSON.parse(fs.readFileSync(path.join(context.out,'registration-invite-experience-1791795523563-8574c9d1/state.private.json'),'utf8'));
const owner=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8').replace(/^\uFEFF/,''));
evidence.scope='Actual ordinary-role read-only desktop workbench, registration and mobile notices. Existing isolated synthetic fixtures only; authentication is the only submitted form.';
evidence.sourceHashes=Object.fromEntries(['plus-ui/src/assets/styles/readability.scss','plus-ui/src/layout/consumer/ConsumerShell.vue','plus-ui/src/layout/business/BusinessFrame.vue'].map(file=>[file,crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')]));
save();
const {chromium}=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json')('playwright');
let browser,activePage;
async function stable(page){
  await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
  await page.waitForFunction(()=>document.getAnimations().every(animation=>animation.effect?.getTiming().iterations===Infinity||animation.playState!=='running'),{},{timeout:18000});
  await page.waitForFunction(()=>!document.querySelector('.el-message'),{},{timeout:12000});
}
async function login(phone,password,viewport){
  const browserContext=await browser.newContext({viewport});
  const page=await browserContext.newPage();activePage=page;
  await page.goto(context.frontend+'/portal/login');
  await page.getByPlaceholder('请输入手机号').fill(phone);
  await page.getByPlaceholder('请输入密码').fill(password);
  await page.getByRole('button',{name:'登录',exact:true}).click();
  await page.waitForURL(url=>!url.pathname.includes('/login'));
  return {page,browserContext};
}
async function inspect(page,name,selectors){
  await stable(page);
  const snapshot=await page.evaluate(selectors=>{
    const visible=element=>element.getBoundingClientRect().width>0&&element.getBoundingClientRect().height>0&&getComputedStyle(element).visibility!=='hidden';
    const fonts=Object.fromEntries(selectors.map(selector=>{const element=[...document.querySelectorAll(selector)].find(visible);const css=element?getComputedStyle(element):null;return[selector,css?{size:parseFloat(css.fontSize),color:css.color,lineHeight:css.lineHeight}:null];}));
    const luminance=color=>{const channels=(color.match(/[\d.]+/g)||[]).slice(0,3).map(Number).map(value=>value/255).map(value=>value<=.04045?value/12.92:((value+.055)/1.055)**2.4);return channels[0]*.2126+channels[1]*.7152+channels[2]*.0722;};
    const primaryContrast=[...document.querySelectorAll('.b-ai-button,.organizer-primary,.studio-primary,.el-button--primary:not(.is-link):not(.is-text):not(.is-plain)')].filter(element=>visible(element)&&!element.disabled).map(element=>{const css=getComputedStyle(element);const ink=luminance(css.color),paper=luminance(css.backgroundColor);return{class:element.className,color:css.color,background:css.backgroundColor,ratio:(Math.max(ink,paper)+.05)/(Math.min(ink,paper)+.05)};});
    const tiny=[];const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);let node;
    while((node=walker.nextNode())){const element=node.parentElement;if(!node.textContent.trim()||!element||!visible(element)||element.closest('svg,script,style,pre,code,.el-popper'))continue;const rect=element.getBoundingClientRect();if(rect.bottom<0||rect.top>innerHeight)continue;const size=parseFloat(getComputedStyle(element).fontSize);if(size<13)tiny.push({tag:element.tagName,class:element.className,parentClass:element.parentElement?.className,size});}
    return{fonts,primaryContrast,tinyText:tiny,scrollWidth:document.documentElement.scrollWidth,viewport:innerWidth,title:document.title,brand:document.querySelector('.consumer-brand strong,.b-brand>div')?.textContent?.trim(),sidebarAssistant:Boolean(document.querySelector('.b-sidebar-ai'))};
  },selectors);
  const file=path.join(directory,name+'.png');await page.screenshot({path:file});
  evidence.screenshots??=[];evidence.screenshots.push(file);
  evidence.pages??={};evidence.pages[name]=snapshot;save();
  check(name+' has no horizontal viewport overflow',snapshot.scrollWidth<=snapshot.viewport);
  check(name+' uses AI体育 in the shell',snapshot.brand?.startsWith('AI体育'));
  check(name+' keeps visible text at least 13px',snapshot.tinyText.length===0,{tinyText:snapshot.tinyText});
  if(snapshot.primaryContrast.length)check(name+' enabled primary actions meet 4.5:1 text contrast',snapshot.primaryContrast.every(action=>action.ratio>=4.5),{actions:snapshot.primaryContrast});
  return snapshot;
}
try{
  browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
  const organizer=await login(owner.people[0].phone,owner.password,{width:1440,height:1000});
  await organizer.page.goto(context.frontend+'/portal/organization?tab=status');
  await organizer.page.getByRole('button',{name:'进入办赛工作台',exact:true}).click();
  await organizer.page.waitForURL(url=>url.pathname.startsWith('/org-desk'));
  await organizer.page.goto(context.frontend+'/org-desk/home');
  await organizer.page.locator('.organizer-stat').first().waitFor();
  const desk=await inspect(organizer.page,'organizer-workbench-desktop',['.b-brand>div','.b-brand small','.b-sidebar nav a','.organizer-stat>span','.organizer-stat p','.organizer-hero h1','.organizer-filters button','.organizer-event-actions a','.b-top-actions .el-button']);
  check('Organizer sidebar assistant card is removed',!desk.sidebarAssistant);
  const participant=await login(context.people[0].phone,context.password,{width:1440,height:1000});
  await participant.page.goto(context.frontend+'/portal/registration/detail/'+state.entry.id);
  await participant.page.locator('.registration-overview').waitFor();
  const registration=await inspect(participant.page,'registration-desktop',['.consumer-brand strong','.consumer-brand>div>span','.consumer-nav a','.registration-overview h1','.participant-main strong','.participant-main p','.status-cells span','.status-cells strong','.el-button','.consumer-note']);
  check('Registration secondary text and actions meet the shared scale',registration.fonts['.status-cells span']?.size>=14&&registration.fonts['.el-button']?.size>=14);
  const mobile=await login(context.people[1].phone,context.password,{width:390,height:844});
  await mobile.page.goto(context.frontend+'/portal/notices');
  await mobile.page.locator('.notice-card').first().waitFor();
  const notices=await inspect(mobile.page,'notices-mobile',['.consumer-brand strong','.consumer-brand>div>span','.consumer-page-head h1','.notice-content h3','.notice-content p','.badge','.el-button','.consumer-mobile-nav a']);
  check('Mobile notice body uses the 16px reading scale',notices.fonts['.notice-content p']?.size===16);
  for(const [device,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}]]){
    const material=await login(owner.people[0].phone,owner.password,viewport);
    await material.page.goto(context.frontend+'/portal/organization?tab=status');
    await material.page.getByRole('button',{name:'进入办赛工作台',exact:true}).click();
    await material.page.waitForURL(url=>url.pathname.startsWith('/org-desk'));
    await material.page.goto(context.frontend+'/org-desk/workspace/2109535728705757185?task=materials');
    const preview=material.page.getByTestId('material-preview');await preview.locator('table').waitFor();
    const details=await preview.evaluate(element=>({bodySize:parseFloat(getComputedStyle(element).fontSize),tableSize:parseFloat(getComputedStyle(element.querySelector('td')).fontSize),paragraphSize:parseFloat(getComputedStyle(element.querySelector('p')).fontSize),hasJava:/javascript:|window\.__|markdownInjected/i.test(element.textContent),tables:element.querySelectorAll('table').length,headings:element.querySelectorAll('h1,h2,h3').length}));
    evidence.materialDetails??={};evidence.materialDetails[device]=details;save();
    check(device+' existing plan opens in readable Markdown preview',await material.page.getByTestId('material-tab-plan').getAttribute('aria-pressed')==='true'&&await material.page.getByTestId('material-content').count()===0&&details.headings>0&&details.tables>0);
    check(device+' existing plan body and table text stay at least 15px',details.bodySize>=15&&details.tableSize>=15&&details.paragraphSize>=15);
    check(device+' existing plan contains no JavaScript injection residue',!details.hasJava);
    if(device==='mobile')check('Mobile material tools are collapsed by default',!await material.page.locator('.studio-tools').evaluate(element=>element.open));
    await preview.scrollIntoViewIfNeeded();
    await inspect(material.page,'materials-'+device,['.studio-read','.studio-read p','.studio-read h1','.studio-read td','.studio-view-switch > span','.studio-tools-toggle']);
    await material.browserContext.close();
  }
  trial.finish();
}catch(error){evidence.failure=String(error.message).replaceAll(context.password,'[private]').replaceAll(owner.password,'[private]');if(activePage){evidence.failurePage=await activePage.evaluate(()=>({path:location.pathname,headings:[...document.querySelectorAll('h1,h2')].map(element=>element.textContent),messages:[...document.querySelectorAll('.el-message,.el-form-item__error,.consumer-state')].map(element=>element.textContent)}));await activePage.screenshot({path:path.join(directory,'failure-page.png')});}save();throw new Error('Read-only readability inspection failed; retained evidence identifies the page.');}finally{await browser?.close();}
