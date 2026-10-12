// Exactly six manual honor UI capabilities. Administrative release API only; SQL is read-only.
// Invoke through the PowerShell 7 wrapper for live PID/listener guards and protected credentials/receipts.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';

const root=process.cwd(),args=process.argv.slice(2),main=args.includes('--main'),preflightOnly=args.includes('--preflight-only');
const codes=['save','submit','review','wear','visibility','proof.upload'].map(code=>'honor.certification.'+code);
const requiredSources=[
 'backend/aisports-domains/d10/aisports-table-honor/src/main/java/org/dromara/sports/tables/d10/honor/HonorCertificationController.java',
 'backend/aisports-domains/d10/aisports-table-honor/src/main/java/org/dromara/sports/tables/d10/honor/HonorCertificationService.java',
 'backend/aisports-domains/d10/aisports-table-honor/src/main/java/org/dromara/sports/tables/d10/honor/HonorCertificationRules.java',
 'backend/aisports-domains/d10/aisports-table-honor/src/test/java/org/dromara/sports/tables/d10/honor/HonorCertificationTest.java',
 'backend/aisports-domains/d01/aisports-table-organization-application/src/main/java/org/dromara/sports/organization/service/StoredObjectApiImpl.java',
 'backend/aisports-domains/d01/aisports-table-organization-application/src/main/java/org/dromara/sports/organization/service/UnreferencedFileCleanup.java',
 'backend/aisports-api/src/main/java/org/dromara/sports/api/HonorDisplayApi.java',
 'backend/aisports-api/src/main/java/org/dromara/sports/api/StoredObjectApi.java',
 'database/migrations/V038__personal_honor_certification.sql',
 'plus-ui/src/api/sports/honorCertification.ts',
 'plus-ui/src/components/business/HonorCertificationReview.vue',
 'plus-ui/src/components/consumer/HonorCertification.vue',
 'scripts/Test-HonorCertification.mjs'
];
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function guard(condition,message){if(!condition){const error=new Error(message);error.safe=true;throw error;}}
function workspaceFile(value,maxBytes=64*1024*1024){
 guard(typeof value==='string'&&value.length>0,'A bounded workspace path is required.');
 const absolute=path.resolve(root,value),relative=path.relative(root,absolute);
 guard(relative&&relative!=='..'&&!relative.startsWith('..'+path.sep)&&!path.isAbsolute(relative),'A release path escaped the workspace.');
 for(let cursor=absolute;cursor!==root;cursor=path.dirname(cursor))guard(!fs.lstatSync(cursor).isSymbolicLink(),'A release path contains a link or reparse point.');
 const stat=fs.statSync(absolute);guard(stat.isFile()&&stat.size>0&&stat.size<=maxBytes,'An evidence/source file is empty, oversized or not ordinary.');return absolute;
}
const hashFile=value=>digest(fs.readFileSync(workspaceFile(value,1024*1024*1024)));
const readJson=value=>JSON.parse(fs.readFileSync(workspaceFile(value),'utf8').replace(/^\uFEFF/,''));
const relative=value=>path.relative(root,value).replaceAll('\\','/');
let receipt,out,lockFile,lockFd,lockOwner,base,token,database,report,evidencePath,evidenceHash,beforeRows,beforeFacts;
const changed=[],attempted=[],checks=[],bindings=[];
function record(name){checks.push({name,passed:true,at:new Date().toISOString()});}
function frozen(name,value){const file=path.join(out,name),fd=fs.openSync(file,'wx');try{fs.writeFileSync(fd,JSON.stringify(value,null,2)+'\n');fs.fsyncSync(fd);}finally{fs.closeSync(fd);}return {path:relative(file),sha256:hashFile(file)};}
const pgBin='C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin/';
function pg(tool,parameters,input){const result=spawnSync(pgBin+tool,parameters,{input,encoding:'utf8',maxBuffer:512*1024*1024,env:{...process.env,PGPASSWORD:process.env.POSTGRES_PASSWORD}});guard(result.status===0,'A local PostgreSQL backup/read operation failed; raw output is withheld.');return result.stdout;}
function sql(query){guard(/^\s*(SELECT|BEGIN)\b/.test(query)&&! /\b(INSERT|UPDATE|DELETE|ALTER|CREATE|DROP|TRUNCATE)\b/i.test(query),'Release SQL must be read-only.');return pg('psql.exe',['-X','-q','-h','127.0.0.1','-p','25432','-U',process.env.POSTGRES_USER,'-d',database,'-At','-v','ON_ERROR_STOP=1'],query).trim();}
function activationRows(){return JSON.parse(sql("SELECT COALESCE(json_agg(t ORDER BY t.code,t.channel),'[]'::json)::text FROM (SELECT a.id::text,a.code,a.channel,a.enabled,a.capability_version_id::text,a.version,v.source_hash,v.revision,v.status FROM asp_capability_activation a LEFT JOIN asp_capability_version v ON v.id=a.capability_version_id AND v.code=a.code) t;"));}
function unrelated(rows){return JSON.stringify(rows.filter(row=>!(row.channel==='ui'&&codes.includes(row.code))).sort((a,b)=>(a.code+'|'+a.channel).localeCompare(b.code+'|'+b.channel)));}
function facts(){
 const tables=['event','team_room','registration','fee_obligation','payment','refund','result_version','growth_record','title_equipment','honor'];
 const statements=tables.map(table=>`SELECT '${table}'||E'\\t'||count(*)||E'\\t'||COALESCE(json_agg(row_to_json(t) ORDER BY id)::text,'[]') FROM asp_${table} t;`);
 const lines=sql('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;\n'+statements.join('\n')+'\nCOMMIT;').split(/\r?\n/);guard(lines.length===tables.length,'Ten business tables must be fingerprinted completely.');
 return lines.map((line,index)=>{const first=line.indexOf('\t'),second=line.indexOf('\t',first+1);guard(first>0&&second>first&&line.slice(0,first)===tables[index]&&/^\d+$/.test(line.slice(first+1,second)),'A complete business fingerprint is malformed.');return {table:'asp_'+tables[index],rows:line.slice(first+1,second),sha256:digest(Buffer.from(line.slice(second+1),'utf8'))};});
}
function latestAudit(code){guard(codes.includes(code),'Only an exact honor UI release audit may be read.');return JSON.parse(sql(`SELECT COALESCE((SELECT json_build_object('id',id::text,'result',result_reference) FROM asp_action_execution WHERE action_code='capability.release' AND result_reference->>'code'='${code}' AND result_reference->>'channel'='ui' ORDER BY occurred_at DESC,id DESC LIMIT 1),'{}'::json)::text;`));}
async function api(route,method='GET',input){
 guard(['/sports/platform/management','/sports/platform/management/release'].includes(route),'Only fixed local administrative routes are allowed.');
 let response,body;try{response=await fetch(base+route,{method,redirect:'error',signal:AbortSignal.timeout(25000),headers:{clientid:'e5cd7e4891bf95d1d19206ce24a7b32e',Authorization:'Bearer '+token,'Content-Type':'application/json'},...(input?{body:JSON.stringify(input)}:{})});body=await response.json();}catch{guard(false,'A fixed local administrator request failed; raw credentials and response bodies are withheld.');}
 guard(response.ok&&body?.code===200,'The current local administrator request was rejected.');return body.data;
}
function allPassed(items){const clean=check=>check&&check.passed!==false&&(!check.status||check.status==='PASS')&&!check.error&&(check.passed===true||check.status==='PASS');if(Array.isArray(items))return items.length>0&&items.every(clean);return items&&Object.keys(items).length>0&&Object.values(items).every(check=>check?.passed===true&&clean(check));}
function validateEvidence(){
 guard(hashFile(evidencePath)===evidenceHash,'The frozen binding changed.');
 for(const binding of bindings)guard(hashFile(binding.path)===binding.sha256,'A bound source/test artifact changed.');
 guard(hashFile('backend/ruoyi-admin/target/ruoyi-admin.jar')===report.jarSha256,'The current verified JAR changed.');
}
function target(rows,code){const found=rows.filter(row=>row.code===code&&row.channel==='ui');guard(found.length<=1,'Duplicate target activations are not allowed.');return found[0];}
function assertManualRows(rows){guard(!rows.some(row=>codes.includes(row.code)&&row.channel==='agent'&&row.enabled),'No honor Agent activation may be enabled, including invalid version pointers.');}
function assertCatalog(catalog){
 guard(Array.isArray(catalog?.definitions)&&Array.isArray(catalog?.activations),'The capability catalog is unavailable.');
 for(const code of codes){const found=catalog.definitions.filter(row=>row.definition?.code===code);guard(found.length===1&&found[0].definitionHash===report.definitionHashes[code],'A current capability definition differs from its bound hash.');const definition=found[0].definition;guard(definition.agent===false&&definition.mutation===true&&definition.inputSchema.required.includes('expectedVersion'),'All six contracts must be manual, mutable and versioned.');guard(!catalog.activations.some(row=>row.code===code&&row.channel==='agent'&&row.enabled),'Honor Agent activation must stay closed.');}
}
async function setEnabled(code,enabled){guard(!preflightOnly&&codes.includes(code)&&typeof enabled==='boolean','Only six UI flags may be released.');await api('/sports/platform/management/release','POST',{code,channel:'ui',enabled,definitionHash:report.definitionHashes[code],evidenceHash});}

