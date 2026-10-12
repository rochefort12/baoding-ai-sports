// Two formerly unobserved branches on one NEW synthetic event, never either canonical event.
// Uses ordinary roles, native APIs, natural wall-clock time and SELECT-only evidence.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {context as c,key,api,request,action,readSql,versionOf,beijingTime,createEvidence} from './lib/BusinessRegression.mjs';

const test=createEvidence('badminton-isolated-boundaries');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const id=value=>{assert.match(String(value),/^\d+$/);return String(value);};
const stateFile=path.join(c.out,'isolated-match-exception-boundaries.private.json');
const s=fs.existsSync(stateFile)?JSON.parse(fs.readFileSync(stateFile,'utf8')):{runId:c.runId,steps:{},keys:{},bodies:{},prefix:c.prefix+'-时序与资金独立补验-'+key().slice(0,8)};
assert.equal(s.runId,c.runId);assert.ok(s.prefix.startsWith(c.prefix+'-时序与资金独立补验-'));
const save=()=>{
  const temporary=stateFile+'.'+key()+'.tmp';const descriptor=fs.openSync(temporary,'wx');
  try{fs.writeFileSync(descriptor,JSON.stringify(s,null,2));fs.fsyncSync(descriptor);}finally{fs.closeSync(descriptor);}
  fs.renameSync(temporary,stateFile);
};
const reqKey=slot=>{s.keys[slot]??=key();save();return s.keys[slot];};
const bodyOnce=(slot,fn)=>{if(s.bodies[slot]===undefined){s.bodies[slot]=fn();save();}return s.bodies[slot];};
const once=async(slot,work)=>{if(s.steps[slot])return;await work();s.steps[slot]={at:new Date().toISOString(),jarSha256:test.evidence.jarSha256};save();};
const remember=async(slot,work)=>{if(s[slot]!==undefined)return s[slot];s[slot]=await work();save();return s[slot];};
const act=async(code,input,slot)=>(await action(c.organizer,code,input,reqKey(slot))).value;
const rows=actor=>api(actor,'/sports/c/registrations');
const row=async(actor,registration)=>{const value=(await rows(actor)).find(r=>String(r.id)===String(registration));assert.ok(value);return value;};
const records=obligation=>api(c.organizer,`/sports/b/fees/obligations/${id(obligation)}/records`);
const closure=slot=>act('event.closure',{eventId:id(s.eventId)},slot);
const person=actor=>id(readSql(`SELECT person_id FROM asp_account WHERE id=${id(actor.id)};`));
const planFingerprint=()=>readSql(`SELECT md5(jsonb_build_object('startsAt',starts_at,'endsAt',ends_at,'name',name,'rules',rules_text,'declaration',declaration_text)::text) FROM asp_event WHERE id=${id(s.eventId)};`);
const resultFingerprint=()=>readSql(`SELECT md5(COALESCE(string_agg(f.kind||':'||f.fact,'|' ORDER BY f.kind,f.fact),'')) FROM (
  SELECT 'match' AS kind,to_jsonb(m)::text AS fact FROM asp_match m WHERE m.id=${id(s.matchId)}
  UNION ALL SELECT 'result',to_jsonb(r)::text FROM asp_result_version r WHERE r.match_id=${id(s.matchId)}
  UNION ALL SELECT 'item',to_jsonb(i)::text FROM asp_result_item i WHERE i.result_version_id IN(SELECT id FROM asp_result_version WHERE match_id=${id(s.matchId)})
  UNION ALL SELECT 'honor',to_jsonb(h)::text FROM asp_honor h WHERE h.event_id=${id(s.eventId)}
  UNION ALL SELECT 'growth',to_jsonb(g)::text FROM asp_growth_record g WHERE g.event_id=${id(s.eventId)}) f;`);
const financeFingerprint=()=>readSql(`SELECT md5(COALESCE(string_agg(f.kind||':'||f.fact,'|' ORDER BY f.kind,f.fact),'')) FROM (
  SELECT 'obligation' AS kind,to_jsonb(o)::text AS fact FROM asp_fee_obligation o WHERE o.id IN(${id(s.entryAObligation)},${id(s.entryBObligation)})
  UNION ALL SELECT 'payment',to_jsonb(p)::text FROM asp_payment p WHERE p.id IN(SELECT payment_id FROM asp_payment_allocation WHERE obligation_id IN(${id(s.entryAObligation)},${id(s.entryBObligation)}))
  UNION ALL SELECT 'allocation',to_jsonb(a)::text FROM asp_payment_allocation a WHERE a.obligation_id IN(${id(s.entryAObligation)},${id(s.entryBObligation)})
  UNION ALL SELECT 'refund',to_jsonb(r)::text FROM asp_refund r WHERE r.payment_id IN(SELECT payment_id FROM asp_payment_allocation WHERE obligation_id IN(${id(s.entryAObligation)},${id(s.entryBObligation)}))
  UNION ALL SELECT 'action',to_jsonb(a)::text FROM asp_payment_action a WHERE a.obligation_id IN(${id(s.entryAObligation)},${id(s.entryBObligation)})) f;`);
