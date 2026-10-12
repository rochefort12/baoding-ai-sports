// Only reads the already settled main task. Never starts, resumes, confirms or reruns a model task.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';
const runId='2109117608078061568',source='.local/main-access/post-release-053ce21f-9531-4add-992e-2a03541dc443/run-summary.json',root=process.cwd();
assert.ok(process.env.AISPORTS_MAIN_ADMIN_TOKEN,'Protected main read session required');
const out=path.resolve(root,'.local/main-access','saved-catalog-'+crypto.randomUUID());fs.mkdirSync(out,{recursive:true});
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),checks=[];
async function read(route){const response=await fetch('http://127.0.0.1:8080'+route,{headers:{clientid:'e5cd7e4891bf95d1d19206ce24a7b32e',Authorization:'Bearer '+process.env.AISPORTS_MAIN_ADMIN_TOKEN}}),packet=await response.json();assert.equal(packet.code,200,'Read of current main catalog or retained task denied');return packet.data;}
function check(name,valid){assert.ok(valid,name);checks.push({name,status:'PASS'});console.log('PASS '+name);}
function observed(reply,label){const hit=reply.match(new RegExp(label+'(?:(?!单打|双打)[\\s\\S]){0,35}?([1-9]\\d*|一|二|两)\\s*(?:位|名|人|个(?:人|队员)?)'));return hit?({一:1,二:2,两:2}[hit[1]]??Number(hit[1])):null;}
let errorCode,counts;
try{
  const originalBytes=fs.readFileSync(source),original=JSON.parse(originalBytes),[catalog,run]=await Promise.all([read('/sports/types'),read('/sports/agents/runs/'+runId)]);
  check('existing settled main task and original reply digest are unchanged',run.id===runId&&run.status==='waiting_input'&&original.runId===runId);
  const answer=run.messages.filter(message=>message.role==='assistant').at(-1);check('saved reply exactly matches original verified main summary',hash(answer.content)===original.replySha256&&run.sourceHash===original.sourceHash);
  const badminton=catalog.sports.find(sport=>sport.code==='badminton');assert.ok(badminton,'Actual badminton catalog required');const types=catalog.types.filter(type=>type.sport_id===badminton.id);
  const singles=types.filter(type=>type.name.includes('单打')),doubles=types.filter(type=>type.name.includes('双打'));
  check('actual catalog has unambiguous singles and doubles participation bounds',singles.length>0&&doubles.length>0&&singles.every(type=>Number(type.min_members)===1&&Number(type.max_members)===1)&&doubles.every(type=>Number(type.min_members)===2&&Number(type.max_members)===2));
  const plain=answer.content.replace(/[*_`]/g,'');counts={single:observed(plain,'单打'),double:observed(plain,'双打')};
  check('saved model reply binds singles to one person and doubles to two people',counts.single===1&&counts.double===2);
  check('saved task contains a real catalog tool step and no write confirmation or receipt',run.steps.some(step=>step.kind==='tool'&&step.name==='type.catalog'&&step.status==='succeeded')&&!run.messages.some(message=>(typeof message.blocks==='string'?JSON.parse(message.blocks):message.blocks||[]).some(block=>['confirmation','receipt'].includes(block.kind))));
  fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify({timestamp:new Date().toISOString(),scope:'Read-only verification of an existing main task and actual public catalog; no new model call or business operation',passed:true,runId,source:{file:source,sha256:hash(originalBytes)},replySha256:hash(answer.content),counts,checks},null,2),{flag:'wx'});
}catch(error){errorCode=error.name==='AssertionError'?'SAVED_CATALOG_ASSERTION_FAILED':'SAVED_CATALOG_READ_FAILED';fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify({timestamp:new Date().toISOString(),scope:'Read-only existing main task verification; no model invocation',passed:false,runId,checks,errorCode,assertion:error.name==='AssertionError'?error.message:'Read-only verification unavailable; original task retained'},null,2),{flag:'wx'});process.exitCode=1;}
console.log(JSON.stringify({evidence:path.relative(root,path.join(out,'receipt.json')).replaceAll('\\','/'),sha256:hash(fs.readFileSync(path.join(out,'receipt.json'))),passed:!errorCode}));
