<template>
  <div class="app-container b-document-workspace" :class="{ embedded }">
    <div v-if="!embedded" class="b-heading">
      <div>
        <span class="b-eyebrow">组织工作台</span>
        <h1>AI办赛</h1>
        <p>把资料交给助手。你可以直接提问、补充或修改，明确要创建时它才会建立草稿。</p>
      </div>
      <router-link to="/org-desk/events"><el-button>返回赛事列表</el-button></router-link>
    </div>
    <el-alert v-if="error" :title="error" type="error" :closable="false" />

    <el-card v-if="!task" shadow="never">
      <div class="b-document-intro">
        <img src="/images/sports/assistant-orb-v2.webp" alt=""/><div><b>整理办赛材料</b>
        <p>上传规程、PDF 或图片，缺少的信息会继续向你确认。发布前由你核对。</p></div>
      </div>
      <el-form label-position="top">
        <el-form-item label="规程原文"
          ><el-input
            v-model="textGoal"
            type="textarea"
            :rows="8"
            maxlength="20000"
            placeholder="从文档或聊天记录里复制整段规程。短的办赛想法也可以贴在这里。"
        /></el-form-item>
        <el-form-item label="资料">
          <label class="document-dropzone" @dragover.prevent @drop.prevent="dropFiles"><span>＋</span><strong>选择或拖入办赛材料</strong><small>DOCX、XLSX、PDF 与图片 · 旧 DOC 请先转换</small><input type="file" multiple :disabled="busy" accept=".docx,.xlsx,.pdf,.jpg,.jpeg,.png,.webp,image/*,application/pdf" @change="pick" /></label>
          <div v-if="picked.length" class="document-files"><p>已选 {{ picked.length }} 份 · {{pickedSize}} MB</p><div v-for="(file,index) in picked" :key="file.name+file.size+file.lastModified"><span :title="file.name">{{file.name}}</span><small>{{(file.size/1024/1024).toFixed(1)}} MB</small><button type="button" :disabled="busy" :aria-label="'移除'+file.name" @click="picked.splice(index,1)">×</button></div></div>
          <p class="b-muted">最多 15 份，单份 15MB，合计 40MB；扫描 PDF 最多 15 页。点击识别前不会发送资料。</p>
        </el-form-item>
        <el-form-item>
          <el-checkbox v-model="consent">我同意把必要的办赛内容和所选资料发送到 DeepSeek。AI 不可用时仍可手动创建。</el-checkbox>
        </el-form-item>
        <div class="b-actions">
          <el-button class="b-ai-button" :disabled="!consent || !textGoal.trim()" :loading="busy" @click="startText">用这段文字办赛</el-button>
          ><el-button type="primary" :disabled="!consent || !picked.length" :loading="busy" @click="submit">识别上传资料</el-button>
        </div>
      </el-form>
    </el-card>

    <template v-else>
      <el-alert v-if="task.status === 'FAILED'" :title="task.errorMessage || '识别没有完成'" type="warning" :closable="false" />
      <div class="b-actions">
        <el-tag>{{ statusLabel(task.status) }}</el-tag>
        <el-button v-if="task.status === 'FAILED' || task.status === 'PROCESSING'" :loading="busy" @click="retry">重试</el-button>
        <el-button v-if="task.status !== 'CREATED'" @click="abandon">放弃并删除资料</el-button>
      </div>

      <div v-if="draftLines.length" class="draft-note">
        <strong>当前草稿</strong>
        <p v-for="line in draftLines" :key="line">{{ line }}</p>
      </div>

      <section v-if="draftUnits.length" class="b-section" aria-label="待核对参赛项目">
        <h3>项目 人数 名额与整单价格</h3>
        <p v-for="unit in draftUnits" :key="unit.name">{{ unit.name }} · {{ unit.seats }} · {{ unit.capacity }} · {{ unit.fee }}</p>
        <p class="b-muted">请对照原文核对。保存草稿不等于发布或实际收款，未识别费用不代表免费。</p>
      </section>
      <section v-if="draftDeclarationText" class="b-section" aria-label="参赛声明确认方式">
        <h3>原文参赛声明</h3><p>{{ draftDeclarationText }}</p>
        <el-checkbox v-if="task.status === 'PENDING_CONFIRMATION'" v-model="declarationAckRequired" :disabled="busy">要求每位参赛成员阅读并确认这份声明</el-checkbox>
        <p class="b-muted">不勾选时保留原文供阅读；确认方式由你选择。</p>
      </section>
      <div v-if="task.status === 'PENDING_CONFIRMATION'" class="b-actions">
        <el-button :disabled="busy" @click="send('请确认并保存赛事草稿')">确认保存草稿</el-button>
      </div>

      <div ref="thread" class="chat">
        <div v-for="(turn, index) in turns" :key="index" class="ask-bubble" :class="turn.role === 'user' ? 'ask-user' : 'ask-ai'">
          {{ turn.text }}
        </div>
        <div v-if="suggestions.length && task.status === 'PENDING_CONFIRMATION'" class="ask-options">
          <button v-for="suggestion in suggestions" :key="suggestion" type="button" :disabled="busy" @click="send(suggestion)">
            {{ suggestion }}
          </button>
        </div>
        <div v-if="task.status === 'PENDING_CONFIRMATION'" class="composer">
          <input v-model="draft" placeholder="直接说" :disabled="busy" @keydown.enter.prevent="sendDraft" />
          <button type="button" :disabled="busy || !draft.trim()" @click="sendDraft">发送</button>
        </div>
      </div>

      <div v-if="task.status === 'CREATED'" class="b-ai-created">
        <p>赛事草稿已保存，仍需核对项目、费用及发布条件。</p>
        <router-link :to="'/org-desk/workspace/' + task.resultObjectId"><el-button type="primary">打开赛事工作区</el-button></router-link>
      </div>
      <details v-if="extracted.length" class="ask-source">
        <summary>查看原文</summary>
        <div v-for="file in extracted" :key="file.fileIndex" class="b-section">
          <h3>{{ file.originalName || '资料' }} · {{ file.mediaKind }}</h3>
          <img v-if="previews[file.fileId]" :src="previews[file.fileId]" alt="原图" />
          <iframe
            v-else-if="file.mediaKind.startsWith('pdf') && previews[file.fileId + '-pdf']"
            :src="previews[file.fileId + '-pdf']"
            title="PDF 原文"
          />
          <p v-for="block in file.blocks" :key="block.label + block.text" class="b-muted">
            <strong>{{ block.label }}</strong> {{ block.text }}
          </p>
        </div>
      </details>
    </template>
  </div>
