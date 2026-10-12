// Seal the successful local candidate and immutable original evidence. This
// records a synthetic regression release, not real bank or on-site acceptance.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {context as c,api,request,createEvidence} from './lib/BusinessRegression.mjs';
const test=createEvidence('candidate-final-binding');
const workspace=fs.realpathSync('.');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const relative=file=>path.relative(workspace,fs.realpathSync(file)).replaceAll('\\','/');
const read=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const gateMap=read(process.argv[2]);
const sourceFiles=[];
function collect(directory){
  for(const item of fs.readdirSync(directory,{withFileTypes:true})){
    if(item.name.startsWith('.')||['target','node_modules','dist','logs'].includes(item.name))continue;
    const file=path.join(directory,item.name);
    if(item.isDirectory())collect(file);
    else if(item.isFile()&&/\.(java|xml|yml|yaml|properties|vue|ts|scss|css|mjs|json)$/.test(item.name)&&!item.name.endsWith('.test.mjs'))sourceFiles.push({path:relative(file),sha256:sha(fs.readFileSync(file))});
  }
}
try {
  const runtimeFile='.local/phase1-implementation/verification-runtime.json';
  const runtime=read(runtimeFile);
  assert.equal(runtime.database,c.database);assert.equal(runtime.port,8082);
  assert.equal(runtime.jarSHA256,'03da46e9cef78f6d72e4c9ebf79840652b7a91fc9ad6e7f01562ace32afd7d07');
  assert.equal(sha(fs.readFileSync(runtime.jarPath)),runtime.jarSHA256);
  const buildLogFile=path.join(c.out,'backend-full-r7-c9e1a232a467493a9ed9c12963f81340/maven-package.log');
  const buildLog=fs.readFileSync(buildLogFile,'utf8');assert.ok(buildLog.includes('BUILD SUCCESS'));
  const classes=[...buildLog.matchAll(/Tests run: (\d+), Failures: (\d+), Errors: (\d+), Skipped: (\d+)[^\r\n]* -- in /g)];
  const tests=classes.reduce((sum,line)=>sum+Number(line[1]),0);
  test.check('the final full local Java build has 391 tests and no failed or skipped classes',classes.length===82&&tests===391&&classes.every(line=>line.slice(2,5).every(value=>value==='0')));
  const frontendFile='.local/product-release-20261011/frontend-refinement-06a3c80805bf4ad596858dd85c363f1d/receipt.json';
  const frontend=read(frontendFile);assert.equal(frontend.passed,true);
  test.check('the successful final frontend build still matches every recorded source',frontend.sources.every(source=>sha(fs.readFileSync(source.path))===source.sha256));
  const requiredEvidence=[];
  for(const [gate,file] of Object.entries(gateMap)){
    const actual=read(file);assert.equal(actual.passed,true,'Passed original evidence: '+gate);
    requiredEvidence.push({gate,path:relative(file),sha256:sha(fs.readFileSync(file)),checks:actual.checks?.length??null});
  }
  for(const gate of ['canonical-proof','canonical-results','canonical-closure','canonical-team-closure','received-link'])assert.equal(requiredEvidence.filter(row=>row.gate===gate).length,1);
  test.check('each release business gate points to its unchanged successful original receipt',requiredEvidence.length>=5);
  const catalog=await api(c.admin,'/sports/platform/management');
  const agents=catalog.activations.filter(row=>row.enabled&&row.channel==='agent').map(row=>row.code).sort();
  test.check('the final runtime preserves five read-only Agent tools and no Agent writes',agents.join(',')==='event.mine,growth.card,registration.mine,room.query,type.catalog'&&agents.every(code=>{const definition=catalog.definitions.find(row=>row.definition.code===code).definition;return definition.agent&&!definition.mutation&&definition.writes.length===0;}));
  const scheduled=read(path.join(c.out,'ai-scheduled-entry-state.json'));
  const event=await api(c.organizer,`/sports/b/events/${scheduled.eventId}`);
  const closure=await api(c.organizer,`/sports/closure/events/${scheduled.eventId}`);
  test.check('the actual scheduled event is closed with independent money and issue closure',String(event.id)===String(scheduled.eventId)&&closure.event.closure_status==='closed'&&closure.competitionEnded&&closure.fundsClosed&&closure.issuesClosed);
  test.check('the final runtime serves public events while private management rejects anonymous access',(await request(null,'/sports/public/events')).code===200&&(await request(null,'/sports/platform/management')).code!==200);
  for(const directory of ['backend','plus-ui/src','ai-gateway'])collect(directory);
  sourceFiles.sort((a,b)=>a.path.localeCompare(b.path));
  const binding={at:new Date().toISOString(),runId:c.runId,passed:true,scope:'Controlled local multi-role synthetic badminton regression; real HTTP/UI/DB/storage and model calls, synthetic people/money/results.',backendJarPath:relative(runtime.jarPath),backendJarSha256:runtime.jarSHA256,backendBuild:{path:relative(buildLogFile),sha256:sha(fs.readFileSync(buildLogFile)),classes:82,tests:391,failures:0,errors:0,skipped:0},frontendBuild:{path:frontendFile,sha256:sha(fs.readFileSync(frontendFile)),originalBackendBinding:frontend.jarSha256,currentFrontendSourcesUnchanged:true},runtime:{pid:runtime.pid,port:8082,database:c.database,recordSha256:sha(fs.readFileSync(runtimeFile))},requiredEvidence,sourceFiles,agentTools:agents,agentWrites:0,limitations:['Synthetic receipts/refunds are not actual bank transactions.','No real business SMS delivery or positive SMS-dependent registration/recovery/closure.','No physical on-site match or real world award credential acceptance.','Configured AI image provider remains unavailable.','Mobile viewport checks do not establish real-device keyboard or broad accessibility acceptance.']};
  const file=path.join(test.directory,'binding.json');fs.writeFileSync(file,JSON.stringify(binding,null,2));
  test.evidence.objects={scheduledEventId:scheduled.eventId};test.evidence.bindingSha256=sha(fs.readFileSync(file));test.evidence.jarSha256=runtime.jarSHA256;test.finish();
  console.log('Binding: '+file);
}catch(error){test.evidence.failure=error.message;test.save();console.error(error.message);process.exitCode=1;}
