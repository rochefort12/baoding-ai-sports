<template>
  <ConsumerShell>
    <div class="premium-event-directory">
    <div class="event-directory-head premium-directory-head">
      <div>
        <span class="city-eyebrow">保定赛事</span>
        <h1>查找赛事</h1>
        <p class="muted">按运动项目、赛事状态或名称筛选。</p>
      </div>
    </div>

    <SportEventFilters v-model:keyword="keyword" v-model:sport="sport" v-model:status="status" :sports="sports" :statuses="statuses" @reset="resetFilters" />

    <div v-if="!loading && !error" class="directory-results" aria-live="polite">{{ filtered.length }} 场赛事</div>
    <ConsumerState v-if="loading" loading title="正在读取公开赛事" />
    <ConsumerState v-else-if="error" error title="赛事暂时无法读取" :description="error"><button class="btn" @click="load">重新加载</button></ConsumerState>
    <ConsumerState v-else-if="!filtered.length" title="没有符合条件的赛事" description="试试其他运动或状态；已有报名可以继续查看。"><button class="btn" type="button" @click="resetFilters">清除筛选</button><router-link class="btn" to="/portal/registration">我的报名</router-link></ConsumerState>
    <div v-else class="event-board">
      <PublicEventCard v-for="(row, index) in filtered" :key="row.id" :event="row" :two="index % 2 === 1" />
    </div>
    </div>
  </ConsumerShell>
</template>

<script setup lang="ts" name="PublicEventList">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import ConsumerShell from '@/layout/consumer/ConsumerShell.vue';
import PublicEventCard from '@/components/consumer/PublicEventCard.vue';
import ConsumerState from '@/components/consumer/ConsumerState.vue';
import { EventCard, listPublicEvents } from '@/api/sports/event';
import SportEventFilters from '@/components/sport-ui/SportEventFilters.vue';

const sports = computed(() => [
  { id: 'all', name: '全部项目' },
  ...Array.from(new Set(rows.value.map((e) => e.projectName).filter((p): p is string => Boolean(p)))).map((p) => ({ id: p, name: p }))
]);
const statuses = [
  { id: 'all', name: '全部赛事' },
  { id: 'open', name: '可报名' },
  { id: 'ongoing', name: '进行中' },
  { id: 'finished', name: '已结束' }
];

const rows = ref<EventCard[]>([]);
const loading = ref(true);
const error = ref('');
const route = useRoute();
const legacySports: Record<string, string> = { badminton: '羽毛球', running: '跑步', basketball: '篮球', football: '足球', 'table-tennis': '乒乓球' };
const initialSport = () => (typeof route.query.sport === 'string' ? legacySports[route.query.sport] || route.query.sport : 'all');
const sport = ref(initialSport());
watch(
  () => route.query.sport,
  () => {
    sport.value = initialSport();
  }
);
const status = ref('all');
const keyword = ref('');

const filtered = computed(() =>
  rows.value.filter((row) => {
    const name = row.name || '';
    if (sport.value !== 'all' && row.projectName !== sport.value) return false;
    if (keyword.value.trim() && !name.toLocaleLowerCase().includes(keyword.value.trim().toLocaleLowerCase())) {
      return false;
    }
    if (status.value === 'open') {
      return row.holdingStatus !== 'cancelled' && row.phase === 'registration';
    }
    if (status.value === 'finished') {
      return row.phase === 'finished';
    }
    if (status.value === 'ongoing') return row.phase === 'ongoing' && row.holdingStatus !== 'cancelled';
    return true;
  })
);

const resetFilters = () => {
  status.value = 'all';
  keyword.value = '';
  sport.value = 'all';
};

const load=async () => {
  loading.value=true;error.value='';
  try {
    const res = await listPublicEvents();
    rows.value = res.data || [];
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '公开赛事暂时无法读取。';
  } finally {
    loading.value = false;
  }
};
onMounted(load);
</script>
<style scoped>
.premium-event-directory{min-width:0}.premium-directory-head{display:flex;align-items:center;margin:8px 0 23px}.premium-directory-head h1{font-size:33px;letter-spacing:-.055em;font-weight:600;margin:9px 0 11px}.city-eyebrow{font-size:11px;color:var(--s-muted);letter-spacing:0}.premium-directory-head p{font-size:12px;line-height:1.9;margin:0}.directory-results{color:var(--s-muted);font-size:11px;margin:0 0 17px}.premium-event-directory .event-board{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,300px),1fr));gap:21px}@media(max-width:700px){.premium-directory-head{margin:7px 0 20px}.premium-directory-head h1{font-size:27px}.premium-directory-head p{font-size:11px}.premium-event-directory .event-board{gap:15px}.directory-results{margin-bottom:15px}}
</style>
