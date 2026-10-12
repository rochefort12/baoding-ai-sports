<template>
  <div class="app-container" :class="{ 'product-admin': !eventKey }">
    <div v-if="!eventKey" class="b-heading"><div><h1>现场执行</h1><p>选择赛事，安排对阵、录入赛果并签发奖项。</p></div><router-link v-if="eventId" :to="'/org-desk/workspace/'+eventId+'?task=closure'"><el-button>场次安排与结果更正</el-button></router-link></div>
    <el-alert v-if="loadError" :title="loadError" type="error" :closable="false" /><el-card shadow="never">
      <template #header>{{ mode === 'checkin' ? '赛事报到' : mode === 'awards' ? '获奖与证明' : '场次与录分' }}</template>
      <p>确认结果后向参赛人展示。更正或撤销正式赛果请进入赛事工作区；获奖证明需单独核实并签发。</p>
      <el-form label-position="top">
        <el-form-item v-if="!eventKey" label="赛事">
          <el-select v-model="eventId" placeholder="选择赛事" @change="loadEvent">
            <el-option v-for="event in events" :key="event.eventId" :label="event.name || '未命名赛事'" :value="event.eventId" />
          </el-select>
        </el-form-item>
        <el-form-item label="项目">
          <el-select v-model="unitId" placeholder="选择项目" @change="loadUnit">
            <el-option v-for="unit in units" :key="unit.unitId" :label="unit.name" :value="unit.unitId" />
          </el-select>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card v-if="eventId && mode === 'checkin'" shadow="never" class="mt-4">
      <template #header>赛事报到</template>
      <p>每个项目分别报到，同一人在本项目只记一次。仅展示本项目已通过审核且满足收款条件的参赛名单。</p>
      <el-alert v-if="visiblePeople.some(p => p.legacyEventCheckin && !p.checkedIn)" title="存在旧赛事级报到记录，请核对本项目实际到场情况后办理项目报到。" type="info" :closable="false" class="mb-3" />
      <div class="project-checkin-mobile">
        <article v-for="row in visiblePeople" :key="row.unitId+':'+row.personId" class="project-checkin-person">
          <div><strong>{{ row.legalName }}</strong><p>{{ row.unitName }}</p></div>
          <span :class="{ 'checked': row.checkedIn }">{{ row.checkedIn ? '已报到' : row.legacyEventCheckin ? '待项目核对' : '未报到' }}</span>
          <el-button v-if="!eventStopped && !row.checkedIn" :loading="checking.has(row.unitId+':'+row.personId)" :disabled="checking.has(row.unitId+':'+row.personId)" type="primary" @click="checkIn(row)">{{ row.legacyEventCheckin ? '核对本项目并报到' : '为本项目报到' }}</el-button>
        </article>
        <el-empty v-if="!visiblePeople.length" description="本项目暂无可报到名单" :image-size="64" />
      </div>
      <el-table :data="visiblePeople" class="project-checkin-table">
        <el-table-column prop="legalName" label="姓名" />
        <el-table-column prop="unitName" label="项目" />
        <el-table-column label="本项目报到" min-width="155">
          <template #default="{ row }"><span>{{ row.checkedIn ? '已报到' : row.legacyEventCheckin ? '待项目核对' : '未报到' }}</span></template>
        </el-table-column>
        <el-table-column label="操作" width="120">
          <template #default="{ row }">
            <el-button v-if="!eventStopped && !row.checkedIn" :loading="checking.has(row.unitId+':'+row.personId)" :disabled="checking.has(row.unitId+':'+row.personId)" link type="primary" @click="checkIn(row)">{{ row.legacyEventCheckin ? '核对并报到' : '报到' }}</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-card v-if="unitId && mode === 'matches'" shadow="never" class="mt-4">
      <template #header>手工场次</template>
      <el-form v-if="!eventStopped" inline>
        <el-input v-model="matchCode" placeholder="场次编号" maxlength="100" style="width: 160px" />
        <el-select v-model="registrationA" placeholder="A 侧报名" style="width: 220px">
          <el-option v-for="entry in entryChoices" :key="entry.registrationId" :label="entry.label" :value="entry.registrationId" />
        </el-select>
        <el-select v-model="registrationB" placeholder="B 侧报名" style="width: 220px">
          <el-option v-for="entry in entryChoices" :key="'b' + entry.registrationId" :label="entry.label" :value="entry.registrationId" />
        </el-select>
        <el-button type="primary" @click="addMatch">建立场次</el-button>
      </el-form>
      <el-table :data="matches" class="mt-4">
        <el-table-column prop="code" label="场次" width="120" />
        <el-table-column prop="sideA" label="A" />
        <el-table-column prop="sideB" label="B" />
        <el-table-column label="比赛结果" min-width="300">
          <template #default="{ row }"><MatchScoreCard :performance="row" :side-a="row.sideA" :side-b="row.sideB" :status="row.resultStatus || undefined" compact /></template>
        </el-table-column>
        <el-table-column label="操作" width="180">
          <template #default="{ row }"><el-button link @click="viewResult(row)">查看详情</el-button>
            <el-button v-if="!eventStopped && row.resultStatus !== 'confirmed'" link type="primary" @click="openResult(row)">录入</el-button>
            <el-button v-if="!eventStopped && row.resultStatus === 'draft'" link type="primary" @click="finalize(row)">确认结果</el-button>
          </template>
        </el-table-column>
      </el-table>
      <el-form v-if="!eventStopped" class="mt-4" label-position="top">
        <p>每场填一行即可：场次编号，A或B，win（胜）/loss（负）/draw（平），总比分，分局比分。所有比分按 A:B 填写；另一方胜负自动补齐。示例：01,A,win,2:1,21:18|18:21|21:17。导入仅保存草稿。</p><el-form-item label="批量导入草稿">
          <el-input v-model="importText" type="textarea" :rows="5" placeholder="场次编号,位置(A/B),胜负(win/loss/draw),总比分,分局比分" />
        </el-form-item>
        <p v-if="importError" class="notice warn" role="alert">{{ importError }}</p><el-button :loading="importing" :disabled="!importText.trim()" @click="importDraft">导入草稿</el-button>
      </el-form>
    </el-card>

    <el-card v-if="unitId && mode === 'awards'" shadow="never" class="mt-4">
      <template #header>获奖</template>
      <p class="b-muted">同一报名项目只有一个当前最终名次。更正已有奖项请到赛事收尾核实原证明；专项奖单独签发。</p>
      <el-form v-if="!eventStopped" inline>
        <el-select v-model="awardRegistrationId" placeholder="获奖报名" style="width: 240px">
          <el-option v-for="entry in entryChoices" :key="'award' + entry.registrationId" :label="entry.label" :value="entry.registrationId" />
        </el-select>
        <el-select v-model="awardKind" aria-label="奖项类型" style="width:140px"><el-option label="最终名次" value="placing"/><el-option label="专项奖" value="special"/></el-select>
        <el-select v-if="awardKind==='special'" v-model="awardMatchIds" multiple placeholder="选择依据场次" style="width:220px"><el-option v-for="match in matches.filter(m=>m.resultStatus==='confirmed')" :key="match.matchId" :label="match.code+' · '+match.summary" :value="match.matchId"/></el-select>
        <el-input v-model="awardTitle" placeholder="赛事内名次或奖项" maxlength="200" style="width: 180px" />
        <el-input v-model="awardBasis" placeholder="依据，例如决赛胜出" maxlength="500" style="width: 220px" />
        <el-button type="primary" @click="grant">确认获奖</el-button>
      </el-form>
      <el-table :data="awards" class="mt-4">
        <el-table-column prop="title" label="称号" width="120" />
        <el-table-column prop="names" label="获奖名单" />
        <el-table-column prop="people" label="人数" width="80" />
      </el-table>
    </el-card>

    <el-dialog class="b-dialog score-dialog" v-model="resultDetailVisible" title="比赛结果详情" width="620px" destroy-on-close>
      <MatchScoreCard v-if="detailMatch" :performance="detailMatch" :side-a="detailMatch.sideA" :side-b="detailMatch.sideB" :code="detailMatch.code" :unit-name="units.find(unit => unit.unitId === unitId)?.name" :status="detailMatch.resultStatus || undefined" />
      <template #footer><el-button @click="resultDetailVisible = false">关闭</el-button></template>
    </el-dialog>
    <el-dialog class="b-dialog score-dialog" v-model="resultVisible" :title="'场次 '+(currentMatch?.code || '')+' · 录入草稿'" width="660px" destroy-on-close>
      <MatchScoreEditor v-if="resultVisible && currentMatch" :key="currentMatch.matchId" :model-value="resultForm" @update:model-value="Object.assign(resultForm, $event)" @pending-game="pendingGame = $event" :side-a="currentMatch.sideA" :side-b="currentMatch.sideB"/>
      <template #footer><span v-if="pendingGame" class="score-help">请先结束本局或取消本局编辑。</span><el-button @click="resultVisible = false">取消</el-button><el-button type="primary" :loading="savingResult" :disabled="!resultForm.outcomeA || pendingGame" @click="saveDraft">核对并保存草稿</el-button></template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts" name="CompetitionDesk">