</template>

<script setup lang="ts" name="SportsEventFromDocument">
import { computed, nextTick, onMounted, onUnmounted, reactive, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ElMessage, ElMessageBox } from 'element-plus';
import {
  abandonAiTask,
  aiTaskFileBlob,
  getAiTask,
  retryAiTask,
  talkAiTask,
  uploadAiTask,
  startTextAiTask,
  type AiTaskCard
} from '@/api/sports/aiTask';

interface Turn {
  role: string;
  text: string;
}

const props = withDefaults(defineProps<{ embedded?: boolean; initialTaskId?: string }>(), { embedded: false });
const emit = defineEmits<{ created: [eventId: string]; taskStarted: [id: string]; expired: [] }>();
const embedded = props.embedded;
const textGoal = ref('');
const route = useRoute();
const router = useRouter();
const task = ref<AiTaskCard | null>(null);
const error = ref('');
const busy = ref(false);
const consent = ref(false);
const picked = ref<File[]>([]);
const pickedSize=computed(()=>(picked.value.reduce((n,f)=>n+f.size,0)/1024/1024).toFixed(1));
const previews = reactive<Record<string, string>>({});
const turns = ref<Turn[]>([]);
const suggestions = ref<string[]>([]);
const draftLines = ref<string[]>([]);
const draftUnits = ref<{ name: string; seats: string; capacity: string; fee: string }[]>([]);
const draftDeclarationText = ref('');
const declarationAckRequired = ref(false);
let declarationChoiceVersion = '';
const draft = ref('');
const thread = ref<HTMLElement | null>(null);
let timer = 0;

const labels: Record<string, string> = {
  name: '名称',
  location: '地点',
  projectName: '运动项目',
  feeDescription: '收费说明',
  registrationOpensAt: '报名开始',
  registrationClosesAt: '报名结束',
  startsAt: '开赛',
  endsAt: '结束',
  registrationReview: '审核',
  rulesText: '规程'
};

const extracted = computed(() => {
  if (!task.value?.extraction) return [];
  try {
    const parsed = JSON.parse(task.value.extraction) as {
      files?: Array<{ fileIndex: number; fileId: string; mediaKind: string; originalName: string; blocks: Array<{ label: string; text: string }> }>;
    };
    return parsed.files || [];
  } catch {
    return [];
  }
});

