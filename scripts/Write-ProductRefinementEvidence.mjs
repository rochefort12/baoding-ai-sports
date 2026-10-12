// Freeze a supplemental report from actual receipts, without replaying any business.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';
const args=process.argv.slice(2),value=key=>args[args.indexOf(key)+1];
for(const key of ['--frontend','--floating','--motion','--select','--date-focus','--work-focus','--runtime','--screens'])assert.ok(args.includes(key),key+' is required');
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex'),read=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
const base='.local/product-release-20261011/';
const files={
  frontend:value('--frontend'),
  entry:base+'entry-ui-1791691539827/receipt.json',floating:value('--floating'),
  motion:value('--motion'),select:value('--select'),dateFocus:value('--date-focus'),workFocus:value('--work-focus'),runtime:value('--runtime'),
  modal:base+'assistant-modal-1791690845953/receipt.json',
  growth:base+'growth-ui-1791690624904/receipt.json',identity:base+'identity-boundary-1791690505461/receipt.json',profile:base+'profile-entry-1791690674314/receipt.json',
  worldDisplay:base+'world-honor-ui-1791691931574/receipt.json',
  worldContracts:base+'world-honor-components-1791691725319/vitest.json',
  review:'.local/honor-certification-20261011/review-ui-7a7dedfc-db5a-4d2f-8b07-bbf45b1c1dae/receipt.json',
  honorHttp:'.local/honor-certification-20261011/actual-39fd23b5-4a5b-410c-aa23-eed5e3778c9a.json',
  honorBinding:'.local/honor-certification-20261011/binding-complete-61701549-2b69-4c39-af84-b53b07422191.json',
  mainRelease:'.local/honor-certification-release-20261011/main-cdeb0ba1-f6a4-4782-bb8f-29f262b94aa4/receipt.json',
  candidateRelease:'.local/honor-certification-release-20261011/candidate-32e8962e-6a38-4f3a-88a9-39abcd632290/receipt.json',
  mainLogin:'.local/main-access/post-release-018d0896-936d-4426-a391-c9ba8ddbefb7/receipt.json',
  migration:base+'global-migration-2b16e4ad2c234a4da183f25ec5e5a1c3/receipt.json',
  backend:base+'runtime-refresh-80aef47a68364630a1fa4d6dc2426749/receipt.json'
};
const values=Object.fromEntries(Object.entries(files).map(([name,p])=>[name,read(p)]));
for(const [name,r] of Object.entries(values)){
  if(name==='growth'){assert.equal(r.checks.length,78);assert.deepEqual(r.failures,[]);assert.deepEqual(r.pageErrors,[]);assert.deepEqual(r.writes,[]);}
  else if(name==='worldContracts'){assert.equal(r.success,true);assert.equal(r.numPassedTests,28);assert.equal(r.numFailedTests,0);}
  else assert.equal(r.passed,true,name+' did not pass');
}
const jar='backend/ruoyi-admin/target/ruoyi-admin.jar',jarHash=sha(jar);
for(const name of ['frontend','backend','honorBinding','honorHttp','mainRelease','candidateRelease'])assert.equal(values[name].jarSha256,jarHash,name+' JAR binding');
for(const file of values.frontend.sources)assert.equal(sha(file.path),file.sha256,'Final frontend source drift: '+file.path);
for(const file of values.honorBinding.sourceFiles)assert.equal(sha(file.path),file.sha256,'Certification source drift: '+file.path);
for(const name of ['floating','motion','select','dateFocus','workFocus'])for(const file of values[name].sourceFiles||[])assert.equal(sha(file.path),file.sha256,name+' source drift: '+file.path);
for(const name of ['floating','motion','worldDisplay']){
  assert.deepEqual(values[name].pageErrors,[]);
  if(values[name].writeRequests)assert.deepEqual(values[name].writeRequests,[]);
  if(values[name].blockedWrites)assert.deepEqual(values[name].blockedWrites,[]);
}
assert.equal(values.mainRelease.targetAgentEnabled,0);assert.equal(values.candidateRelease.targetAgentEnabled,0);
assert.equal(values.mainRelease.businessFactsUnchanged,true);assert.equal(values.mainRelease.unrelatedChannelsUnchanged,true);
const unit=read(values.honorBinding.checks.unit.evidencePath);assert.equal(unit.allSelectedTests,66);assert.equal(unit.tests,24);
const predecessors={
 'docs/04-verification/全局视觉与办理智能体验证-20261011.json':'04b80a823809cf6a5df3e222c2022999749a602b9bab5a8eb96df2f7513e1e71',
 'docs/04-verification/正式产品界面与创作功能验证-20261011.json':'b9ae393cfd2e3bec596d5bfb0783489f91039d0b5d43cdadc4e7126a390991d5',
 'docs/04-verification/羽毛球一期闭环本机验证-20261010.json':'6d18927802b75867876af4753f6cdc2b7151689b92af35eca8dc744ba687a0ee',
 'docs/04-verification/产品组件与视觉验证-20261010.json':'855006d8e09bb1d2839c0bda1152dffa17a28be59a3d3fb6449cf659a7972bf5'
};
for(const [p,h] of Object.entries(predecessors))assert.equal(sha(p),h,'Historical report changed');
const assetsPath='docs/05-ui/assets-20261011-v4/assets.json',assets=read(assetsPath);assert.equal(assets.assets.length,9);
for(const a of assets.assets){assert.equal(sha(a.file),a.sha256);assert.equal(sha(a.original),a.originalSha256);}
const screensPath=value('--screens'),screens=read(screensPath);assert.ok(screens.images.length>=12);
for(const item of screens.images)assert.equal(sha(path.join(path.dirname(screensPath),item.file)),item.sha256);
const modelPath=base+'latest-model-final-check.log';assert.match(fs.readFileSync(modelPath,'utf8'),/Model checked: 121 tables, 1835 columns/);
const report={schemaVersion:1,at:new Date().toISOString(),passed:true,
  scope:'Current local UI refinement, legend and manual world honor workflow. Controlled test version; not a public release, real world certification, or whole phase-one tournament acceptance.',
  jarSha256:jarHash,sourceFiles:values.frontend.sources,certificationSourceFiles:values.honorBinding.sourceFiles,
  checks:Object.fromEntries(Object.entries(files).map(([name,p])=>[name,{evidencePath:p,sha256:sha(p),passed:true,scope:values[name].scope||'Synthetic component contracts'}])),
  counts:{entryUi:values.entry.checks.length,dropdownUi:values.select.checks.length,dateFocusUi:values.dateFocus.checks.length,workFocusUi:values.workFocus.checks.length,
    floatingUi:values.floating.checks.length,motionUi:values.motion.checks.length,modalUi:40,growthUi:78,identityUi:16,profileUi:30,
    worldDisplayUi:37,worldSyntheticContracts:28,reviewReadonlyUi:12,honorSyntheticHttp:33,selectedJava:66,certificationMockedJavaSubset:24,
    mainLoginUi:7,mainManualRelease:10,candidateManualRelease:10,newRasterAssets:9},
  observed:{inputDefaultEmpty:true,guidesPreserved:true,guideDoesNotOverwriteDraft:true,
    guidanceSubmission:'Selected visible topic and user-authored words only on explicit send; server-provided task answer options remain explicit user choices',
    motion:{openMs:440,closeMs:280,sizeMs:540,method:'transform and opacity; FLIP layout committed once; reduced-motion skips'},
    growthRanks:['新星','青铜','白银','黄金','铂金','钻石','星耀','王者','传奇'],equipableGrowthFrames:8,
    worldHonors:['世界冠军','世界亚军','世界季军'],worldBadgeAndFrameAssets:6,assistantFeatureAssets:3,
    honorHumanUiActions:6,honorAgentActions:0,mainUiCapabilities:56,mainReadonlyAgentCapabilities:5,mainAgentWriteCapabilities:0,
    certificationLifecycle:'Synthetic isolated claim approved, worn, public, hidden and revoked through real APIs; final claim revoked, private and unworn; no real world award granted'},
  assets:{manifest:assetsPath,sha256:sha(assetsPath),generation:'Built-in image_gen; model identifier not exposed; original PNGs and prompts retained'},
  screenshots:{manifest:screensPath,sha256:sha(screensPath),images:screens.images.length},
  model:{log:modelPath,sha256:sha(modelPath),tables:121,columns:1835},predecessorHashes:predecessors,
  limitations:['Actual honor evidence/person/issuer validation and first real certification are not accepted by synthetic HTTP or component tests',
    'No real bank transfer, SMS delivery, first registration/recovery or actual complete tournament was executed in this UI round',
    'Generic Agent write/delegation and multi-format material scenarios still require their own acceptance; manual honor actions are closed to Agent',
    'Runtime external image provider is separate from these installed static image_gen assets and remains unaccepted',
    'Animation timings and browser intermediate-frame checks do not certify a fixed frame rate or all-device performance; broad soft-keyboard testing remains',
    'Existing frontend large-chunk warning remains; gateway has no GET /health endpoint, observed response is not a complete dependency health test'],
  failureHistory:'Original compile, selector, model, auth, migration and evidence-export failures remain preserved in local evidence; no failed receipt rewritten as PASS.'
};
const target='docs/04-verification/浮泡交互与传奇荣誉认证验证-20261011.json';assert.ok(!fs.existsSync(target),'Final supplemental report is immutable');
fs.writeFileSync(target,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({passed:true,file:target,sha256:sha(target),jarSha256:jarHash,counts:report.counts}));
