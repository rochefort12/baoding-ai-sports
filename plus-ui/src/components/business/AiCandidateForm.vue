<template>
  <section ref="root" class="ai-chat-form" aria-label="聊天办赛表单" :aria-busy="saving">
    <header><div><strong>办赛表单</strong><p>{{ form.name || '赛事名称待补' }}<span v-if="units.length"> · {{ units.length }} 个项目</span></p></div><button type="button" :aria-expanded="showAll" @click="showAll=!showAll">{{ showAll ? '只看待补项' : '核对全部内容' }}</button></header>
    <p class="ai-chat-form-hint">{{ createdDraft ? '这是刚创建的同一份赛事草稿，可以继续修改并保存。' : displayedFields.length || unitGaps ? '资料已预填，下面直接补充或修改。' : '资料已预填，可核对全部内容后创建。' }}</p>
    <p v-if="stale" class="ai-chat-form-error" role="alert">对话更新了候选，当前未保存的填写已保留。<button type="button" @click="readLatestCandidate">读取最新候选</button></p>
    <p v-if="error" class="ai-chat-form-error" role="alert">{{ error }}</p>
    <details v-if="previousInput" class="ai-chat-previous"><summary>查看刷新前的填写</summary><p>刷新前内容保留在这里，可对照后回填。回填仍需保存。</p><dl><template v-for="field in candidateFields.filter(item=>previousInput!.event[item.key])" :key="field.key"><dt>{{field.label}}</dt><dd>{{previousInput.event[field.key]}}</dd></template></dl><p v-for="(unit,index) in previousInput.units" :key="index">{{unit.name}} · 每单 {{unit.feeAmount||'待补'}} 元 · 上限 {{unit.limitCount||'待补'}} 单</p><el-button :disabled="disabled||saving" @click="restorePrevious">回填刷新前内容</el-button></details>
    <el-form label-position="top" :disabled="disabled || saving" @submit.prevent>
      <div class="ai-chat-form-grid">
        <el-form-item v-for="field in displayedFields" :key="field.key" :label="field.label" :class="{ 'ai-chat-form-wide': field.long }">
          <el-date-picker v-if="field.date" v-model="form[field.key]" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" placeholder="选择时间" />
          <el-input v-else v-model="form[field.key]" :type="field.long ? 'textarea' : 'text'" :autosize="field.long ? {minRows:2,maxRows:6} : undefined" :maxlength="['rulesText','declarationText'].includes(field.key)?120000:field.long?12000:500" placeholder="请填写" />
          <small v-if="fieldIssue(field.key)">{{ fieldIssue(field.key) }}</small>
        </el-form-item>
      </div>
      <el-form-item v-if="showAll || proposal.event?.registrationReview?.status==='conflict' || !['manual','none'].includes(form.registrationReview)" label="报名审核"><el-select v-model="form.registrationReview"><el-option label="无需人工审核" value="none"/><el-option label="人工审核" value="manual"/></el-select><small v-if="proposal.event?.registrationReview?.status==='conflict'">原资料审核方式有冲突，请核对当前选择后保存。</small></el-form-item>
      <p v-else class="ai-chat-form-hint">报名审核：{{ form.registrationReview==='none'?'无需人工审核':'人工审核' }}。收费报名仍需实际足额收款。</p>
      <section v-if="units.length" class="ai-chat-unit-section">
        <div class="ai-chat-unit-summary"><strong>项目与价格</strong><small>{{ unitGaps ? `${unitGaps} 个项目待核对` : '已预填，可展开修改' }}</small></div>
        <div v-if="unitGaps || showAll" class="ai-chat-bulk">
          <el-form-item label="所有项目整单价 / 元"><el-input v-model="bulkPrice" inputmode="decimal" placeholder="如 100；免费填 0"/></el-form-item>
          <el-form-item label="每个项目报名上限 / 单"><el-input v-model="bulkCapacity" inputmode="numeric" placeholder="如 32"/></el-form-item>
          <el-button :disabled="!bulkPrice.trim()&&!bulkCapacity.trim()" @click="applyAll">应用到所有项目</el-button>
        </div>
        <details :open="unitsExpanded" @toggle="unitsExpanded=($event.target as HTMLDetailsElement).open"><summary>逐项核对 {{ units.length }} 个项目</summary>
          <article v-for="(unit,index) in units" :key="index" class="ai-chat-unit">
            <strong>{{ unit.name || `项目 ${index+1}` }}</strong>
            <p v-if="unitConflict(index)" class="ai-chat-form-error">原资料的项目设置存在冲突，请核对下面的值后保存。{{ unitIssue(index) }}</p>
            <div class="ai-chat-form-grid">
              <el-form-item label="项目名称"><el-input v-model="unit.name" maxlength="200" /></el-form-item>
              <el-form-item label="参赛形式"><el-select v-model="unit.entryType"><el-option label="个人" value="individual"/><el-option label="双人" value="pair"/><el-option label="团队" value="team"/></el-select></el-form-item>
              <el-form-item label="报名上限 / 单"><el-input v-model="unit.limitCount" inputmode="numeric"/></el-form-item>
              <el-form-item label="整单价格 / 元"><el-input v-model="unit.feeAmount" inputmode="decimal" placeholder="免费填 0"/></el-form-item>
              <el-form-item label="计费单位"><el-select v-model="unit.feeBasis"><el-option label="整单总价" value="order"/><el-option label="原文按人，待确认" value="per_person"/><el-option label="原文附加费用，待确认" value="additional"/><el-option label="待确认" value="unknown"/></el-select></el-form-item>
              <template v-if="unit.entryType==='team'"><el-form-item label="每单最少人数"><el-input v-model="unit.minMembers" inputmode="numeric"/></el-form-item><el-form-item label="每单最多人数"><el-input v-model="unit.maxMembers" inputmode="numeric"/></el-form-item></template>
            </div>
          </article>
        </details>
      </section>
      <p v-else class="ai-chat-form-error">资料未识别到竞赛项目，请继续补充项目名称、参赛形式和报名上限。</p>
      <el-checkbox v-if="form.declarationText" v-model="declarationRequired">要求每位参赛成员阅读并确认声明</el-checkbox>
    </el-form>
    <footer><p role="status">{{ status || (createdDraft ? '保存会更新原赛事；也可以继续聊天修改或说“发布赛事”。' : '保存后可继续修改，创建成功会显示赛事编号。') }}</p><div><el-button :disabled="disabled||stale" :loading="saving" @click="save(false)">{{createdDraft?'保存赛事修改':'保存表单'}}</el-button><el-button v-if="createdDraft" :disabled="disabled" :loading="saving" @click="refreshActual">读取赛事当前内容</el-button><el-button v-else ref="createButton" type="primary" :disabled="disabled||stale" :loading="saving" @click="save(true)">创建赛事</el-button></div></footer>
  </section>
