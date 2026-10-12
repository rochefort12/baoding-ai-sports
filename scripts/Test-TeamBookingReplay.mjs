// Continue the accepted synthetic booking fixture; do not recreate its event, team or successful bookings.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';
import {context,api,request,key,readSql} from './lib/BusinessRegression.mjs';
const base=process.env.AISPORTS_TEAM_BOOKING_BASE;assert.ok(path.resolve(base).startsWith(path.resolve(context.out)+path.sep));
const previous=JSON.parse(fs.readFileSync(path.join(base,'receipt.json'),'utf8'));assert.ok(previous.passed);
const receipt={at:new Date().toISOString(),passed:false,scope:'Continuation on the same synthetic booking fixture: concurrent selection, replay after editing, pending member submit guard',jarSha256:JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-runtime.json','utf8').replace(/^\uFEFF/,'')).jarSHA256,previous:{path:base,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(base,'receipt.json'))).digest('hex')},checks:[]};
const output=path.join(base,'replay-'+key()+'.json');const save=()=>fs.writeFileSync(output,JSON.stringify(receipt,null,2));const check=(name,ok)=>{receipt.checks.push({name,passed:!!ok});save();assert.ok(ok,name);console.log('PASS '+name);};
try{
 const a={token:(await api(null,'/auth/login','POST',{username:context.people[0].phone,password:context.password,grantType:'platform',tenantId:'900001',clientId:context.clientId})).access_token};
 const candidates=await api(a,'/sports/c/teams/'+previous.objects.teamId+'/candidates');const cap=candidates.find(p=>p.role==='captain');const others=candidates.filter(p=>p.role!=='captain');const unitId=previous.objects.units[2];
 assert.equal(readSql('SELECT count(*) FROM asp_registration WHERE unit_id='+unitId+';'),'0','Do not repeat a completed race');
 const bodies=others.map(p=>({unitId,teamId:previous.objects.teamId,memberAccountIds:[cap.accountId,p.accountId],requestKey:key()}));
 const responses=await Promise.all(bodies.map(body=>request(a,'/sports/c/registrations','POST',body)));const winning=responses.findIndex(r=>r.code===200);assert.ok(winning>=0);const entry=responses[winning].data;receipt.objects={entryId:entry.id,unitId};save();
 check('Two concurrent different rosters yield one complete booking and one conflict',responses.filter(r=>r.code===200).length===1&&entry.members.length===2&&readSql('SELECT count(*) FROM asp_registration WHERE unit_id='+unitId+';')==='1'&&readSql('SELECT count(*) FROM asp_registration_member WHERE registration_id='+entry.id+';')==='2');
 check('Unconfirmed member blocks formal submission without consuming capacity',(await request(a,'/sports/c/registrations/'+entry.id+'/submit','POST',{requestKey:entry.requestKey})).code!==200&&readSql('SELECT used_count FROM asp_capacity_pool WHERE unit_id='+unitId+';')==='0');
 const teammate=entry.members.find(m=>!m.selfMember);await api(a,'/sports/c/registrations/'+entry.id+'/members/'+teammate.id,'DELETE');
 const replay=await api(a,'/sports/c/registrations','POST',bodies[winning]);check('Retry after intentional roster editing returns current state without restoring removed member',replay.id===entry.id&&replay.members.length===1&&replay.members[0].selfMember);
 receipt.passed=true;receipt.finishedAt=new Date().toISOString();save();console.log('Evidence: '+output);
}catch(cause){receipt.failure=cause.message;save();throw cause;}
