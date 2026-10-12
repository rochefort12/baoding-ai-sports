<template>
  <AssistantBubble :open="open" @toggle="toggleLauncher" />
  <section ref="assistantWindow" v-show="open" v-bind="fileDropHandlers" class="b-ai-window" :class="{ expanded, 'reviewing-draft': task && draftVisible }" :style="windowStyle" role="dialog" aria-label="AI运营助手">
    <header class="b-ai-header" tabindex="0" aria-label="拖动聊天窗口，方向键移动" @pointerdown="dragWindow" @keydown="moveByKeyboard">
      <div class="assistant-header-brand"><img src="/images/sports/assistant-orb-v2.webp" alt="" draggable="false" /><div><strong>赛事助手</strong><small>{{busy ? '正在核对任务' : '办赛与赛事管理'}}</small></div></div>
      <div>
        <button type="button" class="b-ai-history" aria-label="历史会话" title="历史会话" :aria-expanded="historyOpen" @pointerdown.stop @click.stop="historyOpen = !historyOpen">
          <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8" fill="none" stroke="currentColor" stroke-width="1.6" /><path d="M12 8v5l3 2" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" /></svg>
        </button
        ><el-button text class="b-ai-new" aria-label="新会话" @click="startFresh">新会话</el-button
        ><el-button text :aria-label="expanded ? '还原聊天窗口' : '放大聊天窗口'" @click="expanded = !expanded">{{ expanded ? '⤡' : '⤢' }}</el-button
        ><el-button text aria-label="关闭聊天窗口" @click="close">×</el-button>
      </div>
    </header>
    <div v-if="historyOpen" class="b-ai-history-pop" @pointerdown.stop @click.stop>
      <p v-if="!recentTasks.length && !opsSessions.length && !genericHistory.length">还没有可恢复的会话。</p>
      <button v-for="item in genericHistory" :key="'agent-'+item.id" type="button" :disabled="busy||genericRunning" @click="resumeGeneric(item.id)">{{item.goal}}</button>
      <div v-for="item in recentTasks" :key="item.id" class="b-ai-history-row">
        <button type="button" :disabled="busy" @click="resumeTask(item.id)">继续：{{ item.label }}</button>
        <button type="button" :disabled="busy" @click="deleteRecentDraft(item)">删除</button>
      </div>
      <button v-for="item in opsSessions" :key="item.sessionId" type="button" :disabled="busy" @click="resumeOps(item.sessionId)">问答：{{ item.preview }}</button>
    </div>
    <div class="b-ai-context" :title="workspaceLabel">
      <span>{{ workspaceLabel }}</span><small>{{ route.query.task ? taskLabel : '工作空间' }}</small>
    </div>
    <div class="b-ai-body">
    <div ref="thread" class="b-ai-messages" @scroll="trackScroll" @wheel.passive="noteReadingInteraction" @touchstart.passive="noteReadingInteraction" @pointerdown="noteReadingInteraction" @keydown.capture="noteReadingKey">
      <div v-if="!turns.length && !task" class="b-ai-message">
        <b>今天先处理哪件事？</b>
        <p>上传规程准备赛事，或继续当前赛事的待办。</p>
      </div>
      <template v-for="item in conversationItems" :key="item.key">
      <div v-if="item.kind === 'message'" class="b-ai-message" :class="{ user: item.turn.user }">
        <p v-if="item.turn.user">{{ item.turn.text }}</p><AssistantMarkdown v-else :text="item.turn.text" />
        <AssistantBlocks v-if="item.turn.blocks" :blocks="item.turn.blocks" :busy="busy||genericRunning" :answer-disabled="genericAwaitingConfirmation" :answer-draft="input" :waiting-confirmation="genericRun?.status==='waiting_confirmation'" @answer="chooseAnswer" @confirm="confirmGeneric(item.turn.agentMessageId!,$event)" />
        <small v-if="item.turn.source">{{ item.turn.source }}</small>
        <div v-if="!item.turn.user" class="b-ai-feedback">
          <button type="button" aria-label="复制这条回复" title="复制" @click="copy(item.turn.text)">
            <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="9" y="9" width="11" height="11" rx="1.5" fill="none" stroke="currentColor" stroke-width="1.6" /><path d="M6 15H5.5A1.5 1.5 0 0 1 4 13.5v-8A1.5 1.5 0 0 1 5.5 4h8A1.5 1.5 0 0 1 15 5.5V6" fill="none" stroke="currentColor" stroke-width="1.6" /></svg>
          </button>
          <span class="b-ai-feedback-split" aria-hidden="true"></span>
          <button type="button" :aria-pressed="item.turn.feedback === 'up'" aria-label="有帮助" title="谢谢，很高兴这句有用" @click="feedback(item.turn, 'up')">
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 10v9H5.5A1.5 1.5 0 0 1 4 17.5v-6A1.5 1.5 0 0 1 5.5 10H8zm0 0 3.2-5.2A1.8 1.8 0 0 1 14.6 6L14 10h4.2a1.8 1.8 0 0 1 1.8 2.1l-.8 6A1.8 1.8 0 0 1 17.4 20H8" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" /></svg>
          </button>
          <button type="button" :aria-pressed="item.turn.feedback === 'down'" aria-label="没帮助" title="收到，下一句我会尽量说得更清楚" @click="feedback(item.turn, 'down')">
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 14V5h-2.5A1.5 1.5 0 0 0 4 6.5v6A1.5 1.5 0 0 0 5.5 14H8zm0 0 3.2 5.2A1.8 1.8 0 0 0 14.6 18L14 14h4.2a1.8 1.8 0 0 0 1.8-2.1l-.8-6A1.8 1.8 0 0 0 17.4 4H8" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" /></svg>
          </button>
        </div>
      </div>
      <template v-else-if="task">
      <section class="b-ai-draft-actions" :data-task-id="task.id" aria-label="这份办赛草稿的操作">
        <div class="b-ai-draft-actions-title"><strong>{{ draftActionTitle }}</strong><span>{{ draftActionStatus }}</span></div>
        <p>{{ draftPublishedState ? '赛事已发布，可以进入管理赛事继续处理报名和安排。' : task.status === 'CREATED' ? '这份草稿已建立赛事，可以继续在聊天或下方表单修改；发布时在这里核对。' : task.proposal ? '资料已填入下方表单，缺少的信息可以直接补充。' : '正在读取资料，识别完成后将在这里显示办赛表单。' }}</p>
        <AssistantActionRail class="b-ai-draft-action-buttons" label="这份草稿的操作">
          <button type="button" class="primary" :disabled="!task.proposal || draftActionsLocked" :aria-expanded="draftVisible" @click="openOrganizerDraft(task.id)">查看表单</button>
          <button v-if="task.status === 'PENDING_CONFIRMATION'" type="button" class="primary" :disabled="!task.proposal || draftActionsLocked" @click="focusCandidateCreation">创建赛事</button>
          <button v-if="task.status === 'CREATED' && task.resultObjectId" type="button" class="primary" :disabled="draftActionsLocked || draftPublishedState" @click="openDraftPublication(task.resultObjectId)">{{ draftPublishedState ? '已发布' : '发布赛事' }}</button>
          <button v-if="task.status === 'CREATED' && task.resultObjectId" type="button" :disabled="draftActionsLocked" @click="openCreatedEvent(task.resultObjectId)">管理赛事</button>
          <button v-if="!draftPublishedState" type="button" :disabled="draftActionsLocked" @click="deleteOrganizerDraft(task.id)">删除草稿</button>
        </AssistantActionRail>
        <small>{{ task.status === 'CREATED' && task.resultObjectId ? '赛事编号：' + task.resultObjectId + (draftPublishedState ? ' · 已发布，可进入管理赛事查看报名和安排。' : ' · 待发布，请核对赛事设置后确认发布。') : '保存保留候选内容，点击表单中的“创建赛事”后才会生成赛事。' }}</small>
        <AssistantActionRail v-if="draftEditable && visibleDraftSuggestions.length" class="b-ai-choices" label="可以选择的回复">
          <button v-for="option in visibleDraftSuggestions" :key="option" type="button" :disabled="draftActionsLocked" :aria-pressed="hasAssistantAnswer(input,option)" @click="chooseAnswer(option)">{{ option }}</button>
        </AssistantActionRail>
      </section>
      <AiCandidateForm v-if="draftEditable && task.proposal" v-show="!publishVisible" :ref="setCandidateForm" :task="task" :disabled="draftActionsLocked" :declaration-ack-required="declarationAckRequired" @saved="candidateSaved" @refreshed="candidateRefreshed" @create="createEditedEvent" />
      <AssistantPublishCard v-if="publishVisible && publishEventId && task.resultObjectId===publishEventId" :ref="setPublicationCard" :event-id="publishEventId" :task-id="task.id" :task-version="task.version" :active="open" :disabled="busy || genericRunning || genericAwaitingConfirmation" :before-confirm="beforePublicationConfirmation" @revise="revisePublication" @busy="publicationBusy=$event" @published="draftPublished" />
      </template>
      </template>
      <form v-if="editor" class="b-ai-component b-ai-settings" @submit.prevent="saveSettings">
        <h3>修改赛事设置</h3>
        <p>{{ editor.name }} · 保存前请核对</p>
        <el-form label-position="top"
          ><el-form-item label="赛事名称"><el-input v-model="editForm.name" maxlength="200" /></el-form-item
          ><el-form-item label="比赛地点"><el-input v-model="editForm.location" maxlength="200" /></el-form-item
          ><el-form-item label="报名开始"
            ><el-date-picker v-model="editForm.registrationOpensAt" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" /></el-form-item
          ><el-form-item label="报名截止"
            ><el-date-picker v-model="editForm.registrationClosesAt" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" /></el-form-item
          ><el-form-item label="开赛时间"
            ><el-date-picker v-model="editForm.startsAt" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" /></el-form-item
          ><el-form-item label="结束时间"
            ><el-date-picker v-model="editForm.endsAt" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" /></el-form-item
        ></el-form>
        <p class="b-muted">项目费用、收款、资格和发布仍按既有任务办理。</p>
        <el-button type="primary" native-type="submit" :loading="saving">保存赛事设置</el-button
        ><el-button @click="editor = undefined">收起</el-button>
      </form>
      <PromotionBoard v-if="mode === 'promote' && promoteId" :event-id="promoteId" />
      <iframe v-if="chart" class="b-ai-sandbox" sandbox="" :srcdoc="chart" title="报名趋势" />
      <div v-if="task?.status==='FAILED'" class="b-ai-message" role="alert"><p>{{task.errorMessage||'资料识别未完成，处理记录已保留。'}}</p><el-button :disabled="busy" @click="retryTask">重试识别</el-button></div>
      <AssistantProgress v-if="genericRun" :class="{'b-ai-progress-completed': !genericRunning && !genericAwaitingConfirmation && !hasProgressIssue(genericRun.steps)}" :steps="genericRun.steps" :active="genericRunning" :connection="genericConnection" />
      <AssistantProgress v-else-if="task" :class="{'b-ai-progress-completed': !['UPLOADED','PROCESSING','FAILED'].includes(task.status) && !hasProgressIssue(taskProgress)}" :steps="taskProgress" :active="['UPLOADED','PROCESSING'].includes(task.status)" :connection="progressConnection" />
      <button v-if="genericRunning" type="button" class="b-ai-stop" @click="stopGeneric">停止当前处理</button>
      <div v-else-if="busy" class="b-ai-message" role="status">已发送请求，正在读取当前组织数据并整理回答…</div>
    </div>

    </div>
    <details class="b-ai-tools" :open="!task && !turns.length"><summary>更多操作</summary>
    <AssistantActionRail class="b-ai-shortcuts" label="快捷操作">
      <button class="highlight" @click="command('AI办赛')">准备赛事</button><button @click="command('运营分析')">查看运营</button
      ><button @click="command('修改设置')">修改设置</button><button @click="command('报名趋势')">数据组件</button
      ><button @click="command('推广文案')">推广文案</button>
    </AssistantActionRail>
    </details>
    <div v-if="attachments.length" class="b-ai-attachments">
      <p>已选 {{ attachments.length }} 份，合计 {{ attachmentSizeLabel }}</p>
      <div class="b-ai-attachment-list">
        <span v-for="(file, index) in attachments" :key="file.name + index">
          <em :title="file.name">{{ file.name }}</em><small class="assistant-file-size">{{ formatAssistantFileSize(file.size) }}</small>
          <button type="button" :disabled="draftActionsLocked" :aria-label="'移除 ' + file.name" @click="attachments.splice(index, 1);fileNotice=''">×</button>
        </span>
      </div>
    </div>
    <p v-if="fileNotice" class="assistant-file-notice" :class="{error:fileNoticeError}" :role="fileNoticeError?'alert':'status'">{{ fileNotice }}</p>
    <form class="b-ai-composer" @submit.prevent="send">
      <input ref="filePicker" type="file" hidden multiple :accept="assistantFileAccept" @change="pickFiles" />
      <el-tooltip :content="uploadHint" placement="top" :show-after="300">
        <span class="b-ai-upload-wrap">
          <button type="button" class="b-ai-upload" :disabled="uploadLocked" aria-label="上传办赛资料" @click="filePicker?.click()">＋</button>
        </span>
      </el-tooltip>
      <textarea ref="composer" v-model="input" maxlength="20000" rows="2" placeholder="继续补充，或问赛事相关问题…" aria-label="发送给AI的消息" @keydown="composerKey" /><el-button
        class="b-ai-button"
        native-type="submit"
        :disabled="busy || publicationBusy || genericRunning || genericAwaitingConfirmation || (!input.trim() && !attachments.length) || !consent"
        >发送 ↑</el-button
      >
    </form>
    <p v-if="genericAwaitingConfirmation" class="b-ai-upload-note">请先核对上方确认卡，或点“修改内容”继续补充。</p>
    <details class="b-ai-retention"><summary>资料与会话说明</summary><p>{{ holdText }}</p><p v-if="task && task.status === 'PENDING_CONFIRMATION'">可以继续上传资料或补充要求；“查看表单”可核对全部字段和原文。</p></details>
    <AssistantFileDropOverlay v-if="fileDragging" :blocked-reason="uploadBlockedReason" :description="uploadDescription" />
  </section>
  <AiDraftDialog v-if="task" ref="draftDialog" v-model="draftVisible" :task="task" :read-only="!draftEditable" :declaration-ack-required="declarationAckRequired" @saved="candidateSaved" @create="createEditedEvent" />
