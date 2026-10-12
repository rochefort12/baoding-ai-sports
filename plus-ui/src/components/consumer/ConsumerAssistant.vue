<template>
  <div class="consumer-app c-ai-overlay">
    <AssistantWindow v-model="consumerAi.open" v-bind="fileDropHandlers" class="c-ai-overlay c-public-assistant">
      <template #heading><div class="c-assistant-title">
          <img class="c-ai-orb" src="/images/sports/assistant-orb-v2.webp" alt="" draggable="false" /><strong>体育助手<small>先找到你要做的事</small></strong>
        </div></template>
      <div class="c-ai-context">
        <ConsumerIcon name="pin" /><span>{{ pageLabel }}{{ eventId ? ' · 当前赛事' : '' }}</span>
      </div>
      <div ref="messagesPanel" class="c-ai-messages" style="min-height: 220px" aria-live="polite">
          <div v-if="!messages.length" class="c-ai-welcome">
            <img class="c-ai-welcome-orb" src="/images/sports/assistant-orb-v2.webp" alt="" draggable="false" />
            <h3>你好，想先做哪件事？</h3>
            <p>说说你的想法。我先找相关信息，缺什么再一起补。</p>
            <div v-if="!store.token" class="assistant-feature-grid" aria-label="参赛咨询功能">
              <button type="button" class="assistant-feature-card" data-testid="assistant-public-events" :disabled="busy" @click="command('找适合我的比赛')">
                <span class="assistant-feature-icon" aria-hidden="true"><img src="/images/sports/assistant/assistant-events.webp" alt="" draggable="false" /></span><span class="assistant-feature-copy"><strong>找适合我的比赛</strong><small>时间、地点和报名条件</small><span class="assistant-feature-status">公开赛事 · 无需登录</span></span><span aria-hidden="true">↗</span>
              </button>
              <button type="button" class="assistant-feature-card" data-testid="assistant-public-rules" :disabled="busy" @click="command('看懂赛事规程')">
                <span class="assistant-feature-icon" aria-hidden="true"><img src="/images/sports/assistant/assistant-rules.webp" alt="" draggable="false" /></span><span class="assistant-feature-copy"><strong>看懂赛事规程</strong><small>把资格、费用和截止时间讲清楚</small><span class="assistant-feature-status">{{ eventId ? '已带入当前赛事' : '先选一场公开赛事' }}</span></span><span aria-hidden="true">↗</span>
              </button>
              <button type="button" class="assistant-feature-card" data-testid="assistant-entry-preparation" :disabled="busy" @click="command('第一次参赛怎么准备')">
                <span class="assistant-feature-icon" aria-hidden="true"><img src="/images/sports/assistant/assistant-team.webp" alt="" draggable="false" /></span><span class="assistant-feature-copy"><strong>第一次参赛怎么准备</strong><small>参赛方式、搭档和准备事项</small><span class="assistant-feature-status">先聊需求 · 无需登录</span></span><span aria-hidden="true">↗</span>
              </button>
            </div>
            <details class="assistant-scope-help"><summary>我还能帮你做什么？</summary><p>登录后，体育助手还可以结合你的报名、房间和成长记录给建议。主办方可以从赛事工作台整理材料、策划、脚本和公告。</p><p>我会说明资料依据；报名提交、到账和发布以对应页面的实际办理结果为准。</p><router-link v-if="!store.token" to="/portal/login" @click="close">登录，继续我的参赛 →</router-link></details>
            <p class="assistant-welcome-note">也可以直接说说你的安排。</p>
          </div>
          <article v-for="(m, i) in messages" :key="i" class="c-ai-message" :class="{ user: m.user }">
            <span class="c-ai-message-label">{{ m.user ? '你' : '体育助手' }}</span>
            <p v-if="m.user">{{ m.text }}</p><AssistantMarkdown v-else :text="m.text" />
            <template v-if="m.sources?.length"
              ><p class="c-ai-source-label">本次回答参考的公开赛事 <small>报名入口在赛事详情</small></p>
              <router-link v-for="s in m.sources" :key="s.eventId" class="c-ai-source" style="display: block; min-height: 64px" :to="'/public/events/' + s.eventId"
                ><strong>{{ s.name }}</strong
                ><small
                  >{{ s.holdingStatus === 'cancelled' ? '已取消' : phaseLabel(s.phase) }} · {{ s.projectName || '运动赛事' }} ·
                  {{ s.location || '地点待公布' }}</small
                ><span>查看详情与原文 →</span></router-link
              >
            </template>
            <small v-if="m.hasMore">这次还有更多匹配的赛事，可以让我继续看。</small>
            <small v-if="m.refreshedAt" class="c-ai-scope"
              >更新于 {{ showTime(m.refreshedAt) }}</small
            >
          </article>
          <p v-if="busy" class="c-ai-thinking" role="status"><span class="assistant-loading-dots" aria-hidden="true"><i></i><i></i><i></i></span>正在核对赛事信息</p>
          <div v-if="error" class="notice danger" role="alert">{{ error }}<button class="btn text" @click="retryReply">重试回答</button></div>
      </div>
      <div v-if="messages.length && !store.token" class="c-ai-shortcuts" aria-label="继续咨询">
        <button type="button" :disabled="busy" @click="command('找适合我的比赛')">找比赛</button
        ><button type="button" :disabled="busy" @click="command('看懂赛事规程')">看懂规程</button
        ><button type="button" :disabled="busy" @click="command('第一次参赛怎么准备')">参赛准备</button>
      </div>
      <form v-if="consumerAi.mode === 'ask'" class="c-ai-form" @submit.prevent="send">
        <div v-if="guidance.length" class="assistant-guidance-topics"><div v-for="topic in guidance" :key="topic" class="assistant-guidance-chip"><span>{{ topic }}</span><button type="button" :aria-label="'取消 ' + topic" @click="guidance=toggleAssistantTopic(guidance,topic)">×</button></div></div>
        <div>
          <textarea
            ref="input"
            v-model="question"
            maxlength="2000"
            rows="2"
            aria-label="发给 AI 的消息"
            placeholder="说说你想做的事"
            :disabled="busy"
            @keydown="composerKey"
          /><button class="c-ai-send" type="submit" :disabled="busy || !question.trim()" aria-label="发送消息">
            <ConsumerIcon name="arrow" />
          </button>
        </div>
      </form>
      <p v-if="fileNotice" class="assistant-file-notice error" role="alert">{{ fileNotice }}<router-link v-if="!store.token" to="/portal/login" @click="close">登录后上传资料 →</router-link></p>
      <p class="c-ai-footnote">Enter 发送 · Shift + Enter 换行</p>
      <AssistantFileDropOverlay v-if="fileDragging" :blocked-reason="uploadBlockedReason" description="登录后的体育助手支持上传规程和材料。" />
    </AssistantWindow>
  </div>
