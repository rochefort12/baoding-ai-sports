<template>
  <div class="organizer-dashboard b-operations">
    <header class="organizer-heading"><div><span class="organizer-kicker">主办方工作台</span><h1>赛事与待办</h1><p>查看报名进度，处理待办，准备赛事材料。</p></div><div class="organizer-create"><router-link to="/org-desk/events/from-document" class="organizer-primary"><img class="sport-assistant-mark" src="/images/sports/assistant-orb-v2.webp" alt="" width="22" height="22" draggable="false"/>准备赛事</router-link><router-link to="/org-desk/events" class="organizer-secondary">管理赛事 →</router-link></div></header>
    <p v-if="error" class="organizer-error" role="alert">{{error}} <button @click="load">重新读取</button></p>
    <section class="organizer-stat-row"><article v-for="(metric,index) in metrics" :key="metric.label" class="organizer-stat" :class="{featured:index===0}"><span>{{metric.label}}</span><strong>{{loading || !snapshot ? '—' : metric.value}}<small>{{metric.unit}}</small></strong><p>{{metric.note}}</p></article></section>
    <div class="organizer-main">
      <section class="organizer-events"><header class="organizer-section-heading"><div><h2>正在推进</h2><p v-if="snapshot">更新于 {{showTime(snapshot.refreshedAt)}}</p></div><button :disabled="loading" class="organizer-text-button" @click="load">{{loading?'读取中…':'刷新'}}</button></header>
        <nav class="organizer-filters" aria-label="赛事状态筛选"><button v-for="filter in filters" :key="filter.key" :class="{active:stage===filter.key}" :aria-pressed="stage===filter.key" @click="stage=filter.key">{{filter.label}}<small>{{countStage(filter.key)}}</small></button></nav>
        <div v-if="loading" class="organizer-empty" role="status">正在读取当前组织赛事…</div>
        <div v-else-if="!filtered.length" class="organizer-empty"><ConsumerIcon name="events"/><h3>{{error?'赛事读取未完成':'这里还没有赛事'}}</h3><p>{{error?'刷新后再继续，当前数量不作估算。':'上传规程或从一个办赛想法开始，先保存草稿再完善安排。'}}</p><router-link to="/org-desk/events/from-document" class="organizer-primary">开始办赛</router-link></div>
        <article v-for="event in filtered.slice(0,6)" :key="event.id" class="organizer-event-card"><OrganizerEventCover :file-id="event.bannerFileId"/><div class="organizer-event-info"><span class="organizer-status" :class="event.phase">{{status(event)}}</span><router-link :to="'/org-desk/workspace/'+event.id"><h3>{{event.name || '未命名赛事'}}</h3></router-link><p>{{showTime(event.startsAt)}} · {{event.location || '地点待完善'}}</p><div v-if="stats(event.id)" class="organizer-event-progress"><span>报名 {{stats(event.id)!.occupied}} / {{stats(event.id)!.capacity}} 组（单）</span><progress :max="Math.max(1,stats(event.id)!.capacity)" :value="stats(event.id)!.occupied" aria-label="已占报名名额"/></div><div class="organizer-event-actions"><router-link :to="'/org-desk/workspace/'+event.id">进入工作区 →</router-link><router-link :to="'/org-desk/workspace/'+event.id+'?task=materials'">策划与文稿</router-link><router-link :to="'/org-desk/workspace/'+event.id+'?task=publication'">封面与发布</router-link></div></div></article>
      </section>
      <aside class="organizer-aside"><section class="organizer-todos"><header class="organizer-section-heading"><h2>需要你处理</h2><span>{{todos.reduce((n,t)=>n+t.count,0)}} 项</span></header><p v-if="!snapshot" class="organizer-note">{{error?'待办暂未读到，请重试。':'正在整理待办…'}}</p><div v-else-if="!todos.length" class="organizer-todo-clear"><span>✓</span><h3>当前待办已清</h3><p>可以继续完善赛事安排与宣传材料。</p></div><router-link v-for="todo in todos.slice(0,6)" :key="todo.id+todo.task" class="organizer-todo" :to="'/org-desk/workspace/'+todo.id+'?task=registrations&filter='+todo.task"><span class="organizer-todo-icon">{{todo.icon}}</span><div><strong>{{todo.label}}</strong><small>{{todo.name}}</small></div><b>{{todo.count}}</b><span>›</span></router-link><p class="organizer-note">付款声明需要核对实际到账；资金操作在报名详情中办理。</p></section>
        <section class="organizer-assistant"><img src="/images/sports/assistant-orb-v2.webp" alt="" draggable="false"/><h2>赛事助手</h2><p>整理办赛资料、查看待办或准备文稿。</p><button @click="command('AI办赛')">整理办赛资料 <span>↗</span></button><button @click="command('运营分析')">查看运营待办 <span>↗</span></button><router-link v-if="filtered[0]" :to="'/org-desk/workspace/'+filtered[0].id+'?task=materials'">写策划、脚本和公告 <span>↗</span></router-link></section>
      </aside>
    </div>
    <section class="organizer-trend"><header class="organizer-section-heading"><div><h2>近 7 日报名</h2><p>按整单最近一次正式提交日期统计</p></div><span>正式提交</span></header><div v-if="snapshot" class="organizer-trend-bars"><div v-for="day in trend" :key="day.date"><strong>{{day.count}}</strong><i :style="{height:(day.count?Math.max(5,(day.count/trendMax)*86):2)+'px'}"/><small>{{day.date.slice(5)}}</small></div></div><p v-else class="organizer-note">报名统计尚未读到。</p></section>
  </div>
