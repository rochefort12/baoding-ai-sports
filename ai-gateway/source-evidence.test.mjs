import {test} from 'node:test';
import assert from 'node:assert/strict';
import {checkedSourceFields} from './kernel.mjs';

test('a declaration may span adjacent source paragraphs without importing location labels',()=>{
  const blocks=['本人自愿参赛。','本人已阅读比赛规则。','本人确认所填资料真实。'];
  const display=blocks.map((text,i)=>`段落${i+1}: ${text}`).join('\n');
  const field={declarationText:{status:'filled',value:blocks.join('\n'),quotes:blocks}};
  assert.equal(checkedSourceFields(field,display,blocks.join('\n')).declarationText.value,blocks.join('\n'));
});
test('declaration provenance rejects omitted middle clauses, reordered clauses, and invented obligations',()=>{
  const source='本人自愿参赛。本人已阅读比赛规则。本人确认所填资料真实。';
  for(const value of ['本人自愿参赛。本人确认所填资料真实。','本人已阅读比赛规则。本人自愿参赛。','本人自愿参赛。本人放弃全部赔偿权利。']){
    assert.throws(()=>checkedSourceFields({declarationText:{status:'filled',value,quotes:['本人自愿参赛。']}},source),e=>e.code==='SOURCE_FIELDS_INCOMPLETE'&&e.field==='declarationText');
  }
});
