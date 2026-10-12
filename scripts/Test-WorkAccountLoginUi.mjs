// Actual form authentication, fresh browser sessions and server-issued roles.
// Credentials are read only from the protected, explicitly selected test run.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {context as c, readSql} from './lib/BusinessRegression.mjs';
const require=createRequire('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=require('playwright');
const fixture=JSON.parse(fs.readFileSync(path.join(c.out,'work-account-auto-tenant.private.json'),'utf8').replace(/^\uFEFF/,''));
assert.equal(fixture.database,c.database);
const out=path.resolve('.local/login-refinement-20261011','authenticated-ui-'+crypto.randomUUID());
fs.mkdirSync(out,{recursive:true});
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const sources=['plus-ui/src/views/login.vue','plus-ui/src/views/index.vue','plus-ui/src/store/modules/user.ts','plus-ui/src/assets/styles/design-system.scss'];
const report={at:new Date().toISOString(),passed:false,scope:'Real candidate work-login forms and server-issued identity; synthetic government/platform/nondefault work accounts. Authentication only. No pre-injected tokens, OAuth, SMS or tournament writes. Viewports are not physical devices.',checks:[],sources:sources.map(file=>({path:file,sha256:hash(file)})),blockedWrites:[],pageErrors:[],screenshots:[]};
function check(name,value){report.checks.push({name,passed:Boolean(value)});assert.ok(value,name);}
const tables=['organization','staff_grant','governance_grant','event','registration','registration_member','team','team_member','fee_obligation','payment','payment_allocation','refund','payment_action','payment_exception','result_version','honor','growth_record'];
const facts=()=>crypto.createHash('sha256').update(readSql(tables.map(table=>`SELECT '${table}='||count(*)||':'||md5(coalesce(string_agg(row_to_json(t)::text,'|' ORDER BY id),'')) FROM asp_${table} t;`).join('\n'))).digest('hex');
const before=facts();
const actors=[
 {label:'government',username:'phase1-government',password:c.password,id:c.government.id,tenant:'000000',heading:'主办方管理',width:390},
 {label:'platform',username:'admin',password:c.password,id:'1',tenant:'000000',heading:'平台工作台',width:1440},
 {label:'nondefault-organization',username:fixture.usernames.different,password:fixture.passwords.tenantDifferent,id:fixture.fixtures.tenantOwner.id,tenant:fixture.fixtures.tenant.tenantId,heading:'业务入口',width:1440},
 {label:'same-name-default',username:fixture.usernames.different,password:fixture.passwords.defaultDifferent,id:fixture.fixtures.defaultDifferent.id,tenant:'000000',heading:'业务入口',width:1024}
];
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
let stage='browser setup';
try{
 for(const actor of actors){
  stage=actor.label;
  const context=await browser.newContext({viewport:{width:actor.width,height:950},reducedMotion:'reduce'});
  const page=await context.newPage();let loginRequests=0;
  page.on('pageerror',()=>report.pageErrors.push({actor:actor.label,message:'Work-login page script error'}));
  await context.route('**/*',route=>{
   const request=route.request(),url=new URL(request.url());
   if(request.method()==='POST'&&url.origin===c.frontend&&url.pathname==='/dev-api/auth/login'){loginRequests++;return route.continue();}
   if(!['GET','HEAD'].includes(request.method())){report.blockedWrites.push({actor:actor.label,path:url.pathname,method:request.method()});return route.abort('blockedbyclient');}
   return route.continue();
  });
  await page.goto(c.frontend+'/login',{waitUntil:'domcontentloaded'});
  await page.getByPlaceholder('请输入工作账号',{exact:true}).waitFor();
  check(actor.label+' starts without an existing session',await page.evaluate(()=>!localStorage.getItem('Admin-Token')));
  check(actor.label+' no organization selection is requested',await page.getByLabel('所属组织').count()===0);
  await page.getByPlaceholder('请输入工作账号',{exact:true}).fill(actor.username);
  await page.getByPlaceholder('请输入密码',{exact:true}).fill(actor.password);
  await page.getByRole('button',{name:'登录工作台',exact:true}).click();
  await page.waitForURL(url=>url.pathname==='/index',{timeout:45000});
  await page.getByRole('heading',{name:actor.heading,exact:true}).waitFor({timeout:45000});
  check(actor.label+' uses one actual form login and reaches its workbench',loginRequests===1&&new URL(page.url()).pathname==='/index');
  const token=await page.evaluate(()=>localStorage.getItem('Admin-Token'));
  const info=await context.request.get(c.backend+'/system/user/getInfo',{headers:{clientid:c.clientId,Authorization:'Bearer '+token}}).then(response=>response.json());
  check(actor.label+' server identity and organization match the account',info.code===200&&String(info.data?.user?.userId)===String(actor.id)&&info.data?.user?.tenantId===actor.tenant);
  check(actor.label+' no authentication secret persists as a remembered form',await page.evaluate(()=>!localStorage.getItem('password')&&!localStorage.getItem('username')));
  check(actor.label+' responsive workbench has no horizontal page overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
  const file=path.join(out,actor.label+'.png');await page.screenshot({path:file,fullPage:true});report.screenshots.push({path:path.relative(process.cwd(),file).replaceAll('\\','/'),sha256:hash(file)});
  await context.close();
 }
 check('no attempted business mutation or script error',report.blockedWrites.length===0&&report.pageErrors.length===0);
 check('tournament, grants, money, results and growth facts are unchanged',before===facts());
 check('verified product sources are unchanged',report.sources.every(source=>hash(source.path)===source.sha256));
 report.passed=true;
}catch(error){report.failure={stage,reason:error.name==='AssertionError'?error.message:'Actual browser authentication or workbench loading failed; private diagnostics omitted'};process.exitCode=1;}
finally{
 await browser.close();report.finishedAt=new Date().toISOString();const file=path.join(out,'receipt.json'),fd=fs.openSync(file,'wx');try{fs.writeFileSync(fd,JSON.stringify(report,null,2));fs.fsyncSync(fd);}finally{fs.closeSync(fd);}
 console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,failure:report.failure,path:path.relative(process.cwd(),file).replaceAll('\\','/')}));
}
