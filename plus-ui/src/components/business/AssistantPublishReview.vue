<template>
  <el-dialog v-model="visible" title="核对并发布赛事" class="b-dialog" width="620px" append-to-body :close-on-click-modal="!publishing" :show-close="!publishing">
    <p v-if="loading" role="status">正在读取这场赛事的发布资料…</p>
    <el-alert v-if="error" :title="error" type="error" :closable="false" />
    <template v-if="event && preview">
      <h3>{{ event.name }}</h3><p>{{ event.location }} · {{ event.startsAt }}</p>
      <el-table :data="preview.units || []"><el-table-column prop="unitName" label="报名项目"/><el-table-column label="每单费用"><template #default="{row}">{{ row.paymentMode === 'free' ? '免费' : row.amount == null ? '待确认' : '¥' + Number(row.amount).toFixed(2) }}</template></el-table-column></el-table>
      <el-form label-position="top"><el-form-item label="公开联系人"><el-input v-model="contactName" maxlength="100" :disabled="preview.contactFrozen || publishing"/></el-form-item><el-form-item label="公开联系方式"><el-input v-model="contactMethod" maxlength="240" :disabled="preview.contactFrozen || publishing"/></el-form-item><el-form-item label="退赛与退款说明"><el-input :model-value="preview.refundNote || ''" type="textarea" readonly/></el-form-item></el-form>
      <el-checkbox v-model="consent" :disabled="publishing">我已核对赛事、项目费用和退改内容，同意公开联系信息</el-checkbox>
      <p class="b-muted">发布后参赛者可以看到赛事；报名按实际报名窗口开放。发布不会确认到账或替参赛者报名。</p>
    </template>
    <template #footer><el-button :disabled="publishing" @click="visible=false">继续核对</el-button><el-button v-if="event" :disabled="publishing" @click="settings">完善赛事设置</el-button><el-button type="primary" :disabled="loading || !event || !preview || event.publicationStatus === 'published' || !consent || !contactName.trim() || !contactMethod.trim()" :loading="publishing" @click="publish">确认发布</el-button></template>
  </el-dialog>
</template>
<script setup lang="ts">
import { ref, watch } from 'vue';
import { useUserStore } from '@/store/modules/user';
import request from '@/utils/request';
import { newRequestKey } from '@/utils/requestKey';
import { getManagedEvent, publishEvent, type EventCard } from '@/api/sports/event';
const visible = defineModel<boolean>({required:true});
const props = defineProps<{eventId:string}>();
const emit = defineEmits<{published:[id:string];settings:[id:string]}>();
type Preview={contactName?:string;contactMethod?:string;contactFrozen?:boolean;refundNote?:string;units?:{unitName:string;paymentMode:string;amount:number|null}[]};
const event=ref<EventCard>(),preview=ref<Preview>(),loading=ref(false),publishing=ref(false),error=ref(''),consent=ref(false),contactName=ref(''),contactMethod=ref('');
let revision=0,requestKey='',requestSignature='';
watch(()=>[visible.value,props.eventId],async()=>{
  const stamp=++revision;
  if(!visible.value)return;
  event.value=undefined;preview.value=undefined;error.value='';consent.value=false;loading.value=true;requestKey=newRequestKey();requestSignature='';
  const identity=useUserStore().token;
  try{const [details,fees]=await Promise.all([getManagedEvent(props.eventId),request<Preview>({url:'/sports/b/events/'+props.eventId+'/preview-fees',method:'get'})]);if(stamp!==revision||identity!==useUserStore().token)return;event.value=details.data;preview.value=fees.data;contactName.value=fees.data.contactName||'';contactMethod.value=fees.data.contactMethod||'';if(details.data.publicationStatus==='published')error.value='这场赛事已经发布，无需重复发布。';}
  catch{if(stamp===revision)error.value='发布资料读取未完成，请重新打开核对。';}
  finally{if(stamp===revision)loading.value=false;}
},{immediate:true});
function settings(){if(publishing.value)return;visible.value=false;emit('settings',props.eventId);}
async function publish(){
  if(publishing.value||!consent.value||!event.value||!preview.value||event.value.publicationStatus==='published')return;
  publishing.value=true;error.value='';const id=props.eventId,identity=useUserStore().token;
  const signature=JSON.stringify([id,contactName.value.trim(),contactMethod.value.trim()]);
  if(requestSignature && requestSignature!==signature)requestKey=newRequestKey();
  requestSignature=signature;
  try{await publishEvent(id,requestKey,contactName.value.trim(),contactMethod.value.trim());if(props.eventId!==id||useUserStore().token!==identity)return;visible.value=false;emit('published',id);}
  catch(reason){if(props.eventId===id&&useUserStore().token===identity)error.value=reason instanceof Error?reason.message:'发布未完成，请按提示补齐设置后重试。';}
  finally{publishing.value=false;}
}
</script>
