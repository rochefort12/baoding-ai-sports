<template>
  <section data-testid="material-studio" class="material-studio" :aria-busy="busy || loading">
    <header class="studio-heading"><div><span class="studio-kicker">赛事创作台</span><h2>赛事材料</h2><p>策划、现场脚本、赛事公告与宣传文案，保存在这场赛事里。</p></div><div class="studio-heading-art"><span class="studio-badge">私有草稿</span><img src="/images/sports/material-notes-v1.png" alt="" width="88" height="88" decoding="async" draggable="false"/></div></header>
    <div v-if="loadError" class="studio-error" role="alert">{{ loadError }} <button @click="load">重新读取</button></div>
    <nav class="studio-tabs" aria-label="文稿类型"><button v-for="item in tabs" :key="item.key" :data-testid="`material-tab-${item.key}`" :aria-pressed="kind === item.key" :class="{ active: kind === item.key }" :disabled="busy" @click="select(item.key)"><ConsumerIcon :name="item.icon" />{{ item.label }}</button></nav>
    <div class="studio-grid">
      <details class="studio-tools" :open="!compactTools"><summary class="studio-tools-toggle">生成或调整文稿 <span>补充要求、基础模板与赛事资料</span></summary>
        <div class="studio-tool-card"><img class="sport-assistant-mark sport-assistant-mark--card" src="/images/sports/assistant-orb-v2.webp" alt="" width="32" height="32" draggable="false"/><h3>{{ selected.label }}助手</h3><p>{{ selected.note }}</p><label for="material-note">补充要求 <small>选填</small></label><textarea id="material-note" v-model="note" rows="4" maxlength="1000" :disabled="busy" placeholder="例如：面向首次参赛者，上午报到，主持语气简洁有活力"/>
          <label class="studio-consent"><input v-model="consent" type="checkbox" data-testid="material-consent" :disabled="busy"/>同意将必要赛事信息发送到 DeepSeek 生成文稿</label>
          <button data-testid="material-generate" class="studio-primary" :disabled="!workspace || !consent || busy || dirty || workspace.aiAvailable === false" @click="generate"><img v-if="!busy" class="sport-assistant-mark" src="/images/sports/assistant-orb-v2.webp" alt="" width="22" height="22" draggable="false"/>{{ busy ? '正在生成…' : '生成文稿' }}</button>
          <p v-if="workspace?.aiAvailable === false" class="studio-callout">AI 生成暂不可用，可以使用模板或手动编辑。已保存的草稿可继续使用。</p><p v-else-if="dirty" class="studio-callout">先保存或放弃当前修改，再生成新稿，避免覆盖你的编辑。</p>
          <button data-testid="material-template" class="studio-secondary" :disabled="!workspace || busy" @click="useTemplate">使用基础模板</button><small class="studio-hint">模板按赛事资料整理，不调用 AI。</small>
        </div>
        <details class="studio-facts"><summary>本次采用的赛事资料</summary><dl v-if="workspace"><dt>赛事</dt><dd>{{workspace.facts.name || '待确认'}}</dd><dt>时间</dt><dd>{{workspace.facts.when || '待确认'}}</dd><dt>地点</dt><dd>{{workspace.facts.where || '待确认'}}</dd><dt>项目</dt><dd>{{workspace.facts.project || '待确认'}}</dd></dl></details>
      </details>
      <div class="studio-editor">
        <div class="studio-document-bar"><span>{{ originLabel }}<small v-if="saved"> · 版本 {{ saved.version }} · {{ businessTime(saved.updatedAt) }}</small></span><button :disabled="!workspace || busy" @click="refreshFacts">更新赛事资料</button></div>
        <p v-if="saved && workspace && saved.factDigest !== workspace.factDigest" class="studio-callout">赛事资料已变化。这份旧稿保留，请核对日期、费用与报名安排后再保存。</p>
        <p v-if="error" class="studio-error" role="alert">{{error}}</p><template v-if="!preview"><label class="sr-only" for="material-title">文稿标题</label><textarea id="material-title" data-testid="material-title" v-model="title" class="studio-title" rows="2" maxlength="200" :disabled="busy || loading" placeholder="填写文稿标题"/></template><h3 v-else-if="!hasMatchingHeading" class="studio-title-read">{{title || selected.label}}</h3>
        <div class="studio-view-switch"><button :class="{active:!preview}" @click="preview=false">编辑正文</button><button :class="{active:preview}" @click="preview=true">阅读预览</button><span>{{content.length.toLocaleString()}} / 10,000 字</span></div>
        <AssistantMarkdown v-if="preview" data-testid="material-preview" class="studio-read material-markdown" :text="content"/><textarea v-else data-testid="material-content" v-model="content" class="studio-body" maxlength="10000" :disabled="busy || loading" placeholder="编辑 Markdown 原文：支持标题、表格、清单和引用。点击阅读预览查看排版。正文最多 10000 字。" aria-label="文稿正文"/>
        <footer class="studio-editor-footer"><div><span>{{dirty ? '有未保存修改' : saved ? '已保存到本赛事' : '尚未保存'}}</span><small>保存不等于发布，公告不会自动发送。</small></div><div><button :disabled="!content" @click="download">下载文稿</button><button :disabled="!content" @click="copy">复制</button><button data-testid="material-save" class="studio-primary" :disabled="!workspace || !title.trim() || !content.trim() || busy || !dirty" @click="save">保存草稿</button></div></footer>
        <details v-if="saved?.history?.length" class="studio-history"><summary>历史版本（{{saved.history.length}}）</summary><button v-for="item in saved.history" :key="item.version" :disabled="busy" @click="restore(item)">版本 {{item.version}} · {{businessTime(item.updatedAt)}} · {{item.source === 'ai' ? 'AI草稿' : '人工编辑'}}<span>载入编辑 →</span></button></details>
      </div>
    </div>
  </section>