try {
 guard(args.filter(value=>value==='--evidence').length===1&&args.filter(value=>value==='--jar-sha256').length===1,'Exactly one evidence path and expected JAR hash are required.');
 evidencePath=workspaceFile(args[args.indexOf('--evidence')+1]);const expectedJar=args[args.indexOf('--jar-sha256')+1]?.toLowerCase();guard(/^[a-f0-9]{64}$/.test(expectedJar||''),'An expected JAR SHA256 is required.');
 const runtimeGuard=JSON.parse(process.env.AISPORTS_HONOR_RUNTIME_GUARD||'null');guard(runtimeGuard?.port===(main?8080:8082)&&runtimeGuard.jarSha256===expectedJar&&Number.isInteger(runtimeGuard.pid)&&runtimeGuard.pid>0,'Invoke the guarded PowerShell wrapper.');
 const releaseRoot=path.resolve(root,'.local/honor-certification-release-20261011');guard(process.env.AISPORTS_HONOR_RELEASE_ROOT===releaseRoot,'A wrapper-protected receipt destination is required.');
 guard(!fs.lstatSync(path.join(root,'.local')).isSymbolicLink()&&!fs.lstatSync(releaseRoot).isSymbolicLink(),'Protected release ancestry cannot contain links.');
 lockOwner=crypto.randomUUID();lockFile=path.join(releaseRoot,'activation.lock');lockFd=fs.openSync(lockFile,'wx');fs.writeFileSync(lockFd,lockOwner);fs.fsyncSync(lockFd);
 out=path.join(releaseRoot,(main?'main-':'candidate-')+lockOwner);fs.mkdirSync(out);
 receipt={schemaVersion:1,scope:'local-honor-certification-ui',startedAt:new Date().toISOString(),endpoint:'http://127.0.0.1:'+(main?8080:8082),main,preflightOnly,passed:false,activated:false,checks,attempted,changed,restoration:'not_required',runtime:runtimeGuard,limitations:['Only six manual UI activation flags; no Agent activation or direct business writes.','Synthetic certification tests do not certify an actual championship.','The database backup is inspected but never automatically restored; rollback restores prior flags using the current verified definitions.']};
 evidenceHash=hashFile(evidencePath);report=readJson(evidencePath);
 guard(report.schemaVersion===1&&report.scope==='local-honor-certification-ui'&&report.passed===true&&report.jarSha256===expectedJar&&!report.error&&(!('failures' in report)||report.failures===0),'A passed current honor UI binding is required.');
 guard(Array.isArray(report.sourceFiles)&&allPassed(report.checks),'All binding checks must pass.');
 guard(report.checks.unit?.passed===true&&report.checks.unit.tests>=24&&report.checks.preflight?.passed===true,'At least 24 passed unit tests and a passed preflight binding are required.');
 guard(JSON.stringify(Object.keys(report.definitionHashes||{}).sort())===JSON.stringify([...codes].sort()),'The binding must contain exactly the six manual certification definitions.');
 for(const code of codes)guard(/^[a-f0-9]{64}$/.test(report.definitionHashes[code]),'Each definition must have a SHA256 binding.');
 const sources=new Set();for(const source of report.sourceFiles){guard(typeof source.path==='string'&&/^[a-f0-9]{64}$/.test(source.sha256),'A source hash is invalid.');guard(!sources.has(source.path),'Duplicate source bindings are not accepted.');sources.add(source.path);bindings.push({path:workspaceFile(source.path),sha256:source.sha256});}
 for(const source of requiredSources)guard(sources.has(source),'A required certification/security/UI source is not bound.');
 for(const check of Object.values(report.checks)){guard(typeof check.evidencePath==='string'&&/^[a-f0-9]{64}$/.test(check.sha256),'Each passed check must bind an immutable artifact.');bindings.push({path:workspaceFile(check.evidencePath),sha256:check.sha256});}
 validateEvidence();
 const preflight=readJson(report.checks.preflight.evidencePath);guard(Array.isArray(preflight.definitions)&&preflight.definitions.length===codes.length,'Preflight must inspect exactly six definitions.');
 for(const code of codes){const found=preflight.definitions.filter(row=>row.code===code);guard(found.length===1&&found[0].agent===false&&found[0].definitionHash===report.definitionHashes[code],'Preflight definition or manual channel binding differs.');}
 guard(preflight.passed!==false&&!preflight.error,'A failed preflight cannot release candidates.');
 if(main){const check=report.checks.http;guard(check?.passed===true,'Main requires a complete passed certification HTTP receipt, not preflight alone.');const http=readJson(check.evidencePath);guard(http.passed===true&&http.jarSha256===expectedJar&&http.sourceSha256===hashFile('scripts/Test-HonorCertification.mjs')&&/^aisports_verify_phase1_[a-f0-9]{32}$/.test(http.database||'')&&allPassed(http.checks)&&!http.error,'Main requires the complete same-JAR isolated HTTP certification flow.');
  const mandatory=['private synthetic proof really round-trips through object storage','foreign participant cannot fetch private proof bytes','generic organizer media cannot expose honor-proof purpose','ordinary government role cannot review external world honors','owner cannot approve their own external honor','approved title comes from reviewer confirmed year event sport and place','both explicit consents reveal only derived approved facts','turning honor consent off immediately removes public display','revocation simultaneously disables wear and public display','revoked synthetic title cannot be worn again','decision history retains correction approval and revocation','synthetic participant display preferences restore via a new real action'];for(const name of mandatory)guard(http.checks.some(value=>value.name===name),'The complete final HTTP flow is missing a required certification/security check.');}
 receipt.evidence={path:relative(evidencePath),sha256:evidenceHash};receipt.jarSha256=expectedJar;record('Current JAR, required sources, all passed checks and exact six definitions bound');
 guard(process.env.POSTGRES_DB==='aisports'&&process.env.POSTGRES_PORT==='25432'&&process.env.POSTGRES_USER&&process.env.POSTGRES_PASSWORD,'The fixed local PostgreSQL configuration is required.');
 if(main){database='aisports';token=process.env.AISPORTS_MAIN_ADMIN_TOKEN;guard(token,'Protected main administrator token required.');}
 else {const runtime=readJson('.local/phase1-implementation/verification-runtime.json'),session=readJson('.local/phase1-implementation/verification-session.json');guard(runtime.port===8082&&runtime.pid===runtimeGuard.pid&&runtime.jarSHA256===expectedJar&&/^aisports_verify_phase1_[a-f0-9]{32}$/.test(runtime.database)&&session.database===runtime.database&&session.admin?.token,'Existing isolated runtime and administrator session must match.');database=runtime.database;token=session.admin.token;guard(preflight.database===database,'Preflight belongs to a different rehearsal.');}
 base=receipt.endpoint;receipt.database=database;
 const catalog=await api('/sports/platform/management');assertCatalog(catalog);beforeRows=activationRows();assertManualRows(beforeRows);beforeFacts=facts();
 receipt.catalogBefore=frozen('catalog-before.json',catalog);receipt.activationsBefore=frozen('activation-before.json',beforeRows);receipt.businessBefore=beforeFacts;
 receipt.prior=codes.map(code=>{const row=target(beforeRows,code);return {code,existed:!!row,enabled:!!row?.enabled,sourceHash:row?.source_hash||null,latestAudit:latestAudit(code)};});record('Real administrator, current catalog and ten complete business row fingerprints frozen');
 const backup=path.join(out,'before.dump');pg('pg_dump.exe',['-h','127.0.0.1','-p','25432','-U',process.env.POSTGRES_USER,'-d',database,'-Fc','-f',backup]);const archive=pg('pg_restore.exe',['--list',backup]);guard(fs.statSync(backup).size>0&&archive.includes('asp_honor'),'The actual backup must contain the honor table and a readable archive catalog.');receipt.backup={path:relative(backup),sha256:hashFile(backup),bytes:fs.statSync(backup).size,validation:'pg_restore --list; no automatic restore'};record('Actual protected database backup and archive table catalog validated');
 validateEvidence();guard(unrelated(activationRows())===unrelated(beforeRows),'Unrelated activation rows changed during preparation.');guard(JSON.stringify(facts())===JSON.stringify(beforeFacts),'Business rows changed during release preparation.');
 if(preflightOnly){receipt.passed=true;receipt.state='prepared_without_activation';record('Preflight-only mode performed no release API request');}
 else {
  for(const code of codes){validateEvidence();const rows=activationRows(),current=target(rows,code),prior=receipt.prior.find(value=>value.code===code);guard(unrelated(rows)===unrelated(beforeRows),'Unrelated activation rows changed before a target release.');guard((!!current?.enabled)===prior.enabled&&(current?.source_hash||null)===prior.sourceHash,'A target changed after its baseline was frozen.');if(current?.enabled&&current.source_hash===report.definitionHashes[code]){record('Already enabled current contract: '+code);continue;}
   attempted.push(code);frozen('attempt-'+attempted.length+'.json',{code,channel:'ui',enabled:true,definitionHash:report.definitionHashes[code],evidenceHash,at:new Date().toISOString()});await setEnabled(code,true);const actual=target(activationRows(),code),audit=latestAudit(code);guard(actual?.enabled===true&&actual.source_hash===report.definitionHashes[code]&&audit.result?.evidenceHash===evidenceHash&&audit.result?.definitionHash===report.definitionHashes[code]&&audit.result?.enabled===true,'The real database release flag/definition/audit does not match this request.');changed.push(code);record('Exact manual UI release verified: '+code);
  }
  const after=await api('/sports/platform/management');assertCatalog(after);const rows=activationRows();assertManualRows(rows);guard(unrelated(rows)===unrelated(beforeRows),'Unrelated channels changed.');for(const code of codes){const row=target(rows,code);guard(row?.enabled===true&&row.source_hash===report.definitionHashes[code],'A final target is not enabled on its verified definition.');}guard(JSON.stringify(facts())===JSON.stringify(beforeFacts),'Business rows changed during activation.');validateEvidence();receipt.catalogAfter=frozen('catalog-after.json',after);receipt.activationsAfter=frozen('activation-after.json',rows);receipt.businessFactsUnchanged=true;receipt.unrelatedChannelsUnchanged=true;receipt.targetAgentEnabled=0;receipt.activated=true;receipt.passed=true;receipt.state='six_manual_ui_enabled';record('All six current UI flags enabled; Agent and unrelated channels plus ten business tables unchanged');
 }
} catch(error) {
 if(receipt){receipt.failure=error.safe?error.message:'A local prerequisite or release operation failed; raw private diagnostics are withheld.';receipt.state='failed';receipt.restoration='not_required';if(attempted.length&&beforeRows&&base){receipt.restoration='restored_prior_flags_using_current_definitions';for(const code of [...attempted].reverse()){try{const prior=receipt.prior.find(value=>value.code===code),now=target(activationRows(),code),audit=latestAudit(code);if((!!now?.enabled)===prior.enabled&&(now?.source_hash||null)===prior.sourceHash)continue;guard(now?.source_hash===report.definitionHashes[code]&&audit.id!==prior.latestAudit.id&&audit.result?.evidenceHash===evidenceHash&&audit.result?.definitionHash===report.definitionHashes[code]&&audit.result?.enabled===true,'A rollback target no longer belongs to this release.');await setEnabled(code,prior.enabled);const restored=target(activationRows(),code);guard(restored?.enabled===prior.enabled&&restored.source_hash===report.definitionHashes[code],'A target prior flag was not restored.');frozen('rollback-'+code.split('.').at(-1)+'.json',{code,enabled:prior.enabled,definitionHash:report.definitionHashes[code],at:new Date().toISOString()});}catch{receipt.restoration='incomplete_requires_private_review';}}
  try{const restored=activationRows();receipt.rollbackActivations=frozen('activation-rollback.json',restored);receipt.unrelatedChannelsUnchanged=unrelated(restored)===unrelated(beforeRows);receipt.businessFactsUnchanged=JSON.stringify(facts())===JSON.stringify(beforeFacts);if(!receipt.unrelatedChannelsUnchanged||!receipt.businessFactsUnchanged)receipt.restoration='incomplete_requires_private_review';}catch{receipt.restoration='incomplete_requires_private_review';}}
 }process.exitCode=1;
} finally {
 token=undefined;
 if(receipt&&out){receipt.finishedAt=new Date().toISOString();frozen('receipt.json',receipt);console.log(JSON.stringify({passed:receipt.passed,activated:receipt.activated,main,state:receipt.state,checks:checks.length,receipt:relative(path.join(out,'receipt.json'))}));}
 else if(process.exitCode)console.log('Honor release stopped before activation; no raw credentials or provider output recorded.');
 if(lockFd!==undefined){fs.closeSync(lockFd);if(lockFile&&fs.readFileSync(lockFile,'utf8')===lockOwner)fs.unlinkSync(lockFile);}
}
