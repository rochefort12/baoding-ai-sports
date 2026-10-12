<template>
  <AssistantWindow v-model="visible" v-bind="fileDropHandlers" class="product-agent">
    <template #heading><div class="agent-heading"><img src="/images/sports/assistant-orb-v2.webp" alt="" draggable="false" /><div><strong>体育助手</strong><small>{{ current ? statusLabels[current.status] || '办理进度' : '从当前任务开始' }}</small></div><button class="agent-icon" aria-label="查看任务记录" :aria-expanded="historyOpen" @click="historyOpen = !historyOpen">◷</button></div></template>
    <div class="agent-workspace">
      <section v-if="historyOpen" class="agent-history" aria-label="任务记录"><div class="agent-history-heading"><strong>任务记录</strong><button @click="newConversation">新任务</button></div><p v-if="!history.length">还没有任务记录</p><button v-for="item in history" :key="item.id" :disabled="busy" @click="select(item.id); historyOpen = false"><span>{{ item.goal }}</span><small>{{ statusLabels[item.status] || '已保存' }}</small></button></section>
      <div v-if="error" class="agent-error" role="alert"><span>{{ error }}</span><button :disabled="busy" @click="resolveError">{{ errorRetryable ? '重新连接' : '知道了' }}</button></div>
      <div ref="thread" class="agent-thread" aria-live="polite" @scroll="trackScroll">
        <section v-if="!current" class="agent-welcome">
          <img src="/images/sports/assistant-orb-v2.webp" alt="" draggable="false" /><h2>你好，这次先做哪件事？</h2><p>说出目标，或把材料交给我。我会结合能读取的信息，帮你继续下一步。</p>
          <div class="agent-starters assistant-feature-grid" aria-label="体育助手功能">
            <button v-for="choice in starterTasks" :key="choice.label" type="button" class="assistant-feature-card" :data-testid="choice.testId" :disabled="busy || !canContinue" @click="chooseGuide(choice.label)"><span class="assistant-feature-icon" aria-hidden="true"><img :src="'/images/sports/assistant/'+choice.art+'.webp'" alt="" draggable="false" /></span><span class="assistant-feature-copy"><strong>{{ choice.label }}</strong><small>{{ choice.description }}</small><span class="assistant-feature-status">{{ choice.status }}</span></span><span aria-hidden="true">↗</span></button>
          </div>
          <details class="assistant-scope-help"><summary>我会怎样帮你推进？</summary><ol><li>先核对目标、当前赛事或能够读取的实际记录。</li><li>信息不足时，一次只补最关键的几个问题。</li><li>给出下一步或对应页面；需要你办理的内容先交给你核对。</li></ol><p>材料与文稿可以先整理建议。保存到赛事、提交报名或发布需要相应权限及页面确认；资金、正式赛果由责任人办理。</p></details>
          <p class="assistant-welcome-note">选一个方向，或直接说说你的安排。已有任务可从记录继续。</p>
        </section>
        <article v-for="entry in current?.messages || []" :key="entry.id" class="agent-message" :class="entry.role"><small>{{ entry.role === 'user' ? '你' : '体育助手' }}</small><p v-if="entry.role === 'user'">{{ entry.content }}</p><AssistantMarkdown v-else :text="entry.content" />
          <template v-for="(block, index) in parseBlocks(entry.blocks)" :key="index">
            <section v-if="block.kind === 'guidance'" class="agent-guidance"><strong>{{ block.title }}</strong><p>{{ block.summary }}</p></section>
            <section v-else-if="block.kind === 'question'" class="agent-question"><strong>{{ block.label }}</strong><p v-if="block.hint">{{ block.hint }}</p><div><button v-for="option in block.options || []" :key="option" type="button" :disabled="busy || !canContinue" :aria-pressed="hasAssistantAnswer(message, option)" @click="prefill(option)">{{ option }}</button></div><small class="agent-choice-hint">可选多项，点已选项可取消；在输入框核对后发送。</small></section>
            <section v-else-if="block.kind === 'checklist'" class="agent-checklist"><strong>{{ block.title }}</strong><div v-for="(item, n) in block.items || []" :key="n"><span :class="item.state">{{ item.state === 'done' ? '✓' : item.state === 'pending' ? '◷' : '○' }}</span><p>{{ item.label }}</p></div></section>
            <router-link v-else-if="block.kind === 'navigation' && safePath(block.path)" class="agent-navigation" :to="block.path!" @click="visible = false">{{ block.label }}<span>→</span></router-link>
            <section v-else-if="block.kind === 'confirmation'" class="agent-confirm"><div class="agent-card-caption">等待你确认</div><strong>{{ block.title }}</strong><ConfirmationSummary :value="block.preview" /><div v-if="current?.status === 'waiting_confirmation'" class="agent-card-actions"><button class="agent-primary" :disabled="busy" @click="confirm(entry.id, true)">{{ busy ? '办理中' : '核对无误，确认' }}</button><button :disabled="busy" @click="confirm(entry.id, false)">修改内容</button></div></section>
            <section v-else-if="block.kind === 'receipt'" class="agent-receipt"><span>✓</span><div><strong>{{ block.receipt?.status === 'succeeded' ? '这一步已办好' : '办理状态已更新' }}</strong><small>回执 {{ block.receipt?.receiptId }}</small></div></section>
            <section v-else-if="block.kind === 'material'" class="agent-material"><strong>{{ block.name }}</strong><p>{{ block.coverage }}</p><small v-if="block.locations?.length">{{ block.locations.slice(0, 6).join(' · ') }}</small></section>
          </template>
        </article>
        <AssistantProgress v-if="current" :steps="current.steps || []" :active="['running','waiting_children'].includes(current.status)" :connection="progressConnection" />
        <button v-for="child in current?.children || []" :key="child.id" class="agent-child" :disabled="busy" @click="select(child.id)"><span>{{ child.goal }}</span><small>{{ statusLabels[child.status] || '处理中' }} →</small></button>
        <details v-if="current" class="assistant-scope-help assistant-inline-features"><summary>看看还能帮我做什么</summary><div class="assistant-feature-grid"><button v-for="choice in starterTasks" :key="choice.label" type="button" class="assistant-feature-card" :data-testid="choice.testId" :disabled="busy || !canContinue" @click="chooseGuide(choice.label)"><span class="assistant-feature-icon" aria-hidden="true"><img :src="'/images/sports/assistant/'+choice.art+'.webp'" alt="" draggable="false" /></span><span class="assistant-feature-copy"><strong>{{ choice.label }}</strong><small>{{ choice.description }}</small><span class="assistant-feature-status">{{ choice.status }}</span></span><span aria-hidden="true">↗</span></button></div><p class="assistant-welcome-note">选一个方向，再说说你的安排。想从头开始，可以点“新任务”。</p></details>
      </div>
      <form class="agent-composer" @submit.prevent="send"><div v-if="guidance.length" class="assistant-guidance-topics"><div v-for="topic in guidance" :key="topic" class="assistant-guidance-chip"><span>{{ topic }}</span><button type="button" :aria-label="'取消 ' + topic" @click="guidance=toggleAssistantTopic(guidance,topic)">×</button></div></div>
        <div class="agent-compose-context"><span>{{ current ? statusLabels[current.status] : '新任务' }}</span><button v-if="current" type="button" :disabled="busy" @click="newConversation">新任务</button><button v-if="['running','waiting_children'].includes(current?.status || '')" type="button" :disabled="busy" @click="stop">停止</button></div>
        <div v-if="attachments.length" class="agent-attachments"><div v-for="(file,index) in attachments" :key="index"><span :title="file.name">{{ file.name }}</span><small class="assistant-file-size">{{ formatAssistantFileSize(file.size) }}</small><button type="button" :disabled="busy" :aria-label="'移除 ' + file.name" @click="attachments.splice(index, 1);fileNotice=''">×</button></div></div>
        <p v-if="fileNotice" class="assistant-file-notice" :class="{error:fileNoticeError}" :role="fileNoticeError?'alert':'status'">{{ fileNotice }}</p>
        <div class="agent-input-box"><textarea ref="composer" v-model="message" rows="2" maxlength="10000" :disabled="busy || !canContinue" placeholder="告诉我你想做什么，或补充刚才的问题…" aria-label="发给体育助手的消息" @keydown="composerKey" /><div class="agent-input-actions"><button type="button" class="agent-attach" :disabled="!!uploadBlockedReason" aria-label="上传体育助手资料" :title="uploadBlockedReason || '可将文档拖入窗口，或点此选择'" @click="filePicker?.click()">＋<span>资料</span></button><button class="agent-submit" :disabled="busy || !canContinue || !message.trim()" aria-label="发送任务">{{ busy ? '…' : '↑' }}</button></div></div>
        <input ref="filePicker" type="file" hidden multiple :accept="assistantFileAccept" @change="pickFiles" />
        <div class="agent-compose-note"><button type="button" :aria-expanded="fileHelp" @click="fileHelp = !fileHelp">拖入资料 / 文件要求</button><span>Enter 发送 · Shift + Enter 换行</span></div><p v-if="fileHelp" class="agent-file-help">可将 DOCX、XLSX、PDF、JPG、PNG、WebP 拖入窗口，或点＋选择。每次最多4份、合计20MB，单份15MB。PDF最多20页；长材料可以分批补充。</p>
      </form>
    </div>
    <AssistantFileDropOverlay v-if="fileDragging" :blocked-reason="uploadBlockedReason" description="每次最多4份，单份15MB、合计20MB。" />
  </AssistantWindow>
