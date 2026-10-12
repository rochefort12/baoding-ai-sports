import test from 'node:test';import assert from 'node:assert/strict';
import {checkedSourceProjects,deriveFixedSourceOrderFees} from './kernel.mjs';
const project=(text,amount,basis='per_person')=>({name:'合成项目',entryType:'individual',quotes:[text],feeAmount:amount,feeBasis:basis,feeQuotes:[text]});
test('exact scoped whole-order quote fixes a model per-person label without changing price',()=>{
 for(const text of ['合成项目每单收费30元。','合成项目每单60元，整队60元，不是每人60元。']){
  const amount=text.includes('30')?'30':'60';const [unit]=checkedSourceProjects([project(text,amount)],text);
  assert.equal(unit.feeBasis.value,'order');assert.equal(unit.feeAmount.value,amount);assert.equal(unit.feeBasis.sources[0].quote,text);
 }
});
test('source pair person fee becomes an auditable order candidate using integer cents',()=>{
 const text='公开双打每单2人，每人收费50.50元。';const [unit]=deriveFixedSourceOrderFees(checkedSourceProjects([{name:'公开双打',entryType:'pair',quotes:[text],feeAmount:'50.50',feeBasis:'per_person',feeQuotes:[text]}],text));
 assert.equal(unit.feeAmount.value,'101.00');assert.equal(unit.feeBasis.value,'order');assert.equal(unit.feeAmount.sources[0].quote,text);assert.deepEqual(unit.feeCalculation,{perPersonAmount:'50.50',memberCount:2,orderAmount:'101.00'});
});
test('additional, conditional, variable, unscoped and mismatched fees are not multiplied',()=>{
 for(const text of ['公开双打每人50元，加项另收20元。','公开双打每人50元，早鸟优惠40元。','公开双打每人50元或60元。','公开双打每人60元。']){
  const units=checkedSourceProjects([{name:'公开双打',entryType:'pair',quotes:[text],feeAmount:'50',feeBasis:'per_person',feeQuotes:[text]}],text);assert.equal(deriveFixedSourceOrderFees(units)[0].feeBasis.value,'per_person');
 }
 const text='团体每队3至5人，每人50元。';const units=checkedSourceProjects([{name:'团体',entryType:'team',minMembers:3,maxMembers:5,quotes:[text],feeAmount:'50',feeBasis:'per_person',feeQuotes:[text]}],text);assert.equal(deriveFixedSourceOrderFees(units)[0].feeBasis.value,'per_person');
});
test('fixed team source count is required and overflow cannot become a price',()=>{
 for(const [text,min,max,amount,basis] of [['团体每队5人，每人50元。',5,5,'50','order'],['团体参赛，每人50元。',5,5,'50','per_person'],['团体每队500人，每人99999999元。',500,500,'99999999','per_person']]){
  const [unit]=deriveFixedSourceOrderFees(checkedSourceProjects([{name:'团体',entryType:'team',minMembers:min,maxMembers:max,quotes:[text],feeAmount:amount,feeBasis:'per_person',feeQuotes:[text]}],text));assert.equal(unit.feeBasis.value,basis);if(basis==='order')assert.equal(unit.feeAmount.value,'250.00');
 }
});
test('person, additional, conflicting or unscoped quotes cannot become whole-order authority',()=>{
 for(const text of ['合成项目每人30元。','合成项目每单30元或每人30元。','合成项目每单30元，另收10元。','合成项目每单40元。']){
  const [unit]=checkedSourceProjects([project(text,'30')],text);assert.equal(unit.feeBasis.value,'per_person');
 }
 const source='合成项目每人30元。另一个项目每单30元。';
 const [unscoped]=checkedSourceProjects([{...project('合成项目每人30元。','30'),feeQuotes:['另一个项目每单30元。']}],source);assert.equal(unscoped.feeBasis.value,'per_person');
 const text='合成项目每单30元，另一版40元。';const [conflict]=checkedSourceProjects([{...project(text,'30'),feeStatus:'conflict',feeAlternatives:['30','40']}],text);assert.equal(conflict.feeAmount.status,'conflict');assert.equal(conflict.feeAmount.value,'');
});