import { computed, onMounted, reactive, ref } from 'vue';
import { newRequestKey } from '@/utils/requestKey';
import MatchScoreEditor from '@/components/business/MatchScoreEditor.vue';
import MatchScoreCard from '@/components/sports/MatchScoreCard.vue';

import { ElMessage, ElMessageBox } from 'element-plus';
import {
  AwardCard,
  CompetitionEvent,
  CompetitionUnit,
  EligiblePerson,
  EntryChoice,
  MatchCard,
  checkInPerson,
  createMatch,
  finalizeResult,
  grantAward,
  importResults,
  listAwards,
  listCompetitionEvents,
  listCompetitionUnits,
  listEligible,
  listMatchEntries,
  listMatches,
  saveResult
} from '@/api/sports/competition';

const props = withDefaults(defineProps<{ eventKey?: string; mode?: string; eventStopped?: boolean }>(), { mode: 'matches' });
const loadError = ref('');
const visiblePeople = computed(() => !unitId.value ? people.value : people.value.filter(p => p.unitId === unitId.value));
const checking = reactive(new Set<string>());
const events = ref<CompetitionEvent[]>([]);
const units = ref<CompetitionUnit[]>([]);
const people = ref<EligiblePerson[]>([]);
const entryChoices = ref<EntryChoice[]>([]);
const matches = ref<MatchCard[]>([]);
const awards = ref<AwardCard[]>([]);
const eventId = ref('');
const unitId = ref('');
const matchCode = ref('');
const registrationA = ref('');
const registrationB = ref('');
const importText = ref('');
const importing = ref(false), importError = ref(''), savingResult = ref(false);
const awardRegistrationId = ref('');
const awardTitle = ref('');
const awardBasis = ref('');
const awardKind = ref('placing');
const awardMatchIds = ref<string[]>([]);
const resultVisible = ref(false);
const pendingGame = ref(false);
const currentMatch = ref<MatchCard>();
const detailMatch = ref<MatchCard>();
const resultDetailVisible = ref(false);
const opposite = (outcome: string) => outcome === 'win' ? 'loss' : outcome === 'loss' ? 'win' : 'draw';
const resultForm = reactive({ outcomeA: '', outcomeB: '', summary: '', games: '' });