</template>
<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue';
import AssistantMarkdown from '@/components/shared/AssistantMarkdown.vue';
import { useRoute } from 'vue-router';
import { askConsumerAi, PublicAiSource } from '@/api/sports/consumerAi';
import { phaseLabel, showTime } from '@/api/sports/event';
import { consumerAi } from '@/utils/consumerAi';
import { useUserStore } from '@/store/modules/user';
import ConsumerIcon from './ConsumerIcon.vue';
import AssistantWindow from './AssistantWindow.vue';
import { toggleAssistantTopic } from '@/utils/assistantAnswers';
import AssistantFileDropOverlay from '@/components/shared/AssistantFileDropOverlay.vue';
import { useAssistantFileDrop } from '@/hooks/useAssistantFileDrop';
const route = useRoute(),
  store = useUserStore();
const eventId = computed(() => {
  if (/^\/public\/events\/\d+$/.test(route.path)) return String(route.params.id);
  // 填写报名也可咨询对应公开规程；只传公开赛事编号，不传项目成员和已填资料。
  if (route.path === '/portal/registration/apply' && /^\d+$/.test(String(route.query.eventId || ''))) return String(route.query.eventId);
  return undefined;
});
const pageLabel = computed(() => String(route.meta.title || (route.path === '/portal/home' ? '发现' : '运动平台')));
const input = ref<HTMLTextAreaElement>(),
  messagesPanel = ref<HTMLElement>();
const question = ref(''),
  busy = ref(false),
  error = ref('');
