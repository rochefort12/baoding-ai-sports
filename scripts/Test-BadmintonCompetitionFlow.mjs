// Real ordinary-role services; only this round's synthetic match and receipt facts.
import fs from 'node:fs';
import path from 'node:path';
import {context as c,key,beijingTime,api,request,action,readSql,versionOf,createEvidence} from './lib/BusinessRegression.mjs';
const scheduled=process.argv.includes('--scheduled');
const canonical=scheduled||process.argv.includes('--canonical');
const canonicalEntries=canonical?JSON.parse(fs.readFileSync(path.join(c.out,scheduled?'ai-scheduled-entry-state.json':'ai-canonical-entry-state.json'),'utf8')):null;
const test=createEvidence(canonical?'canonical-competition-results':'competition-results');
const stateFile=path.join(c.out,scheduled?'scheduled-competition-results-state.json':canonical?'canonical-competition-results-state.json':'competition-results-state.json');
const s=fs.existsSync(stateFile)?JSON.parse(fs.readFileSync(stateFile,'utf8')):{...(canonicalEntries||{}),runId:c.runId,steps:{},keys:{}};
if(s.runId!==c.runId)throw new Error('Another test round owns this state.');
const money=canonicalEntries||JSON.parse(fs.readFileSync(path.join(c.out,'funds-competition-fixed-state.json'),'utf8'));
const event=money.eventId,unit=canonical?money.pairUnitId:money.pairUnit;
const expectedFee=canonical?40:100;
const matchCode=c.prefix+(scheduled?'-SCHEDULE-PAIR-01':canonical?'-AI-PAIR-01':'-PAIR-01');
const save=()=>fs.writeFileSync(stateFile,JSON.stringify(s,null,2));
const once=async(name,fn)=>{if(s.steps[name])return;await fn();s.steps[name]=true;save();};
const remember=async(name,fn)=>{if(s[name]!==undefined)return s[name];s[name]=await fn();save();return s[name];};
const reqKey=name=>{s.keys[name]??=key();save();return s.keys[name];};
const act=async(actor,code,input,slot)=>(await action(actor,code,input,reqKey(slot))).value;
const row=async(actor,id)=>(await api(actor,'/sports/c/registrations')).find(r=>r.id===id);
const person=actor=>readSql(`SELECT person_id FROM asp_account WHERE id=${actor.id};`);
const points=(actor,kind='person')=>Number(readSql(`SELECT COALESCE(sum(points_delta),0) FROM asp_growth_record WHERE event_id=${event} AND ${kind==='team'?'team_id':'person_id'}=${kind==='team'?actor:person(actor)};`));
const isThisResult=r=>r.matchCode===matchCode;
const ownProofs=async actor=>{const ids=new Set(readSql(`SELECT id FROM asp_honor WHERE event_id=${event} AND person_id=${person(actor)};`).split('\n'));return (await api(actor,'/sports/c/proofs')).filter(r=>ids.has(String(r.honorId)));};
async function prepare(){
  if(!canonical){
  await remember('team',async()=> (await api(c.people[0],'/sports/c/teams','POST',{name:c.prefix+'-赛果长期队'})).id);
  for(const i of [1,4])await once('team-member-'+i,async()=>{let d=await api(c.people[0],`/sports/c/teams/${s.team}`);if(!d.applications.some(r=>r.status==='pending')){await api(c.people[i],`/sports/c/teams/${s.team}/applications`,'POST');d=await api(c.people[0],`/sports/c/teams/${s.team}`);}const pending=d.applications.filter(r=>r.status==='pending');if(pending.length!==1)throw new Error('Only the current sequential test applicant may be pending.');await api(c.people[0],`/sports/c/teams/applications/${pending[0].id}/approve`,'POST');});
  test.check('captain and two teammates belong to the persistent pool',(await api(c.people[0],`/sports/c/teams/${s.team}`)).members.filter(r=>r.status==='active').length===3);
  }else test.check('AI canonical team and member-confirmed entries already exist',Boolean(s.team&&s.entryA&&s.entryB&&s.entryAObligation&&s.entryBObligation));
  for(const [name,indices,teamId] of [['entryA',[0,1],s.team],['entryB',[2,3],undefined]]){
    const owner=canonical?c.people.find(p=>p.id===s[name+'Manager']):c.people[indices[0]],member=c.people[indices[1]];
    if(!owner)throw Error('The actual room host and registration manager must be retained');
    if(!canonical){
    await remember(name,async()=> (await api(owner,'/sports/c/registrations','POST',{unitId:unit,teamId,requestKey:reqKey(name+'-create')})).id);
    if(teamId)await once(name+'-self-selected',()=>api(owner,`/sports/c/registrations/${s[name]}/roster`,'POST',{accountId:owner.id}));
    await once(name+'-invite',async()=>{if(teamId)await api(owner,`/sports/c/registrations/${s[name]}/roster`,'POST',{accountId:member.id});else await api(owner,`/sports/c/registrations/${s[name]}/members`,'POST',{phone:member.phone,requestSms:false});});
    await once(name+'-confirmed',async()=>{for(const i of indices){await api(c.people[i],`/sports/c/registrations/${s[name]}/declaration-ack`,'POST');const d=await row(owner,s[name]);const m=d.members.find(r=>String(r.accountId)===c.people[i].id);if(m.status==='pending_confirmation')await api(c.people[i],`/sports/c/registrations/invites/${m.inviteToken}/confirm`,'POST');}});
    await once(name+'-submitted',()=>act(owner,'registration.submit',{registrationId:s[name],expectedVersion:versionOf('asp_registration',s[name])},name+'-submit'));
    await remember(name+'Obligation',async()=> (await api(c.organizer,`/sports/b/fees/units/${unit}/obligations`)).find(r=>r.registrationId===s[name]).obligationId);
    }else test.check(name+' retains the source-confirmed 40-yuan independent obligation',Number((await row(owner,s[name])).feeAmount)===expectedFee);
    await once(name+'-paid',async()=>{s[name+'Payment']??={payerName:'赛果轮合成付款人',amount:String(expectedFee)+'.00',occurredAt:beijingTime(),note:'合成收款登记，无实际银行款项',requestKey:reqKey(name+'-payment')};save();await api(c.organizer,`/sports/b/fees/obligations/${s[name+'Obligation']}/confirm`,'POST',s[name+'Payment']);});
    await once(name+'-approved',()=>api(c.organizer,`/sports/b/registrations/${s[name]}/approve`,'POST'));
    test.check(name+' freezes two confirmed participants and independent paid qualification',(await row(owner,s[name])).status==='approved'&&Number((await api(c.organizer,`/sports/b/fees/obligations/${s[name+'Obligation']}/records`)).netAmount)===expectedFee);
  }
  test.check('the spare persistent member is absent from the frozen match roster',readSql(`SELECT count(*) FROM asp_roster_member m JOIN asp_roster_version v ON v.id=m.roster_version_id WHERE v.registration_id=${s.entryA} AND v.revision=(SELECT roster_revision FROM asp_registration WHERE id=${s.entryA});`)==='2');
  s.sport=readSql("SELECT id FROM asp_sport WHERE code='badminton';");save();
  test.evidence.objects={eventId:event,unitId:unit,teamId:s.team,entryA:s.entryA,entryB:s.entryB};test.save();
}
async function competition(){
  test.check('ordinary participants cannot operate event attendance',(await request(c.people[0],`/sports/b/competition/events/${event}/check-ins`,'POST',{personId:person(c.people[0]),requestKey:key()})).code!==200);
  test.check('ordinary government cannot operate event attendance',(await request(c.government,`/sports/b/competition/events/${event}/check-ins`,'POST',{personId:person(c.people[0]),requestKey:key()})).code!==200);
  for(let i=0;i<4;i++){
    const body={personId:person(c.people[i]),requestKey:reqKey('checkin-'+i)};
    await once('checkin-'+i,()=>api(c.organizer,`/sports/b/competition/events/${event}/check-ins`,'POST',body));
    await api(c.organizer,`/sports/b/competition/events/${event}/check-ins`,'POST',body);
    test.check('attendance '+i+' counts one genuine service fact',readSql(`SELECT count(*) FROM asp_checkin WHERE event_id=${event} AND person_id=${body.personId};`)==='1'&&(points(c.people[i])===10||s.steps.finalized));
  }
  test.check('an unrelated or withdrawn person cannot be checked in',(await request(c.organizer,`/sports/b/competition/events/${event}/check-ins`,'POST',{personId:person(c.people[4]),requestKey:key()})).code!==200);
  test.check('the same entry cannot compete against itself',(await request(c.organizer,`/sports/b/competition/units/${unit}/matches`,'POST',{code:c.prefix+'-self',registrationA:s.entryA,registrationB:s.entryA,requestKey:key()})).code!==200);
  await remember('match',async()=> (await api(c.organizer,`/sports/b/competition/units/${unit}/matches`,'POST',{code:matchCode,registrationA:s.entryA,registrationB:s.entryB,requestKey:reqKey('match-create')})).matchId);
  await once('scheduled',async()=>{
    const e=await api(c.organizer,`/sports/b/events/${event}`);
    // Scheduling is performed through the real service, which requires a future
    // start. A run resumed after event start must not try to backdate the match.
    const start=Math.max(new Date(e.startsAt).getTime(),Date.now()+15000);
    const end=Math.min(new Date(e.endsAt).getTime(),start+3600000);
    if(end<=start)throw Error('The natural event window has elapsed; preserve this run and use a new approved test event.');
    s.scheduledStartsAt=new Date(start).toISOString();save();
    await act(c.organizer,'match.schedule',{matchId:s.match,expectedVersion:versionOf('asp_match',s.match),startsAt:s.scheduledStartsAt,endsAt:new Date(end).toISOString(),courtName:'合成1号球场'},'schedule-actual-future');
  });
  const scheduledStart=JSON.parse(readSql(`SELECT json_build_object('startsAt',scheduled_start) FROM asp_match WHERE id=${s.match};`)).startsAt;
  const waitMs=new Date(scheduledStart).getTime()-Date.now();
  if(waitMs>60000)throw Error('The match has not naturally started; resume this same checkpoint later.');
  if(waitMs>0){console.log('Waiting for the actual scheduled match start; no clock or business-date changes.');await new Promise(resolve=>setTimeout(resolve,waitMs+100));}
  if(!s.steps.finalized){
    test.check('finalization without a score is rejected',(await request(c.organizer,`/sports/b/competition/matches/${s.match}/finalize`,'POST',{requestKey:key()})).code!==200);
    test.check('two simultaneous winners are rejected',(await request(c.organizer,`/sports/b/competition/matches/${s.match}/result`,'POST',{summary:'2:0',games:'21:13|21:16',outcomeA:'win',outcomeB:'win',requestKey:key()})).code!==200);
    await once('scored',()=>api(c.organizer,`/sports/b/competition/matches/${s.match}/result`,'POST',{summary:'2:0',games:'21:13|21:16',outcomeA:'win',outcomeB:'loss',requestKey:reqKey('score')}));
    test.check('an unconfirmed score is absent from personal official results',!(await api(c.people[0],'/sports/c/results')).some(isThisResult));
    test.check('members cannot confirm official scores',(await request(c.people[0],`/sports/b/competition/matches/${s.match}/finalize`,'POST',{requestKey:key()})).code!==200);
    await once('finalized',()=>api(c.organizer,`/sports/b/competition/matches/${s.match}/finalize`,'POST',{requestKey:reqKey('finalize')}));
  }
  await api(c.organizer,`/sports/b/competition/matches/${s.match}/finalize`,'POST',{requestKey:reqKey('finalize')});
  for(let i=0;i<4;i++)test.check('participant '+i+' gains one attendance and one completion milestone',points(c.people[i])===40&&readSql(`SELECT count(DISTINCT milestone) FROM asp_growth_record WHERE event_id=${event} AND person_id=${person(c.people[i])} AND points_delta>0;`)==='2');
  test.check('persistent team earns one completion milestone',points(s.team,'team')===40);
  test.check('an unselected persistent member gets no attendance or completion points',points(c.people[4])===0);
  test.check('a member sees official result without another persons contacts',(await api(c.people[0],'/sports/c/results')).some(isThisResult));
  test.check('an unrelated account does not inherit the squads official result',!(await api(c.people[5],'/sports/c/results')).some(isThisResult));
  await once('awarded',()=>api(c.organizer,'/sports/b/competition/awards','POST',{registrationId:s.entryA,title:'本轮合成双打优胜奖',basis:'隔离测试人工核对当前正式2:0赛果；不是实际赛事获奖',requestKey:reqKey('award')}));
  await remember('oldHonors',async()=> (await ownProofs(c.people[0])).map(r=>r.honorId));
  test.check('both frozen teammates can read their own private winning proof',s.oldHonors.length>0&&(await ownProofs(c.people[1])).length>0);
  test.check('a spare teammate cannot read another members private proof',(await request(c.people[4],`/sports/c/proofs/${s.oldHonors[0]}`)).code!==200);
  test.check('anonymous visitors cannot read private proof',(await request(null,`/sports/c/proofs/${s.oldHonors[0]}`)).code!==200);
  await once('corrected',()=>act(c.organizer,'result.correct',{matchId:s.match,expectedVersion:versionOf('asp_match',s.match),summary:'0:2',games:'13:21|16:21',outcomeA:'loss',outcomeB:'win',reason:'本轮合成记分表核对，交换双方结果'},'correct'));
  if(!s.steps.voided)test.check('correction appends a new result and suspends dependent proofs',readSql(`SELECT count(*) FROM asp_result_version WHERE match_id=${s.match};`)==='2'&&(await ownProofs(c.people[0])).length===0);
  for(let i=0;i<4;i++)test.check('result correction alone does not duplicate participant '+i+' growth',points(c.people[i])===40);
  await once('voided',()=>act(c.organizer,'result.void',{matchId:s.match,expectedVersion:versionOf('asp_match',s.match),reason:'本轮合成无效场次，撤销完赛依据'},'void'));
  if(!s.steps.reinstated){for(let i=0;i<4;i++)test.check('voiding the only match retains attendance but reverses completion '+i,points(c.people[i])===10);test.check('voiding reverses the team completion fact with audit history',points(s.team,'team')===0);}
  await once('reinstated',()=>act(c.organizer,'result.correct',{matchId:s.match,expectedVersion:versionOf('asp_match',s.match),summary:'2:1',games:'21:13|18:21|21:16',outcomeA:'win',outcomeB:'loss',reason:'本轮合成事实重新核实，恢复有效比赛'},'reinstate'));
  for(let i=0;i<4;i++)test.check('reinstatement restores one completion total for participant '+i,points(c.people[i])===40);
  test.check('reinstatement restores one team completion total',points(s.team,'team')===40);
  await once('proofReviewed',async()=>{for(const h of await api(c.organizer,`/sports/proof-review/events/${event}`))await act(c.organizer,'honor.resolve',{honorId:h.id,expectedVersion:Number(h.version),decision:'reissue',title:'本轮合成双打优胜奖',reason:'本轮第4版正式结果人工核验',basisFingerprint:h.basis_fingerprint},'honor-'+h.id);});
  test.check('new proof is visible while the old certificate stays revoked',(await ownProofs(c.people[0])).length>0&&s.oldHonors.every(id=>readSql(`SELECT status FROM asp_honor WHERE id=${id};`)==='revoked'));
  test.evidence.objects={...test.evidence.objects,matchId:s.match,oldHonors:s.oldHonors};test.save();
}
try{await prepare();if(process.argv[2]!=='prepare')await competition();test.finish();}
catch(error){test.evidence.failure=error.message;test.save();save();console.error(error.message);process.exitCode=1;}

