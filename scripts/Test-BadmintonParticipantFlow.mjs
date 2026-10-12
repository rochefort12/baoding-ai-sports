// New-round standard + abnormal participant facts in the root-backed-up isolated runtime.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {testHarness} from './lib/badminton-participant-test.mjs';

const h = testHarness('participant-http');
const {context,people,organizer,progress,api,call,action,once,check,key,reference,room,entry} = h;
const [A,B,C,D,E,F] = people;
const stage = process.argv[3] || 'prepare';
const prefix = context.prefix + '-参与轮';
const iso = hours => new Date(Date.now() + hours * 3600000).toISOString();
const active = detail => detail.members.filter(member => member.status === 'active');
const sameId = (left,right) => String(left)===String(right);
const observed = id => progress.checks.some(row=>row.id===id);
async function rejectHttp(actor, route, method, input, id, text) {
  const reply=await call(actor,route,method,input); check(id,text,reply.code!==200); return reply;
}
async function createTeam(actor, name, slot) {
  return once(slot,async()=>{
    const home=await api(actor,'/sports/c/teams');
    const previous=home.memberships.find(row=>row.name===name && row.membershipStatus==='active');
    if(previous)return api(actor,'/sports/c/teams/'+previous.teamId);
    return api(actor,'/sports/c/teams','POST',{name});
  });
}
async function applyJoin(captain, member, teamId, slot) {
  return once(slot,async()=>{
    let detail=await api(captain,'/sports/c/teams/'+teamId);
    if(active(detail).some(row=>sameId(row.accountId,member.id)))return detail;
    let home=await api(member,'/sports/c/teams');
    let request=home.myApplications.find(row=>row.teamId===teamId && row.status==='pending');
    if(!request){home=await api(member,'/sports/c/teams/'+teamId+'/applications','POST');request=home.myApplications.find(row=>row.teamId===teamId&&row.status==='pending');}
    assert.ok(request,'New team application can be recovered');
    return api(captain,'/sports/c/teams/applications/'+request.id+'/approve','POST');
  });
}
async function freshRoom(actor,unitId,name,slot,teamId) {
  return once(slot,async()=>{
    const existing=(await api(actor,'/sports/rooms')).rooms.find(row=>row.name===name && row.unit_id===unitId);
    if(existing)return {result:{roomId:existing.id},recoveredByUniqueName:true};
    return action(actor,'room.create',{unitId,name,...(teamId?{teamId}:{})},slot+'.create');
  });
}
async function recruitJoin(host,member,roomId,slot) {
  const before=await room(host,roomId);
  if(before.members.some(row=>sameId(row.account_id,member.id)))return;
  await action(host,'room.recruit',{roomId,message:'模拟本轮招募；本人申请，本场两人。',expectedVersion:before.room.version},slot+'.recruit');
  const offer=await action(member,'room.apply',{roomId},slot+'.apply');
  await action(host,'room.answer',{offerId:offer.result.offerId,answer:'accept'},slot+'.hostaccept');
}
async function prepare() {
  const types=await api(A,'/sports/types');
  const pair=types.types.find(row=>row.entry_type==='pair'&&row.capability_status==='manual');
  const single=types.types.find(row=>row.entry_type==='individual'&&row.capability_status==='manual');
  assert.ok(pair&&single,'Actual open badminton singles/doubles types exist');
  reference('sportId',pair.sport_id);
  const fields=[];
  for(const [type,label,options] of [['text','训练习惯',[]],['number','每周运动次数',[]],['date','本次准备日期',[]],['enum','惯用手',['右手','左手']]]) {
    const code='p_'+context.runId.slice(0,8)+'_'+type;
    const row=await once('field.'+type,async()=>{
      const found=(await api(organizer,'/sports/b/fields')).find(row=>row.code===code);
      return found || api(organizer,'/sports/b/fields','POST',{code,label:prefix+' '+label,valueType:type,options});
    }); fields.push(row);
  }
  reference('fields',fields.map(row=>({id:row.id,valueType:row.valueType,label:row.label})));
  const image=await once('declaration-image.upload',async()=>{
    const fixture='plus-ui/public/images/sports/badminton-hero-v1.webp';
    const form=new FormData();form.append('file',new Blob([fs.readFileSync(fixture)],{type:'image/webp'}),'synthetic-badminton-declaration.webp');
    const response=await fetch(context.backend+'/sports/b/media?purpose=event-declaration',{method:'POST',headers:{Authorization:'Bearer '+organizer.token,clientid:context.clientId},body:form});
    const body=await response.json(); assert.equal(body.code,200,'Owned simulated declaration image upload'); return body.data;
  });
  reference('declarationImageId',image.fileId);
  for(const round of [1,2]) {
    const name=prefix+round+'（模拟比赛与声明）';
    const event=await once('event.'+round,async()=>{
      const found=(await api(organizer,'/sports/b/events')).find(row=>row.name===name);
      return found || api(organizer,'/sports/b/events','POST',{name,location:'隔离模拟球馆',projectName:'羽毛球',feeDescription:'免费流程验证，无真实收费',registrationOpensAt:iso(-1),registrationClosesAt:iso(48),startsAt:iso(72),endsAt:iso(78),registrationReview:'manual',rulesText:'本轮模拟：羽毛球单打一人、双打两人，房主计入席位。',noticeText:'本机测试；图片为合成运动素材，不是真实责任声明或现场。',declarationText:round===1?'本人确认这是隔离流程演练，所填身份与赛事均为模拟，不进行真实比赛或转账。':'',declarationFileId:image.fileId,declarationAckRequired:true});
    });
    reference('event'+round,event.id);
    await once('event.'+round+'.fields',()=>api(organizer,'/sports/b/fields/events/'+event.id,'PUT',fields.map(field=>({orgFieldId:field.id,required:true,note:'模拟本人填写，不写入共享身份档案'}))));
    const specs={soloLast:['individual',1],soloGeneral:['individual',6],recruit:['pair',6],matching:['pair',6],timeout:['pair',6],team:['pair',6],conflict:['pair',6],race:['pair',6]};
    const units={};
    for(const [role,[type,capacity]] of Object.entries(specs)) {
      const unitName=prefix+round+'-'+role;
      const result=await once('unit.'+round+'.'+role,async()=>{
        const rows=await api(organizer,'/sports/b/registrations/units?eventId='+event.id);
        const found=rows.find(row=>row.name===unitName); if(found)return {result:{unitId:found.id}};
        return action(organizer,'unit.create',{eventId:event.id,competitionTypeId:(type==='pair'?pair:single).id,name:unitName,limitCount:String(capacity),charged:false},'unit.'+round+'.'+role+'.create');
      }); units[role]=result.result.unitId;
    }
    reference('units'+round,units);
    await once('event.'+round+'.publish',()=>api(organizer,'/sports/b/events/'+event.id+'/publish','POST',{requestKey:key('publish.'+round),contactConfirmed:true,contactName:'模拟赛事联系人',contactMethod:'仅本机演练，不实际联系'}));
    const publicUnits=await api(A,'/sports/c/registrations/units?eventId='+event.id);
    check('S'+round+'.01','New round is public with eight correctly constrained free units',publicUnits.length===8&&publicUnits.every(row=>row.usedCount===0&&row.limitCount>0));
    check('S'+round+'.02','All four fields selected before first submission',(await api(organizer,'/sports/b/fields/events/'+event.id)).length===4);
  }
}
async function teams() {
  for(const round of [1,2]) {
    const base='T'+round+'.';
    const detail=await createTeam(A,prefix+round+'-长期小队','team.'+round);
    const teamId=reference('team'+round,detail.id);
    check(base+'01','Creator is exactly one active captain/member',active(detail).length===1&&active(detail)[0].role==='captain'&&sameId(active(detail)[0].accountId,A.id));
    await applyJoin(A,B,teamId,'team.'+round+'.Bjoin');await applyJoin(A,E,teamId,'team.'+round+'.Ejoin');
    let current=await api(A,'/sports/c/teams/'+teamId);
    check(base+'02','Long-lived pool contains three people; doubles need not include all three',active(current).length===3&&active(current).filter(row=>row.role==='captain').length===1);
    await rejectHttp(C,'/sports/c/teams/'+teamId,'GET',undefined,base+'03','Unrelated person cannot read private roster');
    await rejectHttp(B,'/sports/c/teams/'+teamId+'/name','POST',{name:'不能由普通队员改名'},base+'04','Member cannot rename captain-owned team');
    await once('team.'+round+'.Capply',()=>api(C,'/sports/c/teams/'+teamId+'/applications','POST'));
    current=await api(A,'/sports/c/teams/'+teamId);const pending=current.applications.find(row=>row.status==='pending');assert.ok(pending);
    await once('team.'+round+'.Creject',()=>api(A,'/sports/c/teams/applications/'+pending.id+'/reject','POST',{reason:'模拟拒绝，保留历史；改用另一个邀请流程'}));
    check(base+'05','Rejected application does not silently add a member',active(await api(A,'/sports/c/teams/'+teamId)).length===3);
    const invite=await once('team.'+round+'.Dinvite',()=>api(A,'/sports/c/teams/'+teamId+'/invitations','POST',{phone:D.phone,requestSms:false}));
    const invitation=invite.invitations.find(row=>row.status==='pending');assert.ok(invitation);
    await rejectHttp(F,'/sports/c/teams/invitations/'+invitation.id+'/accept','POST',undefined,base+'06','Someone other than the invited person cannot accept');
    await once('team.'+round+'.Daccept',()=>api(D,'/sports/c/teams/invitations/'+invitation.id+'/accept','POST'));
    check(base+'07','Invited person enters only after personal acceptance',active(await api(A,'/sports/c/teams/'+teamId)).length===4);
    await rejectHttp(D,'/sports/c/teams/invitations/'+invitation.id+'/accept','POST',undefined,base+'08','Repeated legacy acceptance is rejected without another membership');
    await once('team.'+round+'.Dleave',()=>api(D,'/sports/c/teams/'+teamId+'/leave','POST'));
    check(base+'09','Leaving ends one segment and preserves the three-person pool',active(await api(A,'/sports/c/teams/'+teamId)).length===3);
    await rejectHttp(D,'/sports/c/teams/'+teamId,'GET',undefined,base+'10','Former member cannot read current private roster');
    const ownHistory=(await api(D,'/sports/c/teams')).memberships.find(row=>row.teamId===teamId&&row.membershipStatus!=='active');
    check(base+'11','Former member still sees own ended membership only',Boolean(ownHistory));
    const other=await createTeam(A,prefix+round+'-可解散小队','team.extra.'+round);
    await applyJoin(A,F,other.id,'team.extra.'+round+'.Fjoin');
    const target=active(await api(A,'/sports/c/teams/'+other.id)).find(row=>sameId(row.accountId,F.id));
    await rejectHttp(A,'/sports/c/teams/'+other.id+'/leave','POST',undefined,base+'12','Captain cannot directly leave');
    await once('team.extra.'+round+'.transfer',()=>api(A,'/sports/c/teams/'+other.id+'/captain','POST',{memberId:target.id}));
    const transferred=await api(F,'/sports/c/teams/'+other.id);
    check(base+'13','Explicit transfer yields exactly one new captain and retains both members',active(transferred).length===2&&active(transferred).filter(row=>row.role==='captain').length===1&&transferred.captain);
    await once('team.extra.'+round+'.disband',()=>api(F,'/sports/c/teams/'+other.id+'/disband','POST'));
    const history=(await api(F,'/sports/c/teams')).memberships.find(row=>row.teamId===other.id);
    check(base+'14','Disband terminates memberships and preserves history',history?.teamStatus==='disbanded'&&history.membershipStatus!=='active');
    await rejectHttp(F,'/sports/c/teams/'+other.id+'/name','POST',{name:'不能复活'},base+'15','Disbanded team cannot be silently revived by renaming');
  }
  const memberships=(await api(A,'/sports/c/teams')).memberships.filter(row=>row.membershipStatus==='active'&&[progress.objects.team1,progress.objects.team2].includes(row.teamId));
  check('T03.01','One ordinary person can captain multiple independent long-term teams',memberships.length===2&&memberships.every(row=>row.role==='captain'));
}

