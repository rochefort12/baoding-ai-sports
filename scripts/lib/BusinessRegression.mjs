// Shared real-service test helpers. Credentials stay in a protected, explicitly selected run context.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';

const contextPath=process.env.AISPORTS_REGRESSION_CONTEXT;
if(!contextPath) throw new Error('AISPORTS_REGRESSION_CONTEXT must select the prepared private run.');
const allowedRoot=fs.realpathSync(path.resolve('.local/business-regression-20261011'));
const resolved=fs.realpathSync(contextPath);
if(!resolved.startsWith(allowedRoot+path.sep)) throw new Error('Context is outside the protected regression directory.');
export const context=JSON.parse(fs.readFileSync(resolved,'utf8').replace(/^\uFEFF/,''));
if(context.backend!=='http://127.0.0.1:8082'||context.frontend!=='http://127.0.0.1:5192'||!/^aisports_verify_phase1_[a-f0-9]{32}$/.test(context.database)) throw new Error('Only the existing isolated service may be tested.');
const preflight=JSON.parse(fs.readFileSync(path.join(context.out,'preflight-receipt.json'),'utf8').replace(/^\uFEFF/,''));
if(!preflight.passed||preflight.database!==context.database) throw new Error('Backup and independent restore verification are required.');
export const key=()=>crypto.randomUUID();
export const beijingTime=(date=new Date())=>new Date(date.getTime()+8*3600000).toISOString().slice(0,19).replace('T',' ');
export const iso=hours=>new Date(Date.now()+hours*3600000).toISOString();
export async function request(actor,route,method='GET',body){
  const response=await fetch(context.backend+route,{method,signal:AbortSignal.timeout(45000),headers:{clientid:context.clientId,'Content-Type':'application/json',...(actor?.token?{Authorization:'Bearer '+actor.token}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});
  let value;
  try{value=await response.json();}catch{throw new Error('Non-JSON response at '+route+' HTTP '+response.status);}
  return {httpStatus:response.status,...value};
}
export async function api(actor,route,method='GET',body){
  const value=await request(actor,route,method,body);
  assert.equal(value.code,200,route+' business code '+value.code+': '+(value.msg||'rejected'));
  return value.data;
}
export async function action(actor,code,input,requestKey=key()){
  const definition=context.definitions.find(row=>row.definition.code===code)?.definition;
  assert.ok(definition,'Registered action '+code);
  let confirmationId;
  if(definition.confirmation){
    await api(actor,`/sports/platform/actions/${code}/preview`,'POST',input);
    confirmationId=await api(actor,`/sports/platform/actions/${code}/confirm`,'POST',input);
  }
  const receipt=await api(actor,`/sports/platform/actions/${code}/execute`,'POST',{input,requestKey,confirmationId});
  return {value:receipt.result??receipt,receipt,requestKey,confirmationId};
}
export function readSql(statement){
  const executable='C:/ProgramData/AISports/desktop-sports-e3000ec/toolchains/postgresql-17.11/pgsql/bin/psql.exe';
  const result=spawnSync(executable,['-X','-h','127.0.0.1','-p',process.env.POSTGRES_PORT,'-U',process.env.POSTGRES_USER,'-d',context.database,'-At','-v','ON_ERROR_STOP=1'],{input:'BEGIN READ ONLY;\n'+statement+'\nROLLBACK;',encoding:'utf8',env:{...process.env,PGPASSWORD:process.env.POSTGRES_PASSWORD}});
  if(result.status!==0) throw new Error('Read-only isolated evidence query failed.');
  return result.stdout.split(/\r?\n/).filter(line=>line!=='BEGIN'&&line!=='ROLLBACK'&&line!=='').join('\n');
}
export const versionOf=(table,id)=>{
  if(!/^asp_[a-z_]+$/.test(table)||!/^\d+$/.test(String(id))) throw new Error('Unsafe evidence identifier.');
  return Number(readSql(`SELECT version FROM ${table} WHERE id=${id};`));
};
export function createEvidence(label){
  const directory=path.join(context.out,label+'-'+Date.now()+'-'+key().slice(0,8));
  fs.mkdirSync(directory);
  const evidence={at:new Date().toISOString(),runId:context.runId,database:context.database,scope:'Actual isolated HTTP and ordinary-role UI; people, events, materials, money and results are synthetic.',checks:[],objects:{},passed:false};
  const save=()=>fs.writeFileSync(path.join(directory,'receipt.json'),JSON.stringify(evidence,null,2));
  return {directory,evidence,save,check:(name,condition,details={})=>{
    const record={name,passed:Boolean(condition),...details};evidence.checks.push(record);save();
    assert.ok(condition,name);console.log('PASS '+name);
  },finish:()=>{evidence.passed=true;evidence.finishedAt=new Date().toISOString();save();console.log('Evidence: '+directory);}};
}
