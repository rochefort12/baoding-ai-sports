<template>
  <section ref="root" class="b-ai-publication-card" aria-label="聊天发布核对" :aria-busy="loading || publishing || savingPayment">
    <header><strong>核对并发布</strong><div><button type="button" :disabled="loading || publishing || savingPayment || disabled" @click="emit('revise')">修改草稿</button><button type="button" :disabled="loading || publishing || savingPayment || disabled" @click="reload">重新读取</button></div></header>
    <p v-if="loading" role="status">正在读取这场赛事的实际发布资料…</p>
    <p v-if="error" class="b-ai-publication-error" role="alert">{{ error }}</p>
    <template v-if="event && preview">
      <h3>{{ event.name }}</h3><p>{{ event.projectName || '运动项目说明待补' }} · {{ event.location || '地点待补' }}</p>
      <dl class="b-ai-publication-times"><div><dt>报名开始</dt><dd>{{ businessTime(event.registrationOpensAt) }}</dd></div><div><dt>报名截止</dt><dd>{{ businessTime(event.registrationClosesAt) }}</dd></div><div><dt>比赛开始</dt><dd>{{ businessTime(event.startsAt) }}</dd></div><div><dt>比赛结束</dt><dd>{{ businessTime(event.endsAt) }}</dd></div></dl>
      <div class="b-ai-publication-prices"><div v-for="(unit,index) in preview.units || []" :key="index"><strong>{{ unit.unitName }}</strong><span>{{ unit.paymentMode === 'free' ? '免费' : unit.amount == null ? '价格待确认' : '每单 ¥' + Number(unit.amount).toFixed(2) }}</span></div></div>
      <section v-if="hasCharge" class="b-ai-publication-payment" aria-label="赛事收款说明">
        <h4>收款说明</h4>
        <p v-if="paymentError" class="b-ai-publication-error" role="alert">{{ paymentError }}</p>
        <template v-if="payment">
          <p v-if="payment.instruction" class="b-ai-publication-payment-text">{{ payment.instruction }}</p>
          <article v-for="channel in payment.channels" :key="channel.type" class="b-ai-publication-channel"><strong>{{ channel.label }}</strong><p class="b-ai-publication-payment-text">{{ channel.instruction || '此渠道没有补充说明。' }}</p></article>
          <template v-if="needsPaymentSetup">
            <p>收费赛事还没有收款渠道。请填写线下办理的地点或联系付款方式，保存后重新核对发布。</p>
            <el-form label-position="top" :disabled="loading || publishing || savingPayment || disabled || paymentLocked">
              <el-form-item label="收款方式名称"><el-input model-value="线下付款" readonly aria-label="收款方式名称" /></el-form-item>
              <el-form-item label="收款说明"><el-input v-model="paymentInstruction" type="textarea" :rows="3" maxlength="500" show-word-limit aria-label="收款说明" placeholder="填写真实的付款地点或联系办理方式" /></el-form-item>
              <el-button type="primary" :loading="savingPayment" :disabled="loading || publishing || disabled || paymentLocked || !loadedSignature || !paymentInstruction.trim()" @click="savePayment">保存收款说明</el-button>
            </el-form>
            <p v-if="paymentLocked" class="b-ai-publication-note">赛事已有正式报名、已停止办理或已结束，收款设置已锁定。</p>
          </template>
        </template>
        <p v-if="paymentNotice" class="b-ai-publication-payment-saved" role="status">{{ paymentNotice }}</p>
        <p class="b-ai-publication-note">保存的是报名付款指引，实际收款仍由工作人员核实。</p>
      </section>
      <el-form label-position="top" :disabled="publishing || savingPayment || loading || disabled"><el-form-item label="公开联系人"><el-input v-model="contactName" maxlength="100" :disabled="preview.contactFrozen" /></el-form-item><el-form-item label="公开联系方式"><el-input v-model="contactMethod" maxlength="240" :disabled="preview.contactFrozen" /></el-form-item></el-form>
      <details class="b-ai-publication-terms"><summary>退赛与退款说明</summary><p>{{ preview.refundNote || '请核对赛事退改设置' }}</p></details>
      <el-checkbox v-model="consent" :disabled="publishing || savingPayment || loading || disabled || paymentNotReady">我已核对并同意公开这些联系信息</el-checkbox>
      <p class="b-ai-publication-note">也可在聊天中输入“确认发布”，表示已核对本卡和收款说明，并同意公开联系信息。发布后参赛者可看到赛事，报名按实际窗口开放。</p>
      <footer><small>赛事编号：{{ event.id }}</small><el-button type="primary" :disabled="loading || savingPayment || disabled || paymentNotReady || !consent || !contactName.trim() || !contactMethod.trim() || event.publicationStatus === 'published'" :loading="publishing" @click="confirm(false)">确认发布赛事</el-button></footer>
    </template>
  </section>
