import {createRequire} from 'node:module';
import path from 'node:path';
import fs from 'node:fs/promises';
const require=createRequire(path.join(process.argv[2],'_resolve.cjs'));
const {chromium}=require('playwright');
const out=path.resolve('.local','consumer-ui-20261007',process.argv[3]||'before');await fs.mkdir(out,{recursive:true});
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true});
const base='http://127.0.0.1:5173',errors=[];
try{for(const [name,url,width,height] of [['home-desktop','/portal/home',1440,900],['home-mobile','/portal/home',390,844],['events','/public/events',1440,900],['login','/portal/login',1440,900],['login-mobile','/portal/login',390,844]]){const c=await browser.newContext({viewport:{width,height}}),p=await c.newPage();p.on('pageerror',e=>errors.push(e.message));await p.goto(base+url);await p.waitForTimeout(1600);await p.screenshot({path:path.join(out,name+'.png'),fullPage:true});console.log(name+': '+await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));await c.close()}await fs.writeFile(path.join(out,'capture.json'),JSON.stringify({scope:'actual public UI; no account or business writes',errors},null,2))}finally{await browser.close()}