</template>
<script setup lang="ts">
import AiDraftDialog from './AiDraftDialog.vue';
import AiCandidateForm from './AiCandidateForm.vue';
import AssistantPublishCard from './AssistantPublishCard.vue';
import request from '@/utils/request';
import { newRequestKey } from '@/utils/requestKey';
import { computed, nextTick, onMounted, onUnmounted, reactive, ref, watch } from 'vue';
import AssistantActionRail from '@/components/shared/AssistantActionRail.vue';
import { useRoute, useRouter } from 'vue-router';
import { ElMessage, ElMessageBox } from 'element-plus';
import AssistantMarkdown from '@/components/shared/AssistantMarkdown.vue';
import AssistantProgress from '@/components/shared/AssistantProgress.vue';
import AssistantBlocks from '@/components/shared/AssistantBlocks.vue';
import AssistantFileDropOverlay from '@/components/shared/AssistantFileDropOverlay.vue';
import { assistantFileAccept, formatAssistantFileSize, useAssistantFileDrop, validateAssistantFiles } from '@/hooks/useAssistantFileDrop';
import AssistantBubble from '@/components/consumer/AssistantBubble.vue';
import {followAssistantProgress,type VisibleStep,type ProgressConnection} from '@/utils/assistantProgress';
import PromotionBoard from '@/components/business/PromotionBoard.vue';
import { resolveAssistantIntent, appendAiTaskMaterials, startTextAiTask, uploadAiTask, getAiTask, talkAiTask, retryAiTask, abandonAiTask, listOpsChats, readOpsChat, deleteOpsChat, type AiTaskCard } from '@/api/sports/aiTask';
import { businessPickerTime } from '@/utils/business';
import { withoutStructuredNextStep } from '@/utils/assistantReadiness';
import { hasAssistantAnswer, toggleAssistantAnswer } from '@/utils/assistantAnswers';
import { createdProposalState, publicationMessageIntent } from '@/utils/assistantPublication';
import { useUserStore } from '@/store/modules/user';
import { getOperationsSummary, type DeskContext } from '@/api/sports/desk';
import { getManagedEvent, updateEvent, deleteEventDraft, type EventCard, type EventDraft } from '@/api/sports/event';
const props = defineProps<{ context: DeskContext; event?: EventCard }>(),
  emit = defineEmits<{ saved: [] }>();
const router = useRouter();
const route = useRoute(),
  open = ref(false),
  expanded = ref(false),
  historyOpen = ref(false),
  mode = ref(''),
  promoteId = ref(''),
  input = ref(''),
  busy = ref(false),
  saving = ref(false),
  consent = ref(true),
  thread = ref<HTMLElement>();
// 页面对象加载期间也绑定路由中的目标；归属和可见性由服务端重新验证。
const selectedEventId = computed(() => /^\/org-desk\/workspace\/\d+$/.test(route.path) ? String(route.params.eventId) : undefined);
type ChatTurn = { text: string; user?: boolean; source?: string; copy?: boolean; feedback?: 'up' | 'down'; blocks?: string; agentMessageId?: string; draftTaskId?: string };
const workspaceLabel = computed(() => `${props.context.organizationName} · ${props.event?.name || route.meta.title || '运营概览'}`);
const turns = ref<ChatTurn[]>([]),
  chart = ref(''),
  editor = ref<EventCard>(),
  editForm = reactive({} as EventDraft);
let editRoute = '',
  generation = 0,
  commandSequence = 0,
  previousFocus: HTMLElement | undefined;
// 只保留当前账号/组织的任务编号；原文、对话、材料与授权始终从服务端读取。
const taskStorageKey = 'business-ai-task:' + useUserStore().userId + ':' + props.context.organizationId;
const recentStorageKey = 'business-ai-recent:' + useUserStore().userId + ':' + props.context.organizationId;
type RecentTask = { id: string; label: string };
const readRecent = (): RecentTask[] => {
  try {
    const parsed = JSON.parse(sessionStorage.getItem(recentStorageKey) || '[]');
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((item) => item && typeof item.id === 'string' && typeof item.label === 'string').slice(0, 8);
  } catch {
    return [];
  }
};
const recentTasks = ref<RecentTask[]>(readRecent());
const writeRecent = (items: RecentTask[]) => {
  recentTasks.value = items.slice(0, 8);
  sessionStorage.setItem(recentStorageKey, JSON.stringify(recentTasks.value));
};
const opsStorageKey = 'business-ai-ops:' + useUserStore().userId + ':' + props.context.organizationId;
const opsSessionId = ref(sessionStorage.getItem(opsStorageKey) || newRequestKey());
sessionStorage.setItem(opsStorageKey, opsSessionId.value);
const opsExpiresAt = ref('');
const opsSessionLimit = ref(8);
const opsAllSessions = ref<{ sessionId: string; preview: string; expiresAt: string }[]>([]);
const opsSessions = ref<{ sessionId: string; preview: string; expiresAt: string }[]>([]);
const holdText = computed(() => {
  if(genericRun.value)return '通用任务可在任务记录中继续；办赛资料和候选草稿单独保存。';
  if (!opsExpiresAt.value) return '运营问答保留 24 小时，从这段会话的第一句开始计算。办赛草稿另外保存。';
  const when = new Intl.DateTimeFormat('zh-CN', {
    timeZone: 'Asia/Shanghai',
    month: 'numeric',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23'
  }).format(new Date(opsExpiresAt.value));
  return `这段运营问答保留到 ${when}，之后自动删除。办赛草稿不受这段时间影响。`;
});
const rememberedTask = ref(sessionStorage.getItem(taskStorageKey) || undefined),
  taskWasRestored = ref(false);
