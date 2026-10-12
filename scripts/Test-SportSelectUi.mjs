// Actual public filters and empty authentication fields. No login, model or API substitution.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=require('playwright');
const out=path.resolve('.local/product-release-20261011','sport-select-'+Date.now());fs.mkdirSync(out,{recursive:true});
const report={timestamp:new Date().toISOString(),scope:'Actual 5190/5192 public home/catalog dropdown pointer and keyboard controls at desktop/mobile, focus and required error presentation on empty login. No auth request, model, API substitution or business writes.',passed:false,checks:[],blockedWrites:[],pageErrors:[],failures:[],screenshots:[],sourceFiles:[]};
for(const file of ['plus-ui/src/components/sport-ui/SportSelect.vue','plus-ui/src/components/sport-ui/SportEventFilters.vue','plus-ui/src/assets/styles/sport-controls.scss','plus-ui/src/assets/styles/index.scss','scripts/Test-SportSelectUi.mjs'])report.sourceFiles.push({path:file,sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')});
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});let page;
function check(name,value){assert.ok(value,name);report.checks.push(name);}
async function shot(name){const file=path.join(out,name+'.png');await page.screenshot({path:file,fullPage:false});report.screenshots.push({path:path.relative(process.cwd(),file).replaceAll('\\','/'),sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')});}
async function bounded(popup){const box=await popup.boundingBox(),view=page.viewportSize();return box.x>=7&&box.y>=7&&box.x+box.width<=view.width-7&&box.y+box.height<=view.height-7;}
function neutral(color){const channels=(color.match(/[\d.]+/g)||[]).slice(0,3).map(Number);return channels.length===3&&Math.max(...channels)-Math.min(...channels)<65;}
try{
for(const port of [5190,5192])for(const width of [390,1440]){
 const context=await browser.newContext({viewport:{width,height:width<600?844:1000},reducedMotion:'reduce'});
 await context.route('**/*',route=>{if(!['GET','HEAD'].includes(route.request().method())){report.blockedWrites.push({path:new URL(route.request().url()).pathname,method:route.request().method()});return route.abort('blockedbyclient');}return route.continue();});
 page=await context.newPage();page.setDefaultTimeout(12000);page.on('pageerror',()=>report.pageErrors.push('Page script error'));
 for(const [name,route] of [['home','/portal/home'],['catalog','/public/events']]){
  const label=port+'/'+width+'/'+name;await page.goto('http://127.0.0.1:'+port+route,{waitUntil:'domcontentloaded'});const form=page.getByRole('search',{name:'筛选赛事'});await form.waitFor();
  const status=form.getByRole('combobox',{name:'赛事状态',exact:true}),sport=form.getByRole('combobox',{name:'运动项目',exact:true});
  check(label+' actual custom combobox replaces OS menu',await status.evaluate(el=>el.tagName==='BUTTON')&&await form.locator('.sport-select__trigger').count()===2);
  await status.click();let popup=page.getByRole('listbox',{name:'赛事状态',exact:true});await popup.waitFor();check(label+' dropdown is bounded and uses light native-product surface',await bounded(popup)&&await popup.evaluate(el=>getComputedStyle(el).backgroundColor==='rgb(255, 255, 255)'));
  check(label+' selected option is semantic and has no blue fill',await popup.getByRole('option',{name:'全部赛事',exact:true}).getAttribute('aria-selected')==='true'&&await popup.getByRole('option',{name:'全部赛事',exact:true}).evaluate(el=>{const c=getComputedStyle(el).backgroundColor.match(/\d+/g).map(Number);return Math.max(...c.slice(0,3))-Math.min(...c.slice(0,3))<45;}));
  await shot(port+'-'+width+'-'+name+'-open');await status.press('Escape');await popup.waitFor({state:'hidden'});check(label+' Escape preserves control focus',await status.evaluate(el=>el===document.activeElement));
  await status.click();await page.getByRole('listbox',{name:'赛事状态',exact:true}).getByRole('option',{name:'可报名',exact:true}).click();check(label+' actual option pointer selection updates value',await status.innerText()==='可报名');
  const cards=page.locator(name==='home'?'.home-event-grid .premium-event-card':'.event-board .premium-event-card');check(label+' filter changes actual cards without ended results',!(await cards.locator('.card-status').allTextContents()).some(text=>/已结束|已取消|报名已截止/.test(text)));
  await form.getByRole('button',{name:'清除筛选',exact:true}).click();await status.focus();await status.press('ArrowDown');await status.press('End');check(label+' End activates final enabled option',await status.getAttribute('aria-activedescendant')===await page.getByRole('listbox',{name:'赛事状态',exact:true}).getByRole('option').last().getAttribute('id'));
  await status.press('Home');await status.press('ArrowDown');await status.press('Enter');await page.getByRole('listbox',{name:'赛事状态',exact:true}).waitFor({state:'hidden'});check(label+' keyboard Enter chooses the active option',await status.innerText()==='可报名'&&await status.getAttribute('aria-expanded')==='false');
  await form.getByRole('button',{name:'清除筛选',exact:true}).click();await sport.click();popup=page.getByRole('listbox',{name:'运动项目',exact:true});await popup.waitFor();check(label+' sport dropdown has actual available options',await popup.getByRole('option').count()>0);await form.getByRole('searchbox',{name:'搜索赛事名称',exact:true}).click();await popup.waitFor({state:'hidden'});check(label+' outside pointer closes dropdown',await sport.getAttribute('aria-expanded')==='false');
  await status.focus();await status.press('ArrowDown');await status.press('Tab');await page.getByRole('listbox',{name:'赛事状态',exact:true}).waitFor({state:'hidden'});check(label+' Tab closes and moves focus onward',!await status.evaluate(el=>el===document.activeElement));
  await status.focus();await page.keyboard.press('Tab');await page.keyboard.press('Shift+Tab');check(label+' keyboard focus uses one visible neutral border without stacked outline',await status.evaluate(el=>el.matches(':focus-visible')&&getComputedStyle(el).borderTopWidth==='1px'&&getComputedStyle(el).borderTopColor==='rgb(117, 128, 107)'&&getComputedStyle(el).outlineStyle==='none'&&getComputedStyle(el).boxShadow==='none')&&neutral(await status.evaluate(el=>getComputedStyle(el).borderTopColor)));
  check(label+' custom menu and row do not overflow document',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
 }
 await page.goto('http://127.0.0.1:'+port+'/portal/login?returnTo=/portal/home',{waitUntil:'domcontentloaded'});const phone=page.getByPlaceholder('请输入手机号',{exact:true});await phone.waitFor();
 await phone.focus();await phone.press('ArrowLeft');const control=page.locator('.sport-field-control').first();check(port+'/'+width+' empty login focus retains one neutral border without inner or outer frames',await phone.evaluate(el=>el.matches(':focus-visible')&&getComputedStyle(el).outlineStyle==='none'&&getComputedStyle(el).boxShadow==='none'&&getComputedStyle(el).borderTopWidth==='0px')&&neutral(await control.evaluate(el=>getComputedStyle(el).borderTopColor))&&await control.evaluate(el=>getComputedStyle(el).borderTopWidth==='1px'&&getComputedStyle(el).outlineStyle==='none'&&getComputedStyle(el).boxShadow==='none'));
 await shot(port+'-'+width+'-login-focus');await page.getByRole('button',{name:'登录',exact:true}).click();await page.locator('.sport-field.has-error').first().waitFor();check(port+'/'+width+' empty submit retains red error and does not submit credentials',await control.evaluate(el=>{const c=getComputedStyle(el).borderTopColor.match(/\d+/g).map(Number);return c[0]>c[1]+30&&c[0]>c[2]+30;}));await shot(port+'-'+width+'-login-errors');
 check(port+'/'+width+' no floating control in authentication',await page.locator('.assistant-bubble').count()===0);await context.close();page=undefined;
}
check('zero page script errors',report.pageErrors.length===0);check('zero non-GET requests including auth or model',report.blockedWrites.length===0);report.passed=true;
}catch(error){report.failures.push({type:error.name,message:error.name==='AssertionError'?error.message:'Interaction verification did not complete; private details omitted',path:page?new URL(page.url()).pathname:undefined});if(page)await shot('failure').catch(()=>{});process.exitCode=1;}
finally{await browser.close();const file=path.join(out,'receipt.json'),fd=fs.openSync(file,'wx');try{fs.writeFileSync(fd,JSON.stringify(report,null,2)+'\n');fs.fsyncSync(fd);}finally{fs.closeSync(fd);}console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,failures:report.failures,report:path.relative(process.cwd(),file).replaceAll('\\','/')}));}
