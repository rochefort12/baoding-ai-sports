// Main loopback authentication only. Protected credentials arrive via stdin;
// they are never persisted, placed in process arguments or printed in evidence.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const credential=JSON.parse(fs.readFileSync(0,'utf8').replace(/^\uFEFF/,''));
assert.equal(credential.username,'admin');assert.equal(credential.baseUri,'http://127.0.0.1:8080');
assert.ok(credential.password&&credential.clientId);
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=require('playwright');
const out=path.resolve('.local/login-refinement-20261011','main-auth-ui-'+crypto.randomUUID());fs.mkdirSync(out,{recursive:true});
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const sources=['plus-ui/src/views/login.vue','plus-ui/src/views/index.vue','plus-ui/src/components/consumer/WeChatLoginButton.vue','plus-ui/src/assets/styles/design-system.scss'];
const report={at:new Date().toISOString(),passed:false,scope:'Actual main administrator password-form login in a fresh browser session; protected original credential and default organization. Authentication only, no business writes or OAuth.',checks:[],blockedWrites:[],pageErrors:[],sources:sources.map(file=>({path:file,sha256:hash(file)}))};
function check(name,value){report.checks.push({name,passed:Boolean(value)});assert.ok(value,name);}
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
try{
 const context=await browser.newContext({viewport:{width:1440,height:1000},reducedMotion:'reduce'}),page=await context.newPage();let logins=0;
 page.on('pageerror',()=>report.pageErrors.push('Work-login page script error'));
 await context.route('**/*',route=>{const r=route.request(),url=new URL(r.url());if(r.method()==='POST'&&url.origin==='http://127.0.0.1:5190'&&url.pathname==='/dev-api/auth/login'){logins++;return route.continue();}if(!['GET','HEAD'].includes(r.method())){report.blockedWrites.push({path:url.pathname,method:r.method()});return route.abort('blockedbyclient');}return route.continue();});
 await page.goto('http://127.0.0.1:5190/login?redirect=https%3A%2F%2Fexample.invalid',{waitUntil:'domcontentloaded'});
 await page.getByPlaceholder('请输入工作账号',{exact:true}).waitFor();
 check('main login starts without an injected token',await page.evaluate(()=>!localStorage.getItem('Admin-Token')));
 check('main form needs no organization selection',await page.getByLabel('所属组织').count()===0);
 await page.getByPlaceholder('请输入工作账号',{exact:true}).fill(credential.username);
 await page.getByPlaceholder('请输入密码',{exact:true}).fill(credential.password);
 await page.getByRole('button',{name:'登录工作台',exact:true}).click();
 await page.waitForURL(url=>url.origin==='http://127.0.0.1:5190'&&url.pathname==='/index',{timeout:45000});
 await page.getByRole('heading',{name:'平台工作台',exact:true}).waitFor({timeout:45000});
 await page.waitForFunction(()=>{const values=[...document.querySelectorAll('.product-metrics strong')];return values.length===3&&values.every(value=>value.textContent.trim()!=='—');},{},{timeout:45000});
 check('main password form logs in once and rejects an external return URL',logins===1&&new URL(page.url()).origin==='http://127.0.0.1:5190'&&new URL(page.url()).pathname==='/index');
 const token=await page.evaluate(()=>localStorage.getItem('Admin-Token'));
 const info=await context.request.get(credential.baseUri+'/system/user/getInfo',{headers:{clientid:credential.clientId,Authorization:'Bearer '+token}}).then(response=>response.json());
 check('main actual original administrator remains in default organization',info.code===200&&String(info.data?.user?.userId)==='1'&&info.data?.user?.tenantId==='000000'&&info.data?.permissions?.includes('*:*:*'));
 check('main did not persist account password or username',await page.evaluate(()=>!localStorage.getItem('password')&&!localStorage.getItem('username')));
 check('main workbench requests load without an error banner',await page.getByText('工作台数据读取失败，请重试。',{exact:true}).count()===0);
 check('main authentication caused no attempted business write or script error',report.blockedWrites.length===0&&report.pageErrors.length===0);
 check('main verified UI sources stayed unchanged',report.sources.every(source=>hash(source.path)===source.sha256));
 const image=path.join(out,'platform-workbench.png');await page.screenshot({path:image,fullPage:true});report.screenshot={path:path.relative(process.cwd(),image).replaceAll('\\','/'),sha256:hash(image)};
 await context.close();report.passed=true;
}catch(error){report.failure=error.name==='AssertionError'?error.message:'Actual main form login failed; private diagnostics omitted';process.exitCode=1;}
finally{credential.password=undefined;credential.token=undefined;await browser.close();report.finishedAt=new Date().toISOString();const file=path.join(out,'receipt.json'),fd=fs.openSync(file,'wx');try{fs.writeFileSync(fd,JSON.stringify(report,null,2));fs.fsyncSync(fd);}finally{fs.closeSync(fd);}console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,failure:report.failure,path:path.relative(process.cwd(),file).replaceAll('\\','/')}));}