const rememberTask = (id: string) => {
  rememberedTask.value = id;
  sessionStorage.setItem(taskStorageKey, id);
};
const forgetTask = () => {
  rememberedTask.value = undefined;
  sessionStorage.removeItem(taskStorageKey);
};
let windowMoved = false;
const position = reactive({ x: Math.max(12, innerWidth - 584), y: 82 }),
  bubble = reactive({ x: 22, y: 0 }),
  windowWidth = ref(window.innerWidth),
  windowHeight = ref(window.innerHeight);
const windowStyle = computed(() => (expanded.value || windowWidth.value <= 700 ? {} : { right: 'auto', left: position.x + 'px', top: position.y + 'px' }));
const taskLabel = computed(
  () =>
    (
      ({
        overview: '概览',
        projects: '项目与费用',
        registrations: '报名名单',
        fields: '报名设置',
        checkin: '赛事报到',
        matches: '场次录分',
        awards: '获奖证明',
        materials: '策划与文稿',
        publication: '发布管理',
        notifications: '取消通知'
      }) as Record<string, string>
    )[String(route.query.task)] || '赛事任务'
);
const followLatest = ref(true);
let taskScrollSequence=0,readingInteraction=0,taskScrollPending=false,taskPositionScrollTop:number|undefined;
function noteReadingInteraction(){readingInteraction++;taskScrollSequence++;taskScrollPending=false;taskPositionScrollTop=undefined;followLatest.value=false;}
function noteReadingKey(event:KeyboardEvent){if(['ArrowUp','ArrowDown','PageUp','PageDown','Home','End',' '].includes(event.key))noteReadingInteraction();}
function trackScroll() {
  const el=thread.value;if(!open.value||!el?.clientHeight)return;
  if(taskPositionScrollTop!==undefined){const expected=taskPositionScrollTop;taskPositionScrollTop=undefined;if(Math.abs(el.scrollTop-expected)<1)return;}
  followLatest.value=el.scrollHeight-el.scrollTop-el.clientHeight<70;
}
const scroll = () => {
  const sequence=taskScrollSequence,interaction=readingInteraction,stamp=generation,identity=useUserStore().token;
  return nextTick(() => {const el=thread.value;if(open.value&&el?.clientHeight&&!taskScrollPending&&sequence===taskScrollSequence&&interaction===readingInteraction&&stamp===generation&&identity===useUserStore().token&&followLatest.value){taskPositionScrollTop=undefined;el.scrollTop=el.scrollHeight;}});
};
async function revealCurrentTask(id:string) {
  const sequence=++taskScrollSequence,interaction=readingInteraction,stamp=generation,identity=useUserStore().token;
  taskScrollPending=true;
  await nextTick();
  // The window uses v-show. Wait for its visible layout instead of measuring the hidden transcript.
  await new Promise<void>(resolve=>requestAnimationFrame(()=>resolve()));
  if(sequence!==taskScrollSequence||interaction!==readingInteraction||stamp!==generation||identity!==useUserStore().token||!open.value||task.value?.id!==id){if(sequence===taskScrollSequence)taskScrollPending=false;return;}
  const el=thread.value,card=el&&Array.from(el.querySelectorAll<HTMLElement>('.b-ai-draft-actions')).find(candidate=>candidate.dataset.taskId===id);
  taskScrollPending=false;
  if(!el?.clientHeight||!card)return;
  const top=card.getBoundingClientRect().top-el.getBoundingClientRect().top+el.scrollTop-10;
  followLatest.value=false;
  el.scrollTop=Math.max(0,Math.min(top,el.scrollHeight-el.clientHeight));
  taskPositionScrollTop=el.scrollTop;
}
const add = (text: string, source?: string, copy = false, draftTaskId?: string) => {
  turns.value.push({ text, source, copy, draftTaskId });
  scroll();
};
const addDraft = (text: string, source?: string) => add(text, source, false, task.value?.id);
const show = () => {
  if (!open.value) previousFocus = document.activeElement as HTMLElement;
  clamp();
  open.value = true;
};
const close = () => {
  historyOpen.value = false;
  open.value = false;
  previousFocus?.focus();
};
const created = (id: string) => {
  if (task.value) rememberTask(task.value.id);
  addDraft('赛事创建成功。可在这张卡片中核对并发布，或进入管理赛事继续完善。', '赛事编号：' + id);
  ElMessage.success('赛事创建成功');
  emit('saved');
};
const copy = async (text: string) => {
  try {
    await navigator.clipboard.writeText(text);
    ElMessage.success('已复制');
  } catch {
    ElMessage.info('请选中回答文字手动复制');
  }
};
function feedback(turn: { feedback?: 'up' | 'down' }, kind: 'up' | 'down') {
  turn.feedback = turn.feedback === kind ? undefined : kind;
}
async function command(name: string) {
  const sequence = ++commandSequence;
  show();
  chart.value = '';
  editor.value = undefined;
  taskConversation.value = name === 'AI办赛';
  if (name !== 'AI办赛') preparing.value = false;
  if (name === 'AI办赛') {
    await sendPrompt('请帮我用自然语言办理一场赛事。我会提供办赛想法、规程文字或文件，请整理草稿、追问缺失信息，等我确认后再保存。');
    return;
  }
  mode.value = '';
  promoteId.value = '';
  if (name === '推广文案') {
    turns.value.push({user: true, text: '请根据当前赛事准备群消息、朋友圈和海报，缺失内容请标明待补。'});
    if (!props.event?.id) {
      add('请先进入一场赛事，再准备群消息、朋友圈和海报。');
      return;
    }
    mode.value = 'promote';
    promoteId.value = props.event.id;
    await scroll();
    return;
  }
  if (name === '修改设置') {
    turns.value.push({user: true, text: '请帮我读取当前赛事设置，展示可修改内容，由我核对后保存。'});
    if (!props.event) {
      add('请先从赛事管理选择一场赛事，再在这里修改设置。');
      return;
    }
    const path = route.fullPath,
      id = props.event.id;
    try {
      const { data } = await getManagedEvent(id);
      if (path !== route.fullPath || sequence !== commandSequence) return;
      if (!data.editable) {
        add('这场赛事当前不能直接修改。请按发布管理中的下架、解锁等既有规则办理。');
        return;
      }
      editor.value = data;
      editRoute = path;
      for (const key of [
        'name',
        'location',
        'projectName',
        'feeDescription',
        'registrationOpensAt',
        'registrationClosesAt',
        'startsAt',
        'endsAt',
        'registrationReview',
        'rulesText',
        'noticeText',
        'declarationText',
        'routeText'
      ] as const)
        editForm[key] = key.endsWith('At') ? businessPickerTime(data[key]) : data[key] || '';
      for (const key of ['bannerFileId', 'rulesFileId', 'noticeFileId', 'declarationFileId', 'routeFileId'] as const) editForm[key] = data[key];
      await scroll();
    } catch {
      add('当前赛事读取失败，请刷新后重试。');
    }
    return;
  }
  if (name === '报名趋势') {
    turns.value.push({user: true, text: '请用数据组件展示当前组织最近七天的报名提交趋势，并说明统计口径。'});
    try {
      const { data } = await getOperationsSummary();
      if (sequence !== commandSequence) return;
      const counts = new Map<string, number>();
      for (const e of data.events) for (const d of e.trend) counts.set(d.date, (counts.get(d.date) || 0) + d.count);
      const max = Math.max(1, ...counts.values());
      chart.value = `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'"><style>body{font:14px 'Inter','PingFang SC','Microsoft YaHei','Segoe UI',sans-serif;color:#345369;background:#f4fafd;padding:13px}h3{margin:0 0 20px}main{display:flex;gap:12px;height:115px;align-items:end}i{flex:1;background:linear-gradient(#67cbd1,#719ce8);border-radius:5px;position:relative;min-height:2px}b{position:absolute;top:-19px;width:100%;text-align:center;font-style:normal}small{display:block;font-size:12px;font-style:normal;position:absolute;bottom:-18px;width:100%;text-align:center}p{margin-top:28px;font-size:12px}</style><h3>近7日最近正式提交记录 / 整单</h3><main>${[...counts].map(([date, n]) => `<i style="height:${Math.round((n / max) * 95)}px"><b>${n}</b><small>${date.slice(5)}</small></i>`).join('')}</main><p>真实数据快照 · 每条报名最近提交时间，不累计历史重提次数</p></html>`;
      await scroll();
    } catch {
      add('统计读取失败，不展示估算曲线。');
    }
    return;
  }
  input.value =
    name === '推广文案'
      ? '请根据当前赛事生成一份公众号推广文案，缺失信息请标明待补，不编造价格或名额。'
      : '请分析当前组织的运营待办，说明报名、付款声明和资格分别需要处理什么。';
  await send();
}
async function send() {
  if (!consent.value) {
    ElMessage.info('请先勾选输入框上方的模型同意项；手动操作与数据组件无需外部模型。');
    return;
  }
  if (busy.value || publicationBusy.value || genericRunning.value || genericAwaitingConfirmation.value || (!input.value.trim() && !attachments.value.length)) return;
  const publicationIntent=publicationMessageIntent(input.value);
  if(publicationIntent&&draftPublishedState.value){addDraft('这场赛事已经发布。赛事编号：'+task.value?.resultObjectId);input.value='';return;}
  if(publicationIntent==='confirm'&&publishVisible.value&&publicationCard.value&&publishEventId.value===task.value?.resultObjectId) {
    const message=input.value.trim();input.value='';turns.value.push({text:message,user:true});followLatest.value=true;scroll();
    await publicationCard.value.confirm(true);
    return;
  }
  const submittedInput = input.value,
    message = input.value.trim() || '请根据上传的资料整理赛事草稿',
    id = selectedEventId.value,
    path = route.fullPath,
    stamp = ++generation;
  input.value = '';
  busy.value = true;
  const history = turns.value.slice(-6).map((t) => ({ user: !!t.user, text: t.text.slice(0, 2000) }));
  followLatest.value = true;
  turns.value.push({ text: message, user: true });
  scroll();
  try {
    if (message.startsWith('请帮我用自然语言办理一场赛事')) {
      preparing.value = true;
      add('可以。直接在这里描述办赛目标或粘贴规程，也可以点输入框旁的＋上传资料。我会整理候选草稿、追问缺失信息；你明确确认后才保存赛事草稿。请告诉我赛事名称、时间、地点和项目。');
      return;
    }
    // 用户明确点击草稿动作/上传入口才直接进入任务；普通聊天由服务端判断目标。
    const explicitDraft = forcedDraft || (!!publicationIntent && !!task.value && !draftPublishedState.value) || (attachments.value.length > 0 && message === '请根据上传的资料整理赛事草稿');
    forcedDraft = false;
    const intent = explicitDraft ? 'draft' : (await resolveAssistantIntent(message, id, task.value && task.value.status!=='ABANDONED' && !draftPublishedState.value ? task.value.id : undefined, history)).data.intent;
    if (stamp !== generation) return;
    if (intent === 'clarify') { add('你想查看当前赛事的缺项，还是完善未保存的办赛草稿？可以点“运营分析”或草稿里的“继续完善草稿”。'); input.value = message; return; }
    if(intent==='draft'&&attachments.value.length&&task.value&&['PENDING_CONFIRMATION','FAILED'].includes(task.value.status)){
      await persistLocalCandidate();if(stamp!==generation)return;
      const {data}=await appendAiTaskMaterials(task.value,[...attachments.value]);if(stamp!==generation)return;attachments.value=[];genericRun.value=undefined;task.value=data;await loadTask(data.id);addDraft('补充资料已加入当前草稿，正在核对新增信息。你在表单中填写的内容会保留。');return;
    }
    if (intent === 'draft' && task.value && task.value.status!=='ABANDONED') {
      if(draftPublishedState.value||task.value.draftEditable===false){addDraft('这场赛事当前不能通过草稿修改。请从管理赛事按当前状态办理。');input.value=message;return;}
      if (!['PENDING_CONFIRMATION','CREATED'].includes(task.value.status)) { add('资料仍在识别，请等识别完成后继续补充。'); input.value = message; return; }
      if(task.value.status==='CREATED'&&attachments.value.length){addDraft('这场赛事已建立，当前可在聊天或表单修改。新选文件还未提交，请先移除附件后发送修改要求。');input.value=message;return;}
      if (message.length > 500) { add('单次补充请控制在500字内，避免截断。完整规程请在新办赛任务中提交。'); input.value = message; return; }
      await persistLocalCandidate();if(stamp!==generation)return;
      const taskId=task.value.id,wasCreated=task.value.status==='CREATED';
      publishVisible.value=false;
      const {data} = await talkAiTask(task.value.id, message, task.value.version, draftDeclarationText.value ? declarationAckRequired.value : undefined);
      if (stamp !== generation) return;
      const refreshed=(await getAiTask(taskId)).data as AiTaskCard;if(stamp!==generation||task.value?.id!==taskId)return;
      setCurrentTask(refreshed);
      let spoken = withoutStructuredNextStep(data.reply || '', draftReadiness.value?.nextStep);
      if(wasCreated)spoken=spoken.replace('创建前可在表单核对','可在表单核对后保存修改');
      if (spoken && !(data.created&&data.eventId)) addDraft(spoken);
      if (data.created && data.eventId && !wasCreated) created(data.eventId);
      if(data.action==='publish'&&data.eventId)await preparePublication(String(data.eventId),stamp);
      return;
    }
    if (intent === 'new' && task.value && draftEditable.value) { add('当前还有这份赛事草稿。若要另外办一场，请点“新会话”收起它；这份草稿会保留。'); input.value = message; return; }
    if (intent === 'new' || intent === 'draft') {
      genericRun.value=undefined;
      if (task.value?.status === 'CREATED') task.value = undefined;
      const files = [...attachments.value];
      taskConversation.value = true;
      const {data} = files.length ? await uploadAiTask(files, true) : await startTextAiTask(true, message);
      if (stamp !== generation) return;
      attachments.value = [];fileFeedback('',false);
      taskWasRestored.value = false;
      rememberTask(data.id);
      await loadTask(data.id);
      preparing.value = false;
      if (files.length && message !== '请根据上传的资料整理赛事草稿') { input.value = message; add('资料已提交，补充要求保留在输入框中。识别完成后再发送即可。'); }
      return;
    }
    await sendGeneric(message,id,stamp);
    if (path !== route.fullPath) add('上条回答基于提问时的页面。你已切换页面，后续问题会读取新的上下文。');
  } catch (reason) {
    if (stamp === generation) {
      if (!input.value.trim()) input.value = submittedInput;
      add(reason instanceof Error?reason.message:'本次请求未返回完整结果。办赛任务可重新读取状态后再继续，请勿重复确认保存。');
      if (rememberedTask.value) await loadTask(rememberedTask.value).catch(() => add('任务状态暂时无法读取，请稍后重试。'));
    }
  } finally {
    if (stamp === generation) busy.value = false;
  }
}
async function saveSettings() {
  if (!editor.value || saving.value) return;
  if (editRoute !== route.fullPath || editor.value.id !== props.event?.id) {
    editor.value = undefined;
    add('页面已改变，已取消旧表单。请重新读取当前赛事。');
    return;
  }
  saving.value = true;
  try {
    await updateEvent(editor.value.id, { ...editForm });
    editor.value = undefined;
    add('已保存赛事设置；页面保持原位置。');
    emit('saved');
  } catch {
    add('保存未完成，请核对时间及赛事状态后重试。');
  } finally {
    saving.value = false;
  }
}
function clamp() {
  windowWidth.value = innerWidth;
  windowHeight.value = innerHeight;
  position.x = !windowMoved && innerWidth > 700 ? Math.max(12, innerWidth - 584) : Math.min(Math.max(12, position.x), Math.max(12, innerWidth - Math.min(560,innerWidth-24) - 12));
  position.y = Math.min(Math.max(82, position.y), Math.max(82, innerHeight - Math.min(800,innerHeight-100) - 12));
  if (bubble.y) {
    bubble.x = Math.min(Math.max(8, bubble.x), Math.max(8, innerWidth - 160));
    bubble.y = Math.min(Math.max(80, bubble.y), innerHeight - 65);
  }
}
function drag(event: PointerEvent, target: 'window' | 'bubble') {
  if (
    event.button !== 0 ||
    ((event.target as HTMLElement).closest('button') && target === 'window') ||
    (target === 'window' && (expanded.value || innerWidth <= 700))
  )
    return;
  const element = event.currentTarget as HTMLElement,
    rect = element.getBoundingClientRect(),
    origin = target === 'window' ? { ...position } : { x: rect.left, y: rect.top };
  let moved = false;
  element.setPointerCapture(event.pointerId);
  const move = (e: PointerEvent) => {
    if (Math.abs(e.clientX - event.clientX) + Math.abs(e.clientY - event.clientY) > 5) moved = true;
    if (target === 'window') {
      windowMoved = true;
      position.x = origin.x + e.clientX - event.clientX;
      position.y = origin.y + e.clientY - event.clientY;
    } else {
      bubble.x = origin.x + e.clientX - event.clientX;
      bubble.y = origin.y + e.clientY - event.clientY;
    }
    clamp();
  };
  const end = () => {
    element.removeEventListener('pointermove', move);
    element.removeEventListener('pointerup', end);
    element.removeEventListener('pointercancel', end);
    if (target === 'bubble') bubbleDragged = moved;
  };
  element.addEventListener('pointermove', move);
  element.addEventListener('pointerup', end);
  element.addEventListener('pointercancel', end);
}
let bubbleDragged = false;
const dragWindow = (e: PointerEvent) => drag(e, 'window');
const toggleLauncher = () => {
  if (bubbleDragged) {
    bubbleDragged = false;
    return;
  }
  if (open.value) close();
  else show();
};
function moveByKeyboard(e: KeyboardEvent) {
  if (!['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(e.key) || expanded.value || innerWidth <= 700) return;
  e.preventDefault();
  windowMoved = true;
  position.x += e.key === 'ArrowRight' ? 16 : e.key === 'ArrowLeft' ? -16 : 0;
  position.y += e.key === 'ArrowDown' ? 16 : e.key === 'ArrowUp' ? -16 : 0;
  clamp();
}
const escape = (e: KeyboardEvent) => {
  if (e.key === 'Escape' && open.value) close();
};
watch(
  () => props.event?.id,
  (id) => {
    if (mode.value !== 'promote') return;
    if (!id) {
      mode.value = '';
      promoteId.value = '';
      return;
    }
    promoteId.value = id;
  }
);
watch(
  () => route.fullPath,
  () => {
    if (editor.value) {
      editor.value = undefined;
      add('已切换页面，旧赛事设置表单已收起。');
    }
  }
);
onMounted(() => {
  window.addEventListener('resize', clamp);
  document.addEventListener('keydown', escape);
  document.addEventListener('pointerdown', outside);
  if (rememberedTask.value) {
    const id=rememberedTask.value,stamp=generation,identity=useUserStore().token;
    loadTask(id).catch(() => {if(stamp!==generation||identity!==useUserStore().token||rememberedTask.value!==id)return;forgetTask();add('先前办赛任务暂时无法读取，请重试或重新开始。');});
    loadOpsSessions();
  } else {
    loadOpsSessions().then((current) => { if (current) restoreOps(); });
  }
  clamp();
});
onUnmounted(() => {
  generation++;
  commandSequence++;
  window.removeEventListener('resize', clamp);
  document.removeEventListener('keydown', escape);
  document.removeEventListener('pointerdown', outside);
  clearTimeout(taskTimer);
  disconnectProgress?.();
  disconnectGeneric?.();
});
const assistantWindow = ref<HTMLElement>(), filePicker = ref<HTMLInputElement>(), composer = ref<HTMLTextAreaElement>();
type CandidateFormControls={focusCreate:()=>void;persist:()=>Promise<AiTaskCard>;hasUnsavedChanges:()=>boolean;getDeclarationRequired:()=>boolean};
const candidateForm = ref<CandidateFormControls>(),draftDialog=ref<{hasUnsavedChanges:()=>boolean}>();
function setCandidateForm(value: unknown) { candidateForm.value = value as CandidateFormControls | undefined; }
function focusCandidateCreation() { candidateForm.value?.focusCreate(); }
async function chooseAnswer(answer: string) {
  if (draftActionsLocked.value) return;
  input.value = toggleAssistantAnswer(input.value, answer);
  await nextTick();
  composer.value?.focus();
}
const task = ref<AiTaskCard>(), attachments = ref<File[]>([]), preparing = ref(false), taskConversation = ref(true);
// Only opening or selecting a different task moves to its current controls; updates to that task leave history reading alone.
watch(()=>[open.value,task.value?.id] as const,([visible,id],[wasVisible,previousId])=>{
  if(!visible||!id){taskScrollSequence++;taskScrollPending=false;taskPositionScrollTop=undefined;return;}
  if(id&&(!wasVisible||id!==previousId))void revealCurrentTask(id);
},{flush:'sync'});
type ConversationItem = { kind: 'message'; key: string; turn: ChatTurn } | { kind: 'draft'; key: string };
// 草稿动作归属对应任务的最后一条回复，普通运营问答不会把它搬到无关回答下方。
const conversationItems = computed<ConversationItem[]>(() => {
  const items: ConversationItem[] = turns.value.map((turn, index) => ({ kind: 'message', key: `message-${index}`, turn }));
  if (!task.value || task.value.status === 'ABANDONED') return items;
  let anchor = -1;
  for (let index = turns.value.length - 1; index >= 0; index--) {
    if (!turns.value[index].user && turns.value[index].draftTaskId === task.value.id) { anchor = index; break; }
  }
  items.splice(anchor + 1, 0, { kind: 'draft', key: `draft-${task.value.id}` });
  return items;
});
const draftActionTitle = computed(() => draftLines.value.find(line => line.startsWith('赛事：'))?.slice(3) || '这份办赛草稿');
const draftPublishedState=computed(()=>task.value?.published===true||!!task.value?.resultObjectId&&publishedEventIds.value.has(task.value.resultObjectId));
const draftEditable=computed(()=>!!task.value&&['PENDING_CONFIRMATION','CREATED'].includes(task.value.status)&&!draftPublishedState.value&&task.value.draftEditable!==false);
const draftActionStatus = computed(() => task.value?.status === 'CREATED' ? draftPublishedState.value ? '已发布' : '已创建 · 待发布' : task.value?.status === 'FAILED' ? '待重新识别' : task.value?.proposal ? '候选草稿' : '正在识别');
const draftActionsLocked = computed(() => busy.value || publicationBusy.value || genericRunning.value || genericAwaitingConfirmation.value);
function hasProgressIssue(steps:VisibleStep[]){return steps.some(step=>['failed','refused'].includes(step.status));}
function openOrganizerDraft(id: string) {
  if (task.value?.id === id && task.value.proposal && !draftActionsLocked.value) draftVisible.value = true;
}
const publishVisible=ref(false),publishEventId=ref(''),publishedEventIds=ref(new Set<string>()),publicationBusy=ref(false);
const publicationCard=ref<{confirm:(typed?:boolean)=>Promise<boolean>;reload:()=>Promise<void>;focus:()=>Promise<void>}>();
function setPublicationCard(value:unknown){publicationCard.value=value as typeof publicationCard.value;}
function setCurrentTask(data:AiTaskCard,required=declarationAckRequired.value){task.value=data;applyProposal(data.proposal,false);declarationAckRequired.value=required;}
async function persistLocalCandidate() {
  if(draftDialog.value?.hasUnsavedChanges())throw new Error('原文核对表单还有未保存改动，请先在表单保存，再继续聊天或发布。');
  if(!candidateForm.value?.hasUnsavedChanges())return false;
  const id=task.value?.id,identity=useUserStore().token,required=candidateForm.value.getDeclarationRequired();
  const data=await candidateForm.value.persist();
  if(task.value?.id!==id||identity!==useUserStore().token)throw new Error('当前办赛任务已变化，请重新核对。');
  setCurrentTask(data,required);return true;
}
async function synchronizeCreatedDraft(stamp:number) {
  if(!task.value||task.value.status!=='CREATED'||!createdProposalState(task.value.proposal).dirty)return false;
  const id=task.value.id,eventId=task.value.resultObjectId,required=declarationAckRequired.value;
  const {data}=await talkAiTask(id,'请保存修改',task.value.version,draftDeclarationText.value?required:undefined);
  if(stamp!==generation||task.value?.id!==id)throw new Error('当前办赛任务已变化，请重新核对。');
  const actual=(await getAiTask(id)).data as AiTaskCard;
  if(stamp!==generation||task.value?.id!==id)throw new Error('当前办赛任务已变化，请重新核对。');
  setCurrentTask(actual,required);
  if(actual.resultObjectId!==eventId||actual.published||actual.draftEditable===false)throw new Error('赛事实际状态已变化，请重新核对后办理。');
  if(createdProposalState(actual.proposal).dirty)throw new Error(withoutStructuredNextStep(data.reply||'')||'修改还未保存到赛事，请先补齐草稿提示。');
  emit('saved');return true;
}
async function preparePublication(id:string,stamp=generation) {
  if(task.value?.resultObjectId!==id||draftPublishedState.value)throw new Error('请先读取这场赛事的实际状态。');
  await persistLocalCandidate();await synchronizeCreatedDraft(stamp);
  if(stamp!==generation||task.value?.resultObjectId!==id)return;
  publishEventId.value=id;publishVisible.value=true;
  addDraft('请核对下方发布卡。确认资料和联系信息后，可以直接回复“确认发布”。');
  await nextTick();await publicationCard.value?.focus();
}
async function beforePublicationConfirmation() {
  if(attachments.value.length){addDraft('新选文件还未提交，请先移除附件后核对发布。');return false;}
  const dirty=!!draftDialog.value?.hasUnsavedChanges()||!!candidateForm.value?.hasUnsavedChanges()||createdProposalState(task.value?.proposal||null).dirty;
  if(!dirty)return true;
  busy.value=true;const stamp=++generation;
  try{await persistLocalCandidate();await synchronizeCreatedDraft(stamp);addDraft('修改已保存到原赛事，请重新核对发布卡后再确认发布。');}
  catch(reason){addDraft(reason instanceof Error?reason.message:'修改还未保存，请先核对表单。');}
  finally{if(stamp===generation)busy.value=false;}
  return false;
}
function revisePublication(){publishVisible.value=false;void nextTick(()=>candidateForm.value?.focusCreate());}
async function createEditedEvent(candidate:AiTaskCard,required:boolean) {
  if(task.value?.id!==candidate.id||candidate.status!=='PENDING_CONFIRMATION'||draftActionsLocked.value)return;
  // The form has persisted these exact visible values. Confirm that returned
  // version directly; never create using the older parent card or composer text.
  task.value=candidate;
  applyProposal(candidate.proposal,false);
  declarationAckRequired.value=required;
  const stamp=++generation,identity=useUserStore().token;
  busy.value=true;
  followLatest.value=true;
  try {
    const {data}=await talkAiTask(candidate.id,'请确认并保存赛事草稿',candidate.version,draftDeclarationText.value?required:undefined);
    if(stamp!==generation||identity!==useUserStore().token||task.value?.id!==candidate.id)return;
    if(data.created&&data.eventId) {
      const actual=(await getAiTask(candidate.id)).data as AiTaskCard;
      if(stamp!==generation||identity!==useUserStore().token||task.value?.id!==candidate.id)return;
      setCurrentTask(actual,required);
      draftVisible.value=false;
      created(data.eventId);
      return;
    }
    const refreshed=(await getAiTask(candidate.id)).data as AiTaskCard;
    if(stamp!==generation||identity!==useUserStore().token||task.value?.id!==candidate.id)return;
    task.value=refreshed;
    applyProposal(refreshed.proposal,false);
    if(refreshed.status==='CREATED'&&refreshed.resultObjectId){draftVisible.value=false;created(refreshed.resultObjectId);return;}
    const spoken=withoutStructuredNextStep(data.reply||'',draftReadiness.value?.nextStep);
    addDraft(spoken||'赛事尚未创建。请在下方表单补齐待核对内容，再点击“创建赛事”。');
    ElMessage.warning('赛事尚未创建，请核对表单提示');
  } catch(reason) {
    if(stamp!==generation||identity!==useUserStore().token||task.value?.id!==candidate.id)return;
    // A timed-out submission may have reached the server. Recover its status
    // before offering another attempt; no automatic confirmation replay.
    try {
      const refreshed=(await getAiTask(candidate.id)).data as AiTaskCard;
      if(stamp!==generation||identity!==useUserStore().token||task.value?.id!==candidate.id)return;
      task.value=refreshed;
      applyProposal(refreshed.proposal,false);
      if(refreshed.status==='CREATED'&&refreshed.resultObjectId){draftVisible.value=false;created(refreshed.resultObjectId);return;}
      addDraft('赛事没有创建成功，候选表单已保留。'+(reason instanceof Error?reason.message:'请核对提示后重试。'));
    } catch {
      if(stamp===generation)addDraft('创建结果暂时无法核实，候选表单已保留。请稍后重新读取任务记录，避免重复创建。');
    }
  } finally { if(stamp===generation)busy.value=false; }
}
async function openDraftPublication(id:string){
  if(draftActionsLocked.value||task.value?.resultObjectId!==id)return;
  busy.value=true;const stamp=++generation;
  try{await preparePublication(id,stamp);}
  catch(reason){if(stamp===generation)addDraft(reason instanceof Error?reason.message:'发布资料尚未准备完成，请先核对草稿。');}
  finally{if(stamp===generation)busy.value=false;}
}
function openCreatedEvent(id:string){if(task.value?.resultObjectId!==id)return;close();void router.push('/org-desk/workspace/'+id+'?task=publication');}
function draftPublished(id:string){if(task.value?.resultObjectId!==id)return;publishedEventIds.value.add(id);task.value={...task.value,published:true,eventStatus:'published',draftEditable:false};publishVisible.value=false;addDraft('赛事发布成功。赛事编号：'+id+'。报名按实际窗口开放，可进入管理赛事查看进度。');ElMessage.success('赛事发布成功');emit('saved');}
const attachmentSizeLabel = computed(() => {
  const bytes = attachments.value.reduce((sum, file) => sum + file.size, 0);
  if (bytes >= 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)}MB`;
  return `${Math.max(1, Math.round(bytes / 1024))}KB`;
});
const maxUploadFiles = 15;
const fileNotice=ref(''),fileNoticeError=ref(false);
const uploadBlockedReason=computed(()=>{
  if(!useUserStore().token)return '请先登录后添加办赛资料。';
  if(!consent.value)return '请先同意资料处理后添加文件。';
  if(task.value&&['UPLOADED','PROCESSING'].includes(task.value.status))return '正在识别资料，完成后可继续补充文件。';
  if(busy.value||publicationBusy.value||genericRunning.value)return '正在处理上一项，请稍候再添加资料。';
  if(genericAwaitingConfirmation.value)return '请先核对上方确认卡，或选择修改内容。';
  if(task.value?.status==='CREATED')return '这场赛事已创建，请在管理赛事补充材料；聊天可继续修改字段。';
  if(task.value&&!['PENDING_CONFIRMATION','FAILED','ABANDONED'].includes(task.value.status))return '当前草稿状态不能添加资料，请重新读取任务。';
  return '';
});
const uploadLocked=computed(()=>!!uploadBlockedReason.value);
const uploadLimits=computed(()=>({maxFiles:genericRun.value?4:maxUploadFiles,maxFileBytes:15*1024*1024,maxTotalBytes:(genericRun.value?20:40)*1024*1024}));
const uploadDescription=computed(()=>`最多 ${uploadLimits.value.maxFiles} 份，单份 15MB，合计 ${genericRun.value?20:40}MB。`);
const uploadHint=computed(()=>uploadBlockedReason.value||`可拖入 DOCX、XLSX、PDF、JPG、PNG、WebP，或点＋选择。${uploadDescription.value}`);
function fileFeedback(message:string,isError=true){fileNotice.value=message;fileNoticeError.value=isError;}
function addFiles(incoming:File[]){
  if(uploadBlockedReason.value){fileFeedback(uploadBlockedReason.value);return;}
  const result=validateAssistantFiles(attachments.value,incoming,uploadLimits.value);
  if(result.error){fileFeedback(result.error);return;}
  attachments.value=result.files;fileFeedback('已加入待发送资料，核对后点击发送。',false);
}
const {dragging:fileDragging,handlers:fileDropHandlers,reset:resetFileDrop}=useAssistantFileDrop({blockedReason:()=>uploadBlockedReason.value,addFiles,feedback:fileFeedback});
watch(open,value=>{if(!value){resetFileDrop();fileNotice.value='';}});
watch(()=>attachments.value.length,count=>{if(!count){fileNotice.value='';fileNoticeError.value=false;}});
const draftVisible = ref(false);
type GenericRun={id:string;status:string;stopReason?:string;steps:VisibleStep[];messages:{id:string;role:string;content:string;blocks?:string}[]};
const genericRun=ref<GenericRun>(),genericConnection=ref<ProgressConnection>('connecting');
const genericHistory=ref<{id:string;goal:string;status:string}[]>([]);
const genericRunning=computed(()=>!!genericRun.value&&['running','waiting_children'].includes(genericRun.value.status));
const genericAwaitingConfirmation=computed(()=>genericRun.value?.status==='waiting_confirmation');
let disconnectGeneric:(()=>void)|undefined;
const shownGenericMessages=new Set<string>();
function applyGeneric(run:GenericRun){genericRun.value=run;for(const message of run.messages||[])if(message.role==='assistant'&&!shownGenericMessages.has(message.id)){shownGenericMessages.add(message.id);turns.value.push({text:message.content,blocks:message.blocks,agentMessageId:message.id});void scroll();}if(run.stopReason&&turns.value.at(-1)?.source!==run.stopReason)add('本轮处理已停止，已有材料与记录已保留，可以从任务记录继续。',run.stopReason);}
async function confirmGeneric(messageId:string,accepted:boolean){if(!genericRun.value||busy.value)return;busy.value=true;try{await request({url:`/sports/agents/runs/${genericRun.value.id}/confirm`,method:'post',data:{messageId,accepted},headers:{repeatSubmit:false}});applyGeneric((await request<GenericRun>({url:`/sports/agents/runs/${genericRun.value.id}`,method:'get'})).data);}catch{add('这次确认未完成，请先重新读取当前任务状态。');}finally{busy.value=false;}}
async function sendGeneric(message:string,eventId:string|undefined,stamp:number){
  let id=genericRun.value?.id;
  if(attachments.value.length){
    if(attachments.value.length>4||attachments.value.reduce((n,f)=>n+f.size,0)>20*1024*1024){add('材料整理任务每次最多4份、合计20MB，请分批补充。');input.value=message;return;}
    const continuing=id&&genericRun.value?.status==='waiting_input',data=new FormData();attachments.value.forEach(file=>data.append('files',file));data.append(continuing?'message':'goal',message);data.append('consent','true');data.append('context',JSON.stringify(eventId?{eventId}:{}));const result=await request<{runId:string}>({url:continuing?`/sports/agents/runs/${id}/materials`:'/sports/agents/runs/materials',method:'post',data,headers:{repeatSubmit:false},timeout:120000});if(!continuing)id=result.data.runId;attachments.value=[];
  }else if(id&&genericRun.value?.status==='waiting_input')await request({url:`/sports/agents/runs/${id}/answer`,method:'post',data:{message},headers:{repeatSubmit:false}});
  else{const result=await request<{runId:string}>({url:'/sports/agents/runs',method:'post',data:{goal:message,consent:true,context:eventId?{eventId}:{}},headers:{repeatSubmit:false}});id=result.data.runId;}
  if(stamp!==generation)return;const result=await request<GenericRun>({url:`/sports/agents/runs/${id}`,method:'get'});if(stamp===generation)applyGeneric(result.data);
}
async function resumeGeneric(id:string){clearConversation();const result=await request<GenericRun>({url:`/sports/agents/runs/${id}`,method:'get'});for(const item of result.data.messages||[]){turns.value.push({text:item.content,user:item.role==='user',blocks:item.blocks,agentMessageId:item.id});shownGenericMessages.add(item.id);}applyGeneric(result.data);historyOpen.value=false;}
watch(historyOpen,async value=>{if(value)try{genericHistory.value=(await request<{id:string;goal:string;status:string}[]>({url:'/sports/agents/runs',method:'get'})).data.slice(0,12);}catch{genericHistory.value=[];}});
async function stopGeneric(){if(!genericRun.value)return;await request({url:`/sports/agents/runs/${genericRun.value.id}/stop`,method:'post'});const result=await request<GenericRun>({url:`/sports/agents/runs/${genericRun.value.id}`,method:'get'});applyGeneric(result.data);}
function candidateSaved(data:AiTaskCard,required:boolean){if(task.value?.id!==data.id)return;setCurrentTask(data,required);publishVisible.value=false;addDraft(data.status==='CREATED'?'修改已保存到同一赛事草稿，赛事编号：'+data.resultObjectId+'。可以继续聊天修改，或核对发布。':'表单已保存到候选草稿，可以继续补充或创建赛事。');emit('saved');}
function candidateRefreshed(data:AiTaskCard,required:boolean){if(task.value?.id!==data.id)return;setCurrentTask(data,required);publishVisible.value=false;addDraft('已读取同一赛事的当前内容，刷新前填写保留在表单中供核对。');}
watch(()=>[open.value,genericRun.value?.id,genericRun.value?.status,useUserStore().token].join(':'),()=>{
  disconnectGeneric?.();disconnectGeneric=undefined;const id=genericRun.value?.id,identity=useUserStore().token;
  if(open.value&&id)disconnectGeneric=followAssistantProgress<GenericRun>(`/sports/agents/runs/${id}/stream`,snapshot=>{if(identity!==useUserStore().token||genericRun.value?.id!==id)return;applyGeneric(snapshot);if(!['running','waiting_children'].includes(snapshot.status))disconnectGeneric?.();},state=>{genericConnection.value=state;});
});
type DraftReady = { canSaveDraft: boolean; nextStep: string; blockingIssues: { field: string; message: string }[] };
const draftReadiness = ref<DraftReady>();
const draftWarnings = ref<string[]>([]);
const draftLines = ref<string[]>([]), suggestions = ref<string[]>([]), sourceText = ref('');
const visibleDraftSuggestions=computed(()=>task.value?.status==='CREATED'?suggestions.value.filter(option=>option!=='确认保存赛事草稿'):suggestions.value);
const draftDeclarationText=ref(''),declarationAckRequired=ref(false);
let declarationChoiceVersion='';
const draftUnits=ref<{name:string;type:string;seats:string;capacity:string;fee:string;conflict:string}[]>([]),draftSources=ref<string[]>([]);
let taskTimer = 0;
const taskProgress=ref<VisibleStep[]>([]),progressConnection=ref<ProgressConnection>('connecting');
let disconnectProgress:(()=>void)|undefined;
watch(()=>[open.value,task.value?.id,task.value?.status,useUserStore().token].join(':'),()=>{
  disconnectProgress?.();disconnectProgress=undefined;const id=task.value?.id,identity=useUserStore().token;
  if(open.value&&id)disconnectProgress=followAssistantProgress<{id:string;status:string;steps:VisibleStep[]}>(`/sports/b/ai/tasks/${id}/stream`,snapshot=>{
    if(identity!==useUserStore().token||task.value?.id!==id)return;taskProgress.value=snapshot.steps;
    if(!['UPLOADED','PROCESSING'].includes(snapshot.status)){disconnectProgress?.();if(task.value.status!==snapshot.status)void loadTask(id);}
  },state=>{progressConnection.value=state;});
});
function composerKey(e: KeyboardEvent) {
  if (e.key === 'Enter' && !e.shiftKey && !e.isComposing && e.keyCode !== 229) { e.preventDefault(); send(); }
}
function outside(e: PointerEvent) {
  const node = e.target as HTMLElement;
  if (open.value && !expanded.value && !assistantWindow.value?.contains(node) && !node.closest('.assistant-bubble,.assistant-bubble-greeting,.el-popper,.el-overlay,.el-message-box')) open.value = false;
}
let forcedDraft = false;
async function sendPrompt(text: string) { if (busy.value) return; input.value = text; await send(); }
function pickFiles(e: Event) {
  const picker = e.target as HTMLInputElement;
  const files=Array.from(picker.files||[]);picker.value='';if(files.length)addFiles(files);
}
const restoredProposals = new Set<string>();
function applyProposal(raw: string | null, restore: boolean) {
  if (!raw) { draftDeclarationText.value=''; declarationAckRequired.value=false; declarationChoiceVersion=''; draftUnits.value=[]; draftSources.value=[]; return; }
  try {
    const p = JSON.parse(raw);
    suggestions.value = p.suggestions || [];
    draftReadiness.value = p.readiness;
    draftDeclarationText.value=p.event?.declarationText?.value||'';
    const choiceVersion=task.value?.id+':'+task.value?.version+':'+draftDeclarationText.value;
    if(declarationChoiceVersion!==choiceVersion){declarationAckRequired.value=false;declarationChoiceVersion=choiceVersion;}
    draftWarnings.value = ['请核对项目价格与原文后确认；未识别费用不会自动设成免费，保存不等于发布或收款。', ...(p.event?.feeDescription?.value?.includes('加项') ? ['原文含首项/加项价格，需要核对跨项目计价；不能自动按统一价格设置。'] : [])];
    const labels: Record<string,string> = {name:'赛事',location:'地点',projectName:'项目',startsAt:'开赛',endsAt:'结束',registrationOpensAt:'报名开始',registrationClosesAt:'报名截止',feeDescription:'费用',contactName:'联系人',contactMethod:'联系方式',refundTerms:'退改说明',declarationText:'参赛声明'};
    draftLines.value = Object.entries(labels).flatMap(([key,label]) => p.event?.[key]?.value ? [label + '：' + p.event[key].value] : []);
    draftUnits.value=(p.units||[]).map((u:any)=>({name:u.name?.value||'项目名称待补',type:({individual:'个人报名',pair:'双人报名',team:'团队报名'} as Record<string,string>)[u.entryType?.value]||'参赛形式待补',seats:u.entryType?.value==='pair'?'每单2人，房主计入':u.entryType?.value==='individual'?'每单1人':u.minMembers?.value&&u.maxMembers?.value?`每单${u.minMembers.value}至${u.maxMembers.value}人`:'每单人数待补',fee:u.feeAmount?.status==='conflict'||u.feeBasis?.status==='conflict'?'费用有冲突，请补充整单总价':u.feeAmount?.value!==''&&u.feeAmount?.value!=null&&u.feeBasis?.value==='order'?`待确认价格：每单 ¥${Number(u.feeAmount.value).toFixed(2)}`:u.feeBasis?.value==='per_person'?'原文按人计费，请确认整单总价':u.feeBasis?.value==='additional'?'原文含附加费用，请核对整单价格':'每单费用待补；未填不代表免费',capacity:u.limitCount?.status==='conflict'?'名额有冲突，待确认':u.limitCount?.value?`最多${u.limitCount.value}单报名`:'名额待补',conflict:u.limitCount?.status==='conflict'?'原文写法：'+(u.limitCount.alternatives||[]).join(' / '):''}));
    draftSources.value=Object.entries(labels).flatMap(([key,label])=>(p.event?.[key]?.sources||[]).filter((s:any)=>s.quote).map((s:any)=>label+' · '+(s.label||'原文')+'：'+s.quote));
    draftSources.value.push(...(p.units||[]).flatMap((u:any)=>(u.feeAmount?.sources||[]).filter((s:any)=>s.quote).map((s:any)=>(u.name?.value||'项目')+' · 费用依据：'+s.quote)));
    if (restore && !restoredProposals.has(raw)) {
      restoredProposals.add(raw);
      if (!taskWasRestored.value) {
        for (const t of p.dialogue || []) {
          const text = t.role === 'user' ? t.text : withoutStructuredNextStep(t.text, p.readiness?.nextStep);
          if (text) turns.value.push({ text, user: t.role === 'user', draftTaskId: task.value?.id });
        }
        if (!p.dialogue?.length && p.readiness) {
          const spoken = withoutStructuredNextStep(p.reply || '', p.readiness.nextStep);
          if (spoken) addDraft(spoken);
        }
        taskWasRestored.value = true; scroll();
      } else {
        const last = p.dialogue?.at(-1);
        const text = last && last.role !== 'user' ? withoutStructuredNextStep(last.text, p.readiness?.nextStep) : last?.text;
        if (text && last?.role !== 'user' && turns.value.at(-1)?.text !== text) addDraft(text);
      }
    }
  } catch { add('草稿内容暂时无法读取，请重试。'); }
}
async function loadTask(id: string) {
  clearTimeout(taskTimer);
  const stamp = generation, identity = useUserStore().token;
  const {data} = await getAiTask(id);
  if (stamp !== generation || identity !== useUserStore().token) return;
  let actualEvent:EventCard|undefined;
  if(data.status==='CREATED'&&data.resultObjectId){
    try{actualEvent=(await getManagedEvent(data.resultObjectId)).data;}
    catch{ /* 实际赛事声明开关无法读取时，保留当前会话已核对的选择。 */ }
    if(stamp!==generation||identity!==useUserStore().token)return;
  }
  const knownDeclarationRequired=task.value?.id===id?declarationAckRequired.value:undefined;
  if(data.status==='CREATED'&&!actualEvent&&knownDeclarationRequired===undefined)data.draftEditable=false;
  task.value = data;
  applyProposal(data.proposal, true);
  if(actualEvent)declarationAckRequired.value=actualEvent.declarationAckRequired===true;
  else if(knownDeclarationRequired!==undefined)declarationAckRequired.value=knownDeclarationRequired;
  if(data.status==='CREATED'&&!actualEvent&&knownDeclarationRequired===undefined)addDraft('实际赛事设置暂时无法读取，请重新打开这份草稿后继续修改。');
  try { sourceText.value = JSON.parse(data.extraction || '{}').files?.flatMap((f: any) => (f.blocks || []).map((b: any) => b.label + '：' + b.text)).join('\n') || ''; } catch { sourceText.value = ''; }
  if (['PROCESSING','UPLOADED'].includes(data.status)) taskTimer = window.setTimeout(() => loadTask(id).catch(() => add('识别状态读取失败，请重试。')), 2000);
  if(actualEvent?.publicationStatus==='published')publishedEventIds.value.add(actualEvent.id);
  if (data.status === 'ABANDONED') { task.value = undefined; forgetTask(); }
}
async function retryTask() { if (!task.value || busy.value) return; busy.value = true; try { await retryAiTask(task.value.id); await loadTask(task.value.id); } finally { busy.value = false; } }
async function deleteOrganizerDraft(id: string) {
  if (task.value?.id !== id || draftActionsLocked.value) return;
  const current = task.value;
  const stamp = generation, identity = useUserStore().token;
  const saved = current.status === 'CREATED' && !!current.resultObjectId;
  try {
    await ElMessageBox.confirm(saved ? '将删除这场尚未发布的办赛草稿及未使用的收费设置。已有报名、付款义务或发布历史时不会删除。' : '将删除这份还没保存成赛事的办赛草稿，并清除已上传的资料。', '删除办赛草稿', { confirmButtonText: '删除草稿', cancelButtonText: '留下', type: 'warning' });
  } catch { return; }
  // 确认弹窗等待期间切换会话或账号时，不再执行旧任务的删除操作。
  if (stamp !== generation || identity !== useUserStore().token || task.value?.id !== id || draftActionsLocked.value) return;
  busy.value = true;
  try {
    if (saved) await deleteEventDraft(current.resultObjectId!);
    else await abandonAiTask(current.id);
    writeRecent(readRecent().filter((item) => item.id !== current.id));
    if (stamp !== generation || identity !== useUserStore().token || task.value?.id !== id) return;
    clearTimeout(taskTimer);
    task.value = undefined;
    forgetTask();
    draftReadiness.value = undefined;
    draftLines.value = [];
    preparing.value = false;
    add(saved ? '已删除这场办赛草稿。' : '已删除办赛草稿和资料，可以重新开始。');
  } catch (reason) {
    add(reason instanceof Error && reason.message ? reason.message : '办赛草稿没有删除。');
  } finally { if (stamp === generation) busy.value = false; }
}
async function deleteRecentDraft(item: RecentTask) {
  if (busy.value) return;
  let card: AiTaskCard | undefined;
  try { card = (await getAiTask(item.id)).data; } catch { add('这份办赛草稿暂时无法读取。'); return; }
  const saved = card.status === 'CREATED' && !!card.resultObjectId;
  try {
    await ElMessageBox.confirm(saved ? '将删除这场尚未发布的办赛草稿及未使用的收费设置。已有报名、付款义务或发布历史时不会删除。' : '将删除这份还没保存成赛事的办赛草稿，并清除已上传的资料。', '删除办赛草稿', { confirmButtonText: '删除草稿', cancelButtonText: '留下', type: 'warning' });
  } catch { return; }
  busy.value = true;
  try {
    if (saved) await deleteEventDraft(card.resultObjectId!);
    else await abandonAiTask(item.id);
    if (task.value?.id === item.id) { task.value = undefined; forgetTask(); draftReadiness.value = undefined; draftLines.value = []; }
    writeRecent(readRecent().filter((row) => row.id !== item.id));
    add(saved ? '已删除这场办赛草稿。' : '已删除办赛草稿和资料。');
  } catch (reason) {
    add(reason instanceof Error && reason.message ? reason.message : '办赛草稿没有删除。');
  } finally { busy.value = false; }
}
function parkCurrent() {
  const current = task.value;
  clearTimeout(taskTimer);
  if (current && current.status !== 'ABANDONED') {
    const named = draftLines.value.find((line) => line.startsWith('赛事：'));
    const label = (named ? named.slice(3) : '办赛草稿').slice(0, 40);
    writeRecent([{ id: current.id, label }, ...readRecent().filter((item) => item.id !== current.id)]);
  }
  task.value = undefined;
  forgetTask();
}
function clearConversation() {
  generation++;
  commandSequence++;
  busy.value = false;
  genericRun.value=undefined;shownGenericMessages.clear();disconnectGeneric?.();
  parkCurrent();
  turns.value = [];
  chart.value = '';
  editor.value = undefined;
  mode.value = '';
  promoteId.value = '';
  attachments.value = [];
  resetFileDrop();fileNotice.value='';
  input.value = '';
  preparing.value = false;
  taskConversation.value = false;
  forcedDraft = false;
  draftVisible.value = false;
  publishVisible.value = false;
  publishEventId.value = '';
  publicationBusy.value=false;
  draftReadiness.value = undefined;
  draftWarnings.value = [];
  suggestions.value = [];
  draftLines.value = [];
  sourceText.value = '';
  draftUnits.value=[]; draftSources.value=[];
  taskWasRestored.value = false;
  restoredProposals.clear();
  show();
}
async function startFresh() {
  const limit = opsSessionLimit.value;
  if (opsAllSessions.value.length >= limit) {
    const oldest = opsAllSessions.value[opsAllSessions.value.length - 1];
    const title = oldest?.preview || '更早的一段';
    try {
      await ElMessageBox.confirm(`问答最多保留 ${limit} 段。再开一段会删掉最早的「${title}」。`, '新会话', {
        confirmButtonText: '删掉并新开',
        cancelButtonText: '留下'
      });
    } catch {
      return;
    }
    try {
      await deleteOpsChat(oldest.sessionId);
    } catch {
      add('最早的一段没有删掉，这次没有新开。');
      return;
    }
  }
  clearConversation();
  opsSessionId.value = newRequestKey();
  opsExpiresAt.value = '';
  sessionStorage.setItem(opsStorageKey, opsSessionId.value);
  loadOpsSessions();
}
async function resumeTask(id: string) {
  historyOpen.value = false;
  clearConversation();
  rememberTask(id);
  writeRecent(readRecent().filter((item) => item.id !== id));
  taskConversation.value = true;
  const stamp=generation,identity=useUserStore().token;
  try {
    await loadTask(id);
  } catch {
    if(stamp!==generation||identity!==useUserStore().token||rememberedTask.value!==id)return;
    forgetTask();
    add('这份办赛草稿暂时无法读取。');
  }
}
async function loadOpsSessions() {
  try {
    const { data } = await listOpsChats();
    const body = data as { limit?: number; sessions?: { sessionId: string; preview: string; expiresAt: string }[] } | { sessionId: string; preview: string; expiresAt: string }[];
    const all = Array.isArray(body) ? body : body?.sessions || [];
    opsSessionLimit.value = !Array.isArray(body) && body?.limit ? body.limit : 8;
    opsAllSessions.value = all;
    const current = all.find((item) => item.sessionId === opsSessionId.value);
    opsSessions.value = all.filter((item) => item.sessionId !== opsSessionId.value);
    if (current?.expiresAt) opsExpiresAt.value = current.expiresAt;
    return current;
  } catch {
    opsSessions.value = [];
    opsAllSessions.value = [];
  }
}
async function restoreOps() {
  try {
    const { data } = await readOpsChat(opsSessionId.value);
    if (turns.value.length || task.value) return;
    opsExpiresAt.value = data.expiresAt || '';
    for (const turn of data.turns || []) turns.value.push({ text: turn.text, user: !!turn.user });
    scroll();
  } catch {
    opsExpiresAt.value = '';
  }
}
async function resumeOps(id: string) {
  historyOpen.value = false;
  clearConversation();
  opsSessionId.value = id;
  sessionStorage.setItem(opsStorageKey, id);
  try {
    const { data } = await readOpsChat(id);
    opsExpiresAt.value = data.expiresAt || '';
    for (const turn of data.turns || []) turns.value.push({ text: turn.text, user: !!turn.user });
    scroll();
  } catch {
    opsExpiresAt.value = '';
    add('这段问答已经过期或不存在。');
  }
  loadOpsSessions();
}
defineExpose({ command });
</script>
<style scoped lang="scss">
/* 核对草稿时让草稿占完整阅读区；收起后恢复对话，避免消息和固定工具把确认内容挤成一行。 */
.b-ai-window.reviewing-draft{
  >.b-ai-hold,>.b-ai-shortcuts,>.b-ai-choices{display:none;}
  .b-ai-body.with-draft{min-height:180px;}
  .b-ai-body.with-draft .b-ai-draft-panel{max-height:none;min-height:0;flex:1;overscroll-behavior:contain;scrollbar-gutter:stable;}
  &:not(.expanded) .b-ai-body.with-draft .b-ai-messages{display:none;}
  .b-ai-draft-panel>strong{display:block;position:sticky;top:-12px;padding:10px 0;background:var(--s-surface);z-index:1;}
  .b-ai-upload-note{margin-bottom:6px;}
}
@media(max-width:700px){.b-ai-window.reviewing-draft{.b-ai-body.with-draft .b-ai-messages{display:none;}.b-ai-body.with-draft .b-ai-draft-panel{width:auto;max-height:none;flex:1;}.b-ai-header{padding:12px 14px;}}}
@media(max-height:740px){.b-ai-window.reviewing-draft{.b-ai-body.with-draft{min-height:120px;}.b-ai-composer textarea{min-height:32px;}.b-ai-header{padding-top:9px;padding-bottom:9px;}}}
.b-ai-unit-review{margin:16px 0;h4{margin:0 0 8px;font-size:12px;}article{padding:10px 12px;border:1px solid var(--s-line);border-radius:12px;background:var(--s-paper);margin-top:8px;}strong{font-size:12px;}p,small{font-size:11px;line-height:1.7;overflow-wrap:anywhere;margin:6px 0;}small{color:#a44929;}}
.b-ai-launcher{width:64px!important;min-width:64px!important;height:64px!important;min-height:64px!important;display:grid!important;place-items:center;gap:0!important;border:0!important;border-radius:50%!important;background:transparent!important;padding:0!important;box-shadow:none!important;transition:transform .25s!important;&:hover{transform:translateY(-3px);}&:focus-visible{outline:3px solid #ef593655;outline-offset:3px;}}
.assistant-launcher-orb{width:54px;height:54px;max-width:54px;max-height:54px;filter:drop-shadow(0 5px 6px #bf7d3929);flex-shrink:0;object-fit:contain;pointer-events:none;user-select:none;-webkit-user-drag:none;}.assistant-header-brand{display:flex!important;gap:12px;align-items:center;>img{width:42px;height:42px;object-fit:contain;}strong{font-size:15px;}small{display:block;color:var(--s-muted);font-size:11px;margin-top:5px;}}.b-ai-header{background:var(--s-surface)!important;color:var(--s-ink)!important;border-bottom:1px solid var(--s-line)!important;}.b-ai-window{border-radius:26px!important;box-shadow:0 28px 90px #20232126!important;border:1px solid var(--s-line)!important;}.b-ai-context{background:var(--s-paper)!important;color:var(--s-ink)!important;}.b-ai-hold{font-size:10px!important;color:var(--s-muted)!important;}
@keyframes assistant-breathe{0%,100%{transform:translateY(0) rotate(-3deg);}50%{transform:translateY(-2px) rotate(3deg);}}@media(max-width:700px){.b-ai-launcher{right:16px!important;bottom:90px!important;}.b-ai-window{border-radius:25px 25px 0 0!important;}}
@media(prefers-reduced-motion:reduce){.assistant-launcher-orb{animation:none;}.b-ai-launcher{transition:none!important;&:hover{transform:none;}}}
</style>
