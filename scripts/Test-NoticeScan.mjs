import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';
import {context,api,readSql,createEvidence} from './lib/BusinessRegression.mjs';
const proof=createEvidence('notice-six-scans'),source='.local/notice-trial-20261012/six-scanned-annexes.pdf';
try{
 const bytes=fs.readFileSync(source),form=new FormData();proof.evidence.source={sha256:crypto.createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length,pages:6,textLayer:false,coverage:'Five synthetic notice pages plus one explicitly limited official notice-body derivative; separate events, no consolidated official original'};
 form.append('files',new Blob([bytes]),'测试多赛事六页扫描附件.pdf');form.append('consent','true');form.append('goal','这六页是不同赛事的测试通知，不是同一场。请分别整理星河单打与混双每单价、清风是否免费、拾光缺项、山岚两版冲突、盐田历史日期。不要合并成一场，也不创建、不委派、不发布。只读这些页并注明识别范围。');form.append('context','{}');
 const response=await fetch(context.backend+'/sports/agents/runs/materials',{method:'POST',headers:{clientid:context.clientId,Authorization:'Bearer '+context.organizer.token},body:form,signal:AbortSignal.timeout(120000)}),body=await response.json();assert.equal(body.code,200);const id=String(body.data.runId);assert.match(id,/^\d+$/);proof.evidence.objects.runId=id;proof.save();
 let run;const start=Date.now();while(Date.now()-start<310000){run=await api(context.organizer,'/sports/agents/runs/'+id);if(!['running','waiting_children'].includes(run.status)&&readSql(`SELECT tokens_reserved FROM asp_agent_run WHERE id=${id};`)==='0')break;await new Promise(r=>setTimeout(r,1700));}
 proof.evidence.current={id:run.id,status:run.status,stopReason:run.stopReason,seconds:Math.round((Date.now()-start)/100)/10,messages:run.messages.map(m=>({role:m.role,content:m.content,blocks:m.blocks}))};proof.save();
 const text=run.messages.filter(m=>m.role==='assistant').at(-1)?.content||'';
 proof.check('six image-only pages reach a real model answer',run.status==='waiting_input',{status:run.status,stopReason:run.stopReason});
 proof.check('scan answer distinguishes charged free incomplete conflicting and historical notices',['星河','清风','拾光','山岚','盐田','30','60','27','28','50','70'].every(word=>text.includes(word)));
 proof.check('actual retained coverage describes all six scan pages',run.messages.some(m=>String(m.blocks).includes('扫描页[1, 2, 3, 4, 5, 6]')||String(m.blocks).includes('扫描页[1,2,3,4,5,6]')));
 proof.check('multi-event scan does not create any business write',readSql(`SELECT count(*) FROM asp_action_execution WHERE run_id=${id};`)==='0');proof.finish();
}catch(e){proof.evidence.failure=String(e.message).slice(0,350);proof.save();process.exitCode=1;console.log('Six-scan verification failed; source and actual run retained');}