const loadEvent = async () => {
  unitId.value = '';
  people.value = [];
  matches.value = [];
  awards.value = [];
  if (!eventId.value) {
    units.value = [];
    return;
  }
  const [unitRes, peopleRes] = await Promise.all([listCompetitionUnits(eventId.value), listEligible(eventId.value)]);
  units.value = unitRes.data;
  people.value = peopleRes.data;
};

const loadUnit = async () => {
  if (!unitId.value) {
    return;
  }
  const selected = unitId.value; entryChoices.value = []; matches.value = []; awards.value = [];
  const [entryRes, matchRes, awardRes] = await Promise.all([listMatchEntries(unitId.value), listMatches(unitId.value), listAwards(unitId.value)]);
  if (selected !== unitId.value) return;
  entryChoices.value = entryRes.data;
  matches.value = matchRes.data;
  awards.value = awardRes.data;
};

const checkIn = async (row: EligiblePerson) => {
  const targetEvent = eventId.value, pending = row.unitId+':'+row.personId;
  if (checking.has(pending)) return;
  checking.add(pending);
  try {
    await checkInPerson(targetEvent, row.personId, newRequestKey(), row.unitId);
    ElMessage.success(row.unitName+' · 已报到');
    const peopleRes = await listEligible(targetEvent);
    if (targetEvent === eventId.value) people.value = peopleRes.data;
  } finally { checking.delete(pending); }
};

