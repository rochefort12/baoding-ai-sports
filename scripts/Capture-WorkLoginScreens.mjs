// Capture stable anonymous main UI. All mutation requests are blocked.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=require('playwright');
const out=path.resolve('docs/05-ui/work-login-20261011');fs.mkdirSync(out,{recursive:true});
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const report={at:new Date().toISOString(),passed:false,scope:'Stable anonymous main login screenshots, not additional business acceptance',screenshots:[],blockedWrites:[]};
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
try{
 for(const width of [1912,390]){
  const context=await browser.newContext({viewport:{width,height:1000},reducedMotion:'reduce'}),page=await context.newPage();
  await context.route('**/*',route=>{if(!['GET','HEAD'].includes(route.request().method())){report.blockedWrites.push(new URL(route.request().url()).pathname);return route.abort('blockedbyclient');}return route.continue();});
  await page.goto('http://127.0.0.1:5190/login',{waitUntil:'networkidle'});
  await page.locator('.sport-auth-form form').waitFor();await page.locator('#nprogress').waitFor({state:'detached'});
  await page.evaluate(()=>document.fonts.ready);
  const file=path.join(out,width===1912?'desktop.png':'mobile.png');if(fs.existsSync(file))throw new Error('Screenshot already exists; do not overwrite evidence');
  await page.screenshot({path:file,fullPage:true});report.screenshots.push({path:path.relative(process.cwd(),file).replaceAll('\\','/'),sha256:hash(file)});await context.close();
 }
 if(report.blockedWrites.length)throw new Error('Anonymous page attempted mutation');report.passed=true;
}catch{report.failure='Stable anonymous screenshot capture failed';process.exitCode=1;}
finally{await browser.close();report.finishedAt=new Date().toISOString();fs.writeFileSync(path.join(out,'screenshots.json'),JSON.stringify(report,null,2),{flag:'wx'});console.log(JSON.stringify({passed:report.passed,path:path.relative(process.cwd(),out).replaceAll('\\','/')}));}
