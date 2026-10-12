// Ordinary-role real HTTP against the prepared isolated database only.
// The original future AI event is cancelled after valid pre-start result attempts are refused.
// Money, people, attendance and scores here are synthetic; no real bank transfer or clock change.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {context as c,key,api,request,action,readSql,versionOf,beijingTime,createEvidence} from './lib/BusinessRegression.mjs';

const test=createEvidence('badminton-temporal-boundary');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const id=value=>{assert.match(String(value),/^\d+$/,'Business identifier');return String(value);};
const sourceFile=path.join(c.out,'ai-canonical-entry-state.json');
const originalBytes=fs.readFileSync(sourceFile);
const original=JSON.parse(originalBytes.toString('utf8').replace(/^\uFEFF/,''));
const sourceSha=sha(originalBytes);
assert.equal(original.runId,c.runId,'Only the prepared original canonical event may be cancelled.');
assert.equal(original.syntheticBusiness,true,'The event must be an explicitly synthetic isolated scenario.');
const event=id(original.eventId),unit=id(original.pairUnitId);
const entries=['entryA','entryB'].map(name=>({name,registration:id(original[name]),obligation:id(original[name+'Obligation']),manager:c.people.find(person=>String(person.id)===String(original[name+'Manager']))}));
assert.ok(entries.every(entry=>entry.manager),'Use each actual retained room host; never assume C manages D’s room.');
const stateFile=path.join(c.out,'temporal-boundary-state.private.json');
const s=fs.existsSync(stateFile)?JSON.parse(fs.readFileSync(stateFile,'utf8').replace(/^\uFEFF/,'')):{runId:c.runId,eventId:event,sourceSha256:sourceSha,steps:{},keys:{},bodies:{},observations:{}};
assert.equal(s.runId,c.runId);assert.equal(s.eventId,event);assert.equal(s.sourceSha256,sourceSha,'Do not replace the source checkpoint during recovery.');
const save=()=>{
  const temporary=stateFile+'.'+key()+'.tmp';
  const descriptor=fs.openSync(temporary,'wx');
  try {fs.writeFileSync(descriptor,JSON.stringify(s,null,2));fs.fsyncSync(descriptor);} finally {fs.closeSync(descriptor);}
  fs.renameSync(temporary,stateFile);
};
const requestKey=slot=>{s.keys[slot]??=key();save();return s.keys[slot];};
const bodyOnce=(slot,work)=>{if(s.bodies[slot]===undefined){s.bodies[slot]=work();save();}return s.bodies[slot];};
const once=async(slot,work)=>{if(s.steps[slot])return;await work();s.steps[slot]={observedAt:new Date().toISOString(),jarSha256:test.evidence.jarSha256};save();};
const remember=async(slot,work)=>{if(s[slot]!==undefined)return s[slot];s[slot]=await work();save();return s[slot];};
const act=async(code,input,slot)=>(await action(c.organizer,code,input,requestKey(slot))).value;
const records=obligation=>api(c.organizer,`/sports/b/fees/obligations/${id(obligation)}/records`);
const registration=async entry=>{
  const row=(await api(entry.manager,'/sports/c/registrations')).find(value=>String(value.id)===entry.registration);
  assert.ok(row,'The actual retained manager can read the original formal entry.');return row;
};
const person=actor=>id(readSql(`SELECT person_id FROM asp_account WHERE id=${id(actor.id)};`));
const future=()=>JSON.parse(readSql(`SELECT json_build_object('isFuture',starts_at>CURRENT_TIMESTAMP,'secondsBeforeStart',extract(epoch FROM starts_at-CURRENT_TIMESTAMP),'holdingStatus',holding_status,'closureStatus',closure_status) FROM asp_event WHERE id=${event};`));
const requireFuture=()=>{
  const current=future();
  assert.ok(current.isFuture&&Number(current.secondsBeforeStart)>30&&current.holdingStatus==='normal','Do not run an expected refusal at or after the real planned start.');
};
const originalPlan=()=>readSql(`SELECT md5(jsonb_build_object('name',e.name,'project',e.project_name,'startsAt',e.starts_at,'endsAt',e.ends_at,'rules',e.rules_text,'declaration',e.declaration_text,'units',(SELECT jsonb_agg(to_jsonb(u) ORDER BY u.id) FROM asp_competition_unit u WHERE u.event_id=e.id),'feePolicies',(SELECT jsonb_agg(to_jsonb(f) ORDER BY f.id) FROM asp_fee_policy f WHERE f.unit_id IN(SELECT id FROM asp_competition_unit WHERE event_id=e.id)))::text) FROM asp_event e WHERE e.id=${event};`);
const outcomeFingerprint=()=>readSql(`SELECT md5(COALESCE(string_agg(f.kind||':'||f.fact,'|' ORDER BY f.kind,f.fact),'')) FROM (
  SELECT 'result' AS kind,to_jsonb(r)::text AS fact FROM asp_result_version r WHERE r.match_id=${id(s.matchId)}
  UNION ALL SELECT 'item',to_jsonb(i)::text FROM asp_result_item i WHERE i.result_version_id IN(SELECT id FROM asp_result_version WHERE match_id=${id(s.matchId)})
  UNION ALL SELECT 'honor',to_jsonb(h)::text FROM asp_honor h WHERE h.event_id=${event}
  UNION ALL SELECT 'growth',to_jsonb(g)::text FROM asp_growth_record g WHERE g.event_id=${event}) f;`);
