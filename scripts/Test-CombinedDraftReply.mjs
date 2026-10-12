// Fresh fictional candidate only. Actual model merges several user answers at once.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';
import {context,api,beijingTime} from './lib/BusinessRegression.mjs';
const state=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8').replace(/^\uFEFF/,''));
const out=path.resolve('.local/agent-draft-continuity-20261012','combined-'+crypto.randomUUID());fs.mkdirSync(out,{recursive:true});
const report={at:new Date().toISOString(),scope:'New ordinary-organizer synthetic candidate and actual model replies only. No event creation, publication, payment or old task edits.',checks:[],objects:{},passed:false};
const save=()=>fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(report,null,2));
function check(name,value){report.checks.push({name,passed:!!value});save();assert.ok(value,name);console.log('PASS '+name);}
const v=node=>String(node?.value??'');
try{
 const user={token:(await api(null,'/auth/login','POST',{username:state.people[0].phone,password:state.password,grantType:'platform',tenantId:'900001',clientId:context.clientId})).access_token};context.organizer={token:(await api(user,'/auth/organization/enter','POST',{})).access_token};
 let task,name;
 if(process.env.AISPORTS_COMBINED_RESUME){const file=fs.realpathSync(process.env.AISPORTS_COMBINED_RESUME),root=fs.realpathSync('.local/agent-draft-continuity-20261012')+path.sep;assert.ok(file.startsWith(root));const prior=JSON.parse(fs.readFileSync(file,'utf8'));assert.equal(prior.passed,false);assert.equal(prior.checks[0]?.name,'Combined reply updates both eligibility and price');task=await api(context.organizer,`/sports/b/ai/tasks/${prior.objects.taskId}`);assert.equal(task.status,'PENDING_CONFIRMATION');assert.ok(!task.resultObjectId);name=v(JSON.parse(task.proposal).event.name);assert.ok(name.startsWith('模拟合并回答-'));report.resumedFrom={path:path.relative(process.cwd(),file),sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')};report.objects.taskId=task.id;save();}
 else {
 name='模拟合并回答-'+crypto.randomUUID().slice(0,8);const dates=[1,25,48,51].map(h=>beijingTime(new Date(Date.now()+h*3600000)));
 const started=await api(context.organizer,'/sports/b/ai/tasks/text','POST',{consent:true,text:`隔离测试通知，仅用于模拟验证。名称${name}；羽毛球，模拟练习馆。报名${dates[0]}至${dates[1]}；比赛${dates[2]}至${dates[3]}。仅一个公开双打项目，每单2人，名额16单，人工审核。年龄和收费未确定。规程：自备球拍。退赛在开赛前申请。联系人模拟负责人，联系方式仅作测试。`});report.objects.taskId=started.id;save();
 const end=Date.now()+180000;while(Date.now()<end){task=await api(context.organizer,`/sports/b/ai/tasks/${started.id}`);if(!['UPLOADED','PROCESSING'].includes(task.status))break;await new Promise(r=>setTimeout(r,700));}assert.equal(task.status,'PENDING_CONFIRMATION');
 }
 const answer=await api(context.organizer,`/sports/b/ai/tasks/${task.id}/talk`,'POST',{message:'参赛年龄18-35岁，每人50元。',expectedVersion:task.version,declarationAckRequired:false});task=await api(context.organizer,`/sports/b/ai/tasks/${task.id}`);let draft=JSON.parse(task.proposal);fs.writeFileSync(path.join(out,'combined-reply.private.json'),JSON.stringify({answer,task}));
 check('Combined reply updates both eligibility and price',/18[^\n]*35/.test(v(draft.event.rulesText))&&draft.units.length===1&&Number(v(draft.units[0].feeAmount))===100&&v(draft.units[0].feeBasis)==='order');
 check('Other original fields remain present',v(draft.event.name)===name&&v(draft.event.rulesText).includes('自备球拍')&&v(draft.units[0].limitCount)==='16');
 const following=await api(context.organizer,`/sports/b/ai/tasks/${task.id}/talk`,'POST',{message:'继续下一步',expectedVersion:task.version,declarationAckRequired:false});task=await api(context.organizer,`/sports/b/ai/tasks/${task.id}`);draft=JSON.parse(task.proposal);fs.writeFileSync(path.join(out,'next-reply.private.json'),JSON.stringify({following,task}));
 const reply=String(following.reply||following.message||'');
 check('Next model turn retains confirmed answers instead of reasking them',/18[^\n]*35/.test(v(draft.event.rulesText))&&Number(v(draft.units[0].feeAmount))===100&&!/(?:年龄[^。！？\n]*(?:多少|未确定|未说明)|(?:费用|收费|每人|每单|按人|按单)[^。！\n]*(?:多少|未确定|未说明|还是|吗|？))/.test(reply));
 check('No business object is created without confirmation',task.status==='PENDING_CONFIRMATION'&&!task.resultObjectId);report.passed=true;
}catch(error){report.failure=String(error.message).replaceAll(state.password,'[REDACTED]').slice(0,300);process.exitCode=1;console.log('FAIL '+report.failure);}finally{report.finishedAt=new Date().toISOString();save();console.log('Evidence: '+out);}