const statusLabel = (status: string) =>
  ({ UPLOADED: '已上传', PROCESSING: '识别中', PENDING_CONFIRMATION: '待确认', CREATED: '已创建', FAILED: '失败', ABANDONED: '已放弃' })[status] ||
  status;

const pick = (event: Event) => {
  const input = event.target as HTMLInputElement;
  addFiles(Array.from(input.files || []));input.value='';
};
function addFiles(incoming:File[]){if(busy.value)return;const files=[...new Map([...picked.value,...incoming].map(f=>[f.name+':'+f.size+':'+f.lastModified,f])).values()];
  if(files.length>15){error.value='最多选择15份资料，已选资料保留。';return;}
  if(incoming.some(f=>f.size>15*1024*1024)){error.value='有单份资料超过15MB，请压缩或拆分后添加。';return;}
  if(files.reduce((n,f)=>n+f.size,0)>40*1024*1024){error.value='资料合计不能超过40MB，先移除不需要的文件。';return;}
  if(incoming.some(f=>!/\.(docx|xlsx|pdf|jpg|jpeg|png|webp)$/i.test(f.name))){error.value='请选择DOCX、XLSX、PDF、JPG、PNG或WebP；旧DOC先转换。';return;}
  error.value='';picked.value=files;}
function dropFiles(event:DragEvent){addFiles(Array.from(event.dataTransfer?.files||[]));}

const unwrap = <T,>(response: { data: T }) => response.data;

const load = async (id: string) => {
  const card = unwrap((await getAiTask(id)) as { data: AiTaskCard });
  task.value = card;
  readProposal(card.proposal);
  await loadPreviews(card);
  if (card.status === 'PROCESSING' || card.status === 'UPLOADED') {
    if (!turns.value.length) turns.value = [{ role: 'ai', text: '我正在读这些资料。' }];
    window.clearTimeout(timer);
    timer = window.setTimeout(() => load(id), 2000);
  }
};

const submit = async () => {
  error.value = '';
  busy.value = true;
  try {
    const card = unwrap((await uploadAiTask(picked.value, consent.value)) as { data: AiTaskCard });
    emit('taskStarted', card.id);
    if (!embedded) await router.replace('/org-desk/events/from-document/' + card.id);
    await load(card.id);
  } catch (reason) {
    error.value = reason instanceof Error ? reason.message : '上传没有完成';
  } finally {
    busy.value = false;
  }
};

const retry = async () => {
  if (!task.value) return;
  busy.value = true;
  try {
    await retryAiTask(task.value.id);
    await load(task.value.id);
  } finally {
    busy.value = false;
  }
};

const abandon = async () => {
  if (!task.value) return;
  await ElMessageBox.confirm('放弃后删除本次原始文件和提取文字。', '放弃任务');
  await abandonAiTask(task.value.id);
  task.value = null;
  turns.value = [];
  emit('expired');
  if (!embedded) await router.replace('/org-desk/events/from-document');
};

const sendDraft = () => {
  const text = draft.value.trim();
  if (!text) return;
  draft.value = '';
  send(text);
};

const send = async (text: string) => {
  if (!task.value || busy.value) return;
  busy.value = true;
  error.value = '';
  turns.value.push({ role: 'user', text });
  scrollTalk();
  try {
    const response = unwrap(
      (await talkAiTask(task.value.id, text, task.value.version, draftDeclarationText.value ? declarationAckRequired.value : undefined)) as {
        data: { reply: string; suggestions: string[]; action: string; proposal: string; eventId: string | null; created: boolean };
      }
    );
    readProposal(response.proposal);
    const savedUser = [...turns.value].reverse().find((turn) => turn.role === 'user');
    const last = turns.value.at(-1);
    if (!savedUser || savedUser.text !== text) {
      turns.value.push({ role: 'user', text });
      if (response.reply) turns.value.push({ role: 'ai', text: response.reply });
    } else if (response.reply && last?.text !== response.reply) {
      turns.value.push({ role: 'ai', text: response.reply });
    }
    scrollTalk();
    if (response.created && response.eventId) {
      ElMessage.success('已创建草稿');
      task.value = { ...task.value!, status: 'CREATED', resultObjectId: response.eventId };
      emit('created', response.eventId);
      if (!embedded) await router.push('/org-desk/workspace/' + response.eventId);
    } else {
      // Text edits advance the persisted revision. The next human confirmation
      // must bind to the refreshed candidate, including prices and declaration.
      await load(task.value!.id);
    }
  } catch (reason) {
    turns.value.push({ role: 'ai', text: reason instanceof Error ? reason.message : '助手暂时连不上，草稿没有改。请再发一次。' });
    scrollTalk();
  } finally {
    busy.value = false;
  }
};

