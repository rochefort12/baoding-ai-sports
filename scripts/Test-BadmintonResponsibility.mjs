// New-run ordinary people. Real action confirmations, transactions and local
// HTTP only; no SQL, timestamp changes, model writes or historical initialization.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {testHarness,hashFile} from './lib/badminton-participant-test.mjs';
const h=testHarness('participant-responsibility');
const {context,people,progress,api,call,action,once,check,key,reference,room,entry,rejectedAction}=h;
const [A,B,C,D,E,F]=people;
const stage=process.argv[3]||'handover';
const same=(a,b)=>String(a)===String(b);
async function fields(actor,id,slot) {
  const rows=await api(actor,'/sports/c/registrations/'+id+'/fields');
  await once(slot,()=>api(actor,'/sports/c/registrations/'+id+'/fields','PUT',rows.map(row=>({eventFieldId:row.eventFieldId,valueText:({text:'模拟本人训练习惯 '+actor.label,number:'2',date:'2026-10-11',enum:'右手'})[row.valueType]}))));
}
async function acknowledgement(actor,manager,id,slot) {
  await once(slot+'.ack',()=>api(actor,'/sports/c/registrations/'+id+'/declaration-ack','POST'));
  const member=(await entry(manager,id)).members.find(row=>same(row.accountId,actor.id));assert.ok(member);
  if(member.status==='pending_confirmation')await once(slot+'.confirm',()=>api(actor,'/sports/c/registrations/invites/'+member.inviteToken+'/confirm','POST'));
}
async function submit(actor,id,slot) {
  if(progress.operations[slot]?.completed)return progress.operations[slot].result;
  return action(actor,'registration.submit',{registrationId:id,expectedVersion:await h.registrationVersion(actor,id)},slot);
}
async function handover() {
  for(const round of [1,2]){
    if(progress.operations['responsibility.'+round+'.completed']?.completed)continue;
    const id=progress.objects['recruitEntry'+round];assert.ok(id);
    const before=await entry(C,id);assert.equal(before.status,'submitted');
    const base='H'+round+'.';
    if(!progress.operations['handover.'+round+'.accept']?.completed){
    const version=await h.registrationVersion(C,id);
    await rejectedAction(C,'registration.handover',{registrationId:id,targetAccountId:F.id,reason:'模拟错误成员',expectedVersion:version},base+'01','Manager cannot nominate a person outside the confirmed roster',/已确认|有效成员/);
    await rejectedAction(C,'registration.handover',{registrationId:id,targetAccountId:C.id,reason:'模拟自交接',expectedVersion:version},base+'02','Manager cannot nominate themselves',/另一名|有效成员/);
    await rejectedAction(C,'registration.handover',{registrationId:id,targetAccountId:D.id,reason:'模拟旧版本',expectedVersion:version-1},base+'03','Stale registration version rejects responsibility handover',/已变化/);
    const made=await action(C,'registration.handover',{registrationId:id,targetAccountId:D.id,reason:'模拟办理交接；本场免费，等待审核和赛务安排。',expectedVersion:version},'handover.'+round+'.invite');
    const caseId=reference('handover'+round,made.result.caseId);
    check(base+'04','The original manager remains responsible until the named member personally accepts',(await entry(C,id)).canManage&&(await api(D,'/sports/entry-management/pending')).some(row=>same(row.id,caseId)));
    await rejectedAction(C,'registration.handover',{registrationId:id,targetAccountId:D.id,reason:'模拟重复邀请',expectedVersion:version},base+'05','A pending responsibility invitation cannot be duplicated',/已有.*交接/);
    await rejectedAction(E,'registration.acceptHandover',{caseId},base+'06','Another ordinary person cannot accept the named member’s responsibility',/指定接任|本人确认/);
    await action(D,'registration.acceptHandover',{caseId},'handover.'+round+'.accept');
    const after=await entry(D,id),historical=await entry(C,id);
    check(base+'07','Personal acceptance transfers management while preserving frozen roster, revision and original submitter read access',after.canManage&&!historical.canManage&&after.rosterRevision===before.rosterRevision&&after.requestKey===before.requestKey&&after.members.map(row=>String(row.id)).join(',')===before.members.map(row=>String(row.id)).join(','));
    check(base+'08','Room host follows the accepted entry manager without changing room membership',same((await room(D,progress.objects['recruitRoom'+round])).room.host_account_id,D.id)&&(await room(D,progress.objects['recruitRoom'+round])).members.length===2);
    await rejectedAction(C,'registration.handover',{registrationId:id,targetAccountId:D.id,reason:'模拟原管理人越权',expectedVersion:version},base+'09','Former manager cannot create a new handover',/只有当前.*管理人/);
    await rejectedAction(D,'registration.acceptHandover',{caseId},base+'10','Completed handover rejects a new acceptance command',/已结束|过期/);
    check(base+'11','Completed responsibility invitation leaves the recipient’s pending list',!(await api(D,'/sports/entry-management/pending')).some(row=>same(row.id,caseId)));
    }

    const teamId=progress.objects['team'+round],roomId=progress.objects['teamRoom'+round];assert.ok(teamId&&roomId);
    for(const actor of [A,B])await action(actor,'room.ready',{roomId,ready:true,expectedVersion:(await room(actor,roomId)).room.version},'long.'+round+'.ready.'+actor.label);
    const prepared=await action(A,'room.prepare',{roomId,expectedVersion:(await room(A,roomId)).room.version},'long.'+round+'.prepare');
    const longId=reference('teamEntry'+round,prepared.result.registrationId);
    for(const actor of [A,B]){await fields(actor,longId,'long.'+round+'.fields.'+actor.label);await acknowledgement(actor,A,longId,'long.'+round+'.ack.'+actor.label);}
    await submit(A,longId,'long.'+round+'.submit');
    const longBefore=await entry(A,longId),team=await api(A,'/sports/c/teams/'+teamId),target=team.members.find(row=>same(row.accountId,B.id)&&row.status==='active');assert.ok(target);
    const transferBefore=await call(A,'/sports/c/teams/'+teamId+'/captain','POST',{memberId:target.id});
    check(base+'12','Captain transfer is blocked while that captain still manages an unclosed submitted entry',transferBefore.code!==200&&/交接/.test(transferBefore.msg||''));
    const handing=await action(A,'registration.handover',{registrationId:longId,targetAccountId:B.id,reason:'模拟长期队本场责任交接，保留原冻结队名与成员。',expectedVersion:await h.registrationVersion(A,longId)},'long.'+round+'.handover');
    await action(B,'registration.acceptHandover',{caseId:handing.result.caseId},'long.'+round+'.accept');
    await once('long.'+round+'.transfer',()=>api(A,'/sports/c/teams/'+teamId+'/captain','POST',{memberId:target.id}));
    const transferred=await api(B,'/sports/c/teams/'+teamId);
    check(base+'13','After personal responsibility handover captain transfer retains one active captain',transferred.members.filter(row=>row.status==='active'&&row.role==='captain').length===1&&same(transferred.members.find(row=>row.role==='captain'&&row.status==='active').accountId,B.id));
    await once('long.'+round+'.leave',()=>api(A,'/sports/c/teams/'+teamId+'/leave','POST'));
    const retained=await entry(A,longId),managed=await entry(B,longId);
    check(base+'14','Former captain can leave after handover and frozen registration remains readable with its original team and roster',!retained.canManage&&managed.canManage&&retained.teamName===longBefore.teamName&&retained.rosterRevision===longBefore.rosterRevision&&retained.members.length===2);
    const disband=await call(B,'/sports/c/teams/'+teamId+'/disband','POST');
    check(base+'15','Disband stays blocked until actual event and funds responsibilities close',disband.code!==200&&/收尾|报名或资金责任/.test(disband.msg||''));
    check(base+'16','Outstanding-responsibility rejection leaves the long-term team active',(await api(B,'/sports/c/teams/'+teamId)).status==='active');
    await once('responsibility.'+round+'.completed',async()=>({confirmed:true}));
  }
  h.report.unexecuted=['24-hour handover expiry not clock-forced; no direct database change or claim of observing 24 hours.','Long-term team disband after actual event closure is reserved for the full event lifecycle test.'];
}
async function race(){
  for(const round of [1,2]){
    const u=progress.objects['units'+round],eventId=progress.objects['event'+round],base='C'+round+'.';
    const created=await once('concurrent.'+round+'.create',()=>h.prepareAction(A,'registration.create',{unitId:u.soloGeneral},'concurrent.'+round+'.createkey'));
    const drafts=await once('concurrent.'+round+'.createResults',()=>Promise.all([api(A,'/sports/platform/actions/registration.create/execute','POST',created),api(A,'/sports/platform/actions/registration.create/execute','POST',created)]));
    const id=reference('concurrentSingle'+round,drafts[0].result.registrationId);
    check(base+'01','Concurrent same-key draft creation returns the same receipt and registration',drafts[0].receiptId===drafts[1].receiptId&&same(drafts[0].result.registrationId,drafts[1].result.registrationId));
    await fields(A,id,'concurrent.'+round+'.fields');await acknowledgement(A,A,id,'concurrent.'+round+'.ack');
    const body=await once('concurrent.'+round+'.submitPrepared',async()=>h.prepareAction(A,'registration.submit',{registrationId:id,expectedVersion:await h.registrationVersion(A,id)},'concurrent.'+round+'.submit'));
    const submitted=await once('concurrent.'+round+'.samekeyResults',()=>Promise.all([api(A,'/sports/platform/actions/registration.submit/execute','POST',body),api(A,'/sports/platform/actions/registration.submit/execute','POST',body)]));
    check(base+'02','Concurrent same-key formal submission returns one successful action receipt',submitted[0].receiptId===submitted[1].receiptId);
    check(base+'03','Concurrent repeated formal submission freezes one roster and consumes one quota',(await entry(A,id)).rosterRevision===1&&(await api(A,'/sports/c/registrations/units?eventId='+eventId)).find(row=>same(row.id,u.soloGeneral)).usedCount===1);

    const conflict=await once('decline.'+round+'.draft',()=>api(C,'/sports/c/registrations','POST',{unitId:u.conflict,requestKey:key('decline.'+round+'.create')}));
    await once('decline.'+round+'.invite',()=>api(C,'/sports/c/registrations/'+conflict.id+'/members','POST',{phone:D.phone,requestSms:false}));
    for(const actor of [C,D]){await fields(actor,conflict.id,'decline.'+round+'.fields.'+actor.label);await acknowledgement(actor,C,conflict.id,'decline.'+round+'.ack.'+actor.label);}
    const member=(await entry(C,conflict.id)).members.find(row=>same(row.accountId,D.id));
    const prepared=await once('decline.'+round+'.submitPrepared',async()=>h.prepareAction(C,'registration.submit',{registrationId:conflict.id,expectedVersion:await h.registrationVersion(C,conflict.id)},'decline.'+round+'.submit'));
    const outcomes=await once('decline.'+round+'.race',()=>Promise.all([call(C,'/sports/platform/actions/registration.submit/execute','POST',prepared),call(D,'/sports/c/registrations/invites/'+member.inviteToken+'/decline','POST')]));
    const actual=await entry(C,conflict.id),unit=(await api(C,'/sports/c/registrations/units?eventId='+eventId)).find(row=>same(row.id,u.conflict));
    check(base+'04','Member refusal and formal submission cannot both complete successfully',outcomes.filter(row=>row.code===200).length===1);
    check(base+'05','The winning transaction preserves either one frozen complete roster or an unoccupied draft with refusal',actual.status==='submitted'?unit.usedCount===1&&actual.rosterRevision===1&&actual.members.every(row=>row.status==='confirmed'):actual.status==='draft'&&unit.usedCount===0&&actual.rosterRevision===0&&actual.members.find(row=>same(row.accountId,D.id)).status==='declined');
    reference('declineRace'+round,{registrationId:conflict.id,winner:actual.status==='submitted'?'submission':'member-decline'});
  }
}
async function strictRooms(){
  const unit=progress.objects.units1.race;
  const made=await action(C,'room.create',{unitId:unit,name:context.prefix+'-确认绑定异常房间'},'strict.create');
  const id=reference('strictRoom',made.result.roomId);
  await action(C,'room.recruit',{roomId:id,message:'模拟确认绑定的招募异常测试',expectedVersion:(await room(C,id)).room.version},'strict.recruit');
  const invited=await action(F,'room.apply',{roomId:id},'strict.Fapply');
  const offerId=reference('strictOffer',invited.result.offerId);
  await rejectedAction(D,'room.answer',{offerId,answer:'accept'},'RS01','Unrelated ordinary person with a real confirmation cannot accept someone else’s recruitment',/邀请不存在/);
  await rejectedAction(E,'room.apply',{roomId:id},'RS02','Last provisional recruitment seat blocks another applicant',/席位|已满|待确认/);
  await action(C,'room.answer',{offerId,answer:'accept'},'strict.Caccept');
  check('RS03','Only personal applicant and host acceptance creates two seats',(await room(C,id)).members.length===2);
  await rejectedAction(C,'room.answer',{offerId,answer:'accept'},'RS04','A new fully confirmed command cannot accept the completed offer again',/邀请已结束/);
  await action(C,'room.ready',{roomId:id,ready:true,expectedVersion:(await room(C,id)).room.version},'strict.Cready');
  await rejectedAction(C,'room.prepare',{roomId:id,expectedVersion:(await room(C,id)).room.version},'RS05','Prepared host cannot generate a draft before the other member personally prepares',/每人确认准备/);
  await rejectedAction(F,'room.prepare',{roomId:id,expectedVersion:(await room(F,id)).room.version},'RS06','Ordinary non-host cannot generate a room draft',/房主/);
  await rejectedAction(C,'room.ready',{roomId:id,ready:false,expectedVersion:(await room(C,id)).room.version-1},'RS07','Stale preparation command cannot overwrite the current room state',/已变化/);
  await rejectedAction(C,'room.leave',{roomId:id,expectedVersion:(await room(C,id)).room.version},'RS08','A host with a remaining member must nominate that member before leaving',/接任房主/);
  await action(C,'room.leave',{roomId:id,newHostAccountId:F.id,expectedVersion:(await room(C,id)).room.version},'strict.Cleave');
  const left=await room(F,id);check('RS09','Personal host departure transfers the room and keeps one real seat',same(left.room.host_account_id,F.id)&&left.members.length===1);
  const privateAfter=await call(C,'/sports/rooms/'+id);check('RS10','A departed host loses private room access',privateAfter.code!==200&&/成员|不存在/.test(privateAfter.msg||''));
  await action(F,'room.leave',{roomId:id,expectedVersion:left.room.version},'strict.Fleave');
  check('RS11','The final person’s departure closes the room without reserving a formal quota',!(await api(F,'/sports/rooms')).rooms.some(row=>same(row.id,id))&&(await api(F,'/sports/c/registrations/units?eventId='+progress.objects.event1)).find(row=>same(row.id,unit)).usedCount===0);
  const longRoom=progress.objects.teamRoom1;
  await rejectedAction(B,'room.leave',{roomId:longRoom,newHostAccountId:E.id,expectedVersion:(await room(B,longRoom)).room.version},'RS12','Room exit with an existing submitted entry stays in the entry-responsibility flow',/已生成报名|报名详情交接/);
}
async function resubmit(){
  for(const round of [1,2]){
    const id=progress.objects['recruitEntry'+round],eventId=progress.objects['event'+round],unit=progress.objects['units'+round].recruit;
    const original=await entry(D,id);assert.ok(original.canManage);
    const withdrawn=await once('resubmit.'+round+'.withdraw',()=>api(D,'/sports/c/registrations/'+id+'/withdraw','POST'));
    check('BW'+round+'.01','Legal whole-entry withdrawal releases the exact quota and preserves submitted roster history',withdrawn.status==='draft'&&withdrawn.rosterRevision===1&&withdrawn.requestKeyConsumed&&(await api(D,'/sports/c/registrations/units?eventId='+eventId)).find(row=>same(row.id,unit)).usedCount===0);
    const submitted=await submit(D,id,'resubmit.'+round+'.submit');
    const after=await entry(D,id);
    check('BW'+round+'.02','New confirmed resubmission creates a second roster revision and one quota with a fresh submit key',after.status==='submitted'&&after.rosterRevision===2&&after.requestKey!==original.requestKey&&(await api(D,'/sports/c/registrations/units?eventId='+eventId)).find(row=>same(row.id,unit)).usedCount===1);
    await rejectedAction(D,'registration.submit',{registrationId:id,expectedVersion:0},'BW'+round+'.03','A stale repeated submit cannot produce another roster or quota',/已变化|重新核对/);
    check('BW'+round+'.04','Rejected stale request leaves the second frozen roster intact',(await entry(D,id)).rosterRevision===2);
  }
}
async function declarationAccess(){
  const expected=crypto.createHash('sha256').update(fs.readFileSync('plus-ui/public/images/sports/badminton-hero-v1.webp')).digest('hex');
  async function image(actor,id){
    const route='/sports/c/registrations/'+id+'/declaration-image';
    const response=await fetch(context.backend+route,{headers:{clientid:context.clientId,...(actor?{Authorization:'Bearer '+actor.token}:{})}});
    const body=new Uint8Array(await response.arrayBuffer()),type=response.headers.get('content-type')||'';
    h.report.requests.push({actor:actor?.label||'anonymous',method:'GET',route,status:response.status,contentType:type,byteLength:body.length});
    return{response,body,type,digest:crypto.createHash('sha256').update(body).digest('hex')};
  }
  const id=progress.objects.recruitEntry1;
  for(const actor of [C,D]){const result=await image(actor,id);check('DA01.'+actor.label,'Actual manager or frozen roster member reads only the bound statement bytes',result.type.startsWith('image/')&&result.digest===expected&&result.response.headers.get('cache-control')==='private, no-store');}
  for(const actor of [F,null]){const result=await image(actor,id);check('DA02.'+(actor?.label||'anonymous'),'Unrelated or anonymous account cannot receive declaration image bytes',!result.type.startsWith('image/')&&result.digest!==expected);}
  const draft=await once('declaration.pending.draft',()=>api(C,'/sports/c/registrations','POST',{unitId:progress.objects.units1.race,requestKey:key('declaration.pending.create')}));
  reference('declarationPrivateEntry',draft.id);
  await once('declaration.pending.invite',()=>api(C,'/sports/c/registrations/'+draft.id+'/members','POST',{phone:E.phone,requestSms:false}));
  const member=(await entry(C,draft.id)).members.find(row=>same(row.accountId,E.id));assert.ok(member);
  if(!progress.operations['declaration.pending.decline']?.completed){const before=await image(E,draft.id);check('DA03','A real pending personally addressed invitation can read its bound image before confirming',before.type.startsWith('image/')&&before.digest===expected);}
  await once('declaration.pending.decline',()=>api(E,'/sports/c/registrations/invites/'+member.inviteToken+'/decline','POST'));
  const after=await image(E,draft.id);check('DA04','Declining the actual invitation removes statement image access',!after.type.startsWith('image/')&&after.digest!==expected);
  const missing=await image(D,'1');check('DA05','An unrelated registration ID cannot act as an arbitrary file reader',!missing.type.startsWith('image/'));
}
try{await h.preflight();if(stage==='handover')await handover();else if(stage==='race')await race();else if(stage==='strict-rooms')await strictRooms();else if(stage==='resubmit')await resubmit();else if(stage==='declaration-access')await declarationAccess();else throw new Error('Unknown responsibility stage');h.report.passed=true;}
catch(error){h.report.failures.push({id:stage,reason:error.message});process.exitCode=1;}
finally{h.final({stage,sourceFiles:['scripts/Test-BadmintonResponsibility.mjs','scripts/lib/badminton-participant-test.mjs'].map(file=>({path:file,sha256:hashFile(file)}))});}