const window=()=>JSON.parse(readSql(`SELECT json_build_object('eventHasStarted',e.starts_at<=CURRENT_TIMESTAMP,'matchHasStarted',m.scheduled_start<=CURRENT_TIMESTAMP,'secondsToEvent',extract(epoch FROM e.starts_at-CURRENT_TIMESTAMP),'secondsToMatch',extract(epoch FROM m.scheduled_start-CURRENT_TIMESTAMP),'databaseNow',CURRENT_TIMESTAMP) FROM asp_match m JOIN asp_stage st ON st.id=m.stage_id JOIN asp_competition_unit u ON u.id=st.unit_id JOIN asp_event e ON e.id=u.event_id WHERE m.id=${id(s.matchId)};`));
async function naturallyWait(kind){
  let waitingLogged=0;
  while(true){
    const current=window(),remaining=Number(current[kind==='event'?'secondsToEvent':'secondsToMatch']);
    if(current[kind==='event'?'eventHasStarted':'matchHasStarted'])return current;
    assert.ok(Number.isFinite(remaining)&&remaining<=180,'The bounded original schedule is retained.');
    if(Date.now()-waitingLogged>25000){console.log('Waiting for natural '+kind+' start; '+Math.ceil(remaining)+' seconds remain.');waitingLogged=Date.now();}
    // Each wait is at most one second; no process clock, database time or plan is changed.
    await new Promise(resolve=>setTimeout(resolve,Math.min(1000,Math.max(100,remaining*1000))));
  }
}
async function prepare(){
  bodyOnce('schedule',()=>{
    const now=Date.now(),time=seconds=>new Date(now+seconds*1000).toISOString();
    return {registrationOpensAt:time(-3600),registrationClosesAt:time(60),startsAt:time(90),endsAt:time(600),matchStartsAt:time(150),matchEndsAt:time(210)};
  });
  await remember('eventId',async()=>(await act('event.create',{draftJson:JSON.stringify({name:s.prefix,projectName:'羽毛球',location:'独立合成单打球场',feeDescription:'每单20元，仅隔离合成收款',registrationOpensAt:s.bodies.schedule.registrationOpensAt,registrationClosesAt:s.bodies.schedule.registrationClosesAt,startsAt:s.bodies.schedule.startsAt,endsAt:s.bodies.schedule.endsAt,registrationReview:'manual',rulesText:'独立合成比赛与资金异常验证；没有真实现场比赛或银行转账。',declarationText:'只在本机演练，请勿真实转账。',declarationAckRequired:true})},'createEvent')).eventId);
  for(const name of ['ai-canonical-entry-state.json','ai-scheduled-entry-state.json']){
    const prior=JSON.parse(fs.readFileSync(path.join(c.out,name),'utf8'));
    assert.notEqual(String(prior.eventId),String(s.eventId),'Never reuse either canonical event.');
  }
  await remember('unitId',async()=>(await api(c.organizer,'/sports/b/registrations/units','POST',{eventId:s.eventId,name:s.prefix+'-单打',entryType:'individual',minMembers:1,maxMembers:1,limitCount:2,charged:true,amount:'20.00',paymentMode:'offline',payInstruction:'合成款项登记，请勿真实付款',requestKey:reqKey('createUnit')})).id);
  await once('published',()=>act('event.publish',{eventId:s.eventId,expectedVersion:versionOf('asp_event',s.eventId),contactName:'本轮合成责任人',contactMethod:'boundary@simulation.invalid'},'publish'));
  await remember('originalPlanFingerprint',async()=>planFingerprint());
  for(const [slot,actor] of [['entryA',c.people[0]],['entryB',c.people[5]]]){
    await remember(slot,async()=>(await api(actor,'/sports/c/registrations','POST',{unitId:s.unitId,requestKey:reqKey(slot+'Create')})).id);
    await once(slot+'Acknowledged',()=>api(actor,`/sports/c/registrations/${s[slot]}/declaration-ack`,'POST'));
    await once(slot+'Submitted',()=>action(actor,'registration.submit',{registrationId:s[slot],expectedVersion:versionOf('asp_registration',s[slot])},reqKey(slot+'Submit')));
    await remember(slot+'Obligation',async()=>(await row(actor,s[slot])).obligationId);
    const payment=bodyOnce(slot+'Payment',()=>({payerName:'独立补验合成付款人-'+slot,amount:'20.00',occurredAt:beijingTime(),note:'独立补验合成收款，无真实银行交易',requestKey:reqKey(slot+'Payment')}));
    await once(slot+'Paid',()=>api(c.organizer,`/sports/b/fees/obligations/${s[slot+'Obligation']}/confirm`,'POST',payment));
    await once(slot+'Approved',()=>api(c.organizer,`/sports/b/registrations/${s[slot]}/approve`,'POST'));
    test.check('IB01 '+slot+' freezes one personally confirmed singles participant with twenty adequate synthetic funds',(await row(actor,s[slot])).status==='approved'&&Number((await records(s[slot+'Obligation'])).netAmount)===20);
    await once(slot+'Checkin',()=>api(c.organizer,`/sports/b/competition/events/${s.eventId}/check-ins`,'POST',{personId:person(actor),requestKey:reqKey(slot+'Checkin')}));
  }
  test.check('IB02 two new ordinary singles entries consume two distinct places',readSql(`SELECT used_count FROM asp_capacity_pool WHERE unit_id=${id(s.unitId)};`)==='2');
  await remember('matchId',async()=>(await api(c.organizer,`/sports/b/competition/units/${s.unitId}/matches`,'POST',{code:s.prefix+'-01',registrationA:s.entryA,registrationB:s.entryB,requestKey:reqKey('createMatch')})).matchId);
  await once('scheduled',()=>act('match.schedule',{matchId:s.matchId,expectedVersion:versionOf('asp_match',s.matchId),startsAt:s.bodies.schedule.matchStartsAt,endsAt:s.bodies.schedule.matchEndsAt,courtName:'独立合成1号球场'},'scheduleMatch'));
  await once('draft',()=>api(c.organizer,`/sports/b/competition/matches/${s.matchId}/result`,'POST',{summary:'2:0',games:'21:13|21:16',outcomeA:'win',outcomeB:'loss',requestKey:reqKey('draftScore')}));
  test.check('IB03 legal draft exists without an official score',readSql(`SELECT count(*) FROM asp_result_version WHERE match_id=${id(s.matchId)} AND status='draft';`)===(s.steps.finalized?'0':'1'));
}
async function futureFixture(){
  await once('futureFixtureRejected',async()=>{
    const before=resultFingerprint();
    const current=await naturallyWait('event');
    test.check('IB04 database proves the event has begun while this exact fixture remains in the future',current.eventHasStarted&&current.matchHasStarted===false&&Number(current.secondsToMatch)>10);
    const response=await request(c.organizer,`/sports/b/competition/matches/${s.matchId}/finalize`,'POST',{requestKey:reqKey('futureFixtureFinalize')});
    test.check('IB05 complete legal first result is specifically rejected by the fixture start guard',response.code===409&&String(response.msg).includes('本场安排的开始时间'),{actualCode:response.code,actualReason:String(response.msg).slice(0,180)});
    test.check('IB06 fixture-time refusal changes no match, draft, result items, honors or growth',resultFingerprint()===before);
    s.futureFixtureObservation={...current,refusalObservedAt:new Date().toISOString(),code:response.code,reason:response.msg,fingerprint:before};save();
  });
  await once('finalized',async()=>{
    const current=await naturallyWait('match');
    test.check('IB07 both original planned start instants passed naturally',current.eventHasStarted&&current.matchHasStarted);
    await api(c.organizer,`/sports/b/competition/matches/${s.matchId}/finalize`,'POST',{requestKey:reqKey('naturalFinalize')});
    s.finalizedObservation=current;save();
  });
  await api(c.organizer,`/sports/b/competition/matches/${s.matchId}/finalize`,'POST',{requestKey:reqKey('naturalFinalize')});
  test.check('IB08 natural-start confirmation and exact replay retain one official result',readSql(`SELECT count(*) FROM asp_result_version WHERE match_id=${id(s.matchId)} AND status='confirmed';`)==='1');
  for(const actor of [c.people[0],c.people[5]])test.check('IB09 each singles participant earns attendance and completion only once',readSql(`SELECT COALESCE(sum(points_delta),0) FROM asp_growth_record WHERE event_id=${id(s.eventId)} AND person_id=${person(actor)}; SELECT count(*) FROM asp_growth_record WHERE event_id=${id(s.eventId)} AND person_id=${person(actor)} AND milestone='finish';`)==='40\n1');
  await once('wrapup',()=>act('event.wrapup',{eventId:s.eventId,expectedVersion:versionOf('asp_event',s.eventId)},'wrapup'));
  if(!s.steps.conflict){
    const settled=await closure('beforeExceptionSummary');
    test.check('IB10 normal competition is wrapped up with no money or issue obstruction before the isolated exception',settled.competitionEnded&&settled.fundsClosed&&settled.issuesClosed&&Number(settled.missingResults)===0&&Number(settled.proofsAwaitingReview)===0&&Number(settled.openObligations)===0&&Number(settled.pendingFundActions)===0&&Number(settled.pendingRefunds)===0&&Number(settled.unresolvedPaymentExceptions)===0&&Number(settled.openIssues)===0);
  }
}
async function exceptionOnly(){
  await remember('financeBeforeConflict',async()=>financeFingerprint());
  await once('conflict',async()=>{
    const response=await request(c.organizer,`/sports/b/fees/obligations/${s.entryAObligation}/confirm`,'POST',{...s.bodies.entryAPayment,amount:'21.00'});
    test.check('IB11 changing a legitimate existing payment key to twenty-one is refused',response.code!==200&&String(response.msg).includes('不同的付款内容'),{actualCode:response.code,actualReason:String(response.msg).slice(0,180)});
  });
  await remember('exceptionId',async()=>{
    for(let attempt=0;attempt<20;attempt++){
      const value=(await records(s.entryAObligation)).exceptions.find(x=>x.exceptionType==='duplicate_payment'&&x.status==='open');
      if(value)return value.exceptionId;
      await new Promise(resolve=>setTimeout(resolve,250));
    }throw Error('The actual rejected duplicate must persist as one human-review exception.');
  });
  test.check('IB12 duplicate conflict does not create or alter any money fact',financeFingerprint()===s.financeBeforeConflict);
  await once('exceptionOnlyCloseRejected',async()=>{
    const pending=await closure('pendingExceptionSummary');
    test.check('IB13 only this one payment exception remains: no unpaid duty, refund, complaint, proof or missing result',pending.competitionEnded&&pending.issuesClosed&&!pending.fundsClosed&&Number(pending.unresolvedPaymentExceptions)===1&&Number(pending.openObligations)===0&&Number(pending.pendingFundActions)===0&&Number(pending.pendingRefunds)===0&&Number(pending.openIssues)===0&&Number(pending.proofsAwaitingReview)===0&&Number(pending.missingResults)===0);
    const input={eventId:s.eventId,expectedVersion:versionOf('asp_event',s.eventId)};
    await api(c.organizer,'/sports/platform/actions/event.close/preview','POST',input);
    const confirmationId=await api(c.organizer,'/sports/platform/actions/event.close/confirm','POST',input);
    const beforeVersion=versionOf('asp_event',s.eventId),beforeMoney=financeFingerprint();
    const response=await request(c.organizer,'/sports/platform/actions/event.close/execute','POST',{input,requestKey:reqKey('exceptionBlockedClose'),confirmationId});
    test.check('IB14 valid human close confirmation is refused solely with the open money exception',response.code===409&&String(response.msg).includes('仍有待办'),{actualCode:response.code,actualReason:String(response.msg).slice(0,180)});
    test.check('IB15 exception-only closure refusal preserves event version, wrap-up state and every original money fact',versionOf('asp_event',s.eventId)===beforeVersion&&readSql(`SELECT closure_status FROM asp_event WHERE id=${id(s.eventId)};`)==='wrap_up'&&financeFingerprint()===beforeMoney);
    s.exceptionOnlyObservation={at:new Date().toISOString(),summary:pending,code:response.code};save();
  });
  const exception=(await records(s.entryAObligation)).exceptions.find(x=>String(x.exceptionId)===String(s.exceptionId));assert.ok(exception);
  const review=bodyOnce('review',()=>({expectedVersion:Number(exception.version),note:'独立合成核对：原20元收款和报名义务一致，21元仅为同键内容冲突且没有第二款项；保留原账本，不调整资金或资格。',requestKey:reqKey('reviewException')}));
  const route=`/sports/b/fees/obligations/${s.entryAObligation}/exceptions/${s.exceptionId}/resolve`;
  await once('resolved',()=>api(c.organizer,route,'POST',review));
  await api(c.organizer,route,'POST',review);
  test.check('IB16 exact repeat human review appends one audit and never changes original money',readSql(`SELECT count(*) FROM asp_audit_event WHERE action='finance.duplicate_payment.resolve' AND object_type='payment_exception' AND object_id=${id(s.exceptionId)};`)==='1'&&financeFingerprint()===s.financeBeforeConflict&&(await records(s.entryAObligation)).exceptions.find(x=>String(x.exceptionId)===String(s.exceptionId))?.status==='resolved');
  const ready=await closure('resolvedSummary');
  test.check('IB17 resolving the only obstruction restores independent closure readiness',ready.competitionEnded&&ready.fundsClosed&&ready.issuesClosed&&Number(ready.unresolvedPaymentExceptions)===0);
  await once('closed',()=>act('event.close',{eventId:s.eventId,expectedVersion:versionOf('asp_event',s.eventId)},'closeAfterReview'));
  test.check('IB18 normal independent event closes after human review with original time and money facts intact',readSql(`SELECT holding_status||'/'||closure_status FROM asp_event WHERE id=${id(s.eventId)};`)==='normal/closed'&&planFingerprint()===s.originalPlanFingerprint&&financeFingerprint()===s.financeBeforeConflict);
  for(const obligation of [s.entryAObligation,s.entryBObligation]){const value=await records(obligation);test.check('IB19 each original duty remains settled twenty with one receipt and no refund',Number(value.netAmount)===20&&value.receipts.length===1&&value.refunds.length===0);}
}
const sourceFiles=['scripts/Test-BadmintonIsolatedBoundaries.mjs','backend/aisports-domains/d09/aisports-table-match/src/main/java/org/dromara/sports/competition/service/CompetitionService.java','backend/aisports-domains/d04/aisports-table-event/src/main/java/org/dromara/sports/event/service/EventClosureService.java','backend/aisports-domains/d06/aisports-table-fee-obligation/src/main/java/org/dromara/sports/finance/service/FinanceService.java'];
try{
  assert.ok(process.argv.includes('--execute-new'),'Explicitly select the new isolated boundary scenario.');
  const jarPath=process.env.AISPORTS_REGRESSION_JAR_PATH,expected=process.env.AISPORTS_REGRESSION_JAR_SHA256;
  assert.ok(jarPath&&/^[a-f0-9]{64}$/.test(expected||''));assert.ok(fs.realpathSync(jarPath).startsWith(fs.realpathSync(process.cwd())+path.sep));
  assert.equal(hash(fs.readFileSync(jarPath)),expected);test.evidence.jarSha256=expected;test.evidence.runtimePid=Number(process.env.AISPORTS_REGRESSION_RUNTIME_PID);assert.ok(test.evidence.runtimePid>0);
  test.evidence.sourceFiles=Object.fromEntries(sourceFiles.map(file=>[file,hash(fs.readFileSync(file))]));
  test.evidence.scope='NEW synthetic singles event, actual ordinary-role isolated HTTP and natural event/fixture time. Legal early official result refusal with no side effect; one duplicate-payment exception as the sole obstruction; human exact replay and normal closure. No model, real bank, field match, direct SQL mutation or canonical-event mutation.';
  const owner=await api(c.organizer,'/system/user/getInfo'),setup=await api(c.admin,'/system/user/getInfo');
  test.check('ordinary organizer, not setup administrator, operates both independent boundaries',Boolean(owner.user?.userId)&&Boolean(setup.user?.userId)&&String(owner.user.userId)!==String(setup.user.userId));
  await prepare();await futureFixture();await exceptionOnly();
  test.evidence.objects={prefix:s.prefix,eventId:s.eventId,unitId:s.unitId,entryA:s.entryA,entryB:s.entryB,matchId:s.matchId,exceptionId:s.exceptionId};
  test.evidence.timeObservations={futureFixture:s.futureFixtureObservation,finalized:s.finalizedObservation};test.evidence.exceptionOnlyObservation=s.exceptionOnlyObservation;
  test.check('frozen product and new test source stayed unchanged during actual natural-time checks',sourceFiles.every(file=>hash(fs.readFileSync(file))===test.evidence.sourceFiles[file]));test.finish();
}catch(error){test.evidence.failure={name:error.name,message:String(error.message).slice(0,800)};test.save();save();console.log('FAILED '+error.name);process.exitCode=1;}
