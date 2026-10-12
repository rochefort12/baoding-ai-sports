// New fictional Word candidates only; no creation, publication, payments or old task edits.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';
import {context,api,beijingTime} from './lib/BusinessRegression.mjs';
const state=JSON.parse(fs.readFileSync('.local/phase1-implementation/verification-session.json','utf8').replace(/^\uFEFF/,''));
const out=path.resolve('.local/agent-draft-continuity-20261012','document-prices-'+crypto.randomUUID());fs.mkdirSync(out,{recursive:true});
const report={at:new Date().toISOString(),scope:'Actual model extraction of fresh fictional Word notices in the isolated database. Candidate prices only; no event publication or financial operation.',checks:[],objects:[],passed:false};
const save=()=>fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(report,null,2));
const v=node=>String(node?.value??'');
function check(name,value){report.checks.push({name,passed:!!value});save();assert.ok(value,name);console.log('PASS '+name);}
function fixture(file,text){
 const result=spawnSync('C:/Users/ADMIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',['-X','utf8','-c',`import sys,zipfile,html\ntext=sys.stdin.read()\nwith zipfile.ZipFile(sys.argv[1],'w') as z:\n z.writestr('[Content_Types].xml','<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>')\n z.writestr('_rels/.rels','<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>')\n z.writestr('word/document.xml','<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>'+''.join('<w:p><w:r><w:t>'+html.escape(line)+'</w:t></w:r></w:p>' for line in text.splitlines())+'</w:body></w:document>')`,file],{input:text,encoding:'utf8'});assert.equal(result.status,0,result.stderr);
}
try{
 const user={token:(await api(null,'/auth/login','POST',{username:state.people[0].phone,password:state.password,grantType:'platform',tenantId:'900001',clientId:context.clientId})).access_token};context.organizer={token:(await api(user,'/auth/organization/enter','POST',{})).access_token};
 const cases=[{key:'person',price:'公开双打报名每人收费50.50元，每单固定2人。',amount:101,basis:'order',review:'',expectedReview:'none'}, {key:'order',price:'公开双打报名每单100元，双打每单固定2人。',amount:100,basis:'order',review:'报名需要主办方人工审核。',expectedReview:'manual'}, {key:'conditional',price:'公开双打首项198元/人/项，加项100元/人/项，每单固定2人。',review:'报名无需人工审核。',expectedReview:'none'}];
 for(const item of cases){
  const name='模拟文档收费-'+item.key+'-'+crypto.randomUUID().slice(0,8),dates=[1,25,48,51].map(h=>beijingTime(new Date(Date.now()+h*3600000)));
  const notice=`隔离测试通知，仅供模拟验证。赛事名称：${name}\n羽毛球，模拟练习馆。报名${dates[0]}至${dates[1]}；比赛${dates[2]}至${dates[3]}。\n仅一个公开双打项目，名额16单。${item.review}\n${item.price}\n规程：自备球拍。联系人模拟负责人，联系方式仅用于测试。退赛在开赛前申请。`;
  const file=path.join(out,item.key+'.docx');fixture(file,notice);const body=new FormData();body.append('files',new Blob([fs.readFileSync(file)],{type:'application/vnd.openxmlformats-officedocument.wordprocessingml.document'}),path.basename(file));
  const res=await fetch(context.backend+'/sports/b/ai/tasks?bailianConsent=true',{method:'POST',headers:{clientid:context.clientId,Authorization:'Bearer '+context.organizer.token},body});const start=await res.json();assert.equal(start.code,200);report.objects.push({case:item.key,taskId:start.data.id});save();
  let task;const deadline=Date.now()+180000;while(Date.now()<deadline){task=await api(context.organizer,`/sports/b/ai/tasks/${start.data.id}`);if(!['UPLOADED','PROCESSING'].includes(task.status))break;await new Promise(r=>setTimeout(r,700));}
  fs.writeFileSync(path.join(out,item.key+'.private.json'),JSON.stringify(task));check(item.key+': actual Word becomes a single candidate project',task.status==='PENDING_CONFIRMATION'&&task.files.length===1&&JSON.parse(task.proposal).units.length===1);
  const draft=JSON.parse(task.proposal),unit=draft.units[0];
  check(item.key+': source review is honored and missing review defaults to none',v(draft.event.registrationReview)===item.expectedReview&&(!item.review?draft.event.registrationReview.sources.some(source=>source.kind==='default'):draft.event.registrationReview.sources.some(source=>source.kind==='document'&&source.quote?.includes('审核'))));
  if(item.basis){check(item.key+': price is prefilled without a chat answer',Number(v(unit.feeAmount))===item.amount&&v(unit.feeBasis)===item.basis);check(item.key+': original fee evidence is retained',unit.feeAmount.sources.some(source=>source.kind==='document'&&source.quote?.includes(item.key==='person'?'50.50':'100')));}
  else{check('Conditional price preserves both source amounts and conditions',v(draft.event.feeDescription).includes('198')&&v(draft.event.feeDescription).includes('100')&&v(draft.event.feeDescription).includes('加项'));check('Conditional price requires clarification instead of a flat order charge',v(unit.feeBasis)!=='order'&&draft.readiness?.canSaveDraft!==true);}
  check(item.key+': no event is created without user confirmation',!task.resultObjectId);
 }
 report.passed=true;
}catch(error){report.failure=String(error.message).replaceAll(state.password,'[REDACTED]').slice(0,300);console.log('FAIL '+report.failure);process.exitCode=1;}finally{report.finishedAt=new Date().toISOString();save();console.log('Evidence: '+out);}
