<template>
  <el-dialog :model-value="!!claim" title="核实奖项与证明" width="720px" class="b-dialog honor-review-dialog" destroy-on-close :close-on-click-modal="!busy" :close-on-press-escape="!busy" :show-close="!busy" @close="emit('close')">
    <template v-if="claim">
      <div class="honor-review-summary"><span>{{ claim.unit_name }} · {{ claim.award_kind === 'placing' ? '项目名次' : '专项奖' }}</span><h3>{{ claim.names || '名单待核对' }}</h3><p>原奖项：<strong>{{ claim.title }}</strong> · {{ claim.people_count }} 人</p><details v-if="claim.history_count"><summary>已保留 {{ claim.history_count }} 份历史证明</summary><p>旧版继续留档，重新签发后只展示最新有效证明。</p></details></div>
      <el-alert v-if="error" :title="error" type="error" :closable="false" />
      <div class="honor-result-heading"><h4>核对正式比赛结果</h4><span>{{ claim.basis_results.length }} 场</span></div>
      <p class="b-muted">{{ claim.award_kind === 'placing' ? '请结合本项目的全部正式结果，确认这份奖项的最终名次。' : '请核对下列关联比赛，确认是否符合这个专项奖。' }}</p>
      <div class="honor-basis-list"><MatchScoreCard v-for="result in claim.basis_results" :key="result.matchId" :code="result.code || result.matchId" :unit-name="result.unitName || claim.unit_name" :side-a="result.sideA" :side-b="result.sideB" :performance="result.performance" :status="result.status" /><p v-if="!claim.basis_results.length" class="b-muted">缺少正式结果，请先录入并确认赛果。</p></div>
      <el-form label-position="top"><el-form-item label="办理方式"><el-radio-group v-model="decision"><el-radio-button value="reissue">签发新证明</el-radio-button><el-radio-button value="revoke">撤销该奖项</el-radio-button></el-radio-group></el-form-item><el-form-item v-if="decision === 'reissue'" label="确认后的奖项名称"><el-input v-model="title" maxlength="200" show-word-limit /></el-form-item><el-form-item :label="decision === 'reissue' ? '核实说明' : '撤销原因'"><el-input v-model="reason" type="textarea" :rows="3" maxlength="2000" show-word-limit :placeholder="decision === 'reissue' ? '例如：已核对全部正式赛果，确认该报名获得第二名。' : '说明这个奖项为什么需要撤销。'" /></el-form-item></el-form>
      <p class="b-muted">{{ decision === 'reissue' ? '新证明替换同一奖项的旧版，原证明保留在历史记录中。' : '该奖项不再显示为有效证明，原记录和撤销原因保留。' }}</p>
    </template>
    <template #footer><el-button :disabled="busy" @click="emit('close')">暂不办理</el-button><el-button :type="decision === 'reissue' ? 'primary' : 'danger'" :loading="busy" :disabled="!reason.trim() || decision === 'reissue' && (!title.trim() || !validBasis)" @click="submit">{{ decision === 'reissue' ? '确认并签发' : '确认撤销' }}</el-button></template>
  </el-dialog>
</template>
<script setup lang="ts">
import { performAction } from '@/api/sports/phase1';
import { computed, ref, watch } from 'vue';
import MatchScoreCard from '@/components/sports/MatchScoreCard.vue';
import type { MatchPerformance } from '@/utils/matchPresentation';
export interface ReviewClaim { id: string; title: string; version: number; people_count: number; names: string; unit_name: string; award_kind: string; status: string; history_count: number; basis_text: string; basis_fingerprint: string; basis_results: {matchId: string;code: string;revision: number;status: string;unitName?: string;sideA?: string;sideB?: string;performance?: MatchPerformance}[] }
const props = defineProps<{claim?: ReviewClaim; initialDecision?: string}>();
const emit = defineEmits<{close: []; completed: []}>();
const title = ref(''); const reason = ref(''); const decision = ref('reissue'); const busy = ref(false); const error = ref('');
const validBasis = computed(() => !!props.claim?.basis_results.length && props.claim.basis_results.every(result => result.status === 'confirmed'));
watch(() => [props.claim, props.initialDecision] as const, ([claim]) => {title.value = claim?.title || ''; reason.value = ''; decision.value = props.initialDecision || 'reissue'; error.value = '';}, { immediate: true });
async function submit() {if (!props.claim || busy.value) return; busy.value = true; error.value = ''; try {
  await performAction('honor.resolve', {honorId: props.claim.id, expectedVersion: props.claim.version, decision: decision.value, reason: reason.value.trim(), ...(decision.value === 'reissue' ? {title: title.value.trim(), basisFingerprint: props.claim.basis_fingerprint} : {})}, decision.value === 'reissue' ? `确认将 ${props.claim.names} 的「${props.claim.title}」替换为「${title.value.trim()}」？` : `确认撤销 ${props.claim.names} 的「${props.claim.title}」？`);
  emit('completed'); emit('close');
} catch (cause) {if (cause !== 'cancel' && cause !== 'close') error.value = cause instanceof Error ? cause.message : '办理未完成，请刷新并重新核对。';} finally {busy.value = false;} }
</script>
