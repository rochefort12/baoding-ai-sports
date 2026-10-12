<template>
  <el-dialog :model-value="!!unit" :title="reviewing ? '确认本次报名名单' : '选择报名方式与队伍'" width="680px" class="b-dialog registration-team-dialog" :close-on-click-modal="!busy" :close-on-press-escape="!busy" :show-close="!busy" destroy-on-close @close="emit('close')">
    <template v-if="unit">
      <div class="team-booking-summary"><span>{{ entryTypeLabel(unit.entryType) }} · {{ unit.minMembers === unit.maxMembers ? `${unit.minMembers} 位参赛者` : `${unit.minMembers}—${unit.maxMembers} 位参赛者` }}</span><h3>{{ unit.name }}</h3><p>{{ price }} · 草稿不占名额、不付款</p></div>
      <el-alert v-if="error" :title="error" type="error" :closable="false" />
      <template v-if="!reviewing">
        <div class="team-booking-options" aria-label="报名身份">
          <button v-if="!fixedTeamId" type="button" :aria-pressed="!teamId" :class="{selected:!teamId}" @click="selectTeam('')"><strong>个人报名</strong><span>{{ unit.entryType === 'individual' ? '使用本人已有资料' : '本人参加，再邀请搭档' }}</span></button>
          <button v-for="team in availableTeams" :key="team.teamId" type="button" :aria-pressed="teamId === team.teamId" :class="{selected:teamId === team.teamId}" @click="selectTeam(team.teamId)"><strong>{{ team.name }}</strong><span>代表队伍报名 · 你是队长</span></button>
        </div>
        <template v-if="teamId">
          <div class="between team-booking-heading"><h4>本次参赛成员</h4><span>已选 {{ selected.length }} / {{ unit.maxMembers }} 人</span></div>
          <p class="consumer-muted">{{ teamMembers.length > unit.maxMembers ? '队伍人数超过本项目人数，请选择本次实际上场成员。' : '已为你选入可用成员，请核对。' }}队长可代办，不必本人上场。</p>
          <p v-if="reading" role="status">正在读取队员…</p>
          <div v-else class="team-booking-members">
            <div v-for="person in teamMembers" :key="person.personId" class="team-booking-member-choice" :class="{unavailable:!person.selectable}">
              <el-checkbox :model-value="selected.includes(person.accountId)" @change="toggleMember(person.accountId, !!$event)" :disabled="!person.selectable || !selected.includes(person.accountId) && selected.length >= unit.maxMembers"><span class="registration-avatar">{{ (person.legalName || '友').slice(0,1) }}</span><span><strong>{{ person.legalName || '队员' }}</strong><small>{{ !person.selectable ? '账号或本人资料未完成，暂不可报名' : person.role === 'captain' ? '队长 · 本人' : '队员 · 本人确认参加' }}</small></span></el-checkbox>
            </div>
            <p v-if="!teamMembers.length && !reading" class="consumer-muted">没有可选队员，请先在“我的队伍”完善成员。</p>
          </div>
        </template>
        <p v-else class="consumer-muted">已有本人基础资料会自动带入，只需补充赛事要求的资料与声明。</p>
      </template>
      <template v-else>
        <h4>{{ selectedTeam?.name || '个人报名' }} · 本次名单</h4>
        <div class="team-booking-members"><article v-for="person in chosenMembers" :key="person.accountId"><span class="registration-avatar">{{ (person.legalName || '友').slice(0,1) }}</span><div><strong>{{ person.legalName }}</strong><p>{{ person.role === 'captain' ? '本人资料自动带入' : '确认后发送参赛邀请，由成员本人确认' }}</p></div></article><article v-if="!teamId"><span class="registration-avatar">我</span><div><strong>本人</strong><p>使用已有本人资料</p></div></article></div>
        <p class="team-booking-note">{{ teamId && chosenMembers.some(person => person.role !== 'captain') ? '名单一次带入，系统会通知队员。全员本人资料、参赛声明确认后，由队长正式提交。' : '确认名单后继续核对本人资料与参赛声明，正式提交后才占用名额。' }}</p>
      </template>
    </template>
    <template #footer><el-button :disabled="busy" @click="reviewing ? reviewing = false : emit('close')">{{ reviewing ? '返回调整' : '暂不报名' }}</el-button><el-button type="primary" :loading="busy" :disabled="reading || !canContinue" @click="reviewing ? prepare() : reviewing = true">{{ reviewing ? '确认名单，继续报名' : '核对本次名单' }}</el-button></template>
  </el-dialog>
</template>
<script setup lang="ts">
import { createEntry, entryTypeLabel, type EntryCard, type UnitCard } from '@/api/sports/registration';
import { listCandidates, type CandidateCard, type MembershipCard } from '@/api/sports/team';
import { newRequestKey } from '@/utils/requestKey';
const props = defineProps<{unit?: UnitCard; teams: MembershipCard[]; price: string; fixedTeamId?: string}>();
const emit = defineEmits<{close: []; prepared: [entry: EntryCard]}>();
const teamId = ref(''); const selected = ref<string[]>([]); const teamMembers = ref<CandidateCard[]>([]);
const reading = ref(false); const busy = ref(false); const reviewing = ref(false); const error = ref('');
let generation = 0; let requestKey = ''; let payload = '';
const availableTeams = computed(() => props.fixedTeamId ? props.teams.filter(team => team.teamId === props.fixedTeamId) : props.teams);
const selectedTeam = computed(() => props.teams.find(team => team.teamId === teamId.value));
const chosenMembers = computed(() => teamMembers.value.filter(person => selected.value.includes(person.accountId)));
const canContinue = computed(() => !!props.unit && (!teamId.value || !!selectedTeam.value && selected.value.length >= props.unit.minMembers && selected.value.length <= props.unit.maxMembers));
function toggleMember(id: string, included: boolean) { selected.value = included ? [...selected.value.filter(account => account !== id), id] : selected.value.filter(account => account !== id); }
async function selectTeam(id: string) {
  const current = ++generation; teamId.value = id; teamMembers.value = []; selected.value = []; error.value = ''; reading.value = !!id;
  if (!id) return;
  try { const response = await listCandidates(id); if (current !== generation) return;
    teamMembers.value = response.data || []; const eligible = teamMembers.value.filter(person => person.selectable);
    selected.value = eligible.length <= (props.unit?.maxMembers || 0) ? eligible.map(person => person.accountId) : eligible.filter(person => person.role === 'captain').map(person => person.accountId);
  } catch (cause) { if (current === generation) error.value = cause instanceof Error ? cause.message : '队员暂时无法读取，请重新选择队伍。'; }
  finally { if (current === generation) reading.value = false; }
}
watch(() => props.unit, unit => { reviewing.value = false; requestKey = ''; payload = ''; void selectTeam(unit ? props.fixedTeamId || (availableTeams.value.length === 1 ? availableTeams.value[0].teamId : '') : ''); });
async function prepare() {
  if (!props.unit || busy.value || !canContinue.value) return;
  const currentPayload = JSON.stringify([props.unit.id, teamId.value, [...selected.value].sort()]);
  if (payload !== currentPayload) { payload = currentPayload; requestKey = newRequestKey(); }
  busy.value = true; error.value = '';
  try { const response = await createEntry(props.unit.id, requestKey, teamId.value || undefined, teamId.value ? selected.value : undefined); emit('prepared', response.data); }
  catch (cause) { error.value = cause instanceof Error ? cause.message : '报名未完成，名单保留，请核对后重试。'; }
  finally { busy.value = false; }
}
</script>
