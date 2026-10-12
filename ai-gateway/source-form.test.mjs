import test from 'node:test';
import assert from 'node:assert/strict';
import {canonicalFieldReferences,readVisualBatch,hydrateSourceQuotes} from './material-reader.mjs';
import {checkedSourceFields,runTask} from './kernel.mjs';
test('source IDs assemble a long declaration in actual source order without labels or model retyping',()=>{
  const clauses=Array.from({length:12},(_,i)=>`${i+1}、参赛声明原句${i+1}。`),evidence=clauses.map((text,i)=>({sourceId:'s'+i,text}));
  const fields=canonicalFieldReferences({declarationText:{status:'filled',sourceRefs:evidence.map(s=>s.sourceId).reverse()}},evidence);
  const checked=checkedSourceFields(fields,clauses.map((s,i)=>'段落'+i+':'+s).join('\n'),clauses.join('\n'));
  assert.equal(checked.declarationText.value,clauses.join('\n'));assert.equal(checked.declarationText.sources.length,12);
});
test('a guessed, repeated or unreadable source reference cannot populate a form',()=>{
  const evidence=[{sourceId:'s1',text:'原句'},{sourceId:'s2',text:'无法辨认',status:'unreadable'}];
  for(const sourceRefs of [['s9'],['s1','s1'],['s2']])assert.throws(()=>canonicalFieldReferences({declarationText:{status:'filled',sourceRefs}},evidence),e=>e.code==='SOURCE_FIELDS_INCOMPLETE');
});
test('sport description is a quoted form field and cannot be fabricated from unrelated classifications',()=>{
 const source='2026年秋季羽毛球邀请赛，A组18-34岁男单。';
 const direct=checkedSourceFields({projectName:{value:'羽毛球',status:'filled',quotes:['2026年秋季羽毛球邀请赛']}},source);
 assert.equal(direct.projectName.value,'羽毛球');assert.equal(direct.projectName.sources[0].quote,'2026年秋季羽毛球邀请赛');
 const refs=canonicalFieldReferences({projectName:{value:'羽毛球',status:'filled',sourceRefs:['sport']}},[{sourceId:'sport',text:source}]);
 assert.equal(checkedSourceFields(refs,source).projectName.value,'羽毛球');
 assert.throws(()=>checkedSourceFields({projectName:{value:'足球',status:'filled',quotes:['A组18-34岁男单']}},source),error=>error.code==='SOURCE_FIELDS_INCOMPLETE'&&error.field==='projectName');
});
test('independent sport extraction fills the persisted candidate in both material protocols',async()=>{
 const source='赛事名称：秋季羽毛球赛。运动项目：羽毛球。项目：公开单打，限16单。';
 for(const progressEnabled of [false,true]){
  let fieldPrompt='';
  const result=await runTask({env:{DEEPSEEK_API_KEY:'fixture',AI_COMPAT_BASE_URL:'https://example.test',AI_TEXT_MODEL:'fixture'},body:{progressEnabled,extraction:{files:[{blocks:[{text:source}]}]}},fetchImpl:async(_url,request)=>{
   const prompt=JSON.parse(request.body).messages[0].content;
   let response;
   if(prompt.includes('原文项目目录提取'))response={projects:[{name:'公开单打',entryType:'individual',limitCount:16,sourceRefs:['s1']}]};
   else if(prompt.includes('原文履约字段提取')||prompt.includes('sourceId材料清单')){fieldPrompt=prompt;response={fields:{projectName:{value:'羽毛球',status:'filled',...(progressEnabled?{sourceRefs:['s1']}:{quotes:['运动项目：羽毛球']})}}};}
   else response={reply:'赛事已整理',action:'ask',event:{name:{value:'秋季羽毛球赛',status:'filled'}}};
   return {ok:true,json:async()=>({choices:[{message:{content:JSON.stringify(response)}}]})};
  }});
  assert.match(fieldPrompt,/projectName/);assert.equal(result.ok,true);assert.equal(result.proposal.event.projectName.value,'羽毛球');assert.equal(result.proposal.event.projectName.sources[0].kind,'document');
 }
});
test('explicit sport description labels survive a model omitting the independently requested field',async()=>{
 const description='羽毛球分龄单打、双打和团体比赛',source=`赛事名称：合成赛。运动项目说明：${description}。项目：公开单打。`;
 for(const progressEnabled of [false,true]){
  const result=await runTask({env:{DEEPSEEK_API_KEY:'fixture',AI_COMPAT_BASE_URL:'https://example.test',AI_TEXT_MODEL:'fixture'},body:{progressEnabled,extraction:{files:[{blocks:[{text:source}]}]}},fetchImpl:async(_url,request)=>{
   const prompt=JSON.parse(request.body).messages[0].content;
   const response=prompt.includes('原文项目目录提取')?{projects:[{name:'公开单打',entryType:'individual',sourceRefs:['s1']}]}:prompt.includes('原文履约字段提取')||prompt.includes('sourceId材料清单')?{fields:{}}:{event:{name:'合成赛',projectName:'羽毛球'},reply:'已整理'};
   return {ok:true,json:async()=>({choices:[{message:{content:JSON.stringify(response)}}]})};
  }});
  assert.equal(result.ok,true);assert.equal(result.proposal.event.projectName.value,description);assert.equal(result.proposal.event.projectName.sources[0].quote,`运动项目说明：${description}`);
 }
});
test('a missing independent sport field overrides an unquoted summary and distinct labels remain conflicting',async()=>{
 for(const [source,expected] of [['赛事名称：合成赛。项目：公开单打。','missing'],['运动项目：羽毛球。补充运动项目：乒乓球。项目：公开单打。','conflict']]){
  const result=await runTask({env:{DEEPSEEK_API_KEY:'fixture',AI_COMPAT_BASE_URL:'https://example.test',AI_TEXT_MODEL:'fixture'},body:{progressEnabled:true,extraction:{files:[{blocks:[{text:source}]}]}},fetchImpl:async(_url,request)=>{
   const prompt=JSON.parse(request.body).messages[0].content;
   const response=prompt.includes('原文项目目录提取')?{projects:[{name:'公开单打',entryType:'individual',sourceRefs:['s1']}]}:prompt.includes('sourceId材料清单')?{fields:{}}:{event:{name:'合成赛',projectName:'摘要猜测羽毛球'},reply:'已整理'};
   return {ok:true,json:async()=>({choices:[{message:{content:JSON.stringify(response)}}]})};
  }});
  assert.equal(result.ok,true);assert.equal(result.proposal.event.projectName.value,'');assert.equal(result.proposal.event.projectName.status,expected);
  if(expected==='conflict')assert.deepEqual(result.proposal.event.projectName.alternatives,['羽毛球','乒乓球']);
 }
});
test('general quotations preserve actual clauses and refuse invented source IDs',()=>{
  const evidence=[{sourceId:'m0',text:'第一条原句'},{sourceId:'m1',text:'第二条原句'}];
  const output=hydrateSourceQuotes('已整理',[{kind:'source_quote',title:'原文',sourceRefs:['m1','m0']}],evidence);
  assert.equal(output.reply,'已整理\n\n原文\n\n第一条原句\n\n第二条原句');assert.deepEqual(output.blocks,[]);
  assert.throws(()=>hydrateSourceQuotes('',[{kind:'source_quote',sourceRefs:['m9']}],evidence));
  assert.equal(hydrateSourceQuotes('',[{kind:'source_quote',title:'原文',startRef:'m0',endRef:'m1'}],evidence).reply,'原文\n\n第一条原句\n\n第二条原句');
});
test('visible image roles are bounded and reasoning content never enters source assets',async()=>{
  const result=await readVisualBatch({env:{AI_VISION_MODEL:'vision',AI_COMPAT_BASE_URL:'https://example.test'},items:[{index:0,location:'图片',url:'data:image/png;base64,AA=='}],fetchImpl:async()=>new Response(JSON.stringify({choices:[{message:{content:JSON.stringify({items:[{index:0,status:'read',text:'可见表格',role:'execute-payment',caption:'可见描述'}]}),reasoning_content:'hidden'}}],usage:{total_tokens:22}}))});
  assert.equal(result.items[0].role,'other');assert.equal(result.items[0].caption,'可见描述');assert.equal(result.tokens,22);assert.ok(!JSON.stringify(result).includes('hidden'));
});