const readProposal = (raw: string | null) => {
  suggestions.value = [];
  draftLines.value = [];
  if (!raw) return;
  try {
    const parsed = JSON.parse(raw) as {
      dialogue?: Turn[];
      suggestions?: string[];
      event?: Record<string, { value?: string }>;
      units?: Array<{ name?: { value?: string }; entryType?: { value?: string }; minMembers?: { value?: number }; maxMembers?: { value?: number }; limitCount?: { value?: number; status?: string }; feeAmount?: { value?: string | number; status?: string }; feeBasis?: { value?: string; status?: string } }>;
    };
    turns.value = parsed.dialogue || [];
    suggestions.value = parsed.suggestions || [];
    const event = parsed.event || {};
    draftDeclarationText.value = event.declarationText?.value || '';
    const choiceVersion = `${task.value?.id}:${task.value?.version}:${draftDeclarationText.value}`;
    if (choiceVersion !== declarationChoiceVersion) { declarationAckRequired.value = false; declarationChoiceVersion = choiceVersion; }
    draftUnits.value = (parsed.units || []).map((unit) => ({
      name: unit.name?.value || '项目名称待补',
      seats: unit.entryType?.value === 'pair' ? '每单2人' : unit.entryType?.value === 'individual' ? '每单1人' : unit.minMembers?.value && unit.maxMembers?.value ? `每单${unit.minMembers.value}至${unit.maxMembers.value}人` : '每单人数待补',
      capacity: unit.limitCount?.status === 'conflict' ? '名额有冲突' : unit.limitCount?.value ? `限${unit.limitCount.value}单` : '名额待补',
      fee: unit.feeAmount?.status === 'conflict' || unit.feeBasis?.status === 'conflict' ? '费用有冲突' : unit.feeBasis?.value === 'order' && unit.feeAmount?.value !== '' && unit.feeAmount?.value != null ? `每单${unit.feeAmount.value}元` : '整单价格待核对'
    }));
    draftLines.value = Object.keys(labels)
      .map((key) => {
        const value = event[key]?.value || '';
        if (!value) return '';
        const shown = key === 'registrationReview' ? (value === 'manual' ? '要审核' : value === 'none' ? '不审核' : value) : value;
        return `${labels[key]}：${shown.length > 80 ? shown.slice(0, 80) + '…' : shown}`;
      })
      .filter(Boolean);
    const names = (parsed.units || []).map((unit) => unit.name?.value || '').filter(Boolean);
    if (names.length) draftLines.value.push(`项目：${names.join('、')}`);
    scrollTalk();
  } catch {
    error.value = '草稿暂时读不出来';
  }
};

const scrollTalk = () => {
  nextTick(() => {
    const node = thread.value;
    if (node) node.scrollTop = node.scrollHeight;
  });
};

const loadPreviews = async (card: AiTaskCard) => {
  for (const file of card.files) {
    if (!['jpeg', 'png', 'webp', 'pdf-text', 'pdf-scan'].includes(file.mediaKind)) continue;
    const blob = (await aiTaskFileBlob(card.id, file.fileId)) as unknown as Blob;
    const url = URL.createObjectURL(blob);
    if (file.mediaKind.startsWith('pdf')) previews[file.fileId + '-pdf'] = url;
    else previews[file.fileId] = url;
  }
};

onMounted(async () => {
  const taskId = route.params.taskId;
  const resumeId = embedded ? props.initialTaskId : typeof taskId === 'string' ? taskId : undefined;
  if (resumeId) {
    try {
      await load(resumeId);
      if (task.value?.status === 'CREATED' && task.value.resultObjectId) emit('created', task.value.resultObjectId);
      if (task.value?.status === 'ABANDONED') {
        task.value = null;
        emit('expired');
      }
    } catch {
      task.value = null;
      error.value = '先前任务已不可用，或当前身份无权读取。可以重新开始办赛。';
      emit('expired');
    }
  }
});
onUnmounted(() => {
  window.clearTimeout(timer);
  Object.values(previews).forEach(URL.revokeObjectURL);
});
const startText = async () => {
  if (!textGoal.value.trim() || !consent.value || busy.value) return;
  busy.value = true;
  error.value = '';
  try {
    const card = unwrap((await startTextAiTask(consent.value, textGoal.value.trim())) as { data: AiTaskCard });
    emit('taskStarted', card.id);
    if (!embedded) await router.replace('/org-desk/events/from-document/' + card.id);
    await load(card.id);
  } catch (reason) {
    error.value = reason instanceof Error ? reason.message : '文字办赛暂时不可用';
  } finally {
    busy.value = false;
  }
};
</script>

