<template>
  <section v-if="steps.length || active" class="assistant-progress" aria-label="处理过程">
    <div class="assistant-progress-heading" role="status"><span class="assistant-progress-dot" :class="{active}" aria-hidden="true"></span><strong>{{ latest ? describe(latest) : '正在接收任务' }}</strong></div>
    <p v-if="active && connection !== 'live'" class="assistant-progress-connection">{{ connection === 'unavailable' ? '实时连接暂不可用，正在重新读取已保存的进度。' : '正在连接实时进度，已保存的记录仍可查看。' }}</p>
    <details v-if="steps.length"><summary>查看处理记录 <span>{{ steps.length }} 条</span></summary><ol><li v-for="step in steps.slice(-30)" :key="step.sequence"><span :class="step.status">{{ step.status === 'succeeded' ? '✓' : step.status === 'started' ? '○' : '!' }}</span><p>{{ describe(step) }}</p></li></ol><p v-if="steps.length > 30" class="assistant-progress-note">显示最近30条记录，历史任务和已完成的操作仍然保留。</p></details>
  </section>
</template>
<script setup lang="ts">
import {computed} from 'vue';
import type {VisibleStep,ProgressConnection} from '@/utils/assistantProgress';
const props=withDefaults(defineProps<{steps:VisibleStep[];active:boolean;connection?:ProgressConnection}>(),{connection:'connecting'});
const latest=computed(()=>props.steps.at(-1));
const names:Record<string,string>={material_read:'读取材料文字',vision_batch:'核对材料图片',material_image:'核对材料图片',answer_prepare:'整理当前目标与回答',source_projects:'核对完整项目分类',source_fields:'校验原文字段',model:'整理候选草稿',playbook:'读取当前办理范围',sports_playbook:'读取当前办理范围',sports_capabilities:'核对已开放能力',sports_preview:'查询业务记录',sports_execute:'办理已授权步骤',sports_recovery:'恢复已保存的办理记录',sports_children:'读取职能助手结果',sports_delegate:'委派已授权任务',sports_propose:'准备待确认内容',describe_event_constraints:'核对赛事填写要求',read_document_block:'读取原文位置',validate_event_proposal:'检查草稿完整性','deepseek-flash':'整理回答'};
const fields:Record<string,string>={declarationText:'参赛声明',feeDescription:'收费说明',rulesText:'竞赛规程',contactName:'联系人',contactMethod:'联系方式',refundTerms:'退改条件',projectName:'项目分类'};
const reasons:Record<string,string>={invalid_catalog:'项目清单格式不完整',invalid_name:'缺少项目名称',duplicate_name:'项目名称重复',missing_project_quote:'项目引用无法在原文找到',missing_fee_quote:'费用引用无法在原文找到'};
function describe(step:VisibleStep){let meta:Record<string,any>={};try{meta=JSON.parse(step.summary||'{}');}catch{}const title=names[step.name]||'核对业务步骤';if(meta.recognitionStatus==='unreadable')return `${title} · 第${Number(meta.index)+1}处无法完整读取，待人工核对`;if(step.status==='failed'||step.status==='refused')return `${title}未完成${meta.field?' · '+(fields[meta.field]||'原文字段')+'依据未通过校验':''}${reasons[meta.reason]?'：'+reasons[meta.reason]:''}`;return `${step.status==='started'?(props.active&&step===latest.value?'正在':'开始'):'已完成'}${title}${meta.total?' · '+meta.completed+'/'+meta.total:step.name==='material_image'?' · 第'+(Number(meta.index)+1)+'处':''}`;}
</script>
