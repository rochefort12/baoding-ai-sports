// Publish only sanitized, verifiable metadata; never copy private context,
// credentials, raw materials or full model messages to a public report.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {context as c,createEvidence} from './lib/BusinessRegression.mjs';
const test=createEvidence('final-business-report');
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const read=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const rel=file=>path.relative(process.cwd(),fs.realpathSync(file)).replaceAll('\\','/');
function record(file,label){const value=read(file);assert.equal(value.passed,true,label+' must have passed');return {label,path:rel(file),sha256:hash(file),checks:Array.isArray(value.checks)?value.checks.length:null};}
try{
  const output='docs/04-verification/羽毛球一期多账号全流程测试-20261011.json';
  assert.ok(!fs.existsSync(output),'A published report is immutable; use a new linked generation after publication.');
  const bindingFile=path.join(c.out,'candidate-final-binding-1791703963854-f9c972e0/binding.json');
  const binding=read(bindingFile);assert.equal(binding.passed,true);
  for(const source of binding.sourceFiles)assert.equal(hash(source.path),source.sha256,'Verified product source changed: '+source.path);
  for(const evidence of binding.requiredEvidence)assert.equal(hash(evidence.path),evidence.sha256,'Original accepted evidence changed');
  const predecessorFile='docs/04-verification/浮泡交互与传奇荣誉认证验证-20261011.json';
  assert.equal(hash(predecessorFile),'63e6eb81e82bc610056bffd4cbd0e04890b17e1aa454c5acda2d57263c155d44');
  const predecessor=read(predecessorFile),predecessorHashes={...predecessor.predecessorHashes,[predecessorFile]:hash(predecessorFile)};
  for(const [file,expected] of Object.entries(predecessorHashes))assert.equal(hash(file),expected,'Frozen prior report changed');
  const mainFile='.local/main-access/business-regression-ed4ae9860a6144ad93ae1cf34e232fb4/receipt.json';
  const main=read(mainFile);assert.equal(main.passed,true);assert.equal(main.businessFactsUnchanged,true);assert.equal(main.jarSha256,binding.backendJarSha256);
  const extra=read(process.argv[2]);
  const supplemental=Object.entries(extra).map(([label,file])=>record(file,label));
  test.check('accepted product sources, original business gates and five frozen predecessor reports remain unchanged',true);
  test.check('the actual main package promotion kept 46 business tables and all channel flags',main.fingerprintTableCount===46&&main.uiEnabled===56&&main.agentEnabled===5&&main.agentWrites===0);
  const indices=read(process.argv[3]);
  const indexRecords=Object.entries(indices).map(([label,file])=>({label,path:rel(file),sha256:hash(file)}));
  const report={schemaVersion:'1.0',at:new Date().toISOString(),runId:c.runId,state:'LOCAL_MULTI_ROLE_SYNTHETIC_BADMINTON_REGRESSION_PASSED_WITH_EXTERNAL_GATES_OPEN',passed:true,scope:'Ordinary-role real HTTP, UI, PostgreSQL transactions, private storage and model calls; synthetic people, materials, money, scores and award grounds. Not whole-phase real-world acceptance.',sites:{main:'http://127.0.0.1:5190/portal/home',isolated:'http://127.0.0.1:5192/portal/home'},roleCoverage:['ordinary organizer','scoped ordinary government reviewer','six ordinary participants','platform operator only for setup and explicit external-honor verification duty'],backend:binding.backendBuild,backendJarSha256:binding.backendJarSha256,sourceBinding:{path:rel(bindingFile),sha256:hash(bindingFile),sourceFileCount:binding.sourceFiles.length},frontend:binding.frontendBuild,acceptedGates:binding.requiredEvidence,supplemental,indices:indexRecords,main:{evidence:record(mainFile,'tested-main-package-install'),pid:main.mainPid,jarSha256:main.jarSha256,priorJarSha256:main.priorJarSha256,backupSha256:main.backupSha256,businessFingerprintTables:46,businessFactsUnchanged:true,uiEnabled:56,readOnlyAgentEnabled:5,agentWrites:0,rebound:main.rebound.map(row=>({code:row.code,channel:row.channel,definitionHash:row.definitionHash}))},historicalReports:predecessorHashes,limitations:binding.limitations.concat(['Natural 24-hour handover expiration and long-term retention remain unobserved.','Three legacy attribute catalog tables are model/module-only and remain outside enabled badminton workflows.','Generic Agent write tools and unverified cross-domain delegated actions remain closed.','Test counts include repeated prerequisites and must not be summed into business delivery or project completion.']),countsAreNotProgress:true,noRealWorldAwardClaim:true};
  const body=JSON.stringify(report,null,2);
  const stage=output+'.'+crypto.randomUUID()+'.stage';
  const fd=fs.openSync(stage,'wx');
  try{fs.writeFileSync(fd,body);fs.fsyncSync(fd);}finally{fs.closeSync(fd);}
  assert.ok(!fs.existsSync(output),'A published report is immutable.');
  fs.renameSync(stage,output);
  test.evidence.report={path:output,sha256:hash(output)};test.finish();
  console.log('Public report: '+output);console.log('SHA256: '+hash(output));
}catch(error){test.evidence.failure=error.message;test.save();console.error(error.message);process.exitCode=1;}