<style scoped>
.draft-note {
  max-width: 720px;
  margin-bottom: 12px;
  color: #4d645c;
}
.chat {
  max-width: 720px;
  max-height: 70vh;
  overflow: auto;
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding-bottom: 8px;
}
.ask-bubble {
  border-radius: 16px;
  padding: 12px 14px;
  white-space: pre-wrap;
}
.ask-ai {
  align-self: flex-start;
  max-width: 92%;
  background: #fff;
  border: 1px solid #e2e9e4;
}
.ask-user {
  align-self: flex-end;
  max-width: 80%;
  background: var(--el-color-primary-light-9);
}
.ask-options {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.ask-options button,
.composer button {
  border: 0;
  background: var(--b-green);
  color: #fff;
  border-radius: 999px;
  padding: 6px 12px;
  cursor: pointer;
}
.ask-options button {
  background: #fff;
  color: #243b36;
  border: 1px solid #c5d5ce;
}
.composer {
  display: flex;
  gap: 8px;
  position: sticky;
  bottom: 0;
  background: #f4f6f5;
  padding-top: 8px;
}
.composer input {
  flex: 1;
  border: 1px solid #c5d5ce;
  border-radius: 999px;
  padding: 10px 14px;
  background: #fff;
  color: #243b36;
}
.composer button:disabled,
.ask-options button:disabled {
  opacity: 0.45;
  cursor: default;
}
.ask-source {
  margin-top: 18px;
}
.ask-source img {
  max-width: 100%;
}
</style>
<style scoped lang="scss">
.b-document-intro{display:flex;align-items:center;gap:18px;padding:25px!important;background:linear-gradient(135deg,#fff7ef,var(--s-surface))!important;border-radius:23px!important;margin-bottom:24px;>img{width:68px;height:68px;object-fit:contain;}b{font-size:23px!important;letter-spacing:-.6px;color:var(--s-ink)!important;}p{font-size:12px;color:var(--s-muted);line-height:1.8;margin:10px 0 0;}}.document-dropzone{position:relative;width:100%;box-sizing:border-box;border:1px dashed #cfd4ce;border-radius:21px;padding:28px;display:grid;place-items:center;gap:10px;background:var(--s-paper);cursor:pointer;>span{font-size:27px;color:var(--s-primary);}strong{font-size:14px;color:var(--s-ink);}small{font-size:11px;color:var(--s-muted);text-align:center;}input{position:absolute;inset:0;width:100%;height:100%;opacity:0;cursor:pointer;}&:focus-within{outline:3px solid #ef593655;outline-offset:3px;}}.document-files{width:100%;min-width:0;margin:14px 0;max-height:175px;overflow:auto;border:1px solid var(--s-line);border-radius:15px;padding:10px 15px;box-sizing:border-box;>p{font-size:11px;color:var(--s-muted);margin:4px 0 12px;}div{display:flex;align-items:center;gap:12px;padding:8px 0;min-width:0;span{min-width:0;flex:1;white-space:nowrap;text-overflow:ellipsis;overflow:hidden;font-size:12px;color:var(--s-ink);}small{white-space:nowrap;color:var(--s-muted);font-size:10px;}button{border:0;background:var(--s-paper);color:var(--s-muted);border-radius:8px;width:25px;height:25px;cursor:pointer;}}}.ask-user{background:var(--s-ink)!important;color:white!important;}.ask-ai{background:var(--s-surface)!important;border-color:var(--s-line)!important;color:var(--s-ink)!important;}.composer{background:var(--s-paper)!important;padding:15px;border-radius:18px;input{border-color:var(--s-line)!important;color:var(--s-ink)!important;}button{background:var(--s-primary)!important;border-color:var(--s-primary)!important;}}@media(max-width:600px){.b-document-intro{padding:20px!important;gap:12px;align-items:flex-start;>img{width:43px;height:43px;}b{font-size:19px!important;}}.document-dropzone{padding:25px 15px;}.composer{padding:10px;}}
</style>