const addMatch = async () => {
  await createMatch(unitId.value, matchCode.value, registrationA.value, registrationB.value, newRequestKey());
  ElMessage.success('已建立场次');
  matchCode.value = '';
  await loadUnit();
};

const viewResult = (row: MatchCard) => { detailMatch.value = row; resultDetailVisible.value = true; };
const openResult = (row: MatchCard) => {
  pendingGame.value = false;
  currentMatch.value = row;
  resultForm.outcomeA = row.outcomeA || '';
  resultForm.outcomeB = row.outcomeB || '';
  resultForm.summary = row.summary || '';
  resultForm.games = row.games || '';
  resultVisible.value = true;
};

const saveDraft = async () => {
  if (!currentMatch.value) {
    return;
  }
  if (savingResult.value || !resultForm.outcomeA || pendingGame.value) return;
  savingResult.value = true;
  try {
  await saveResult(currentMatch.value.matchId, resultForm.summary, resultForm.games, resultForm.outcomeA, resultForm.outcomeB, newRequestKey());
  ElMessage.success('已保存草稿');
  resultVisible.value = false;
  await loadUnit();
  } finally { savingResult.value = false; }
};

const finalize = async (row: MatchCard) => {
  try {
    await ElMessageBox.confirm(`${row.sideA}（A）对 ${row.sideB}（B），总比分 ${row.summary || '未记录'}，分局 ${row.games || '未记录'}。确认后将向参赛者展示，更正需另走赛果修订。`, '确认正式结果');
  } catch {
    return;
  }
  await finalizeResult(row.matchId, newRequestKey());
  ElMessage.success('正式结果已确认并向参赛者展示');
  await loadUnit();
};

const importDraft = async () => {
  if (!unitId.value || importing.value) {
    return;
  }
  importing.value = true; importError.value = '';
  try {
  const res = await importResults(eventId.value, unitId.value, importText.value, newRequestKey());
  ElMessage.success(res.data.message);
  if (unitId.value) {
    await loadUnit();
  }
  } catch (cause) { importError.value = cause instanceof Error ? cause.message : '导入失败，请检查场次编号和各行内容。'; }
  finally { importing.value = false; }
};

const grant = async () => {
  if (!awardBasis.value.trim()) {
    ElMessage.warning('请填写获奖依据');
    return;
  }
  if (awardKind.value === 'special' && !awardMatchIds.value.length) { ElMessage.warning('请选择专项奖依据的正式场次'); return; }
  await grantAward(awardRegistrationId.value, awardTitle.value, awardBasis.value.trim(), newRequestKey(), awardKind.value, awardKind.value==='special' ? awardMatchIds.value : undefined);
  awardBasis.value = '';
  ElMessage.success('已确认获奖');
  awardTitle.value = '';
  await loadUnit();
};

onMounted(async () => {
  try {
    if (props.eventKey) {
      eventId.value = props.eventKey;
      await loadEvent();
      if (units.value.length) {
        unitId.value = units.value[0].unitId;
        await loadUnit();
      }
    } else {
      const res = await listCompetitionEvents();
      events.value = res.data;
    }
  } catch {
    loadError.value = '现场数据读取失败，请刷新页面重试。';
  }
});
</script>
