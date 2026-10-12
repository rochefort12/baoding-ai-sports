// Real navigation/assistant motion on the formal frontend. No model or business writes.
import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');const {chromium}=require('playwright');
const out=path.resolve('.local/product-release-20261011/motion-'+Date.now());fs.mkdirSync(out,{recursive:true});
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});const checks=[];let lastPage;
try {for(const motion of ['no-preference','reduce']){
 const context=await browser.newContext({viewport:{width:1440,height:1000},reducedMotion:motion,...(motion==='no-preference'?{recordVideo:{dir:out,size:{width:1440,height:1000}}}:{})});const page=await context.newPage();lastPage=page;const errors=[],writes=[];
 page.on('pageerror',()=>errors.push('Page script error'));page.on('request',r=>{if(new URL(r.url()).pathname.startsWith('/dev-api/')&&r.method()!=='GET')writes.push(r.method());});
 await page.goto('http://127.0.0.1:5192/portal/home',{waitUntil:'domcontentloaded'});await page.locator('.home-feature').waitFor();await page.waitForTimeout(400);
 const duration=await page.locator('.header-ai-entry').evaluate(e=>getComputedStyle(e).transitionDuration);
 const max=Math.max(...duration.split(',').map(x=>parseFloat(x)*(x.trim().endsWith('ms')?.001:1)));assert.ok(motion==='reduce'?max<=.01:max>=.15);checks.push(motion+' computed assistant motion respects system preference');
 await page.locator('.header-ai-entry').hover();await page.waitForTimeout(450);
 await page.getByRole('button',{name:'打开体育 AI 助手',exact:true}).click();await page.getByRole('dialog',{name:'AI 参赛助手',exact:true}).waitFor();
 assert.ok(await page.locator('.c-ai-welcome-orb').isVisible());checks.push(motion+' asset assistant entry opens real conversation panel');
 await page.keyboard.press('Escape');await page.getByRole('dialog',{name:'AI 参赛助手',exact:true}).waitFor({state:'hidden'});
 checks.push(motion+' Escape closes assistant and restores page');
 await page.getByRole('link',{name:'赛事',exact:true}).first().click();await page.waitForURL(u=>u.pathname==='/public/events');
 await page.locator('.public-event-card,.premium-event-card,.event-card').first().waitFor();await page.waitForTimeout(400);
 assert.deepEqual(errors,[]);assert.deepEqual(writes,[]);await page.screenshot({path:path.join(out,motion+'.png')});await context.close();
 }
 const receipt={timestamp:new Date().toISOString(),scope:'Actual formal UI navigation and system motion preferences. No model, credentials or business writes.',passed:true,checks};fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(receipt,null,2),{flag:'wx'});console.log(checks.map(x=>'PASS '+x).join('\n'));console.log('Evidence: '+path.relative(process.cwd(),out));
}catch(error){await lastPage?.screenshot({path:path.join(out,'failed.png')}).catch(()=>{});const reason=String(error.message).replace(/(token|Authorization|password)=[^&\s]+/gi,'credential=[REDACTED]').slice(0,800);fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({passed:false,checks,reason},null,2),{flag:'wx'});console.log(reason);process.exitCode=1;}finally{await browser.close();}