async function rooms() {
  for(const round of [1,2]) {
    const u=progress.objects['units'+round];assert.ok(u,'Prepare this round first');
    const base='R'+round+'.';
    const created=await freshRoom(C,u.recruit,prefix+round+'-招募房间','room.recruit.'+round);
    const roomId=reference('recruitRoom'+round,created.result.roomId);
    let current=await room(C,roomId);
    check(base+'01','Room host counts as first seat and no formal registration is created',current.members.length===1&&sameId(current.members[0].account_id,C.id)&&current.room.registration_id===null);
    await rejectHttp(F,'/sports/rooms/'+roomId,'GET',undefined,base+'02','Unrelated participant cannot read private room members');
    await action(C,'room.recruit',{roomId,message:'本轮模拟招募搭档',expectedVersion:current.room.version},'room.recruit.'+round+'.open');
    const declined=await action(D,'room.apply',{roomId},'room.recruit.'+round+'.firstapply');
    const awaiting=await room(C,roomId);
    check(base+'03','Applying reserves only an invitation and does not join silently',awaiting.members.length===1);
    await rejectHttp(E,'/sports/platform/actions/room.apply/execute','POST',{input:{roomId},requestKey:key('room.fullnegative.'+round)},base+'04','Pending confirmation reserves the last seat against another applicant');
    await action(C,'room.answer',{offerId:declined.result.offerId,answer:'decline'},'room.recruit.'+round+'.decline');
    check(base+'05','Declined invitation leaves only the host',(await room(C,roomId)).members.length===1);
    const accepted=await action(D,'room.apply',{roomId},'room.recruit.'+round+'.secondapply');
    const receipt=await action(C,'room.answer',{offerId:accepted.result.offerId,answer:'accept'},'room.recruit.'+round+'.accept');
    const replay=await api(C,'/sports/platform/actions/room.answer/execute','POST',{input:{offerId:accepted.result.offerId,answer:'accept'},requestKey:key('room.recruit.'+round+'.accept')});
    check(base+'06','Repeated accepted action reuses receipt and leaves two unique seats',replay.replayed===true&&replay.receiptId===receipt.receiptId&&(await room(C,roomId)).members.length===2);
    current=await room(C,roomId);
    await action(C,'room.ready',{roomId,ready:true,expectedVersion:current.room.version},'room.recruit.'+round+'.Cready');
    current=await room(C,roomId);
    check(base+'07','Preparation affects only the actual caller',current.members.find(row=>sameId(row.account_id,C.id)).ready===true&&current.members.find(row=>sameId(row.account_id,D.id)).ready===false);
    await rejectHttp(C,'/sports/platform/actions/room.prepare/execute','POST',{input:{roomId,expectedVersion:current.room.version},requestKey:key('room.unready.'+round)},base+'08','One unprepared partner prevents draft preparation');
    await action(D,'room.ready',{roomId,ready:true,expectedVersion:current.room.version},'room.recruit.'+round+'.Dready');
    current=await room(C,roomId);
    check(base+'09','Both personal preparations yield a ready two-person room',current.members.every(row=>row.ready)&&current.room.status==='ready');
    await rejectHttp(D,'/sports/platform/actions/room.prepare/execute','POST',{input:{roomId,expectedVersion:current.room.version},requestKey:key('room.nonhost.'+round)},base+'10','Prepared member cannot create host-owned entry');
    const prepared=await action(C,'room.prepare',{roomId,expectedVersion:current.room.version},'room.recruit.'+round+'.prepare');
    reference('recruitEntry'+round,prepared.result.registrationId);
    check(base+'11','Only a ready room creates one two-person draft',(await entry(C,prepared.result.registrationId)).members.length===2&&(await entry(C,prepared.result.registrationId)).status==='draft');

    const first=await action(E,'room.match',{unitId:u.matching,timePreference:'evening'},'match.'+round+'.Equeue');
    const second=await action(F,'room.match',{unitId:u.matching,timePreference:'evening'},'match.'+round+'.Fqueue');
    const offerId=reference('matchOffer'+round,second.result.offerId);
    check(base+'12','Compatible match creates invitation before any member enters',(await api(E,'/sports/rooms')).offers.some(row=>row.id===offerId)&&!(await api(E,'/sports/rooms')).rooms.some(row=>row.unit_id===u.matching));
    const alone=await action(E,'room.answer',{offerId,answer:'accept'},'match.'+round+'.Eaccept');
    check(base+'13','One personal acceptance waits without joining for the other',alone.result.status==='waiting_partner'&&(await api(F,'/sports/rooms')).offers.find(row=>row.id===offerId).my_status==='pending');
    const joined=await action(F,'room.answer',{offerId,answer:'accept'},'match.'+round+'.Faccept');
    reference('matchRoom'+round,joined.result.roomId);
    check(base+'14','Both actual members accept before the room reaches two seats',(await room(E,joined.result.roomId)).members.length===2);
    const transfer=await room(E,joined.result.roomId);const host=people.find(row=>sameId(row.id,transfer.room.host_account_id));const peer=host.id===E.id?F:E;
    await action(host,'room.leave',{roomId:joined.result.roomId,newHostAccountId:peer.id,expectedVersion:transfer.room.version},'match.'+round+'.hostleave');
    const remaining=await room(peer,joined.result.roomId);
    check(base+'15','Host departure transfers to actual active partner and removes only self',sameId(remaining.room.host_account_id,peer.id)&&remaining.members.length===1&&sameId(remaining.members[0].account_id,peer.id));
    await rejectHttp(host,'/sports/rooms/'+joined.result.roomId,'GET',undefined,base+'16','Departed host cannot continue to read private roster');
    await action(peer,'room.leave',{roomId:joined.result.roomId,expectedVersion:remaining.room.version},'match.'+round+'.peerleave');
    check(base+'17','Last member departure closes the unregistered room',!(await api(peer,'/sports/rooms')).rooms.some(row=>row.id===joined.result.roomId));

    const long=await freshRoom(A,u.team,prefix+round+'-长期队房间','room.team.'+round,progress.objects['team'+round]);
    reference('teamRoom'+round,long.result.roomId);
    current=await room(A,long.result.roomId);
    await action(A,'room.recruit',{roomId:long.result.roomId,message:'本队成员专属，本场只选两人',expectedVersion:current.room.version},'room.team.'+round+'.recruit');
    await rejectHttp(C,'/sports/platform/actions/room.apply/execute','POST',{input:{roomId:long.result.roomId},requestKey:key('room.team.outsider.'+round)},base+'18','Outsider cannot fill a long-team-only room');
    await recruitJoin(A,B,long.result.roomId,'room.team.'+round+'.Bjoin');
    current=await room(A,long.result.roomId);
    check(base+'19','Long-team room keeps its team identity and only two of three permanent members',current.room.team_id===progress.objects['team'+round]&&current.members.length===2&&active(await api(A,'/sports/c/teams/'+progress.objects['team'+round])).length===3);
    await rejectHttp(A,'/sports/platform/actions/room.leave/execute','POST',{input:{roomId:long.result.roomId,newHostAccountId:B.id,expectedVersion:current.room.version},requestKey:key('room.team.hostbeforecaptain.'+round)},base+'20','Long-team host cannot leave to someone who has not yet inherited captaincy');
  }
}

