<template>
  <div class="match-score-editor">
    <p class="score-help">比分按 A : B 记录。点按计分后手动结束本局，核对胜方再保存草稿。</p>
    <div class="score-winners" role="group" aria-label="选择比赛胜方">
      <button v-for="side in sides" :key="side.slot" type="button" class="score-winner" :class="{ selected: modelValue.outcomeA === side.outcome }" :aria-pressed="modelValue.outcomeA === side.outcome" @click="choose(side.outcome)"><small>{{ side.slot }}</small><strong>{{ side.name }}</strong><span>点击选择获胜</span></button>
      <button type="button" class="score-draw" :aria-pressed="modelValue.outcomeA === 'draw'" @click="choose('draw')">平局</button>
    </div>
    <div class="score-live">
      <div v-for="side in sides" :key="side.slot" class="score-counter"><label :for="'score-'+side.slot">{{ side.slot }} · {{ side.name }}</label><div><button type="button" :aria-label="side.slot+' 侧减一分'" :disabled="live[side.slot] === 0" @click="live[side.slot]--">−</button><input :id="'score-'+side.slot" v-model.number="live[side.slot]" type="number" min="0" max="9999" :aria-label="side.slot+' 侧当前比分'"/><button type="button" :aria-label="side.slot+' 侧加一分'" @click="live[side.slot] = Math.min(9999, live[side.slot]+1)">+</button></div></div>
    </div>
    <div class="score-game-actions"><label>目标分提醒 <input v-model.number="target" type="number" min="1" max="9999" aria-label="目标分提醒"/></label><div><el-button v-if="pendingGame" @click="cancelGame">取消本局编辑</el-button><el-button @click="finishGame">结束本局</el-button></div></div>
    <p v-if="Math.max(live.A, live.B) >= target && live.A !== live.B" class="score-prompt" role="status">达到你设置的提示分。请核对本场规则，再点击“结束本局”。</p>
    <p class="score-help">目标分只用于提醒；系统不会自动判定赛点、结束比赛或发布赛果。</p>
    <ol v-if="games.length" class="score-games"><li v-for="(game, index) in games" :key="index"><span>第 {{ index + 1 }} 局</span><strong>{{ game.a }} : {{ game.b }}</strong><button type="button" :aria-label="'修改第 '+(index+1)+' 局'" @click="editGame(index)">修改</button><button type="button" :aria-label="'删除第 '+(index+1)+' 局'" @click="removeGame(index)">删除</button></li></ol>
    <div class="score-summary"><div><small>当前总比分 · A : B</small><strong>{{ modelValue.summary || '尚未记录' }}</strong></div><el-button :disabled="!games.length" @click="finishMatch">结束比赛并核对胜方</el-button></div>
    <details class="score-advanced"><summary>直接填写比分 / 保留原始记录</summary><el-form label-position="top"><el-form-item label="总比分（A : B）"><el-input :model-value="modelValue.summary" @update:model-value="patch({ summary: $event })" placeholder="例如 2:1"/></el-form-item><el-form-item label="分局比分（A : B）"><el-input :model-value="modelValue.games" @update:model-value="changeRawGames" placeholder="21:18|18:21|21:17"/></el-form-item></el-form></details>
  </div>
</template>
<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { ElMessage } from 'element-plus';
type Draft = { outcomeA: string; outcomeB: string; summary: string; games: string };
const props = defineProps<{ modelValue: Draft; sideA: string; sideB: string }>();
const emit = defineEmits<{ 'update:modelValue': [value: Draft]; 'pending-game': [value: boolean] }>();
const live = reactive<Record<string, number>>({ A: 0, B: 0 });
const target = ref(21), editing = ref<number | null>(null);
const pendingGame = computed(() => editing.value !== null || live.A !== 0 || live.B !== 0);
watch(pendingGame, value => emit('pending-game', value), { immediate: true });
const cancelGame = () => { live.A = 0; live.B = 0; editing.value = null; };
const games = ref<{ a: number; b: number }[]>([]);
const sides = computed(() => [{ slot: 'A', name: props.sideA, outcome: 'win' }, { slot: 'B', name: props.sideB, outcome: 'loss' }]);
const patch = (value: Partial<Draft>) => emit('update:modelValue', { ...props.modelValue, ...value });
const choose = (value: string) => patch({ outcomeA: value, outcomeB: value === 'win' ? 'loss' : value === 'loss' ? 'win' : 'draw' });
const parseGames = (value: string) => value.split('|').filter(Boolean).filter(game => /^\d+:\d+$/.test(game)).map(game => { const [a,b] = game.split(':').map(Number); return { a,b }; });
watch(() => props.modelValue.games, value => { games.value = parseGames(value); }, { immediate: true });
const totals = () => [games.value.filter(game => game.a > game.b).length, games.value.filter(game => game.b > game.a).length];
const syncGames = () => { const [a,b] = totals(); patch({ games: games.value.map(game => `${game.a}:${game.b}`).join('|'), summary: `${a}:${b}`, outcomeA: '', outcomeB: '' }); };
const validScore = (value: number) => Number.isInteger(value) && value >= 0 && value <= 9999;
const finishGame = () => {
  if (!validScore(live.A) || !validScore(live.B) || live.A === live.B) { ElMessage.warning('请填写双方有效比分，并核对本局胜方。'); return; }
  if (props.modelValue.games && games.value.map(game => `${game.a}:${game.b}`).join('|') !== props.modelValue.games) { ElMessage.warning('原分局记录含自定义内容，请先在直接填写中核对，避免覆盖。'); return; }
  const game = { a: live.A, b: live.B };
  if (editing.value == null) games.value.push(game); else games.value[editing.value] = game;
  editing.value = null; live.A = 0; live.B = 0; syncGames();
  ElMessage.success('本局已记入编辑区，请继续计分或结束比赛。');
};
const editGame = (index: number) => { editing.value = index; live.A = games.value[index].a; live.B = games.value[index].b; };
const removeGame = (index: number) => { games.value.splice(index,1); editing.value = null; syncGames(); };
const finishMatch = () => { const [a,b] = totals(); choose(a > b ? 'win' : a < b ? 'loss' : 'draw'); ElMessage.success('已根据记录的局数选中胜方，请核对后保存草稿。'); };
const changeRawGames = (value: string) => { editing.value = null; patch({ games: value, outcomeA: '', outcomeB: '' }); };
</script>
