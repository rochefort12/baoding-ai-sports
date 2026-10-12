// The two actual local frontends, public data and client-side filters only.
// No login, model call, response substitution or business write is allowed.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const root=process.cwd();
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=require('playwright');
const output=path.join(root,'.local/product-release-20261011','entry-ui-'+Date.now());
fs.mkdirSync(output,{recursive:true});
const report={timestamp:new Date().toISOString(),scope:'Main 5190 and rehearsal 5192 public home/catalog at 390/730/1024/1440. Real GET data; client-side search, sport/status filters, keyboard focus, non-draggable authored navigation scenes and actual assistant open/close geometry. No login, prompt, model, API substitution or business mutation.',checks:[],screenshots:[],blockedWrites:0,pageErrors:[],passed:false};
const check=(name,value)=>{assert.ok(value,name);report.checks.push({name,passed:true});};
const capture=async(page,file)=>{await page.screenshot({path:path.join(output,file),fullPage:true});report.screenshots.push({file,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(output,file))).digest('hex')});};
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
let currentPage;
try {
  for(const port of [5190,5192]) for(const width of [390,730,1024,1440]) {
    const context=await browser.newContext({viewport:{width,height:width<800?844:1000},reducedMotion:'no-preference'});
    await context.route('**/dev-api/**',async route=>{if(route.request().method()!=='GET'){report.blockedWrites++;return route.abort();}return route.continue();});
    const page=await context.newPage();currentPage=page;
    page.on('pageerror',()=>report.pageErrors.push('Page script error'));
    for(const [name,url] of [['home','/portal/home'],['catalog','/public/events']]) {
      const label=`${port}/${width}/${name}`;
      await page.goto(`http://127.0.0.1:${port}${url}`);
      await page.getByRole('search',{name:'筛选赛事'}).waitFor();
      await page.waitForTimeout(350);
      check(label+' no Vite error',await page.locator('vite-error-overlay').count()===0);
      check(label+' no document overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
      const bubble=page.locator('.assistant-bubble');
      if(await bubble.count()) check(label+' global assistant remains a small floating action',await bubble.evaluate(element=>{const box=element.getBoundingClientRect(),image=element.querySelector('img').getBoundingClientRect();return box.width<=72&&box.height<=90&&image.width<=58&&image.height<=58;}));
      check(label+' redundant AI chooser is absent',await page.getByRole('button',{name:'帮我选赛事',exact:true}).count()===0&&await page.getByRole('button',{name:'找赛事',exact:true}).count()===0);
      const metrics=await page.getByRole('search',{name:'筛选赛事'}).evaluate(form=>{const controls=[...form.querySelectorAll('.sport-event-filters__search,.sport-event-filters__select')].map(control=>control.getBoundingClientRect());return {height:form.getBoundingClientRect().height,tops:controls.map(box=>box.y),heights:controls.map(box=>box.height)};});
      check(label+' filter is one compact row',metrics.height<=46&&Math.max(...metrics.tops)-Math.min(...metrics.tops)<=1&&metrics.heights.every(height=>height>=40));
      const cards=page.locator(name==='home'?'.home-event-grid .premium-event-card':'.event-board .premium-event-card');
      const before=await cards.count();
      await page.getByRole('searchbox',{name:'搜索赛事名称'}).fill('__NO_MATCH_ENTRY_UI__');
      check(label+' actual search can produce the empty state',await cards.count()===0&&await page.getByRole('heading',{name:name==='home'?'暂时没有符合条件的赛事':'没有符合条件的赛事',exact:true}).isVisible());
      await page.getByRole('button',{name:'清除筛选',exact:true}).first().click();
      check(label+' reset restores real items',await cards.count()===before);
      await page.getByRole('combobox',{name:'赛事状态'}).click();await page.keyboard.press('Escape');
      await page.getByRole('combobox',{name:'赛事状态'}).click();await page.getByRole('listbox',{name:'赛事状态'}).getByRole('option',{name:'可报名',exact:true}).click();
      check(label+' open filter excludes ended/cancelled cards',!(await cards.locator('.card-status').allTextContents()).some(text=>/已结束|已取消|报名已截止/.test(text)));
      await page.getByRole('button',{name:'清除筛选',exact:true}).first().click();
      const sport=page.getByRole('combobox',{name:'运动项目'});await sport.click();const sportOptions=page.getByRole('listbox',{name:'运动项目'}).getByRole('option'), sports=await sportOptions.allTextContents();
      if(sports.length>1){await sportOptions.nth(1).click();check(label+' sport filter applies to actual cards',(await cards.locator('.event-kicker>span:first-child').allTextContents()).every(text=>text.trim()===sports[1].trim()));await page.getByRole('button',{name:'清除筛选',exact:true}).first().click();}else await sport.press('Escape');
      if(name==='home') {
        const actions=page.locator('.home-services .sport-art-action');
        check(label+' five distinct authored scenes are available',await actions.count()===5&&await actions.locator('img').evaluateAll(images=>new Set(images.map(image=>image.getAttribute('src'))).size===5&&images.every(image=>image.complete&&image.naturalWidth>0&&image.draggable===false&&getComputedStyle(image).pointerEvents==='none')));
        check(label+' five service routes remain actual links',JSON.stringify(await actions.evaluateAll(links=>links.map(link=>link.getAttribute('href'))))===JSON.stringify(['/portal/registration','/portal/rooms','/portal/teams','/portal/growth','/portal/results']));
        check(label+' shortcut labels are visible text',await actions.locator('.sport-art-action__label').evaluateAll(labels=>labels.every(label=>label.textContent.trim().length>0&&label.getBoundingClientRect().width>0)));
        check(label+' task cards remain aligned',await page.evaluate(()=>{const a=document.querySelector('.home-squad').getBoundingClientRect(),b=document.querySelector('.home-next .c-next-step').getBoundingClientRect();return Math.abs(a.height-b.height)<=1.5;}));
        await actions.first().focus();
        await page.keyboard.press('Tab');await page.keyboard.press('Shift+Tab');
        check(label+' keyboard focus remains visible',await actions.first().evaluate(link=>link.matches(':focus-visible')&&getComputedStyle(link).outlineStyle!=='none'));
        const art=await actions.first().locator('img').boundingBox();
        await page.evaluate(()=>{window.__entryDragCount=0;document.addEventListener('dragstart',event=>{if(event.target instanceof HTMLImageElement&&!event.defaultPrevented)window.__entryDragCount++;});});
        await page.mouse.move(art.x+art.width/2,art.y+art.height/2);await page.mouse.down();await page.mouse.move(art.x+art.width/2+40,art.y+art.height/2+40,{steps:8});await page.mouse.up();
        check(label+' actual image drag creates no native ghost event',await page.evaluate(()=>window.__entryDragCount===0));
        await page.waitForTimeout(120);
        check(label+' image drag does not accidentally follow the action',new URL(page.url()).pathname===url);
      }
      await page.evaluate(()=>{document.activeElement?.blur();window.scrollTo(0,0);});
      await page.waitForTimeout(120);
      await capture(page,`${port}-${width}-${name}.png`);
      const assistant=page.getByRole('button',{name:'打开体育助手，可拖动或用方向键移动',exact:true});
      check(label+' floating assistant action is available',await assistant.count()===1);
      await assistant.click();
      const panel=page.getByRole('dialog',{name:'体育助手聊天窗口',exact:true});
      await panel.waitFor({state:'visible'});await page.waitForTimeout(250);
      check(label+' opened assistant remains within the viewport',await panel.evaluate(element=>{const box=element.getBoundingClientRect();return box.left>=7&&box.top>=7&&box.right<=innerWidth-7&&box.bottom<=innerHeight-7&&box.width>=Math.min(330,innerWidth-16)&&box.height<innerHeight;}));
      check(label+' assistant close is a visible reachable control',await page.getByRole('button',{name:'关闭聊天窗口',exact:true}).isVisible());
      await capture(page,`${port}-${width}-${name}-assistant-open.png`);
      await page.getByRole('button',{name:'关闭聊天窗口',exact:true}).click();
      await panel.waitFor({state:'hidden'});
      check(label+' closing assistant restores the floating action',await assistant.isVisible()&&await assistant.getAttribute('aria-expanded')==='false');
    }
    await context.close();currentPage=undefined;
  }
  check('No page script errors',report.pageErrors.length===0);check('No non-GET request occurred',report.blockedWrites===0);report.passed=true;
} catch(error) {report.error=String(error.message).slice(0,220);process.exitCode=1;if(currentPage)await currentPage.screenshot({path:path.join(output,'failed.png'),fullPage:true}).catch(()=>{});}
finally {await browser.close();const receipt=path.join(output,'receipt.json'),fd=fs.openSync(receipt,'wx');try{fs.writeFileSync(fd,JSON.stringify(report,null,2)+'\n');fs.fsyncSync(fd);}finally{fs.closeSync(fd);}console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,error:report.error,report:path.relative(root,receipt).replaceAll('\\','/')}));}
