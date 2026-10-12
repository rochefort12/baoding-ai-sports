import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {context,api,request,key,action,versionOf} from './lib/BusinessRegression.mjs';
const run=process.env.AISPORTS_AWARD_RUN,s=JSON.parse(fs.readFileSync(path.join(run,'state.private.json'),'utf8')),out=path.join(run,'new-basis-'+key()+'.json');
const r={at:new Date().toISOString(),passed:false,scope:'New official match and revoke/regrant using ordinary role on final isolated candidate; synthetic records only',jarSha256:JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8').replace(/^\uFEFF/,'')).jarSHA256,checks:[]};
const save=()=>{fs.writeFileSync(path.join(run,'state.private.json'),JSON.stringify(s,null,2));fs.writeFileSync(out,JSON.stringify(r,null,2));};const check=(name,ok)=>{r.checks.push({name,passed:!!ok});save();assert.ok(ok,name);console.log('PASS '+name);};const session=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8').replace(/^\uFEFF/,''));
const login=async(phone,password)=>({token:(await api(null,'/auth/login','POST',{username:phone,password,grantType:'platform',tenantId:'900001',clientId:context.clientId})).access_token});
try{const platform=await login(session.people[0].phone,session.password),org={token:(await api(platform,'/auth/organization/enter','POST',{})).access_token},a=await login(context.people[0].phone,context.password);
const own=async()=> (await api(a,'/sports/c/proofs')).filter(p=>p.eventName===s.label);
assert.ok(!s.newBasisFinished,'This finite new-basis scenario already completed; do not repeat its mutations.');
s.m4=await api(org,'/sports/b/competition/units/'+s.main.id+'/matches','POST',{code:'03',registrationA:s.a.id,registrationB:s.b.id,requestKey:key()});save();
await api(org,'/sports/b/competition/matches/'+s.m4.matchId+'/result','POST',{summary:'2:0',games:'21:18|21:17',outcomeA:'win',outcomeB:'loss',requestKey:key()});
check('A selected draft cannot be used as special award evidence',(await request(org,'/sports/b/competition/awards','POST',{registrationId:s.a.id,title:'未确认场次专项奖（模拟）',basis:'测试：草稿不能作为正式依据',requestKey:key(),awardKind:'special',basisMatchIds:[s.m4.matchId]})).code!==200);
const finalizeKey=key();await api(org,'/sports/b/competition/matches/'+s.m4.matchId+'/finalize','POST',{requestKey:finalizeKey});
let pending=await api(org,'/sports/proof-review/events/'+s.event.id);check('Later official match puts only the same project final placing into review',pending.length===1&&pending[0].award_kind==='placing'&&pending[0].basis_results.length===3&&(await own()).length===2);
const version=Number(pending[0].version);await api(org,'/sports/b/competition/matches/'+s.m4.matchId+'/finalize','POST',{requestKey:finalizeKey});
check('Replaying match confirmation does not suspend or bump a proof again',Number((await api(org,'/sports/proof-review/events/'+s.event.id))[0].version)===version);
await action(org,'honor.resolve',{honorId:pending[0].id,expectedVersion:version,decision:'reissue',title:'第二名',reason:'新增合成场次03后核实项目完整正式依据',basisFingerprint:pending[0].basis_fingerprint});
check('Reissued final placing captures all three official match revisions',(await own()).length===3&&(await api(org,'/sports/proof-review/events/'+s.event.id)).length===0);
let awards=await api(org,'/sports/proof-review/events/'+s.event.id+'?includeVerified=true'),special=awards.find(h=>h.title==='体育精神奖');
await action(org,'honor.resolve',{honorId:special.id,expectedVersion:Number(special.version),decision:'revoke',reason:'合成撤销专项奖原因：责任人独立核实'});
const history=(await api(a,'/sports/c/proofs?history=true')).find(p=>p.honorId===special.id);
check('Revocation preserves its actual explanation and removes the current proof',(await own()).length===2&&!history.current&&history.status==='revoked'&&history.reason==='合成撤销专项奖原因：责任人独立核实');
await api(org,'/sports/b/competition/awards','POST',{registrationId:s.a.id,title:'体育精神奖',basis:'合成重新授奖：场次02独立专项表现',requestKey:key(),awardKind:'special',basisMatchIds:[s.m2.matchId]});
check('A deliberately regranted special award keeps the revoked original in history',(await own()).length===3&&(await own()).filter(p=>p.title==='体育精神奖').length===1&&(await request(a,'/sports/c/proofs/'+special.id)).code!==200);
s.newBasisFinished=true;r.passed=true;r.finishedAt=new Date().toISOString();save();console.log('Evidence: '+out);
}catch(e){r.failure=e.message;save();throw e;}

