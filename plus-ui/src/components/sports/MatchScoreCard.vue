<template>
  <div class="match-score-card" :class="{ 'match-score-card--compact': compact, 'match-score-card--void': status === 'void' }">
    <div v-if="code || unitName || status" class="match-score-caption"><span v-if="unitName">{{ unitName }}</span><strong v-if="code">场次 {{ code }}</strong><span v-if="status" class="match-score-status">{{ statusLabel }}</span></div>
    <template v-if="status !== 'void' && status !== 'missing'">
      <div class="match-score-board">
        <div class="match-score-team" :class="{ 'winner': performance?.outcomeA === 'win' }"><span class="match-side">A</span><strong>{{ sideA || 'A 方参赛者' }}</strong><span>{{ recordedOutcomeLabel(performance?.outcomeA) }}</span></div>
        <div class="match-score-total"><small>总比分 · A : B</small><div v-if="total"><b>{{ total.a }}</b><span>:</span><b>{{ total.b }}</b></div><strong v-else class="match-score-text">{{ performance?.summary || '尚未录分' }}</strong></div>
        <div class="match-score-team" :class="{ 'winner': performance?.outcomeB === 'win' }"><span class="match-side">B</span><strong>{{ sideB || 'B 方参赛者' }}</strong><span>{{ recordedOutcomeLabel(performance?.outcomeB) }}</span></div>
      </div>
      <ol v-if="games?.length" class="match-game-scores" aria-label="分局比分，按 A 方与 B 方显示"><li v-for="game in games" :key="game.number"><span>第 {{ game.number }} 局</span><strong><b :class="{ 'game-winner': Number(game.a) > Number(game.b) }">{{ game.a }}</b><em>:</em><b :class="{ 'game-winner': Number(game.b) > Number(game.a) }">{{ game.b }}</b></strong></li></ol>
      <div v-else-if="games === null" class="match-score-original"><span>原始分局说明</span><p>{{ performance?.games }}</p></div>
      <p v-else-if="!compact" class="match-score-note">本场未提供分局比分。</p>
    </template>
    <p v-else class="match-score-note">{{ status === 'void' ? '本场正式赛果已撤销，请先核实有效结果。' : '本场还没有正式结果，暂不能作为签发依据。' }}</p>
  </div>
</template>
<script setup lang="ts">
import { computed } from 'vue';
import { recordedGameScores, recordedOutcomeLabel, recordedScorePair, type MatchPerformance } from '@/utils/matchPresentation';
const props = defineProps<{ performance?: MatchPerformance | null; sideA?: string | null; sideB?: string | null; code?: string; unitName?: string; status?: string | null; compact?: boolean }>();
const total = computed(() => recordedScorePair(props.performance?.summary));
const games = computed(() => recordedGameScores(props.performance?.games));
const statusLabel = computed(() => ({ confirmed: '正式结果', draft: '录分草稿', void: '已撤销', missing: '待确认' } as Record<string, string>)[props.status || ''] || '待录分');
</script>