</template>
<script setup lang="ts" name="OrganizationDesk">
import { computed, inject, onMounted, ref, watch } from 'vue';
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import OrganizerEventCover from '@/components/business/OrganizerEventCover.vue';
import { listManagedEvents, phaseLabel, publicationLabel, showTime, type EventCard } from '@/api/sports/event';
import { getOperationsSummary, type OperationsSnapshot } from '@/api/sports/desk';
import { businessAiKey, businessRevisionKey } from '@/utils/businessAi';
const command = inject(businessAiKey, () => {}),
  revision = inject(businessRevisionKey, ref(0));
const rows = ref<EventCard[]>([]),
  snapshot = ref<OperationsSnapshot>(),
  loading = ref(true),
  error = ref(''),
  stage = ref('active');
const filters = [
  { key: 'active', label: '当前赛事' },
  { key: 'registration', label: '报名中' },
  { key: 'ongoing', label: '举办中' },
  { key: 'draft', label: '待完善' }
];
const match = (e: EventCard, key: string) =>
  e.holdingStatus === 'normal' &&
  (key === 'active'
    ? e.phase !== 'finished'
    : key === 'draft'
      ? e.publicationStatus === 'draft'
      : e.publicationStatus === 'published' && e.phase === key);
const countStage = (key: string) => rows.value.filter((e) => match(e, key)).length;
const filtered = computed(() =>
  rows.value.filter((e) => match(e, stage.value)).sort((a, b) => (a.startsAt || '9999').localeCompare(b.startsAt || '9999'))
);
const stats = (id: string) => snapshot.value?.events.find((e) => e.eventId === id);
const total = (key: 'currentEntries' | 'pendingReview' | 'declaredEntries' | 'pendingFunds') =>
  snapshot.value?.events.reduce((sum, e) => sum + e[key], 0) || 0;