async function timeout() {
  const u=progress.objects.units2;assert.ok(u);
  const queued=await action(E,'room.match',{unitId:u.timeout,timePreference:'morning'},'timeout2.Equeue');
  const other=await action(F,'room.match',{unitId:u.timeout,timePreference:'evening'},'timeout2.Fincompatible');
  check('RXC01','Different fixed time preferences stay in separate queues',other.result.status==='waiting'&&!other.result.offerId);
  await action(F,'room.stopMatch',{requestId:other.result.requestId},'timeout2.Fstop');
  const matching=await action(F,'room.match',{unitId:u.timeout,timePreference:'morning'},'timeout2.Fcompatible');
  const offerId=matching.result.offerId;
  const home=await api(E,'/sports/rooms');const offer=home.offers.find(row=>row.id===offerId);
  const prepared=await once('timeout2.confirmedBeforeExpiry',()=>h.prepareAction(E,'room.answer',{offerId,answer:'accept'},'timeout2.acceptlate'));
  check('RXC02','Acceptance confirmation is bound to this actual offer before its natural expiry',Boolean(prepared.confirmationId));
  if(offer){
    progress.objects.timeoutExpiresAt=offer.expires_at;h.save();
    const expires=new Date(offer.expires_at).getTime();
    check('RXC03','Actual invitation has at most a 120-second confirmation window',expires-Date.now()>0&&expires-Date.now()<=121000);
    while(Date.now()<expires+1100) {
      const remaining=Math.ceil((expires-Date.now())/1000); console.log(JSON.stringify({stage:'real-invitation-timeout',remainingSeconds:Math.max(0,remaining)}));
      await new Promise(resolve=>setTimeout(resolve,Math.min(20000,Math.max(200,expires+1100-Date.now()))));
    }
  }
  const late=await rejectHttp(E,'/sports/platform/actions/room.answer/execute','POST',prepared,'RXC04','Natural expiration rejects previously confirmed acceptance without direct clock/database changes');
  check('RXC05','Late acceptance rejects expired offer or its changed confirmation snapshot, rather than an unconfirmed request',/过期|失效|超时|待办内容已变化/.test(late.msg||''));
  const after=await api(E,'/sports/rooms');
  check('RXC06','Expired offer disappears and does not produce a joined room',!after.offers.some(row=>row.id===offerId)&&!after.rooms.some(row=>row.unit_id===u.timeout));
  for(const actor of [E,F])for(const req of (await api(actor,'/sports/rooms')).requests.filter(row=>row.unit_id===u.timeout))await action(actor,'room.stopMatch',{requestId:req.id},'timeout2.finalstop.'+actor.label);
}