</template>
<script setup lang="ts">
import { computed, nextTick, onUnmounted, ref, watch } from 'vue';
import { useUserStore } from '@/store/modules/user';
import request from '@/utils/request';
import { newRequestKey } from '@/utils/requestKey';
import { businessTime } from '@/utils/business';
import { getManagedEvent, publishEvent, type EventCard } from '@/api/sports/event';
import { getAiTask, type AiTaskCard } from '@/api/sports/aiTask';
import { getEventPaymentConfig, saveEventPaymentConfig, type PaymentSettings } from '@/api/sports/finance';
import { createdProposalState, publicationReviewSignature } from '@/utils/assistantPublication';
import '@/assets/styles/assistant-publication.scss';

const props=defineProps<{ eventId:string; taskId:string; taskVersion?:number; active?:boolean; disabled?:boolean; beforeConfirm:()=>Promise<boolean> }>();
const emit=defineEmits<{ published:[id:string]; busy:[value:boolean];revise:[] }>();
type Preview={eventVersion?:number;previewHash?:string;contactName?:string;contactMethod?:string;contactFrozen?:boolean;refundNote?:string;units?:{unitName:string;paymentMode:string;amount:number|string|null}[]};
const root=ref<HTMLElement>(),event=ref<EventCard>(),preview=ref<Preview>(),loading=ref(false),publishing=ref(false),error=ref(''),consent=ref(false),contactName=ref(''),contactMethod=ref('');
const payment=ref<PaymentSettings>(),paymentInstruction=ref(''),paymentError=ref(''),paymentNotice=ref(''),savingPayment=ref(false);
const hasCharge=computed(()=>Boolean(preview.value?.units?.some(unit=>unit.paymentMode!=='free')));
const needsPaymentSetup=computed(()=>hasCharge.value&&payment.value?.channels.length===0);
const paymentNotReady=computed(()=>hasCharge.value&&(!payment.value||payment.value.channels.length===0));
const paymentLocked=computed(()=>Boolean(event.value&&(event.value.registrationReviewLocked||event.value.holdingStatus==='cancelled'||(event.value.endsAt&&new Date(event.value.endsAt).getTime()<=Date.now()))));
let revision=0,paymentOperation=0,publicationOperation=0,mounted=true,currentScope='',loadedIdentity='',loadedSignature='',loadedTaskVersion:number|undefined,loadedEventVersion:number|undefined,loadedPreviewHash:string|undefined,requestKey='',requestSignature='';
function scopeKey(){return JSON.stringify([props.eventId,props.taskId,useUserStore().token]);}
function isActive(){return mounted&&props.active!==false;}
function isCurrent(stamp:number,scope:string){return mounted&&props.active!==false&&stamp===revision&&scope===scopeKey();}
async function readActual() {
  const id=props.eventId,taskId=props.taskId,stamp=revision,scope=scopeKey();
  const [details,fees,task]=await Promise.all([getManagedEvent(id),request<Preview>({url:'/sports/b/events/'+id+'/preview-fees',method:'get'}),getAiTask(taskId)]);
  if(!isCurrent(stamp,scope))throw new Error('核对窗口已变化，请重新读取。');
  const actual=task.data as AiTaskCard;
  if(actual.resultObjectId!==id)throw new Error('赛事与当前办赛任务不一致，请重新读取任务。');
  const state=createdProposalState(actual.proposal);
  let settings:PaymentSettings|undefined,paymentReadError='';
  // Free events do not require access to the separate payment capability.
  if(fees.data.units?.some(unit=>unit.paymentMode!=='free')) {
    try {const response=await getEventPaymentConfig(id);settings=response.data;}
    catch(reason) {paymentReadError=reason instanceof Error?reason.message:'收款说明读取未完成，请重新读取；需有本组织的资金办理权限，现有渠道不会被覆盖。';}
  }
  return {event:details.data,preview:fees.data,task:actual,state,payment:settings,paymentError:paymentReadError,signature:publicationReviewSignature(details.data,fees.data,fees.data.eventVersion??actual.eventVersion??state.eventVersion,settings)};
}
function assignActual(actual:Awaited<ReturnType<typeof readActual>>) {
  event.value=actual.event;preview.value=actual.preview;contactName.value=actual.preview.contactName||'';contactMethod.value=actual.preview.contactMethod||'';
  payment.value=actual.payment;paymentError.value=actual.paymentError;
  loadedSignature=actual.signature;loadedTaskVersion=actual.task.version;loadedEventVersion=actual.preview.eventVersion??actual.task.eventVersion??actual.state.eventVersion;loadedPreviewHash=actual.preview.previewHash;loadedIdentity=useUserStore().token;
  consent.value=false;
}
async function reload() {
  if(!mounted||props.active===false)return;
  const stamp=++revision,scope=scopeKey();
  loading.value=true;error.value='';loadedSignature='';consent.value=false;requestKey=newRequestKey();requestSignature='';
  try {
    const actual=await readActual();if(!isCurrent(stamp,scope))return;
    assignActual(actual);
    if(actual.event.publicationStatus==='published')error.value='这场赛事已经发布，无需重复发布。';
    else if(actual.state.dirty)error.value='候选修改尚未同步到赛事，请先保存赛事修改，再核对发布。';
  } catch(reason){if(isCurrent(stamp,scope))error.value=reason instanceof Error?reason.message:'发布资料读取未完成，请重新读取。';}
  finally{if(isCurrent(stamp,scope))loading.value=false;}
}
async function savePayment() {
  if(props.active===false||loading.value||publishing.value||savingPayment.value||props.disabled||paymentLocked.value)return;
  if(!payment.value||!loadedSignature){paymentError.value='请先成功读取实际收款设置，再保存说明。';return;}
  const instruction=paymentInstruction.value.trim();
  if(!instruction||instruction.length>500){paymentError.value='请填写收款说明，最多500字。';return;}
  const stamp=revision,scope=scopeKey(),id=props.eventId,operation=++paymentOperation;
  const contact={name:contactName.value,method:contactMethod.value,sourceName:preview.value?.contactName||'',sourceMethod:preview.value?.contactMethod||''};
  if(useUserStore().token!==loadedIdentity){paymentError.value='登录状态已变化，请重新读取后再保存。';return;}
  savingPayment.value=true;emit('busy',true);paymentError.value='';paymentNotice.value='';consent.value=false;
  // The API replaces the whole configuration: preserve every existing channel and its protected fields.
  const channels=payment.value.channels.map(channel=>({...channel}));
  if(channels.some(channel=>channel.type==='offline')){paymentError.value='线下付款渠道已存在，请重新读取实际说明。';savingPayment.value=false;emit('busy',false);return;}
  channels.push({type:'offline',label:'线下付款',instruction,qrFileId:null,accountName:null,bankName:null,bankAccount:null});
  try {
    const response=await saveEventPaymentConfig(id,{revision:payment.value.revision,instruction:payment.value.instruction,channels});
    if(!isCurrent(stamp,scope))return;
    payment.value=response.data;
    // Saving payment instructions never confirms publication; the actual preview and consent are renewed.
    await reload();
    if(isActive()&&scope===scopeKey()) {
      // Keep locally filled contacts when saving an unrelated instruction did not alter their actual source.
      if(preview.value&&!preview.value.contactFrozen&&(preview.value.contactName||'')===contact.sourceName&&(preview.value.contactMethod||'')===contact.sourceMethod){contactName.value=contact.name;contactMethod.value=contact.method;}
      paymentNotice.value=loadedSignature&&!paymentError.value?'收款说明已保存，请重新核对本卡后确认发布。':'收款说明已保存，发布资料还需重新读取和核对。';
    }
  } catch(reason) {
    if(isCurrent(stamp,scope))paymentError.value=reason instanceof Error?reason.message:'收款说明未保存，请重试；若设置已变化，请重新读取后再保存。';
  } finally {
    if(operation===paymentOperation){savingPayment.value=false;emit('busy',false);}
  }
}
async function confirm(typed=false):Promise<boolean> {
  if(props.active===false||publishing.value||savingPayment.value)return false;
  if(loading.value){error.value='发布资料还在读取，请核对卡片后再确认。';return false;}
  if(props.disabled){error.value='正在处理上一项修改，请稍后核对发布。';return false;}
  if(!event.value||!preview.value||!loadedSignature){error.value='请先读取并核对发布资料，再确认发布。';await reload();return false;}
  if(paymentNotReady.value){error.value=paymentError.value?'请先成功读取并核对实际收款说明。':'收费赛事需要先填写并保存收款说明，再核对发布。';return false;}
  if(!typed&&!consent.value)return false;
  if(!contactName.value.trim()||!contactMethod.value.trim()){error.value='请填写并核对公开联系人和联系方式。';return false;}
  const stamp=revision,id=props.eventId,identity=useUserStore().token,operation=++publicationOperation;
  if(identity!==loadedIdentity){error.value='登录状态已变化，请重新核对发布资料。';await reload();return false;}
  publishing.value=true;emit('busy',true);error.value='';
  try {
    if(!await props.beforeConfirm()){await reload();return false;}
    if(stamp!==revision||id!==props.eventId||identity!==useUserStore().token)return false;
    const actual=await readActual();if(stamp!==revision||id!==props.eventId||identity!==useUserStore().token)return false;
    if(actual.event.publicationStatus==='published'){emit('published',id);return true;}
    if(actual.paymentError||(actual.preview.units?.some(unit=>unit.paymentMode!=='free')&&!actual.payment?.channels.length)){assignActual(actual);error.value='请先成功读取并保存可用的收款说明，再重新核对发布。';return false;}
    if(actual.state.dirty||actual.task.version!==loadedTaskVersion||actual.signature!==loadedSignature){assignActual(actual);error.value='发布资料已变化，请重新核对后确认发布。';return false;}
    consent.value=true;
    const signature=publicationReviewSignature(id,contactName.value.trim(),contactMethod.value.trim(),loadedEventVersion);
    if(requestSignature&&requestSignature!==signature)requestKey=newRequestKey();requestSignature=signature;
    if(loadedEventVersion===undefined||!loadedPreviewHash)throw new Error('未读取到发布核对版本，请重新读取资料。');
    const result=await publishEvent(id,requestKey,contactName.value.trim(),contactMethod.value.trim(),loadedEventVersion,loadedPreviewHash);
    if(stamp!==revision||id!==props.eventId||identity!==useUserStore().token)return false;
    if(result.data?.publicationStatus!=='published')throw new Error('发布状态尚未核实，请重新读取赛事。');
    event.value=result.data;emit('published',id);return true;
  } catch(reason) {
    if(stamp!==revision||id!==props.eventId||identity!==useUserStore().token)return false;
    try{const actual=await readActual();if(stamp!==revision||identity!==useUserStore().token)return false;if(actual.event.publicationStatus==='published'){event.value=actual.event;emit('published',id);return true;}}
    catch { /* Preserve the original failure and request key for status recovery. */ }
    error.value=reason instanceof Error?reason.message:'发布未完成，请按提示补齐设置后重试。';return false;
  } finally {if(operation===publicationOperation){publishing.value=false;emit('busy',false);}}
}
async function focus(){await nextTick();root.value?.scrollIntoView({block:'start',behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'});}
defineExpose({confirm,reload,focus});
function resetScope(){revision++;paymentOperation++;publicationOperation++;loadedSignature='';loadedIdentity='';event.value=undefined;preview.value=undefined;payment.value=undefined;paymentInstruction.value='';paymentError.value='';paymentNotice.value='';contactName.value='';contactMethod.value='';consent.value=false;loading.value=false;publishing.value=false;savingPayment.value=false;emit('busy',false);}
watch(()=>[props.eventId,props.taskId,props.taskVersion],()=>{const scope=scopeKey();if(scope!==currentScope){resetScope();currentScope=scope;}void reload();},{immediate:true});
watch(()=>props.active,value=>{if(value===false){revision++;paymentOperation++;publicationOperation++;loadedSignature='';consent.value=false;loading.value=false;publishing.value=false;savingPayment.value=false;emit('busy',false);}else void reload();});
watch(()=>useUserStore().token,()=>{resetScope();currentScope=scopeKey();error.value='登录状态已变化，请重新读取发布资料。';});
onUnmounted(()=>{mounted=false;revision++;paymentOperation++;publicationOperation++;emit('busy',false);});
</script>