</template>
<script setup lang="ts">
import { computed, nextTick, onUnmounted, ref, watch } from 'vue';
import request from '@/utils/request';
import ConfirmationSummary from './ConfirmationSummary.vue';
import AssistantMarkdown from '@/components/shared/AssistantMarkdown.vue';
import AssistantProgress from '@/components/shared/AssistantProgress.vue';
import AssistantFileDropOverlay from '@/components/shared/AssistantFileDropOverlay.vue';
import { assistantFileAccept, formatAssistantFileSize, useAssistantFileDrop, validateAssistantFiles } from '@/hooks/useAssistantFileDrop';
import {followAssistantProgress,type VisibleStep,type ProgressConnection} from '@/utils/assistantProgress';
import AssistantWindow from './AssistantWindow.vue';
import { useRoute } from 'vue-router';
import { useUserStore } from '@/store/modules/user';
import { hasAssistantAnswer, toggleAssistantAnswer, toggleAssistantTopic } from '@/utils/assistantAnswers';
import '@/assets/styles/sports-assistant.scss';
import '@/assets/styles/sports-agent.scss';
const visible = defineModel<boolean>({ default: false });
interface Block { kind: string; title?: string; summary?: string; label?: string; hint?: string; options?: string[]; items?: {label: string; state: string}[]; path?: string; name?: string; coverage?: string; locations?: string[]; preview?: unknown; receipt?: {receiptId: string; status: string} }
interface Run { id: string; status: string; stopReason?: string; steps: VisibleStep[]; messages: {id: string; role: string; content: string; blocks: string}[]; children: {id: string; goal: string; status: string}[] }
const guidance=ref<string[]>([]);
const current = ref<Run>(), history = ref<{id: string; goal: string; status: string}[]>([]), message = ref(''), busy = ref(false), error = ref('');
const errorRetryable = ref(true);
const historyOpen = ref(false), fileHelp = ref(false), thread = ref<HTMLElement>(), composer = ref<HTMLTextAreaElement>(), filePicker = ref<HTMLInputElement>(), attachments = ref<File[]>([]);
const route = useRoute(), user = useUserStore();
const historyKey = computed(() => `sports-agent-run:${user.userId || 'participant'}:${user.tenantId || 'platform'}`);
const canContinue = computed(() => !current.value || !['running','waiting_children','waiting_confirmation','stopped','completed'].includes(current.value.status));
const fileNotice=ref(''),fileNoticeError=ref(false);
const uploadBlockedReason=computed(()=>{
  if(!user.token)return '请先登录后上传材料。';
  if(busy.value||['running','waiting_children'].includes(current.value?.status||''))return '任务正在处理中，请稍候再添加资料。';
  if(current.value?.status==='waiting_confirmation')return '请先核对上方确认卡，或选择修改内容。';
  if(!canContinue.value)return '当前任务已结束，请点新任务后添加资料。';
  return '';
});
function fileFeedback(value:string,isError=true){fileNotice.value=value;fileNoticeError.value=isError;}
function addFiles(files:File[]){
  if(uploadBlockedReason.value){fileFeedback(uploadBlockedReason.value);return;}
  const result=validateAssistantFiles(attachments.value,files,{maxFiles:4,maxFileBytes:15*1024*1024,maxTotalBytes:20*1024*1024});
  if(result.error){fileFeedback(result.error);return;}
  attachments.value=result.files;fileFeedback('资料已加入待发送列表，请补充目标后点击发送。',false);
}
const {dragging:fileDragging,handlers:fileDropHandlers,reset:resetFileDrop}=useAssistantFileDrop({blockedReason:()=>uploadBlockedReason.value,addFiles,feedback:fileFeedback});
watch(()=>attachments.value.length,count=>{if(!count){fileNotice.value='';fileNoticeError.value=false;}});
// Topic cards leave the user-owned composer intact and never execute a task.
const starterTasks = computed(() => [
  {label:'找到合适的比赛',description:'按运动、时间和地点整理选择',status:'公开赛事',art:'assistant-events',testId:'agent-feature-events'},
  {label:'看懂赛事规程',description:'资格、人数、费用和重要时间',status:'当前赛事或上传规程',art:'assistant-rules',testId:'agent-feature-rules'},
  {label:'继续我的报名',description:'看看当前进度和还差哪一步',status:'我的报名',art:'assistant-rules',testId:'agent-feature-registration'},
  {label:'组队或找搭档',description:'已有房间、队友和补员准备',status:'我的房间',art:'assistant-team',testId:'agent-feature-room'},
  {label:'查看积分与称号',description:'成长记录、当前段位和下一目标',status:'运动成长',art:'assistant-events',testId:'agent-feature-growth'},
  {label:route.path.startsWith('/org-desk')?'整理当前赛事材料':'第一次办赛怎么准备',description:'规程、策划、脚本、公告和宣传稿',status:'主办方赛事工作台',art:'assistant-rules',testId:'agent-feature-materials'}
]);
const statusLabels: Record<string,string> = {running:'正在办理',waiting_children:'等待职能助手返回',waiting_input:'等你补充',waiting_confirmation:'等待确认',failed:'进度已保留',stopped:'已停止',completed:'已完成'};
const failures: Record<string,string> = {KEY_ABSENT:'暂时无法继续，目标和资料已保存。',MODEL_TIMEOUT:'这次处理超时，进度已保留。补充一句即可继续。',GATEWAY_UNAVAILABLE:'连接暂时中断，进度已保留。',TOOL_LIMIT:'这次处理较多，分一步继续会更清楚。',BUSY:'正在处理其他任务，请稍后继续。',AUTH_REVOKED:'当前授权已变化，请重新核对可办理范围。',BUDGET_LIMIT:'本次任务已达到用量上限，办理记录已保留。',MATERIAL_LIMIT:'资料识别内容过大，请拆分后补充。'};
let revision=0,selection=0,followLatest=true;
const progressConnection=ref<ProgressConnection>('connecting');
let disconnectProgress:(()=>void)|undefined;
watch(()=>[visible.value,current.value?.id,current.value?.status,user.token].join(':'),()=>{disconnectProgress?.();disconnectProgress=undefined;const id=current.value?.id,stamp=revision;if(visible.value&&id)disconnectProgress=followAssistantProgress<Run>(`/sports/agents/runs/${id}/stream`,snapshot=>{if(stamp!==revision||current.value?.id!==id)return;current.value=snapshot;error.value=snapshot.stopReason?failures[snapshot.stopReason]||'这一步未能完成，进度已保留。':'';if(!['running','waiting_children'].includes(snapshot.status))disconnectProgress?.();scrollLatest();},state=>{progressConnection.value=state;});});
function parseBlocks(value: string): Block[] { try { const data=typeof value==='string'?JSON.parse(value):value;return Array.isArray(data)?data:[]; } catch { return []; } }
function safePath(value?: string) { return !!value && /^\/(portal|public|org-desk|organization-review|government|sports-platform)(\/|\?|$)/.test(value) && !/[\\\u0000-\u001f]/.test(value) && !value.startsWith('//'); }
function trackScroll() { if (thread.value) followLatest=thread.value.scrollHeight-thread.value.scrollTop-thread.value.clientHeight<90; }
async function scrollLatest(force=false) { await nextTick();if(force||followLatest)thread.value?.scrollTo({top:thread.value.scrollHeight,behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'}); }
function pageContext() { const context:Record<string,string>={};const hints=[{key:'eventId',value:route.params.eventKey||route.params.eventId||route.query.eventId},{key:'roomId',value:route.path.startsWith('/portal/rooms/')?route.params.id:route.query.room},{key:'registrationId',value:route.params.registrationId||(route.path.includes('/registration/detail/')?route.params.id:route.query.registrationId)}];for(const hint of hints)if(typeof hint.value==='string'&&/^[1-9]\d{0,18}$/.test(hint.value))context[hint.key]=hint.value;return context; }
function pickFiles(event:Event) {const input=event.target as HTMLInputElement,files=Array.from(input.files||[]);input.value='';if(files.length)addFiles(files);}
async function resolveError() { error.value=''; if (errorRetryable.value) { if (current.value) await select(current.value.id); await load(); } }
async function chooseGuide(label:string) { if(!canContinue.value||busy.value)return;guidance.value=toggleAssistantTopic(guidance.value,label);await nextTick();composer.value?.focus(); }
// A visible answer option from the current task is an explicit user selection.
async function prefill(answer:string) { if(!canContinue.value||busy.value)return;guidance.value=[];message.value=toggleAssistantAnswer(message.value,answer);await nextTick();composer.value?.focus(); }
async function select(id:string) { errorRetryable.value=true;const requestRevision=revision,requestSelection=++selection;try{const result=(await request<Run>({url:`/sports/agents/runs/${id}`})).data;if(revision!==requestRevision||selection!==requestSelection)return;current.value=result;sessionStorage.setItem(historyKey.value,id);error.value=result.stopReason?failures[result.stopReason]||'这一步未能完成，进度已保留。':'';await scrollLatest();}catch{if(revision===requestRevision)error.value='暂时无法读取进度，请重新连接。';} }
async function load() { errorRetryable.value=true;const requestRevision=revision;try{const result=(await request<{id:string;goal:string;status:string}[]>({url:'/sports/agents/runs'})).data;if(revision!==requestRevision)return;history.value=result;const last=sessionStorage.getItem(historyKey.value);if(last&&!current.value&&result.some(r=>r.id===last))await select(last);}catch{if(revision===requestRevision)error.value='任务记录暂时无法读取，请重新连接。';} }
async function send() { if(busy.value||!message.value.trim()||!canContinue.value)return;busy.value=true;error.value='';const requestRevision=revision;const submittedWords=guidance.value.length?guidance.value.join('、')+'：'+message.value.trim():message.value.trim();try{if(attachments.value.length){const data=new FormData();attachments.value.forEach(file=>data.append('files',file));data.append(current.value?'message':'goal',submittedWords);data.append('consent','true');data.append('context',JSON.stringify(pageContext()));const result=await request<{runId:string}>({url:current.value?`/sports/agents/runs/${current.value.id}/materials`:'/sports/agents/runs/materials',method:'post',data,timeout:120000,headers:{repeatSubmit:false}});if(revision!==requestRevision)return;if(!current.value)await select(result.data.runId);attachments.value=[];}else if(current.value)await request({url:`/sports/agents/runs/${current.value.id}/answer`,method:'post',data:{message:submittedWords}});else{const result=await request<{runId:string}>({url:'/sports/agents/runs',method:'post',data:{goal:submittedWords,consent:true,context:pageContext()}});if(revision!==requestRevision)return;await select(result.data.runId);}if(revision!==requestRevision)return;message.value='';guidance.value=[];if(current.value)await select(current.value.id);await scrollLatest(true);await load();}catch{if(revision===requestRevision)error.value='没有提交成功，文字和资料还在。请重试。';}finally{if(revision===requestRevision)busy.value=false;} }
async function confirm(messageId:string,accepted:boolean) { if(!current.value||busy.value)return;busy.value=true;error.value='';try{await request({url:`/sports/agents/runs/${current.value.id}/confirm`,method:'post',data:{messageId,accepted}});await select(current.value.id);await scrollLatest(true);}catch{error.value='这次确认没有成功，请核对进度后重试。';}finally{busy.value=false;} }
async function stop() { if(!current.value||busy.value)return;busy.value=true;try{await request({url:`/sports/agents/runs/${current.value.id}/stop`,method:'post'});await select(current.value.id);}catch{error.value='停止请求没有成功，请重新连接确认状态。';}finally{busy.value=false;} }
function newConversation() { if(busy.value)return;revision++;selection++;current.value=undefined;attachments.value=[];resetFileDrop();fileNotice.value='';message.value='';guidance.value=[];sessionStorage.removeItem(historyKey.value);error.value='';historyOpen.value=false;followLatest=true; }
function composerKey(event:KeyboardEvent) { if(event.key==='Enter'&&!event.shiftKey&&!event.isComposing&&event.keyCode!==229){event.preventDefault();send();} }
watch(()=>user.token,()=>{revision++;selection++;current.value=undefined;history.value=[];attachments.value=[];resetFileDrop();fileNotice.value='';message.value='';guidance.value=[];error.value='';busy.value=false;});
watch(visible,open=>{if(open)load();else{resetFileDrop();fileNotice.value='';}});
const timer=setInterval(()=>{if(progressConnection.value!=='live'&&visible.value&&!busy.value&&current.value&&['running','waiting_children'].includes(current.value.status))select(current.value.id);},5000);
onUnmounted(()=>{revision++;clearInterval(timer);disconnectProgress?.();});
</script>