async function fill(actor,id,slot) {
  const rows=await api(actor,'/sports/c/registrations/'+id+'/fields');
  const values={text:'仅本人填写的模拟训练说明 '+actor.label,number:'3',date:'2026-10-11',enum:'右手'};
  await once(slot,()=>api(actor,'/sports/c/registrations/'+id+'/fields','PUT',rows.map(row=>({eventFieldId:row.eventFieldId,valueText:values[row.valueType]}))));
  return rows;
}
async function confirmMember(actor,manager,id,slot) {
  const before=await entry(manager,id);const member=before.members.find(row=>sameId(row.accountId,actor.id));assert.ok(member);
  await once(slot+'.ack',()=>api(actor,'/sports/c/registrations/'+id+'/declaration-ack','POST'));
  if(member.status==='pending_confirmation')await once(slot+'.confirm',()=>api(actor,'/sports/c/registrations/invites/'+member.inviteToken+'/confirm','POST'));
}
async function registration() {
  for(const round of [1,2]) {
    const u=progress.objects['units'+round],id=progress.objects['recruitEntry'+round];assert.ok(id);
    const base='B'+round+'.';
    let before=await entry(C,id);
    if(!observed(base+'01'))check(base+'01','Prepared member remains pending until their own confirmation',before.members.find(row=>sameId(row.accountId,D.id)).status==='pending_confirmation');
    if(!observed(base+'02'))await rejectHttp(C,'/sports/c/registrations/'+id+'/submit','POST',{requestKey:before.requestKey},base+'02','Missing member confirmation and fields reject formal submission');
    const fields=await fill(C,id,'entry.'+round+'.Cfields');
    check(base+'03','Each participant reads exactly four required current event fields',fields.length===4&&fields.every(row=>row.required));
    await confirmMember(C,C,id,'entry.'+round+'.C');
    const pending=(await entry(C,id)).members.find(row=>sameId(row.accountId,D.id));
    await rejectHttp(F,'/sports/c/registrations/invites/'+pending.inviteToken+'/confirm','POST',undefined,base+'04','Unrelated account cannot accept a member invitation');
    const ownBefore=await api(D,'/sports/c/registrations/'+id+'/fields');
    if(!observed(base+'05'))check(base+'05','Captain saving personal answers cannot fill their partner’s fields',ownBefore.every(row=>!row.valueText));
    if(!observed(base+'06'))await rejectHttp(D,'/sports/c/registrations/'+id+'/fields','PUT',ownBefore.map(row=>({eventFieldId:row.eventFieldId,valueText:row.valueType==='number'?'not-a-number':row.valueType==='date'?'2026-99-99':row.valueType==='enum'?'未知选项':'模拟'})),base+'06','Invalid typed answers reject the whole personal save');
    await fill(D,id,'entry.'+round+'.Dfields');await confirmMember(D,C,id,'entry.'+round+'.D');
    before=await entry(C,id);
    check(base+'07','Both actual members are confirmed with current declaration acknowledgement',before.members.every(row=>row.status==='confirmed')&&before.declarationAcknowledged);
    const version=await h.registrationVersion(C,id);
    const prepared=await h.prepareAction(C,'registration.submit',{registrationId:id,expectedVersion:version},'entry.'+round+'.submit');
    const first=await once('entry.'+round+'.submit-result',()=>api(C,'/sports/platform/actions/registration.submit/execute','POST',prepared));
    const repeat=await api(C,'/sports/platform/actions/registration.submit/execute','POST',{input:prepared.input,requestKey:prepared.requestKey});
    const submitted=await entry(C,id),unit=(await api(C,'/sports/c/registrations/units?eventId='+progress.objects['event'+round])).find(row=>row.id===u.recruit);
    check(base+'08','Formal submission freezes exactly two members and consumes one entry quota',submitted.status==='submitted'&&submitted.rosterRevision===1&&submitted.members.length===2&&unit.usedCount===1);
    check(base+'09','Same action key replays the successful receipt without another roster/quota',repeat.replayed===true&&repeat.receiptId===first.receiptId&&(await entry(C,id)).rosterRevision===1);
    await rejectHttp(D,'/sports/c/registrations/'+id+'/withdraw','POST',undefined,base+'10','Ordinary member cannot withdraw the manager-owned entry');
    check(base+'11','Submitted personal field answers cannot be edited by the member',(await call(D,'/sports/c/registrations/'+id+'/fields','PUT',ownBefore.map(row=>({eventFieldId:row.eventFieldId,valueText:'不能篡改冻结依据'})))).code!==200);
    await rejectHttp(C,'/sports/platform/actions/room.leave/execute','POST',{input:{roomId:progress.objects['recruitRoom'+round],newHostAccountId:D.id,expectedVersion:(await room(C,progress.objects['recruitRoom'+round])).room.version},requestKey:key('submitted-room.leave.'+round)},base+'12','Room roster cannot change after an entry is generated; responsibility moves through entry handover');

    const singles=[];
    for(const actor of [E,F]) {
      const draft=await once('last.'+round+'.'+actor.label+'.draft',()=>api(actor,'/sports/c/registrations','POST',{unitId:u.soloLast,requestKey:key('last.'+round+'.'+actor.label+'.create')}));
      await fill(actor,draft.id,'last.'+round+'.'+actor.label+'.fields');await confirmMember(actor,actor,draft.id,'last.'+round+'.'+actor.label);
      singles.push({actor,id:draft.id,key:context.runId+'.last.'+round+'.'+actor.label});
    }
    const preparedSingles=await Promise.all(singles.map(async row=>({row,body:await h.prepareAction(row.actor,'registration.submit',{registrationId:row.id,expectedVersion:await h.registrationVersion(row.actor,row.id)},'last.'+round+'.'+row.actor.label+'.submit')})));
    const outcomes=await once('last.'+round+'.concurrent',()=>Promise.all(preparedSingles.map(({row,body})=>call(row.actor,'/sports/platform/actions/registration.submit/execute','POST',body))));
    const actual=await Promise.all(singles.map(row=>entry(row.actor,row.id)));
    const lastUnit=(await api(E,'/sports/c/registrations/units?eventId='+progress.objects['event'+round])).find(row=>row.id===u.soloLast);
    check(base+'13','Two ordinary complete drafts concurrently compete for the last single quota',outcomes.filter(row=>row.code===200).length===1&&actual.filter(row=>row.status==='submitted').length===1&&lastUnit.usedCount===1);
    reference('lastSingles'+round,singles.map((row,index)=>({id:row.id,actor:row.actor.label,status:actual[index].status})));
  }
}

try {
  await h.preflight();
  if(stage==='prepare')await prepare();else if(stage==='teams')await teams();else if(stage==='rooms')await rooms();else if(stage==='timeout')await timeout();else if(stage==='registration')await registration();else throw new Error('Unknown participant stage');
  h.report.passed=true;
} catch(error) { h.report.failures.push({id:stage,reason:error.message}); process.exitCode=1; }
finally { h.final({stage,sourceFiles:[{path:'scripts/Test-BadmintonParticipantFlow.mjs',sha256:(await import('./lib/badminton-participant-test.mjs')).hashFile('scripts/Test-BadmintonParticipantFlow.mjs')}]}); }
