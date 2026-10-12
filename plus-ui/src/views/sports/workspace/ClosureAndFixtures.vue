<template>
  <section class="b-panel">
    <div class="b-toolbar"><h2>赛事收尾</h2><el-button :loading="loading" @click="load">刷新核对</el-button></div>
    <el-alert v-if="error" :title="error" type="error" :closable="false" />
    <template v-if="closure">
      <div class="closure-grid">
        <article><span>比赛与正式结果</span><h3>{{ closure.competitionEnded ? '比赛已结束' : '比赛进行中' }}</h3><p>{{ closure.missingResults }} 场待确认 · {{ closure.proofsAwaitingReview }} 项证明待复核</p></article>
        <article><span>资金责任</span><h3>{{ closure.fundsClosed ? '资金已结清' : '仍需处理' }}</h3><p>{{ closure.openObligations }} 笔付款义务 · {{ closure.pendingFundActions }} 项退款等后续 · {{ closure.pendingRefunds }} 笔退款</p></article>
        <article><span>问题与协调</span><h3>{{ closure.issuesClosed ? '投诉已处理' : '仍需回复' }}</h3><p>{{ closure.openIssues }} 个未处理问题</p></article>
      </div>
      <div class="b-actions"><el-button v-if="!closure.competitionEnded" type="primary" :loading="busy" @click="close('event.wrapup')">核对正式赛果，确认比赛结束</el-button><el-button v-else-if="closure.event.closure_status !== 'closed'" type="primary" :loading="busy" @click="close('event.close')">确认资金和问题全部收尾</el-button><el-tag v-else type="success">赛事已收尾</el-tag><router-link to="/org-desk/issues"><el-button>进入问题处理</el-button></router-link></div>
    </template>
  </section>
  <section class="b-panel">
    <div class="fixture-workspace-heading"><div><h3>场次安排与赛果</h3><p class="b-muted">按项目查看对阵、时间和比分。更正正式结果后，相关获奖证明需要重新核实。</p></div><img class="fixture-heading-art" src="/images/sports/match-court-v1.png" alt="" width="140" height="90" /></div>
    <div class="fixture-filters"><label for="fixture-project">比赛项目</label><el-select id="fixture-project" v-model="projectFilter" placeholder="全部比赛项目" aria-label="筛选场次项目"><el-option label="全部比赛项目" value="" /><el-option v-for="project in projects" :key="project.id" :label="project.name" :value="project.id" /></el-select><span class="b-muted">{{ visibleFixtures.length }} 场</span></div>
    <div class="fixture-cards">
      <article v-for="row in visibleFixtures" :key="row.id" class="fixture-card" :data-match-id="row.id" :data-unit-id="row.unit_id">
        <header><div><h4>场次 {{ row.code }}</h4><p>{{ row.unit_name || '项目待核对' }}</p></div><el-tag :type="row.result_status === 'void' ? 'danger' : row.result_status === 'confirmed' ? 'success' : 'info'">{{ row.result_status === 'void' ? '结果已撤销' : row.result_status === 'confirmed' ? '正式结果' : '待录分' }}</el-tag></header>
        <MatchScoreCard :performance="row.displayPerformance" :side-a="row.side_a" :side-b="row.side_b" :status="row.result_status || undefined" compact />
        <p v-if="row.displayPerformance === null" class="b-muted">比分记录暂时无法读取，请刷新核对。</p>
        <dl class="fixture-plan"><div><dt>球场</dt><dd>{{ row.court_name || '尚未安排' }}</dd></div><div><dt>比赛时间 · 北京时间</dt><dd>{{ row.scheduled_start ? businessTime(row.scheduled_start) : '尚未安排' }}<template v-if="row.scheduled_end"> — {{ businessTime(row.scheduled_end) }}</template></dd></div></dl>
        <footer><el-button :disabled="!canSchedule(row) || busy" @click="schedule(row)">{{ row.scheduled_start ? '调整时间' : '安排时间' }}</el-button><el-button v-if="row.result_revision" type="primary" :disabled="busy" @click="correct(row)">{{ row.result_status === 'void' ? '恢复有效赛果' : '更正结果' }}</el-button><el-button v-if="row.result_status === 'confirmed'" link type="danger" :disabled="busy" @click="voidResult(row)">撤销赛果</el-button></footer>
      </article>
    </div>
    <p v-if="!loading && !visibleFixtures.length" class="b-muted">{{ projectFilter ? '本项目尚未建立场次。' : '尚未建立场次，请先在场次与录分中安排对阵。' }}</p>
  </section>
  <section class="b-panel">
    <div class="b-toolbar"><h3>获奖证明复核</h3><el-switch v-model="showVerified" active-text="查看已签发奖项" @change="load" /></div>
    <p class="b-muted">先核对参赛人和正式比分，再确认奖项名称。签发新证明后，原证明会留在历史记录中。</p>
    <div class="honor-review-cards"><article v-for="row in proofs" :key="row.id"><header><div><h4>{{ row.names || '名单待核对' }}</h4><span>{{ row.unit_name }} · {{ row.award_kind === 'placing' ? '项目名次' : '专项奖' }}</span></div><el-tag :type="row.status === 'verified' ? 'success' : 'warning'">{{ row.status === 'verified' ? '有效证明' : '待复核' }}</el-tag></header><p><strong>{{ row.title }}</strong> · {{ row.people_count }} 人</p><details v-if="row.basis_text || row.history_count" class="honor-original-note"><summary>查看原签发说明</summary><p v-if="row.basis_text">{{ row.basis_text }}</p><p v-if="row.history_count" class="b-muted">已保留 {{ row.history_count }} 份历史证明。</p></details><footer><el-button type="primary" @click="reviewProof(row, 'reissue')">核实奖项与证明</el-button><el-button type="danger" link @click="reviewProof(row, 'revoke')">撤销该奖项</el-button></footer></article></div>
    <p v-if="!proofs.length" class="b-muted">{{ showVerified ? '暂无赛事奖项。' : '当前没有待复核证明。打开“查看已签发奖项”可核实已有证明。' }}</p>
  </section>
  <HonorReviewDialog :claim="reviewing" :initial-decision="reviewDecision" @close="reviewing = undefined" @completed="load" />
  <el-dialog class="b-dialog score-dialog fixture-schedule-dialog" v-model="dialog" :title="mode === 'schedule' ? '安排场次时间' : '更正正式赛果'" width="620px" destroy-on-close :close-on-click-modal="!busy" :close-on-press-escape="!busy" :show-close="!busy">
    <div v-if="selected" class="fixture-dialog-context"><strong>{{ selected.unit_name }} · 场次 {{ selected.code }}</strong><span>{{ selected.side_a || 'A 方' }} 对 {{ selected.side_b || 'B 方' }}</span></div>
    <el-form label-position="top"><template v-if="mode === 'schedule'"><el-form-item label="开始时间（北京时间）"><el-date-picker v-model="form.startsAt" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" placeholder="选择开始时间" /></el-form-item><el-form-item label="结束时间（北京时间）"><el-date-picker v-model="form.endsAt" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" placeholder="选择结束时间" /></el-form-item><el-form-item label="球场"><el-input v-model="form.courtName" maxlength="80" placeholder="例如 1 号场" /></el-form-item><p class="b-muted">保存前会核对球场和参赛人的时间冲突。</p></template><template v-else><MatchScoreEditor :key="selected?.id" :model-value="form" @update:model-value="Object.assign(form, $event)" @pending-game="pendingGame = $event" :side-a="selected?.side_a || 'A 方'" :side-b="selected?.side_b || 'B 方'" /><el-form-item label="更正原因"><el-input v-model="form.reason" type="textarea" :rows="3" maxlength="2000" placeholder="说明原结果的问题和本次核对结论" /></el-form-item></template></el-form>
    <template #footer><el-button :disabled="busy" @click="dialog = false">取消</el-button><el-button type="primary" :loading="busy" :disabled="mode === 'schedule' ? !form.startsAt || !form.endsAt || !form.courtName.trim() : !form.outcomeA || pendingGame || !form.reason.trim()" @click="save">{{ mode === 'schedule' ? '核对并保存安排' : '核对并更正赛果' }}</el-button></template>
  </el-dialog>