const metrics = computed(() => [
  { label: '报名中的赛事', value: countStage('registration'), unit: '场', note: '已发布 · 报名窗口开放' },
  { label: '正在举办', value: countStage('ongoing'), unit: '场', note: '已发布 · 比赛进行中' },
  { label: '正式报名', value: total('currentEntries'), unit: '单', note: '当前已提交或已通过，含历史赛事' },
  { label: '待审核', value: total('pendingReview'), unit: '单', note: '当前赛事 · 资格待确认' }
]);
const status = (e: EventCard) => (e.publicationStatus === 'published' ? phaseLabel(e.phase) : publicationLabel(e.publicationStatus));
const trend = computed(() => {
  const days = new Map<string, number>();
  for (const e of snapshot.value?.events || []) for (const d of e.trend) days.set(d.date, (days.get(d.date) || 0) + d.count);
  return [...days].sort(([a], [b]) => a.localeCompare(b)).map(([date, count]) => ({ date, count }));
});
const trendMax = computed(() => Math.max(1, ...trend.value.map((d) => d.count)));
const todos = computed(() => {
  const result: { id: string; name: string; task: string; count: number; icon: string; label: string }[] = [];
  for (const e of snapshot.value?.events || []) {
    const name = rows.value.find((row) => row.id === e.eventId)?.name || '未命名赛事';
    if (e.pendingReview) result.push({ id: e.eventId, name, task: 'submitted', count: e.pendingReview, icon: '◷', label: '资格待审核' });
    if (e.declaredEntries) result.push({ id: e.eventId, name, task: 'declared', count: e.declaredEntries, icon: '¥', label: '付款声明待核对' });
    if (e.pendingFunds) result.push({ id: e.eventId, name, task: 'refund', count: e.pendingFunds, icon: '↺', label: '资金待收尾' });
  }
  return result;
});
let sequence = 0;
async function load() {
  const stamp = ++sequence;
  loading.value = true;
  error.value = '';
  try {
    const [events, ops] = await Promise.all([listManagedEvents(), getOperationsSummary()]);
    if (stamp !== sequence) return;
    rows.value = events.data;
    snapshot.value = ops.data;
  } catch {
    if (stamp !== sequence) return;
    rows.value = [];
    snapshot.value = undefined;
    error.value = '组织运营数据读取失败，请刷新重试。';
  } finally {
    if (stamp === sequence) loading.value = false;
  }
}
onMounted(load);
watch(revision, load);
</script>
<style scoped lang="scss">
.organizer-dashboard{color:var(--s-ink);max-width:1400px;margin:0 auto;}.organizer-heading{display:flex;justify-content:space-between;align-items:center;gap:24px;margin:8px 0 28px;h1{font-size:32px;letter-spacing:-1.3px;margin:12px 0;}p{font-size:13px;color:var(--s-muted);line-height:1.7;}}.organizer-kicker{color:var(--s-primary);font-size:12px;font-weight:650;}.organizer-create{display:flex;gap:10px;flex-wrap:wrap;}.organizer-primary,.organizer-secondary{display:inline-flex;align-items:center;justify-content:center;padding:13px 20px;border-radius:14px;font-size:13px;font-weight:650;text-decoration:none;transition:transform .2s,box-shadow .2s;}.organizer-primary{background:var(--s-primary);color:white!important;box-shadow:0 6px 16px #ef59361c;}.organizer-secondary{background:var(--s-surface);color:var(--s-ink);border:1px solid var(--s-line);}.organizer-primary:hover,.organizer-secondary:hover{transform:translateY(-2px);}.organizer-stat-row{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:26px;}.organizer-stat{padding:24px;background:var(--s-surface);border-radius:24px;border:1px solid var(--s-line);>span{font-size:13px;color:var(--s-muted);}strong{display:block;font-size:43px;letter-spacing:-1.8px;margin:16px 0 10px;line-height:1;small{font-size:13px;margin-left:8px;letter-spacing:0;font-weight:500;}}p{font-size:11px;color:var(--s-muted);line-height:1.5;margin:0;}&.featured{background:var(--s-ink);color:white;>span,p{color:#c4cac4;}strong small{color:#c4cac4;}}}.organizer-main{display:grid;grid-template-columns:minmax(0,1fr) 310px;gap:26px;}.organizer-events,.organizer-todos,.organizer-trend{background:var(--s-surface);border:1px solid var(--s-line);border-radius:26px;padding:26px;}.organizer-section-heading{display:flex;align-items:center;justify-content:space-between;gap:15px;margin-bottom:19px;h2{font-size:19px;letter-spacing:-.4px;margin:0;}p{font-size:11px;color:var(--s-muted);margin:7px 0 0;}>span{font-size:11px;color:var(--s-muted);}}.organizer-text-button{border:0;background:none;color:var(--s-muted);cursor:pointer;font-size:12px;}.organizer-filters{display:flex;gap:7px;overflow:auto;margin-bottom:22px;padding-bottom:2px;button{border:0;background:transparent;white-space:nowrap;padding:10px 12px;border-radius:13px;font-size:12px;color:var(--s-muted);cursor:pointer;small{margin-left:7px;opacity:.6;}&.active{color:var(--s-ink);font-weight:650;background:var(--s-paper);}}}.organizer-event-card{display:grid;grid-template-columns:155px minmax(0,1fr);gap:21px;padding:0 0 24px;margin-bottom:24px;border-bottom:1px solid var(--s-line);&:last-child{padding-bottom:0;margin-bottom:0;border-bottom:0;}}.organizer-event-info{min-width:0;h3{font-size:18px;margin:10px 0 8px;line-height:1.45;letter-spacing:-.4px;overflow-wrap:anywhere;}p{color:var(--s-muted);font-size:12px;line-height:1.6;margin:8px 0;}}.organizer-status{font-size:10px;background:var(--s-paper);color:var(--s-muted);padding:5px 8px;border-radius:6px;display:inline-block;&.registration{background:#eff6e9;color:#53733c;}&.ongoing{background:#fff1e6;color:#ac5834;}}.organizer-event-progress{display:flex;gap:15px;align-items:center;color:var(--s-muted);font-size:10px;margin:12px 0;progress{appearance:none;flex:1;max-width:120px;height:4px;border:0;border-radius:10px;overflow:hidden;&::-webkit-progress-bar{background:var(--s-paper);}&::-webkit-progress-value{background:var(--s-primary);}}}.organizer-event-actions{display:flex;flex-wrap:wrap;gap:15px;font-size:11px;margin-top:17px;a:first-child{color:var(--s-primary);font-weight:650;}a:not(:first-child){color:var(--s-muted);}}.organizer-aside{display:grid;gap:20px;align-content:start;}.organizer-todos{padding:24px 20px;}.organizer-todo{display:flex;align-items:center;gap:11px;padding:15px 0;border-bottom:1px solid var(--s-line);.organizer-todo-icon{width:34px;height:34px;display:grid;place-items:center;border-radius:11px;background:#fff1e9;color:var(--s-primary);font-size:16px;}div{min-width:0;flex:1;strong{font-size:12px;font-weight:650;}small{display:block;color:var(--s-muted);margin-top:7px;font-size:10px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}}b{font-size:19px;font-weight:550;}>span:last-child{color:var(--s-muted);}}.organizer-note{color:var(--s-muted);font-size:11px;line-height:1.8;}.organizer-todo-clear{padding:15px 0 25px;text-align:center;>span{display:grid;place-items:center;width:45px;height:45px;margin:0 auto 14px;background:#f0f6ea;color:#74935e;border-radius:50%;font-size:20px;}h3{font-size:15px;}p{font-size:11px;color:var(--s-muted);line-height:1.8;}}.organizer-assistant{position:relative;border:1px solid var(--s-line);background:linear-gradient(135deg,#fff7f0,#fff);border-radius:25px;padding:25px;overflow:hidden;>img{position:absolute;width:90px;height:90px;right:12px;top:0;opacity:.9;}h2{font-size:18px;margin-top:20px;position:relative;}p{font-size:12px;color:var(--s-muted);line-height:1.8;position:relative;max-width:220px;}button,a{display:flex;justify-content:space-between;align-items:center;width:100%;border:0;background:#fff9;color:var(--s-ink);border-radius:12px;padding:13px;margin-top:8px;box-sizing:border-box;text-align:left;font-size:12px;cursor:pointer;span{color:var(--s-primary);}}}.organizer-trend{margin-top:25px;}.organizer-trend-bars{display:flex;gap:20px;justify-content:space-around;padding:15px 0 0;height:140px;>div{display:flex;flex-direction:column;justify-content:flex-end;align-items:center;gap:10px;flex:1;strong{font-size:12px;font-weight:500;color:var(--s-muted);}i{width:80%;max-width:75px;background:#ef59365b;border-radius:6px 6px 0 0;transition:height .4s;}small{font-size:10px;color:var(--s-muted);}}}.organizer-empty{text-align:center;display:grid;place-items:center;padding:55px 12px;>svg{width:44px;height:44px;color:var(--s-muted);}h3{font-size:17px;margin-top:20px;}p{font-size:12px;color:var(--s-muted);max-width:340px;line-height:1.8;margin:0 0 24px;}}.organizer-error{background:#fff0eb;padding:15px;border-radius:14px;font-size:13px;color:#b13d2d;button{border:0;background:none;color:inherit;text-decoration:underline;cursor:pointer;}}button:focus-visible,a:focus-visible{outline:3px solid #ef593655;outline-offset:3px;}@media(max-width:1100px){.organizer-main{grid-template-columns:minmax(0,1fr) 280px;gap:18px;}.organizer-events{padding:22px;}.organizer-event-card{grid-template-columns:120px minmax(0,1fr);gap:16px;}}@media(max-width:900px){.organizer-main{grid-template-columns:1fr;}.organizer-aside{grid-template-columns:1fr 1fr;}.organizer-heading{align-items:flex-start;h1{font-size:27px;}}.organizer-stat{padding:20px;}}@media(max-width:600px){.organizer-heading{flex-direction:column;gap:6px;margin-top:0;h1{font-size:27px;}p{font-size:12px;}}.organizer-create{width:100%;a{flex:1;}}.organizer-stat-row{grid-template-columns:repeat(2,1fr);gap:12px;}.organizer-stat{padding:19px;strong{font-size:36px;}>span{font-size:12px;}p{font-size:10px;}}.organizer-aside{grid-template-columns:1fr;}.organizer-events{padding:20px 16px;}.organizer-event-card{grid-template-columns:1fr;gap:13px;}.organizer-event-info h3{font-size:19px;}.organizer-event-progress progress{max-width:none;}.organizer-event-actions{font-size:12px;gap:20px;}.organizer-trend{padding:22px 16px;}.organizer-trend-bars{gap:9px;}}@media(prefers-reduced-motion:reduce){.organizer-primary,.organizer-secondary,.organizer-trend-bars i{transition:none;}.organizer-primary:hover,.organizer-secondary:hover{transform:none;}}
</style>
