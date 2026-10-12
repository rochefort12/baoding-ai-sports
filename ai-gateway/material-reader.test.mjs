import test from 'node:test';
import assert from 'node:assert/strict';
import {readVisualBatch,orderedMaterialSources,canonicalProjectReferences} from './material-reader.mjs';
import {runAgent} from './agent.mjs';
const env={DEEPSEEK_API_KEY:'fixture',AI_COMPAT_BASE_URL:'https://fixture.invalid',AI_VISION_MODEL:'fixture-vision'};
const items=[0,1].map(index=>({index,location:`段落${index+1}`,url:'data:image/png;base64,YQ=='}));
const answer=value=>({ok:true,json:async()=>({usage:{total_tokens:30},choices:[{message:{content:JSON.stringify(value),reasoning_content:'DO_NOT_PERSIST'}}]})});
test('image-only paragraphs preserve their context and impossible anchors are refused',()=>{
  const sources=[{location:'段落47',text:'年龄分组'},{location:'段落49',text:'奖项'}];
  const visuals=[{location:'段落48',afterBlock:1,status:'read',text:'A组18至34岁：男子单打'}];
  assert.deepEqual(orderedMaterialSources(sources,visuals).map(s=>s.text),['年龄分组','A组18至34岁：男子单打','奖项']);
  assert.throws(()=>orderedMaterialSources(sources,[{...visuals[0],afterBlock:3}]),e=>e.code==='MATERIAL_INCOMPLETE');
});
test('source references produce exact original quotes and reject unknown or unreadable sources',()=>{
  const source=[{sourceId:'s1',text:'A组（18—34岁）：男子单打、女子单打。'},{sourceId:'s2',text:'每人200元，兼项另收100元。'},{sourceId:'s3',text:'未能识别',status:'unreadable'}];
  const result=canonicalProjectReferences([{name:'A组男子单打',sourceRefs:['s1'],feeRefs:['s2']}],source)[0];assert.deepEqual(result.quotes,[source[0].text]);assert.deepEqual(result.feeQuotes,[source[1].text]);
  for(const id of ['s404','s3'])assert.throws(()=>canonicalProjectReferences([{sourceRefs:[id]}],source),e=>e.code==='PROJECT_GROUPS_INCOMPLETE');
});
test('vision rejects missing, duplicate, and invented visual entries',async()=>{
  for(const value of [{items:[{index:0,status:'read',text:'甲'}]},{items:[{index:0,status:'read',text:'甲'},{index:0,status:'read',text:'乙'}]},{items:[{index:0,status:'read',text:'甲'},{index:3,status:'read',text:'乙'}]}])await assert.rejects(readVisualBatch({env,items,fetchImpl:async()=>answer(value)}),e=>e.code==='MATERIAL_INCOMPLETE');
});
test('unreadable content is explicit and hidden reasoning is not returned',async()=>{
  const result=await readVisualBatch({env,items,fetchImpl:async()=>answer({items:[{index:0,status:'read',text:'每人200元；兼项另收100元'},{index:1,status:'unreadable',text:'猜测内容'}]})});assert.equal(result.items[1].text,'');assert.equal(result.tokens,30);assert.ok(!JSON.stringify(result).includes('DO_NOT_PERSIST'));
});
test('generic agent reads 222 paragraphs and 13 images in three bounded batches; recovery reuses completed transcriptions',async()=>{
  const visuals=Array.from({length:13},(_,index)=>({index,location:`段落${index+1}`,kind:'png',sha256:String(index).padStart(64,'0')}));
  const sources=Array.from({length:222},(_,index)=>({location:`段落${index+1}`,text:index===221?'第12条声明：原文末尾。':`原文资料${index}`}));
  const cache=new Map(),offsets=[],sizes=[],modelInputs=[];
  const fetchImpl=async(url,options)=>{
    if(url.includes('/progress')){const input=JSON.parse(options.body);if(input.stage==='material_image')cache.set(input.index,{status:input.recognitionStatus,text:input.text});return {ok:true};}
    if(url.includes('/materials/')){
      const offset=Number(new URL(url).searchParams.get('offset'));offsets.push(offset);
      const loaded=visuals.slice(offset,offset+6).map(item=>({...item,cached:cache.get(item.index),url:cache.has(item.index)?undefined:'data:image/png;base64,YQ=='}));
      return {ok:true,json:async()=>({items:loaded})};
    }
    const input=JSON.parse(options.body);
    if(url.includes('/mcp'))return {ok:true,text:async()=>JSON.stringify({id:input.id,result:input.method==='tools/list'?{tools:[]}: {}})};
    if(input.model==='fixture-vision'){const indices=input.messages[0].content.filter(i=>i.type==='text'&&i.text.startsWith('图片序号')).map(i=>Number(i.text.match(/序号(\d+)/)[1]));sizes.push(indices.length);return answer({items:indices.map(index=>({index,status:'read',text:`分类表${index}：男子双打`}))});}
    modelInputs.push(input);return answer({reply:'依据全部材料整理完毕，尚未办理业务。',blocks:[]});
  };
  const body={runId:'1',runToken:'fixture',progressEnabled:true,model:'deepseek-flash',backendPort:8082,messages:[{role:'user',content:'只整理材料'}],materials:[{fileId:'2',name:'长规程',sha256:'f'.repeat(64),coverage:'全部222段、13图',sources,visuals}]};
  const first=await runAgent({env,fetchImpl,body});assert.equal(first.ok,true);assert.equal(first.tokens,120);assert.deepEqual(offsets,[0,6,12]);assert.deepEqual(sizes,[6,6,1]);assert.equal(cache.size,13);assert.match(JSON.stringify(modelInputs[0].messages),/第12条声明：原文末尾/);assert.match(JSON.stringify(modelInputs[0].messages),/分类表12/);
  const second=await runAgent({env,fetchImpl,body});assert.equal(second.ok,true);assert.equal(second.tokens,30);assert.deepEqual(sizes,[6,6,1]);assert.ok(!JSON.stringify(cache).includes('DO_NOT_PERSIST'));
});
