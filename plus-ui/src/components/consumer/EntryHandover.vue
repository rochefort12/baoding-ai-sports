<template>
  <section v-if="pending.length || detail?.candidates.length" class="consumer-card" data-testid="entry-responsibility-handover">
    <h3>报名责任交接</h3>
    <p class="consumer-muted">报名管理人负责本单名单、资金核对和问题收尾。队长变更后不会自动更换，接任人须本人接受。</p>
    <div v-for="item in pending" :key="item.id" class="handover-pending">
      <span>交接说明：{{ item.reason }} · {{ item.expires_at }}</span>
      <el-button type="primary" :loading="busy" @click="accept(item.id)">本人接受管理责任</el-button>
    </div>
    <template v-if="detail?.candidates.length">
      <el-select v-model="target" placeholder="选择一名已确认成员">
        <el-option v-for="candidate in detail.candidates" :key="candidate.account_id" :value="candidate.account_id" :label="candidate.nickname" />
      </el-select>
      <el-input v-model="reason" type="textarea" maxlength="2000" placeholder="说明本场进度、资金待办和交接事项" class="handover-reason" />
      <el-button :disabled="!target || !reason.trim()" :loading="busy" @click="handover">邀请对方接任</el-button>
    </template>
  </section>
</template>
<script setup lang="ts">
import request from '@/utils/request';import {performAction} from '@/api/sports/phase1';
const props=defineProps<{registrationId?:string}>();const pending=ref<{id:string;reason:string;expires_at:string}[]>([]);const detail=ref<{registration:{version:number};candidates:{account_id:string;nickname:string}[]}>();const target=ref('');const reason=ref('');const busy=ref(false);const emit=defineEmits(['changed']);
async function load(){pending.value=(await request({url:'/sports/entry-management/pending'})).data;if(props.registrationId)detail.value=(await request({url:`/sports/entry-management/${props.registrationId}`})).data;else detail.value=undefined;}
async function accept(caseId:string){busy.value=true;try{await performAction('registration.acceptHandover',{caseId},'我已了解本单报名、资金与问题的处理进度，同意接任报名管理责任。');await load();emit('changed');}finally{busy.value=false;}}
async function handover(){if(!props.registrationId||!detail.value)return;busy.value=true;try{await performAction('registration.handover',{registrationId:props.registrationId,targetAccountId:target.value,reason:reason.value,expectedVersion:detail.value.registration.version},'发起交接后，你仍继续负责；对方本人接受后才会移交。');await load();emit('changed');}finally{busy.value=false;}}
onMounted(load);watch(()=>props.registrationId,load);
</script><style scoped>.handover-pending{display:flex;gap:16px;align-items:center;padding:16px;border:1px solid #d5e8db;border-radius:12px;margin-bottom:16px;flex-wrap:wrap}.handover-reason{margin:12px 0}</style>