const guidance=ref<string[]>([]);
const fileNotice=ref('');
const uploadBlockedReason=computed(()=>busy.value?'正在核对赛事信息，请稍候再处理资料。':store.token?'请使用登录后的体育助手任务窗口上传材料。':'登录后可上传规程和材料；当前公开咨询不接收文件。');
const {dragging:fileDragging,handlers:fileDropHandlers,reset:resetFileDrop}=useAssistantFileDrop({blockedReason:()=>uploadBlockedReason.value,addFiles:()=>{},feedback:value=>{fileNotice.value=value;}});
watch(()=>consumerAi.open,value=>{if(!value){resetFileDrop();fileNotice.value='';}});
const messages = ref<{ user: boolean; text: string; sources?: PublicAiSource[]; hasMore?: boolean; refreshedAt?: string }[]>([]);
let seq = 0,
  returnFocus: HTMLElement | null = null;
const close = () => {
  consumerAi.open = false;
  returnFocus?.focus();
};
const reset = () => {
  seq++;
  busy.value = false;
  messages.value = [];
  error.value = '';
  question.value = '';
  guidance.value = [];
  resetFileDrop();fileNotice.value='';
  failedMessage.value = '';
};
watch(eventId, reset);
watch(() => store.token, reset);
watch(
  () => consumerAi.revision,
  async () => {
    if (!consumerAi.open) return;
    returnFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    if (busy.value) return;
    if (consumerAi.prompt.trim()) {
      const topic = /规程|资格|费用/.test(consumerAi.prompt) ? '看懂赛事规程' : /报名/.test(consumerAi.prompt) ? '查看报名进度' : '继续参赛咨询';
      if (!guidance.value.includes(topic)) guidance.value.push(topic);
    }
    error.value = '';
    await nextTick();
    await scrollMessages();
    if (input.value) input.value.focus();
    // A guide selects a topic; the composer always belongs to the user's own words.
  }
);
const command = async (label: string) => {
  if (busy.value) return;
  guidance.value=toggleAssistantTopic(guidance.value,label);
  await nextTick();input.value?.focus();
};
// 先显示用户消息；失败重试保留同一条消息，不重复写入历史。
const failedMessage = ref('');
const send = async () => {
  const draft=question.value.trim();if(!draft||busy.value)return;
  const succeeded=await submitMessage(guidance.value.length ? guidance.value.join('、')+'：'+draft : draft);
  if(succeeded&&question.value.trim()===draft){question.value='';guidance.value=[];}
};
const retryReply = async () => {
  const draft=question.value.trim(),failed=failedMessage.value;
  const draftMessage=guidance.value.length?guidance.value.join('、')+'：'+draft:draft;
  const succeeded=await submitMessage(failed,true);
  // Retry the failed request without erasing a newer user-authored draft.
  if(succeeded&&draftMessage===failed&&question.value.trim()===draft){question.value='';guidance.value=[];}
};
const submitMessage = async (message: string, retry = false) => {
  if (busy.value || !message) return;
  const requestSeq = ++seq, selectedEvent = eventId.value;
  const prior = retry ? messages.value.slice(0, -1) : messages.value;
  const history = prior.slice(-8).map(item => ({user: item.user, text: item.text.slice(0, 2000)}));
  if (!retry) messages.value.push({user: true, text: message});
  error.value = ''; busy.value = true;
  await scrollMessages();
  try {
    const result = await askConsumerAi({eventId: selectedEvent, message, consent: true, ...(history.length ? {history} : {})});
    if (requestSeq !== seq) return;
    messages.value.push({user: false, text: result.data.reply, sources: result.data.sources, hasMore: result.data.hasMore, refreshedAt: result.data.refreshedAt});
    failedMessage.value = '';
    await scrollMessages();
    return true;
  } catch (cause) {
    if (requestSeq === seq) {
      failedMessage.value = message;
      error.value = cause instanceof Error ? cause.message : '回答暂时不可用，请重试或直接查看赛事。';
    }
  } finally { if (requestSeq === seq) busy.value = false; }
};
const scrollMessages = async () => {
  await nextTick();
  messagesPanel.value?.scrollTo({top: messagesPanel.value.scrollHeight, behavior: 'smooth'});
};
const composerKey = (e: KeyboardEvent) => {
  if (e.key === 'Enter' && !e.shiftKey && !e.isComposing && e.keyCode !== 229) { e.preventDefault(); send(); }
};
onBeforeUnmount(() => {
  seq++;
  consumerAi.open = false;
});
</script>
<style lang="scss">
@use '@/assets/styles/sports-assistant.scss';
</style>