const singlesFingerprint=obligation=>readSql(`SELECT md5(COALESCE(string_agg(f.kind||':'||f.fact,'|' ORDER BY f.kind,f.fact),'')) FROM (
  SELECT 'payment' AS kind,to_jsonb(p)::text AS fact FROM asp_payment p WHERE p.id IN(SELECT payment_id FROM asp_payment_allocation WHERE obligation_id=${id(obligation)})
  UNION ALL SELECT 'allocation',to_jsonb(a)::text FROM asp_payment_allocation a WHERE a.obligation_id=${id(obligation)}
  UNION ALL SELECT 'refund',to_jsonb(r)::text FROM asp_refund r WHERE r.payment_id IN(SELECT payment_id FROM asp_payment_allocation WHERE obligation_id=${id(obligation)})
  UNION ALL SELECT 'action',to_jsonb(a)::text FROM asp_payment_action a WHERE a.obligation_id=${id(obligation)}) f;`);
async function blocked(slot,label,operation){
  await once(slot,async()=>{
    requireFuture();
    const before=outcomeFingerprint(),version=versionOf('asp_event',event);
    const response=await operation();
    test.check(label,response.code===409&&String(response.msg).includes('尚未开赛'),{actualCode:response.code,actualReason:String(response.msg).slice(0,180)});
    test.check(label+' preserves score, honor, growth and event version',outcomeFingerprint()===before&&versionOf('asp_event',event)===version);
    s.observations[slot]={observedAt:new Date().toISOString(),code:response.code,reason:String(response.msg).slice(0,180),fingerprint:before};save();
  });
}
async function rejectedAction(code,slot){
  const input={eventId:event,expectedVersion:versionOf('asp_event',event)};
  const definition=c.definitions.find(row=>row.definition.code===code)?.definition;
  assert.ok(definition,'The current action definition is available.');
  let confirmationId;
  if(definition.confirmation){
    await api(c.organizer,`/sports/platform/actions/${code}/preview`,'POST',input);
    confirmationId=await api(c.organizer,`/sports/platform/actions/${code}/confirm`,'POST',input);
  }
  return request(c.organizer,`/sports/platform/actions/${code}/execute`,'POST',{input,requestKey:requestKey(slot),confirmationId});
}
async function prepare(){
  if(!s.steps.cancelled)requireFuture();
  await remember('originalPlanFingerprint',async()=>originalPlan());
  const singles=JSON.parse(fs.readFileSync(path.join(c.out,'canonical-singles-refund-state.json'),'utf8'));
  assert.equal(singles.runId,c.runId);assert.equal(String(singles.eventId),event);
  assert.ok(singles.steps?.refunded,'The independent singles refund must be completed beforehand.');
  s.singleObligation??=id(singles.obligationId);save();
  const singleRecord=await records(s.singleObligation);
  test.check('TB01 already-refunded singles remains zero and is not replayed',Number(singleRecord.netAmount)===0&&singleRecord.receipts.length===1&&singleRecord.refunds.length===1);
  await remember('singleFingerprint',async()=>singlesFingerprint(s.singleObligation));
  const proof=JSON.parse(fs.readFileSync(path.join(c.out,'canonical-payment-proof-state.json'),'utf8'));
  assert.equal(proof.runId,c.runId);assert.ok(proof.proofId,'Wait for the actual payment-proof upload fix and successful private upload.');
  const proofRows=await api(entries[0].manager,`/sports/c/registrations/${entries[0].registration}/payment-proofs`);
  test.check('TB02 optional private payment image exists before money registration',proofRows.some(row=>String(row.id)===String(proof.proofId)));
  for(const entry of entries){
    const before=await records(entry.obligation);
    test.check('TB03 '+entry.name+' retains the material-confirmed forty-yuan duty',Number(before.dueAmount)===40&&String((await registration(entry)).obligationId)===entry.obligation);
    if(!s.steps[entry.name+'Paid']){
      test.check('TB04 '+entry.name+' starts unpaid with no synthetic receipt',Number(before.netAmount)===0&&before.receipts.length===0);
      const body=bodyOnce(entry.name+'Payment',()=>({payerName:'时序轮合成原付款人-'+entry.name,amount:'40.00',occurredAt:beijingTime(),note:'隔离时序测试合成收款，不是真实银行到账',requestKey:requestKey(entry.name+'Payment')}));
      await once(entry.name+'Paid',()=>api(c.organizer,`/sports/b/fees/obligations/${entry.obligation}/confirm`,'POST',body));
    }
    await once(entry.name+'Approved',()=>api(c.organizer,`/sports/b/registrations/${entry.registration}/approve`,'POST'));
    if(!s.steps.cancelled)test.check('TB05 '+entry.name+' has independent adequate funds and human qualification',(await registration(entry)).status==='approved'&&Number((await records(entry.obligation)).netAmount)===40);
  }
  if(s.steps.cancelled)return;
  requireFuture();
  for(let index=0;index<4;index++){
    const personId=person(c.people[index]);
    await once('attendance-'+index,()=>api(c.organizer,`/sports/b/competition/events/${event}/check-ins`,'POST',{personId,requestKey:requestKey('attendance-'+index)}));
    test.check('TB06 participant '+index+' pre-start attendance is distinct from completion',readSql(`SELECT count(*) FROM asp_checkin WHERE event_id=${event} AND person_id=${personId}; SELECT COALESCE(sum(points_delta),0) FROM asp_growth_record WHERE event_id=${event} AND person_id=${personId}; SELECT count(*) FROM asp_growth_record WHERE event_id=${event} AND person_id=${personId} AND milestone IN('finish','team_finish');`)==='1\n10\n0');
  }
  await remember('matchId',async()=>(await api(c.organizer,`/sports/b/competition/units/${unit}/matches`,'POST',{code:c.prefix+'-TEMPORAL-FUTURE-PAIR',registrationA:entries[0].registration,registrationB:entries[1].registration,requestKey:requestKey('match')})).matchId);
  await once('scheduled',async()=>{
    const detail=await api(c.organizer,`/sports/b/events/${event}`);
    await act('match.schedule',{matchId:s.matchId,expectedVersion:versionOf('asp_match',s.matchId),startsAt:detail.startsAt,endsAt:new Date(Math.min(new Date(detail.endsAt).getTime(),new Date(detail.startsAt).getTime()+3600000)).toISOString(),courtName:'时序轮合成1号球场'},'schedule');
  });
  test.check('TB07 valid opponents can be pre-arranged at their future event time',readSql(`SELECT count(*) FROM asp_match m JOIN asp_stage s ON s.id=m.stage_id JOIN asp_competition_unit u ON u.id=s.unit_id JOIN asp_event e ON e.id=u.event_id WHERE m.id=${id(s.matchId)} AND m.scheduled_start=e.starts_at AND m.scheduled_start>CURRENT_TIMESTAMP;`)==='1');
  await once('draftScored',()=>api(c.organizer,`/sports/b/competition/matches/${s.matchId}/result`,'POST',{summary:'2:0',games:'21:13|21:16',outcomeA:'win',outcomeB:'loss',requestKey:requestKey('draftScore')}));
  test.check('TB08 legal synthetic draft score does not create an official result',readSql(`SELECT count(*) FROM asp_result_version WHERE match_id=${id(s.matchId)} AND status='draft'; SELECT count(*) FROM asp_result_version WHERE match_id=${id(s.matchId)} AND status='confirmed';`)==='1\n0');
}
async function temporalRefusals(){
  if(s.steps.cancelled)return;
  await blocked('resultRejected','TB09 complete legal draft cannot become a first formal result before start',()=>request(c.organizer,`/sports/b/competition/matches/${s.matchId}/finalize`,'POST',{requestKey:requestKey('futureFinalize')}));
  await blocked('awardRejected','TB10 future event cannot create a new event award',()=>request(c.organizer,'/sports/b/competition/awards','POST',{registrationId:entries[0].registration,title:'时序轮合成双打优胜奖',basis:'合成测试提前申请奖项，尚未发生现场比赛',requestKey:requestKey('futureAward')}));
  await blocked('wrapupRejected','TB11 normal future event cannot be declared ended',()=>rejectedAction('event.wrapup','futureWrapup'));
  await blocked('closeRejected','TB12 normal future event cannot be declared fully closed',()=>rejectedAction('event.close','futureClose'));
  const closure=await act('event.closure',{eventId:event},'beforeCancelSummary');
  test.check('TB13 normal future event still reports no completed competition',closure.competitionEnded===false&&closure.missingResults===1&&Number(closure.proofsAwaitingReview)===0);
  test.check('TB14 planned details and source checkpoint remain unchanged before cancellation',originalPlan()===s.originalPlanFingerprint&&sha(fs.readFileSync(sourceFile))===sourceSha);
}
async function cancellation(){
  assert.ok(['resultRejected','awardRejected','wrapupRejected','closeRejected'].every(slot=>s.steps[slot]),'All four true time refusals must be observed before cancellation.');
  await remember('attendanceFingerprint',async()=>readSql(`SELECT md5(COALESCE(string_agg(to_jsonb(i)::text,'|' ORDER BY i.id),'')) FROM asp_checkin i WHERE i.event_id=${event};`));
  if(!s.steps.cancelled){
    const current=future();
    const reason='时序轮合成验证已确认赛前正式结果受阻；取消未来赛事并按原付款人退还两单模拟收款，保留报到与草稿。';
    if(current.holdingStatus==='cancelled'){
      assert.equal(readSql(`SELECT cancel_reason FROM asp_event WHERE id=${event};`),reason,'Only this checkpoint’s exact cancellation may be recovered.');
      s.steps.cancelled={observedAt:new Date().toISOString(),recoveredFromRetainedBusinessFact:true};save();
    } else {
      requireFuture();
      await once('cancelled',()=>api(c.organizer,`/sports/b/events/${event}/cancel`,'POST',{reason}));
    }
  }
  test.check('TB15 cancellation retains the legitimate pre-start attendance facts',readSql(`SELECT holding_status FROM asp_event WHERE id=${event};`)==='cancelled'&&readSql(`SELECT md5(COALESCE(string_agg(to_jsonb(i)::text,'|' ORDER BY i.id),'')) FROM asp_checkin i WHERE i.event_id=${event};`)===s.attendanceFingerprint);
  for(const entry of entries){
    const before=await records(entry.obligation);
    assert.equal(before.receipts.length,1,'Only this checkpoint’s one synthetic receipt may be refunded.');
    const payment=before.receipts[0];
    assert.equal(payment.payerName,s.bodies[entry.name+'Payment'].payerName,'Refund the original synthetic payer.');
    if(!s.steps[entry.name+'Refunded']){
      assert.equal(Number(payment.amount),40);assert.equal(Number(payment.refundedAmount),0);
      assert.ok(payment.pendingActionId,'Cancellation must create a genuine human refund action.');
      const body=bodyOnce(entry.name+'Refund',()=>({amount:'40.00',occurredAt:beijingTime(),recipientName:payment.payerName,note:'隔离时序取消后按原付款人全额退还合成款项，没有真实银行转账',requestKey:requestKey(entry.name+'Refund')}));
      await once(entry.name+'Refunded',()=>api(c.organizer,`/sports/b/fees/actions/${payment.pendingActionId}/refund`,'POST',body));
    }
    const after=await records(entry.obligation);
    test.check('TB16 '+entry.name+' keeps one original receipt and its single full original-payer refund',Number(after.netAmount)===0&&after.receipts.length===1&&after.refunds.length===1&&Number(after.refunds[0].amount)===40&&after.refunds[0].recipientName===payment.payerName);
  }
  test.check('TB17 earlier singles money is never replayed by doubles cancellation',singlesFingerprint(s.singleObligation)===s.singleFingerprint&&(await records(s.singleObligation)).refunds.length===1);
  const beforeClose=await act('event.closure',{eventId:event},'cancelledSummary');
  test.check('TB18 cancelled future event separates missing scores from completed refund and issue duties',beforeClose.competitionEnded===true&&beforeClose.fundsClosed===true&&beforeClose.issuesClosed===true&&Number(beforeClose.openObligations)===0&&Number(beforeClose.pendingFundActions)===0&&Number(beforeClose.unresolvedPaymentExceptions)===0&&Number(beforeClose.pendingRefunds)===0);
  await once('cancelWrapup',()=>act('event.wrapup',{eventId:event,expectedVersion:versionOf('asp_event',event)},'cancelWrapup'));
  await once('cancelClose',()=>act('event.close',{eventId:event,expectedVersion:versionOf('asp_event',event)},'cancelClose'));
  const final=await act('event.closure',{eventId:event},'finalSummary');
  test.check('TB19 cancellation aftercare can close before the unchanged planned start',readSql(`SELECT closure_status='closed' AND starts_at>CURRENT_TIMESTAMP FROM asp_event WHERE id=${event};`)==='t'&&final.competitionEnded&&final.fundsClosed&&final.issuesClosed);
  test.check('TB20 cancelled history still has no official future score, event honor or completion growth',readSql(`SELECT count(*) FROM asp_result_version WHERE match_id=${id(s.matchId)} AND status='confirmed'; SELECT count(*) FROM asp_honor WHERE event_id=${event} AND category='event'; SELECT count(*) FROM asp_growth_record WHERE event_id=${event} AND milestone IN('finish','team_finish');`)==='0\n0\n0');
  test.check('TB21 original planned event, source price and immutable participant checkpoint were preserved',originalPlan()===s.originalPlanFingerprint&&sha(fs.readFileSync(sourceFile))===sourceSha);
}
const sourceFiles=['scripts/Test-BadmintonTemporalBoundary.mjs','backend/aisports-domains/d09/aisports-table-match/src/main/java/org/dromara/sports/competition/service/CompetitionService.java','backend/aisports-domains/d09/aisports-table-match/src/main/java/org/dromara/sports/competition/domain/CompetitionEvent.java','backend/aisports-domains/d09/aisports-table-match/src/main/java/org/dromara/sports/competition/domain/CompetitionMatch.java','backend/aisports-domains/d04/aisports-table-event/src/main/java/org/dromara/sports/event/service/EventClosureService.java'];
try{
  assert.ok(process.argv.includes('--execute-future-cancel'),'Prepared only: parent must explicitly authorize --execute-future-cancel after the new JAR and proof upload pass.');
  const jarPath=process.env.AISPORTS_REGRESSION_JAR_PATH,expectedJar=process.env.AISPORTS_REGRESSION_JAR_SHA256;
  assert.ok(jarPath&&/^[a-f0-9]{64}$/.test(expectedJar||''),'Bind the real currently running isolated JAR.');
  assert.ok(fs.realpathSync(jarPath).startsWith(fs.realpathSync(process.cwd())+path.sep),'Only this project’s JAR may be bound.');
  const actualJar=sha(fs.readFileSync(jarPath));assert.equal(actualJar,expectedJar);
  const runtimePid=Number(process.env.AISPORTS_REGRESSION_RUNTIME_PID);assert.ok(Number.isSafeInteger(runtimePid)&&runtimePid>0);
  test.evidence.jarSha256=actualJar;test.evidence.runtimePid=runtimePid;test.evidence.jarFile=path.relative(process.cwd(),jarPath).replaceAll('\\','/');
  test.evidence.sourceFiles=Object.fromEntries(sourceFiles.map(file=>[file,sha(fs.readFileSync(file))]));
  test.evidence.scope='Actual isolated ordinary-role HTTP with read-only PostgreSQL evidence. Original future synthetic AI event: pre-start attendance, legal draft, four exact time refusals, cancellation, 2×40 synthetic original-payer refunds and closed aftercare. No real field match, bank transfer, model call, clock change or direct database write.';
  test.evidence.objects={eventId:event,unitId:unit,entryA:entries[0].registration,entryB:entries[1].registration,sourceSha256:sourceSha};
  const identity=await api(c.organizer,'/system/user/getInfo');
  const setup=await api(c.admin,'/system/user/getInfo');
  test.check('ordinary organizer is distinct from the platform setup administrator',Boolean(identity.user?.userId)&&Boolean(setup.user?.userId)&&String(identity.user.userId)!==String(setup.user.userId));
  test.check('the retained event belongs to this organizer’s original isolated organization',readSql(`SELECT organization_id FROM asp_event WHERE id=${event};`)===String(c.organizationId));
  await prepare();await temporalRefusals();await cancellation();
  test.evidence.objects.matchId=s.matchId;test.evidence.observations=s.observations;
  test.evidence.reusedCompletedCheckpointSteps=Object.entries(s.steps).filter(([,value])=>value.jarSha256&&value.jarSha256!==actualJar).map(([slot,value])=>({slot,...value}));
  test.check('temporal source stayed unchanged during the actual narrow run',sourceFiles.every(file=>sha(fs.readFileSync(file))===test.evidence.sourceFiles[file]));
  test.finish();
}catch(error){test.evidence.failure={name:error.name,message:String(error.message).slice(0,700)};test.save();save();console.log('FAILED '+error.name);process.exitCode=1;}