</template>

<script setup lang="ts">
import { computed, nextTick, reactive, ref, watch } from 'vue';
import { editAiCandidate, getAiTask, talkAiTask, type AiTaskCard } from '@/api/sports/aiTask';
import { getManagedEvent } from '@/api/sports/event';
import { applyUniformCandidateValues, candidateFields, candidateUnitIds, canRestoreCandidateUnits, readCandidateForm } from '@/utils/aiCandidateForm';

const props=defineProps<{ task:AiTaskCard; disabled?:boolean; declarationAckRequired:boolean }>();
const emit=defineEmits<{ saved:[task:AiTaskCard,declarationRequired:boolean]; create:[task:AiTaskCard,declarationRequired:boolean]; refreshed:[task:AiTaskCard,declarationRequired:boolean] }>();
const root=ref<HTMLElement>(),createButton=ref<{ $el?:HTMLElement }>(),form=reactive<Record<string,string>>({}),units=ref<Record<string,string>[]>([]);
const showAll=ref(false),unitsExpanded=ref(false),saving=ref(false),stale=ref(false),error=ref(''),status=ref(''),declarationRequired=ref(false),bulkPrice=ref(''),bulkCapacity=ref('');
let loadedVersion:number|undefined, baseline='',cover:{fileId:string;index?:number}={fileId:'0'};
const proposal=ref<any>({});
const previousInput=ref<{event:Record<string,string>;units:Record<string,string>[];unitIds:string[];declaration:boolean}>();
const createdDraft=computed(()=>props.task.status==='CREATED');
const snapshot=()=>JSON.stringify({event:form,units:units.value,declarationRequired:declarationRequired.value});
const issues=computed<{field:string;message:string}[]>(()=>proposal.value.readiness?.blockingIssues||[]);
const fieldIssue=(key:string)=>issues.value.find(issue=>issue.field===key||key.endsWith('At')&&issue.field==='times')?.message;
// 待补字段依据加载版本固定，避免用户输入首字后输入框消失。
const missingFields=ref<string[]>([]);
const displayedFields=computed(()=>candidateFields.filter(field=>showAll.value||missingFields.value.includes(field.key)));
const unitConflict=(index:number)=>Object.values(proposal.value.units?.[index]||{}).some((node:any)=>node?.status==='conflict');
const unitIssue=(index:number)=>issues.value.filter(issue=>issue.field.startsWith(`units[${index}].`)).map(issue=>issue.message).join(' ');
const unitGaps=computed(()=>units.value.filter((unit,index)=>unitConflict(index)||!unit.name.trim()||!['individual','pair','team'].includes(unit.entryType)||!/^[1-9]\d*$/.test(unit.limitCount)||!/^\d+(?:\.\d{1,2})?$/.test(unit.feeAmount)||unit.feeBasis!=='order'||unit.entryType==='team'&&(!/^[1-9]\d*$/.test(unit.minMembers)||!/^[1-9]\d*$/.test(unit.maxMembers)||Number(unit.maxMembers)<Number(unit.minMembers))).length);
function reset(){
  try{
    const data=readCandidateForm(props.task);Object.keys(form).forEach(key=>delete form[key]);Object.assign(form,data.event);units.value=data.units;cover=data.cover;proposal.value=data.proposal;
    missingFields.value=candidateFields.filter(field=>!field.optional&&!form[field.key]?.trim()||data.proposal.event?.[field.key]?.status==='conflict'||!!fieldIssue(field.key)).map(field=>field.key);
    declarationRequired.value=props.declarationAckRequired;loadedVersion=props.task.version;stale.value=false;error.value='';status.value='';baseline=snapshot();unitsExpanded.value=units.value.length<=4&&unitGaps.value>0;
  }catch{error.value='候选表单读取失败，请重新打开这份任务。';}
}
function applyAll(){try{applyUniformCandidateValues(units.value,bulkPrice.value,bulkCapacity.value);error.value='';status.value='已填入所有项目，保存后更新候选。';}catch(reason){error.value=reason instanceof Error?reason.message:'批量填写未完成。';}}
async function persist():Promise<AiTaskCard>{
  if(saving.value||stale.value)throw new Error(stale.value?'当前填写与最新对话版本不同，请读取最新候选后再保存。':'表单正在保存，请稍后继续。');
  if(loadedVersion===undefined)throw new Error('未读取到候选版本，请重新打开任务。');
  saving.value=true;error.value='';status.value='正在保存表单…';
  try{
    const result=await editAiCandidate(props.task.id,{expectedVersion:loadedVersion,event:{...form},units:units.value.map(unit=>({...unit})),cover:{...cover},declarationAckRequired:declarationRequired.value});
    loadedVersion=result.data.version;baseline=snapshot();saving.value=false;
    status.value=createdDraft.value?'修改已保存到原赛事草稿。':'表单已保存到候选草稿。';return result.data;
  }catch(reason){error.value=reason instanceof Error?reason.message:'保存没有完成，请核对候选版本后重试。';status.value='填写内容已保留。';throw reason;}
  finally{saving.value=false;}
}
async function save(create:boolean){
  if(props.disabled)return;
  try{const result=await persist();if(create&&!createdDraft.value){status.value='表单已保存，正在创建赛事…';emit('create',result,declarationRequired.value);}else emit('saved',result,declarationRequired.value);}catch{ /* 输入和具体错误保留在表单中。 */ }
}
const hasUnsavedChanges=()=>saving.value||stale.value||!!baseline&&snapshot()!==baseline;
function preservePreviousInput(){if(!previousInput.value||snapshot()!==baseline)previousInput.value={event:{...form},units:units.value.map(unit=>({...unit})),unitIds:candidateUnitIds(proposal.value.units),declaration:declarationRequired.value};}
function readLatestCandidate(){preservePreviousInput();reset();status.value='已读取最新候选，刷新前填写保留供核对。';}
async function refreshActual(){
  if(saving.value||props.disabled||!props.task.resultObjectId)return;
  preservePreviousInput();
  saving.value=true;error.value='';status.value='正在读取原赛事的当前内容，刷新前填写会保留供核对…';
  try{
    const current=(await getAiTask(props.task.id)).data as AiTaskCard;
    await talkAiTask(current.id,'重新读取赛事草稿',current.version);
    const updated=(await getAiTask(current.id)).data as AiTaskCard,actual=(await getManagedEvent(props.task.resultObjectId)).data;
    if(updated.resultObjectId!==props.task.resultObjectId||!updated.draftEditable)throw new Error('赛事状态已变化，请按当前状态办理。');
    baseline='';stale.value=false;emit('refreshed',updated,!!actual.declarationAckRequired);status.value='已按实际赛事重新读取，刷新前填写可展开核对。';
  }catch(reason){error.value=reason instanceof Error?reason.message:'读取没有完成，当前填写已保留。';status.value='当前填写未覆盖。';}finally{saving.value=false;}
}
function restorePrevious(){
  const previous=previousInput.value;if(!previous)return;
  Object.assign(form,previous.event);declarationRequired.value=previous.declaration;
  const matching=canRestoreCandidateUnits(previous.unitIds,candidateUnitIds(proposal.value.units));
  if(matching)units.value=previous.units.map(unit=>({...unit}));
  status.value=matching?'刷新前填写已回填，保存后更新原赛事。':'赛事字段已回填；项目目录已变化或缺少项目身份，请对照刷新前项目逐项核对。';
}
async function focusCreate(){if(unitGaps.value)unitsExpanded.value=true;await nextTick();const hasGaps=missingFields.value.length||unitGaps.value;root.value?.scrollIntoView({block:hasGaps?'start':'end',behavior:'smooth'});const input=hasGaps?root.value?.querySelector<HTMLInputElement>('.ai-chat-form-grid input:not([disabled]),.ai-chat-form-grid textarea:not([disabled])'):undefined;(input||createButton.value?.$el)?.focus({preventScroll:true});}
defineExpose({focusCreate,persist,hasUnsavedChanges,getDeclarationRequired:()=>declarationRequired.value});
watch(()=>[props.task.id,props.task.version],(_current,prior)=>{if(prior&&_current[0]!==prior[0]){previousInput.value=undefined;baseline='';showAll.value=false;bulkPrice.value='';bulkCapacity.value='';}if(prior&&_current[0]===prior[0]&&baseline&&snapshot()!==baseline){stale.value=true;return;}reset();},{immediate:true});
</script>
