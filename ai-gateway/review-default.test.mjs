import test from 'node:test';import assert from 'node:assert/strict';
import {applyDefaultRegistrationReview,checkedSourceFields} from './kernel.mjs';import {canonicalFieldReferences} from './material-reader.mjs';
test('missing review defaults without an interruption or artificial source quotation',()=>{
 const result=applyDefaultRegistrationReview({event:{},reply:'已整理。报名是否需要人工审核？',suggestions:['人工审核','无需人工审核','查看表单']});assert.equal(result.event.registrationReview.value,'none');assert.equal(result.event.registrationReview.sources[0].kind,'default');assert.equal(result.event.registrationReview.sources[0].quote,'');assert.doesNotMatch(result.reply,/是否需要人工审核/);assert.deepEqual(result.suggestions,['查看表单']);
});
test('explicit manual, existing selection and genuine conflict are preserved',()=>{
 const field={value:'manual',status:'filled',sources:[{kind:'dialogue',quote:'人工审核'}]};assert.deepEqual(applyDefaultRegistrationReview({event:{registrationReview:field}}).event.registrationReview,field);assert.deepEqual(applyDefaultRegistrationReview({event:{}},{event:{registrationReview:field}}).event.registrationReview,field);const conflict={value:'',status:'conflict'};assert.deepEqual(applyDefaultRegistrationReview({event:{registrationReview:conflict}}).event.registrationReview,conflict);
});
test('source review enum retains the actual source citation rather than becoming a paragraph',()=>{
 const text='报名由主办方人工审核通过。',fields=canonicalFieldReferences({registrationReview:{value:'manual',status:'filled',sourceRefs:['s1']}},[{sourceId:'s1',text,status:'read'}]);const result=checkedSourceFields(fields,text);assert.equal(result.registrationReview.value,'manual');assert.equal(result.registrationReview.sources[0].quote,text);assert.throws(()=>checkedSourceFields({registrationReview:{value:'automatic',status:'filled',quotes:[text]}},text));
});