</template>
<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { onBeforeRouteLeave, onBeforeRouteUpdate } from 'vue-router';
import { ElMessage, ElMessageBox } from 'element-plus';
import { useMediaQuery } from '@vueuse/core';
import AssistantMarkdown from '@/components/shared/AssistantMarkdown.vue';
import '@/assets/styles/material-markdown.scss';
import '@/assets/styles/material-studio.scss';
import { businessTime } from '@/utils/business';
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import { getEventMaterials, writeEventMaterial, type EventMaterial, type MaterialKind, type MaterialWorkspace } from '@/api/sports/organizerMaterials';
const props=defineProps<{eventId:string}>();
const tabs=[{key:'plan' as MaterialKind,label:'执行策划',icon:'file',note:'分工、资源、风险与赛前到赛后的执行清单。'}, {key:'script' as MaterialKind,label:'现场脚本',icon:'calendar',note:'主持串词、现场节点与工作人员提示。'}, {key:'announcement' as MaterialKind,label:'赛事公告',icon:'bell',note:'面向参赛者的时间、地点、报名和提醒。'}, {key:'promotion' as MaterialKind,label:'宣传文案',icon:'events',note:'社群邀请与分享文案，保留真实赛事安排。'}];
const workspace=ref<MaterialWorkspace>(),kind=ref<MaterialKind>('plan'),title=ref(''),content=ref(''),note=ref(''),consent=ref(false),busy=ref(false),loading=ref(false),error=ref(''),loadError=ref(''),preview=ref(false),templateUsed=ref(false);
const selected=computed(()=>tabs.find(t=>t.key===kind.value)!);const saved=computed(()=>workspace.value?.materials[kind.value]);
const compactTools=useMediaQuery('(max-width:760px)');
const hasMatchingHeading=computed(()=>content.value.trimStart().split('\n')[0].replace(/^#\s+/, '').trim()===title.value.trim()&&content.value.trimStart().startsWith('# '));
const dirty=computed(()=>title.value!==(saved.value?.title||'')||content.value!==(saved.value?.content||''));
const originLabel=computed(()=>templateUsed.value?'基础模板 · 可编辑':dirty.value?'人工编辑':saved.value?.source==='ai'?'AI草稿 · 待负责人核对':'人工草稿');
let sequence=0;
function hydrate(){title.value=saved.value?.title||'';content.value=saved.value?.content||'';templateUsed.value=false;error.value='';preview.value=!!content.value.trim();}
async function confirmDiscard(){if(!dirty.value)return true;try{await ElMessageBox.confirm('当前修改还没有保存，放弃后继续？','保留你的编辑',{confirmButtonText:'放弃修改',cancelButtonText:'继续编辑',type:'warning'});return true;}catch{return false;}}
async function select(next:MaterialKind){if(next===kind.value||!await confirmDiscard())return;kind.value=next;hydrate();}
async function load(){const stamp=++sequence;loading.value=true;loadError.value='';try{const r=await getEventMaterials(props.eventId);if(stamp!==sequence)return;workspace.value=r.data;hydrate();}catch{if(stamp===sequence)loadError.value='文稿工作台读取失败，当前编辑内容保留。';}finally{if(stamp===sequence)loading.value=false;}}
async function refreshFacts(){if(!await confirmDiscard())return;await load();}
function inputs(){return {eventId:props.eventId,kind:kind.value,expectedVersion:saved.value?.version||0,factDigest:workspace.value!.factDigest};}
async function save(){if(!workspace.value||busy.value)return;busy.value=true;error.value='';try{const r=await writeEventMaterial('save',{...inputs(),title:title.value,content:content.value});workspace.value.materials[kind.value]=r.data.result;hydrate();ElMessage.success('草稿已保存，尚未发布');}catch{error.value='保存未完成，当前编辑内容保留。若提示版本或赛事资料变化，请先下载手稿，再更新资料核对。';}finally{busy.value=false;}}
async function generate(){if(!workspace.value||busy.value||dirty.value||!consent.value)return;busy.value=true;error.value='';try{const r=await writeEventMaterial('generate',{...inputs(),note:note.value,consent:'confirmed'});workspace.value.materials[kind.value]=r.data.result;hydrate();ElMessage.success('AI草稿已保存，请核对后使用');}catch{error.value='AI文稿未完成，已保存材料和当前内容保留。可以重试或使用基础模板。';}finally{busy.value=false;}}
async function useTemplate(){if(!workspace.value||!await confirmDiscard())return;const f=workspace.value.facts,missing='【待主办方确认】',name=f.name||missing;
const base=`赛事：${name}\n时间：${f.when||missing}\n地点：${f.where||missing}\n运动项目：${f.project||missing}\n履约联系：${f.contact?.trim()||missing}\n收费说明：${f.feeDescription||missing}`;
const sections:Record<MaterialKind,string>={plan:`## 一、赛事安排\n${base}\n\n## 二、负责人及分工\n- 总负责人：${missing}\n- 报到与资格核对：${missing}\n- 场地、器材与裁判：${missing}\n- 现场应急联系及处置：${missing}\n\n## 三、执行清单\n### 赛前\n- 核对正式规则、场地及人员安排\n- 确认报名名单、收款和资格状态\n- 告知参赛者时间与报到要求\n### 比赛日\n- 逐人报到，核实名单与声明\n- 人工确认场次和球场；变更后通知受影响人员\n- 记录实际比分，保留争议与处理依据\n### 赛后\n- 负责人确认正式结果及获奖依据\n- 处理退款、投诉和必要更正\n\n## 四、资源与风险\n场地、器材、医疗/应急及天气预案：${missing}`,script:`## 现场流程\n${base}\n\n| 节点 | 主持串词 | 工作人员提示 |\n| --- | --- | --- |\n| 报到 | 欢迎参加${name}，请按通知办理报到。 | 核实本人及名单，异常联系负责人。 |\n| 开场 | 欢迎各位运动伙伴。今天的比赛安排以现场负责人确认的赛程为准。 | 确认场地、器材及裁判到位。 |\n| 比赛 | 请参赛者关注场次通知，提前做好准备。 | 人工核对场次、球场及时间。 |\n| 颁奖 | 感谢每位参赛者与工作人员的投入。获奖名单以正式赛果为准。 | 负责人确认结果后再宣读获奖名单。 |\n| 收尾 | 本场赛事成绩和办理进度可在平台查询。 | 核对遗留物品、退款与投诉待办。 |\n\n开场/颁奖时间、嘉宾及具体名单：${missing}`,announcement:`## ${f.cancelled?'赛事取消通知':'参赛者须知'}\n${base}\n\n${f.cancelled?'本赛事已取消，请关注承办方关于后续处理的通知。':'请在报名截止前完成本人资料与声明确认，提交后的收费报名请按实际付款指引办理。'}\n\n### 需要你确认\n- 报到时间、地点及携带材料：${missing}\n- 正式比赛规则：${f.rules||missing}\n- 交通、停车与现场联系：${missing}\n\n本稿为待核对公告，保存不会自动发布或发送。`,promotion:`## ${name}\n${base}\n\n${f.cancelled?'赛事已取消，请联系承办方了解后续安排。':'选择报名项目，核对参赛人数、时间和规则后提交。'}\n\n${f.published&&!f.cancelled?`赛事详情：${location.origin}/public/events/${props.eventId}`:'赛事尚未公开，报名链接将在正式发布后可用。'}\n\n报名安排与费用以平台最新正式资料为准。`};
title.value=`${name} · ${selected.value.label}`.slice(0,200);content.value=sections[kind.value];templateUsed.value=true;preview.value=true;}
async function restore(item:Omit<EventMaterial,'history'>){if(!await confirmDiscard())return;title.value=item.title;content.value=item.content;templateUsed.value=false;preview.value=false;ElMessage.info('旧版本已载入编辑，保存后成为新版本');}
function download(){const b=new Blob([`# ${title.value}\n\n${content.value}\n\n---\n工作草稿，尚未自动发布。导出时间：${new Date().toLocaleString('zh-CN')}`],{type:'text/markdown;charset=utf-8'});const u=URL.createObjectURL(b),a=document.createElement('a');a.href=u;a.download=(title.value||selected.value.label)+'.md';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000);}
async function copy(){try{await navigator.clipboard.writeText(`${title.value}\n\n${content.value}`);ElMessage.success('已复制，尚未发送');}catch{ElMessage.info('请在编辑区选中文字复制');}}
const beforeUnload=(e:BeforeUnloadEvent)=>{if(dirty.value){e.preventDefault();e.returnValue='';}};window.addEventListener('beforeunload',beforeUnload);onBeforeUnmount(()=>{++sequence;window.removeEventListener('beforeunload',beforeUnload);});onBeforeRouteLeave(()=>confirmDiscard());onBeforeRouteUpdate((to,from)=>to.query.task!==from.query.task||to.params.eventId!==from.params.eventId?confirmDiscard():true);watch(()=>props.eventId,load,{immediate:true});
</script>