</template>
<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import HonorReviewDialog, { type ReviewClaim } from '@/components/sports/HonorReviewDialog.vue';
import MatchScoreCard from '@/components/sports/MatchScoreCard.vue';
import MatchScoreEditor from '@/components/business/MatchScoreEditor.vue';
import { businessPickerTime, businessTime } from '@/utils/business';
import { readMatchPerformance, type MatchPerformance } from '@/utils/matchPresentation';
import request from '@/utils/request';
import { ElMessageBox } from 'element-plus';
import { performAction } from '@/api/sports/phase1';
const props = defineProps<{ eventKey: string }>();
interface Closure { event: { version: number; closure_status: string }; competitionEnded: boolean; fundsClosed: boolean; issuesClosed: boolean; missingResults: number; proofsAwaitingReview: number; openObligations: number; pendingFundActions: number; pendingRefunds: number; openIssues: number }
interface Fixture { id: string; code: string; unit_id: string; unit_name: string; status: string; holding_status: string; version: number; result_revision: number | null; result_status: string | null; court_name: string | null; scheduled_start: string | null; scheduled_end: string | null; performance: string | null; displayPerformance?: MatchPerformance | null; side_a: string | null; side_b: string | null }
const reviewing = ref<ReviewClaim>(); const reviewDecision = ref('reissue'); const showVerified = ref(false); const pendingGame = ref(false);
const proofs = ref<ReviewClaim[]>([]); const closure = ref<Closure>(); const fixtures = ref<Fixture[]>([]); const error = ref(''); const busy = ref(false); const loading = ref(false); const dialog = ref(false); const mode = ref('schedule'); const selected = ref<Fixture>(); const projectFilter = ref('');
const form = reactive({ startsAt: '', endsAt: '', courtName: '', summary: '', games: '', outcomeA: '', outcomeB: '', reason: '' });
const projects = computed(() => [...new Map(fixtures.value.map(row => [row.unit_id, { id: row.unit_id, name: row.unit_name }])).values()]);
const visibleFixtures = computed(() => fixtures.value.filter(row => !projectFilter.value || row.unit_id === projectFilter.value));
const canSchedule = (row: Fixture) => row.holding_status === 'normal' && !['completed', 'confirmed', 'cancelled'].includes(row.status);
let loadVersion = 0;
async function load() {
  const version = ++loadVersion; const eventKey = props.eventKey; loading.value = true; error.value = '';
  try {
    const responses = await Promise.all([request<Closure>({ url: `/sports/closure/events/${eventKey}` }), request<Fixture[]>({ url: `/sports/fixtures/events/${eventKey}` }), request<ReviewClaim[]>({ url: `/sports/proof-review/events/${eventKey}`, params: { includeVerified: showVerified.value } })]);
    if (version !== loadVersion || eventKey !== props.eventKey) return;
    closure.value = responses[0].data; fixtures.value = responses[1].data.map(row => ({ ...row, displayPerformance: readMatchPerformance(row.performance) })); proofs.value = responses[2].data;
    if (projectFilter.value && !projects.value.some(project => project.id === projectFilter.value)) projectFilter.value = '';
  } catch { if (version === loadVersion) error.value = '暂时无法核对收尾状态，请重试。'; } finally { if (version === loadVersion) loading.value = false; }
}
async function close(code: string) { if (!closure.value || busy.value) return; busy.value = true; try { await performAction(code, { eventId: props.eventKey, expectedVersion: closure.value.event.version }, code === 'event.wrapup' ? '已核对各场正式结果，结束新增报名，转入资金和问题收尾。' : '已核实真实收款、退款和问题回复。系统将再次核对全部待办。'); await load(); } finally { busy.value = false; } }
function schedule(row: Fixture) { if (!canSchedule(row)) return; selected.value = row; mode.value = 'schedule'; Object.assign(form, { startsAt: businessPickerTime(row.scheduled_start), endsAt: businessPickerTime(row.scheduled_end), courtName: row.court_name || '' }); dialog.value = true; }
function correct(row: Fixture) { selected.value = row; mode.value = 'correct'; pendingGame.value = false; const current = readMatchPerformance(row.performance); if (!current) { error.value = '正式赛果无法读取，请刷新后核对。'; return; } Object.assign(form, { summary: current.summary || '', games: current.games || '', outcomeA: current.outcomeA || '', outcomeB: current.outcomeB || '', reason: '' }); dialog.value = true; }
async function save() { if (!selected.value || busy.value) return; busy.value = true; try { const base = { matchId: selected.value.id, expectedVersion: selected.value.version }; const input = mode.value === 'schedule' ? { ...base, startsAt: form.startsAt, endsAt: form.endsAt, courtName: form.courtName.trim() } : { ...base, summary: form.summary, games: form.games, outcomeA: form.outcomeA, outcomeB: form.outcomeA === 'win' ? 'loss' : form.outcomeA === 'loss' ? 'win' : 'draw', reason: form.reason.trim() }; await performAction(mode.value === 'schedule' ? 'match.schedule' : 'result.correct', input, mode.value === 'schedule' ? `确认安排「${selected.value.unit_name} · 场次 ${selected.value.code}」在 ${form.courtName}，北京时间 ${form.startsAt} 至 ${form.endsAt} 比赛？` : `确认更正「${selected.value.unit_name} · 场次 ${selected.value.code}」，比分 ${form.summary}？旧结果保留，相关证明需复核。`); dialog.value = false; await load(); } finally { busy.value = false; } }
async function voidResult(row: Fixture) { if (busy.value) return; try { const answer = await ElMessageBox.prompt('请说明撤销原因。相关成长会同步调整，获奖证明需要重新核实。', `${row.unit_name} · 场次 ${row.code} · 撤销赛果`, { inputType: 'textarea', inputValidator: value => !!value?.trim() && value.length <= 2000 || '请填写2000字内的原因' }); busy.value = true; await performAction('result.void', { matchId: row.id, expectedVersion: row.version, reason: answer.value }, `确认撤销「${row.unit_name} · 场次 ${row.code}」的正式赛果？原版本和更正记录继续保留。`); await load(); } finally { busy.value = false; } }
function reviewProof(row: ReviewClaim, decision: string) { reviewing.value = row; reviewDecision.value = decision; }
onMounted(load); watch(() => props.eventKey, () => { dialog.value = false; reviewing.value = undefined; selected.value = undefined; projectFilter.value = ''; fixtures.value = []; proofs.value = []; closure.value = undefined; load(); });
</script>
<style scoped>
.closure-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:18px;margin:20px 0}.closure-grid article{background:#f2f8f4;padding:22px;border-radius:16px;border:1px solid #d9e9df}.closure-grid article>span{color:#718a79;font-size:13px}.closure-grid h3{color:#276c4e}.closure-grid p{font-size:13px;color:#718277;line-height:1.8}@media(max-width:800px){.closure-grid{grid-template-columns:1fr}}
</style>
