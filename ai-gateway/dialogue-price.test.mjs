import test from 'node:test';import assert from 'node:assert/strict';
import {reconcileExplicitDialogueFees} from './kernel.mjs';
const field=value=>({value,status:'filled',sources:[],alternatives:[]});
const unit=(name,type='pair',min='',max='')=>({name:field(name),entryType:field(type),minMembers:field(min),maxMembers:field(max),limitCount:field(16),feeAmount:field(''),feeBasis:field('')});
test('combined age and person quote keeps model eligibility and fixes exact order arithmetic',()=>{
 const draft={event:{rulesText:field('自备球拍')},units:[unit('公开双打')]};
 const proposal={event:{rulesText:field('自备球拍，参赛年龄18-35岁')},units:[{...unit('公开双打项目'),feeAmount:field('50'),feeBasis:field('per_person')}],reply:'年龄已写入。这个50元是按人还是按单？'};
 const result=reconcileExplicitDialogueFees(proposal,draft,'参赛年龄18-35岁，每人50.50元。');
 assert.equal(result.units[0].feeAmount.value,'101.00');assert.equal(result.units[0].feeBasis.value,'order');assert.equal(result.units[0].name.value,'公开双打');assert.match(result.event.rulesText.value,/18-35/);assert.doesNotMatch(result.reply,/按人还是/);assert.match(result.units[0].feeAmount.sources[0].quote,/参赛年龄/);
});
test('multi-project ambiguity, conditional prices, questions and changed rosters are untouched',()=>{
 const proposal={reply:'待核对',units:[unit('甲')]};
 for(const message of ['年龄18-35岁，每人50元，加项20元','每人50元吗？','如果18岁，每人50元','不是每人50元','人数改成3人，每人50元'])assert.equal(reconcileExplicitDialogueFees(proposal,{units:[unit('甲')]},message),proposal);
 assert.equal(reconcileExplicitDialogueFees(proposal,{units:[unit('甲'),unit('乙')]},'年龄18-35岁，每人50元'),proposal);
 assert.equal(reconcileExplicitDialogueFees({...proposal,units:[unit('甲'),unit('乙')]},{units:[unit('甲')]},'年龄18-35岁，每人50元').units.length,2);
});
test('variable teams keep per-person basis, explicit order is never multiplied and zero remains filled',()=>{
 for(const [type,min,max,message,amount,basis] of [['team',3,5,'年龄18-35岁，每人50元','50.00','per_person'],['pair','','','年龄18-35岁，每单50元','50.00','order'],['pair','','','年龄18-35岁，每人0元','0.00','order']]){
  const result=reconcileExplicitDialogueFees({reply:'已整理'}, {units:[unit('甲',type,min,max)]},message);assert.equal(result.units[0].feeAmount.value,amount);assert.equal(result.units[0].feeBasis.value,basis);assert.equal(result.units[0].feeAmount.status,'filled');
 }
});
test('moving on retains current business fields instead of a model rewriting settled values',()=>{
 const draft={event:{rulesText:field('年龄18-35岁，自备球拍')},units:[{...unit('甲'),feeAmount:field('100'),feeBasis:field('order')}]};
 const result=reconcileExplicitDialogueFees({event:{rulesText:field('')},units:[],reply:'下一步核对声明'},draft,'继续下一步');assert.deepEqual(result.event,draft.event);assert.deepEqual(result.units,draft.units);assert.equal(result.reply,'下一步核对声明');
});
test('an explicit all-project order quotation is written without multiplying doubles or variable teams',()=>{
 for(const message of ['全部项目100元','每项100元','参赛年龄18-35岁，全部项目每项100.50元']){
  const draft={units:[unit('双打','pair'),unit('团体','team',3,5)]};
  const result=reconcileExplicitDialogueFees({event:{rulesText:field('参赛年龄18-35岁')},reply:'请确认整单总价。'},draft,message);
  for(const project of result.units){assert.equal(project.feeAmount.value,message.includes('100.50')?'100.50':'100.00');assert.equal(project.feeBasis.value,'order');assert.equal(project.feeAmount.sources[0].quote,message);assert.equal(project.limitCount.value,16);}
  assert.match(result.event.rulesText.value,/18-35/);assert.doesNotMatch(result.reply,/请确认整单总价/);
 }
});
test('all-project conditional prices and an unscoped amount do not become order policies',()=>{
 const draft={units:[unit('双打'),unit('团体','team',3,5)]},proposal={reply:'请核对条件'};
 for(const message of ['全部项目100元，另收20元','全部项目100元，加项优惠','全部项目100元吗？','不是全部项目100元','年龄18-35岁，100元'])assert.equal(reconcileExplicitDialogueFees(proposal,draft,message),proposal);
});
