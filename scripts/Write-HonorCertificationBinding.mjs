// Bind observed tests and sources to a selective local UI activation; does not release anything.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const root=process.cwd(),args=process.argv.slice(2),value=name=>args[args.indexOf(name)+1];
assert.ok(args.includes('--preflight')&&args.includes('--build-log'));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(path.resolve(root,file))).digest('hex');
const read=file=>JSON.parse(fs.readFileSync(path.resolve(root,file),'utf8').replace(/^\uFEFF/,''));
const preflightPath=value('--preflight'),buildPath=value('--build-log'),preflight=read(preflightPath);
const log=fs.readFileSync(buildPath,'utf8');assert.ok(log.includes('BUILD SUCCESS'));
const observed=[...log.matchAll(/Tests run: (\d+), Failures: (\d+), Errors: (\d+), Skipped: (\d+),.* -- in ([\w.]+)/g)].map(m=>({name:m[5],tests:+m[1],failures:+m[2],errors:+m[3],skipped:+m[4]}));
assert.ok(observed.length>=13&&observed.every(t=>t.failures===0&&t.errors===0&&t.skipped===0));
const selected=['HonorCertificationTest','HonorProofStorageTest','HonorProofCleanupTest'];
const certification=observed.filter(t=>selected.some(name=>t.name.endsWith('.'+name)));assert.equal(certification.length,3);
const tests=certification.reduce((n,t)=>n+t.tests,0);assert.equal(tests,24);
const releaseSource=fs.readFileSync('scripts/Release-HonorCertificationUi.mjs','utf8');
const block=releaseSource.match(/const requiredSources=\[([\s\S]*?)\];/);assert.ok(block);
const sources=[...block[1].matchAll(/'([^']+)'/g)].map(m=>m[1]);
for(const p of ['scripts/Release-HonorCertificationUi.ps1','scripts/Release-HonorCertificationUi.mjs','scripts/Write-HonorCertificationBinding.mjs'])sources.push(p);
assert.equal(new Set(sources).size,sources.length);
const codes=['save','submit','review','wear','visibility','proof.upload'].map(v=>'honor.certification.'+v);
assert.deepEqual(preflight.definitions.map(d=>d.code).sort(),[...codes].sort());assert.ok(preflight.definitions.every(d=>d.agent===false&&/^[a-f0-9]{64}$/.test(d.definitionHash)));
assert.equal(preflight.sourceSha256,sha('scripts/Test-HonorCertification.mjs'));
const out='.local/honor-certification-20261011',id=crypto.randomUUID();fs.mkdirSync(out,{recursive:true});
const unitPath=out+'/unit-'+id+'.json';fs.writeFileSync(unitPath,JSON.stringify({passed:true,scope:'Selected Java tests; mocked dependencies where declared, not a real championship verification.',tests,selected:certification,allSelectedTests:observed.reduce((n,t)=>n+t.tests,0),build:{path:buildPath,sha256:sha(buildPath)},jarSha256:sha('backend/ruoyi-admin/target/ruoyi-admin.jar')},null,2),{flag:'wx'});
const report={schemaVersion:1,scope:'local-honor-certification-ui',passed:true,at:new Date().toISOString(),jarSha256:sha('backend/ruoyi-admin/target/ruoyi-admin.jar'),sourceFiles:sources.map(p=>({path:p,sha256:sha(p)})),definitionHashes:Object.fromEntries(preflight.definitions.map(d=>[d.code,d.definitionHash])),checks:{unit:{evidencePath:unitPath,sha256:sha(unitPath),passed:true,tests},preflight:{evidencePath:preflightPath,sha256:sha(preflightPath),passed:true}}};
if(args.includes('--http')){const p=value('--http'),http=read(p);assert.equal(http.passed,true);assert.equal(http.jarSha256,report.jarSha256);assert.equal(http.sourceSha256,sha('scripts/Test-HonorCertification.mjs'));assert.ok(http.checks.length>0&&http.checks.every(c=>c.status==='PASS'));report.checks.http={evidencePath:p,sha256:sha(p),passed:true};}
const target=out+'/binding-'+(args.includes('--http')?'complete-':'candidate-')+id+'.json';fs.writeFileSync(target,JSON.stringify(report,null,2),{flag:'wx'});console.log(JSON.stringify({passed:true,path:target,sha256:sha(target),jarSha256:report.jarSha256,unitTests:tests}));
