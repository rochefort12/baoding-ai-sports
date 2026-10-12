// Read-only anonymous/signed-in header comparison on the current frontend.
import fs from 'node:fs';import path from 'node:path';import {createRequire} from 'node:module';
import {context,createEvidence} from './lib/BusinessRegression.mjs';
const trial=createEvidence('header-brand');const {evidence,directory,check,save}=trial;
evidence.scope='Read-only anonymous and ordinary-person desktop/mobile home header geometry; authentication is the only submitted form.';save();
const {chromium}=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json')('playwright');
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
async function stable(page){await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));await page.waitForFunction(()=>document.getAnimations().every(animation=>animation.effect?.getTiming().iterations===Infinity||animation.playState!=='running'));await page.locator('.el-message').waitFor({state:'hidden'});}
try{
 for(const [role,width] of [['anonymous',1440],['signed-in',1440],['anonymous',390],['signed-in',390]]){
  const browserContext=await browser.newContext({viewport:{width,height:width===1440?1000:844}});const page=await browserContext.newPage();
  if(role==='signed-in'){await page.goto(context.frontend+'/portal/login');await page.getByPlaceholder('请输入手机号').fill(context.people[0].phone);await page.getByPlaceholder('请输入密码').fill(context.password);await page.getByRole('button',{name:'登录',exact:true}).click();await page.waitForURL(url=>!url.pathname.includes('/login'));}
  await page.goto(context.frontend+'/portal/home');await page.locator('.consumer-brand strong').waitFor();await stable(page);
  const geometry=await page.evaluate(()=>({title:document.title,viewport:innerWidth,scrollWidth:document.documentElement.scrollWidth,elements:['.brand-group','.consumer-brand','.consumer-brand>div','.consumer-brand strong','.consumer-brand>div>span','.consumer-city','.consumer-city strong'].map(selector=>{const element=document.querySelector(selector);const css=getComputedStyle(element);const rect=element.getBoundingClientRect();return{selector,text:element.textContent.trim(),clientWidth:element.clientWidth,scrollWidth:element.scrollWidth,x:rect.x,width:rect.width,height:rect.height,display:css.display,overflow:css.overflow,whiteSpace:css.whiteSpace,fontSize:css.fontSize,flexShrink:css.flexShrink,flexBasis:css.flexBasis};})}));
  evidence.geometry??={};evidence.geometry[role+'-'+width]=geometry;save();
  const file=path.join(directory,role+'-'+width+'.png');await page.screenshot({path:file});evidence.screenshots??=[];evidence.screenshots.push(file);save();
  check(role+' '+width+' uses the AI体育 page title',geometry.title.includes('AI体育'));
  check(role+' '+width+' brand text does not overflow its box',geometry.elements.filter(element=>element.height>0&&element.selector!=='.consumer-city').every(element=>element.scrollWidth<=element.clientWidth+1));
  check(role+' '+width+' header and page do not overflow viewport',geometry.scrollWidth<=geometry.viewport&&geometry.elements[0].x+geometry.elements[0].width<=geometry.viewport);
  await browserContext.close();
 }
 trial.finish();
}catch(error){evidence.failure=String(error.message).replaceAll(context.password,'[private]');save();throw new Error('Read-only brand geometry check failed; inspect its retained evidence.');}finally{await browser.close();}
