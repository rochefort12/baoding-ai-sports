<template>
  <template v-for="(block,index) in parsed" :key="index">
    <section v-if="block.kind==='guidance'" class="agent-guidance"><strong>{{block.title}}</strong><p>{{block.summary}}</p></section>
    <section v-else-if="block.kind==='question'" class="agent-question"><strong>{{block.label}}</strong><p v-if="block.hint">{{block.hint}}</p><div><button v-for="option in block.options||[]" :key="option" type="button" :disabled="busy||answerDisabled" :aria-pressed="hasAssistantAnswer(answerDraft || '',option)" @click="emit('answer',option)">{{option}}</button></div><small class="agent-choice-hint">可选多项，在输入框核对后发送。</small></section>
    <section v-else-if="block.kind==='checklist'" class="agent-checklist"><strong>{{block.title}}</strong><div v-for="(item,n) in block.items||[]" :key="n"><span :class="item.state">{{item.state==='done'?'✓':item.state==='pending'?'◷':'○'}}</span><p>{{item.label}}</p></div></section>
    <router-link v-else-if="block.kind==='navigation'&&safePath(block.path)" class="agent-navigation" :to="block.path!">{{block.label}} →</router-link>
    <section v-else-if="block.kind==='confirmation'" class="agent-confirm"><small>等待你确认</small><strong>{{block.title}}</strong><ConfirmationSummary :value="block.preview"/><div v-if="waitingConfirmation" class="agent-card-actions"><button :disabled="busy" class="agent-primary" @click="emit('confirm',true)">核对无误，确认</button><button :disabled="busy" @click="emit('confirm',false)">修改内容</button></div></section>
    <section v-else-if="block.kind==='receipt'" class="agent-receipt"><span>✓</span><div><strong>{{block.receipt?.status==='succeeded'?'这一步已办好':'办理状态已更新'}}</strong><small>回执 {{block.receipt?.receiptId}}</small></div></section>
    <section v-else-if="block.kind==='material'" class="agent-material"><strong>{{block.name}}</strong><p>{{block.coverage}}</p></section>
  </template>
</template>
<script setup lang="ts">
import {computed} from 'vue';
import ConfirmationSummary from '@/components/consumer/ConfirmationSummary.vue';
import '@/assets/styles/sports-agent.scss';
import {hasAssistantAnswer} from '@/utils/assistantAnswers';
interface Block{kind:string;title?:string;summary?:string;label?:string;hint?:string;options?:string[];items?:{label:string;state:string}[];path?:string;preview?:unknown;receipt?:{receiptId:string;status:string};name?:string;coverage?:string}
const props=defineProps<{blocks?:string;busy:boolean;waitingConfirmation:boolean;answerDraft?:string;answerDisabled?:boolean}>(),emit=defineEmits<{answer:[string];confirm:[boolean]}>();
const parsed=computed<Block[]>(()=>{try{const value=JSON.parse(props.blocks||'[]');return Array.isArray(value)?value.slice(0,8):[];}catch{return [];}});
function safePath(value?:string){return !!value&&/^\/(portal|public|org-desk|organization-review|government|sports-platform)(\/|\?|$)/.test(value)&&!/[\\\u0000-\u001f]/.test(value)&&!value.startsWith('//');}
</script>
