// Seal only observed, bounded login evidence; preserve every prior failure.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const root=process.cwd();
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const read=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const run='.local/business-regression-20261011/626cd3f32f36461984a58973a8bab828/';
const local='.local/login-refinement-20261011/';
const install=local+'main-release-b9077082fa5f4ebf9eb54cc6fdc9a6b3/';
const cases=[
 ['backend-build',local+'backend-292da4a7acf345da9fab2ae62aea59ba/receipt.json'],
 ['frontend-build','.local/product-release-20261011/frontend-refinement-f46df6e570b14f2e9b0f92d8fa282edf/receipt.json'],
 ['candidate-account-api',run+'work-account-auto-tenant-1791706347708-378f53c0/receipt.json'],
 ['candidate-responsive-layout',local+'ui-3e030a64-1cb4-482b-b0fe-e22e1be2d920/receipt.json'],
 ['candidate-actual-form-login',local+'authenticated-ui-9b3b27f9-46f7-4d85-bca7-545963436048/receipt.json'],
 ['main-installation-completion',install+'completion-6e635592c22247c9b6a14890dbce9bf0/receipt.json'],
 ['main-responsive-layout',local+'ui-9278462b-f833-4f39-8e0a-1c32a8c5697d/receipt.json'],
 ['main-actual-form-login',local+'main-auth-ui-f8bb0d3f-0abd-4485-8f1e-9bab122b54fe/receipt.json'],
 ['runtime-checkpoint',local+'checkpoint-d66e3167aa4d46b2af9b3390f73fdec8.json'],
 ['stable-main-screenshots','docs/05-ui/work-login-20261011/screenshots.json']
];
const evidence=cases.map(([gate,file])=>{const value=read(file);assert.equal(value.passed,true,gate);if(value.checks?.length&&typeof value.checks[0]!=='string')assert.ok(value.checks.every(check=>check.passed===true),gate);for(const source of value.sources||[])assert.equal(hash(source.path),source.sha256,'A verified source changed');for(const shot of value.screenshots||[])assert.equal(hash(shot.path),shot.sha256,'A verified screenshot changed');return {gate,path:file,sha256:hash(file),passed:true,checks:Array.isArray(value.checks)?value.checks.length:undefined,scope:value.scope};});
const main=read(cases[5][1]);const checkpoint=read(cases[8][1]);
assert.equal(main.jarSha256,'6320dee809a26392b6065fdbcd3d5fdf7f14c551b1ba4c92745aaef22134598b');
assert.equal(main.mainPid,59180);assert.equal(checkpoint.packages.find(item=>item.port===8080).pid,main.mainPid);
for(const runtime of checkpoint.packages)assert.equal(hash(runtime.jarPath),main.jarSha256);
assert.equal(main.businessFactsUnchanged,true);assert.equal(main.catalogUnchanged,true);assert.equal(main.agentWrites,0);
const sourceBinding=install+'source-binding.json';assert.equal(hash(sourceBinding),main.sourceBindingSha256);
for(const source of read(sourceBinding).sources)assert.equal(hash(source.path),source.sha256,'Release source changed');
const failures=[
 [run+'work-account-auto-tenant-1791706045577-bca469aa/receipt.json','Node child process referenced an absent PowerShell executable. No authentication or fixture creation occurred; corrected test entry passed independently.'],
 [local+'main-release-90c54ec59d2047fdadf0f5709c86e528/receipt.json','Protected saved session returned 401 before backup or stop. Original password reauthentication recovered the session; no reset.'],
 [install+'receipt.json','Installation succeeded but exact JSON serialization comparison incorrectly treated JVM set and object order as changes. Original failed receipt remains false.'],
 [install+'completion-52f060d346d140a6b005b324f3745f41/receipt.json','Set normalization still compared JSON object property order. Original failure preserved.'],
 [install+'completion-c8fbcb611c3d4c3ca42850059197fbd8/receipt.json','All content and 46 table checks passed; an empty events array was unwrapped by PowerShell and mistakenly classified as missing. Original failure preserved.']
].map(([file,reason])=>{assert.equal(read(file).passed,false);return {path:file,sha256:hash(file),passed:false,reason};});
const historical=[
 ['docs/04-verification/羽毛球一期多账号全流程测试-20261011.json','ba6ea409563f6fbd4ac095ab63bb950989aaa15ef2ad074b58f5da742ca39aba'],
 ['docs/04-verification/浮泡交互与传奇荣誉认证验证-20261011.json','63e6eb81e82bc610056bffd4cbd0e04890b17e1aa454c5acda2d57263c155d44'],
 ['docs/04-verification/全局视觉与办理智能体验证-20261011.json','04b80a823809cf6a5df3e222c2022999749a602b9bab5a8eb96df2f7513e1e71'],
 ['docs/04-verification/正式产品界面与创作功能验证-20261011.json','b9ae393cfd2e3bec596d5bfb0783489f91039d0b5d43cdadc4e7126a390991d5'],
 ['docs/04-verification/羽毛球一期闭环本机验证-20261010.json','6d18927802b75867876af4753f6cdc2b7151689b92af35eca8dc744ba687a0ee'],
 ['docs/04-verification/产品组件与视觉验证-20261010.json','855006d8e09bb1d2839c0bda1152dffa17a28be59a3d3fb6449cf659a7972bf5']
].map(([file,sha256])=>{assert.equal(hash(file),sha256,'Prior report changed');return {path:file,sha256,unchanged:true};});
const report={at:new Date().toISOString(),passed:true,status:'LOCAL_WORK_LOGIN_REFINEMENT_PASSED_WITH_WECHAT_AUTHORIZATION_PENDING',scope:'Current work-password identity selection, work login visual layout and local package installation. This does not replace earlier tournament acceptance or prove real WeChat OAuth.',version:{branch:'ai-feature',backendJarSha256:main.jarSha256,priorMainJarSha256:'03da46e9cef78f6d72e4c9ebf79840652b7a91fc9ad6e7f01562ace32afd7d07',mainPid:main.mainPid,candidatePid:41152},observed:{backendTests:415,backendFailures:0,backendErrors:0,backendSkipped:0,candidateApiChecks:30,candidateFormChecks:27,candidateLayoutChecks:178,mainLayoutChecks:140,mainFormChecks:8,mainCompletionChecks:main.checks.length,mainBusinessTablesUnchanged:46,uiEnabled:main.uiEnabled,agentEnabled:main.agentEnabled,agentWrites:0,wechatAvailable:false},sourceBinding:{path:sourceBinding,sha256:hash(sourceBinding),provenance:'Backend compiler inputs, source/build timing and packaged class equality; release-time hashes, not a pre-build hash manifest. Frontend type/build source hashes unchanged.'},evidence,failures,historicalReports:historical,limits:['Real WeChat OAuth, state/callback and uniquely bound work identity are pending.','Actual HTTP uses captcha disabled; enabled captcha, stopped/expired tenants, consecutive failure locks and mapped identity restrictions are unit-test evidence only in this run.','Candidate workbench headings and identities passed; candidate tests do not assert all summary requests completed. Main administrator metrics loading was separately observed.','The legacy anonymous tenant-directory compatibility endpoint still exists; the new work login does not request it.','Synthetic organization fixtures were created only through public APIs in the isolated database; no tournament facts or existing roles were changed.','Viewports are browser emulation, not physical phone or soft-keyboard testing.','Previous real bank, SMS, physical tournament and general Agent write acceptance remain separate outstanding conditions.']};
const file=path.join(root,'docs/04-verification/工作账号自动组织与登录布局验证-20261011.json');const fd=fs.openSync(file,'wx');try{fs.writeFileSync(fd,JSON.stringify(report,null,2));fs.fsyncSync(fd);}finally{fs.closeSync(fd);}
console.log(JSON.stringify({passed:report.passed,status:report.status,sha256:hash(file),path:path.relative(root,file).replaceAll('\\','/')}));
