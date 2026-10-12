<template>
  <ConsumerShell
    ><ConsumerPageHeader title="我的赛果" eyebrow="我的参赛 · 运动记录" description="查看本人参与场次的正式结果。"
      ><router-link class="btn" to="/portal/proofs">查看成绩证明<ConsumerIcon name="arrow" /></router-link
    ></ConsumerPageHeader>
    <nav class="personal-nav">
      <router-link to="/portal/registration">报名与进度</router-link><router-link to="/portal/teams">我的队伍</router-link
      ><router-link to="/portal/results" class="active">正式赛果</router-link><router-link to="/portal/proofs">成绩证明</router-link>
    </nav>
    <ConsumerState v-if="error" error title="赛果暂时无法读取" :description="error"><button class="btn" @click="load">重新读取</button></ConsumerState><ConsumerState
      v-else-if="loading"
      loading
      title="正在读取赛果"
      icon="award"
    /><ConsumerState
      v-else-if="!results.length"
      title="暂无正式赛果"
      description="暂无已确认的本人赛果，报名与参赛进度可在我的参赛查看。"
      icon="award"
      ><router-link class="btn primary" to="/public/events">发现赛事</router-link></ConsumerState
    >
    <div v-else class="result-grid">
      <article v-for="result in results" :key="result.matchCode + result.unitName" class="result-card">
        <div class="between">
          <span class="badge gray">{{ result.unitName }}</span
          ><span v-if="result.eventCancelled" class="badge red">赛事已取消 · 历史</span><span v-else class="badge">正式赛果</span>
        </div>
        <h3>{{ result.eventName }}</h3>
        <p class="consumer-note">场次 {{ result.matchCode }}</p>
        <MatchScoreCard :performance="result" :side-a="result.sideA" :side-b="result.sideB" />
        <BattleCardButton :result="result" />
      </article>
    </div>
    <p class="consumer-note" style="margin-top: 20px">仅展示已确认赛果；取消赛事的记录保留历史标识。</p></ConsumerShell
  >
</template>
<script setup lang="ts" name="PortalResults">
import { onMounted, ref } from 'vue';
import ConsumerPageHeader from '@/components/consumer/ConsumerPageHeader.vue';
import ConsumerState from '@/components/consumer/ConsumerState.vue';
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import ConsumerShell from '@/layout/consumer/ConsumerShell.vue';
import { listMyResults } from '@/api/sports/competition';
import BattleCardButton from '@/components/consumer/BattleCardButton.vue';
import MatchScoreCard from '@/components/sports/MatchScoreCard.vue';
const error = ref('');
const loading = ref(true);
const results = ref<
  {
    matchCode: string;
    unitName: string;
    eventName: string;
    eventCancelled: boolean;
    summary: string;
    outcomeA: string;
    outcomeB: string;
    games?: string;
    sideA?: string;
    sideB?: string;
  }[]
>([]);

const load=async () => {
  loading.value=true;error.value='';
  try {
    const res = await listMyResults();
    results.value = res.data || [];
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '赛果暂时无法读取。';
  } finally {
    loading.value = false;
  }
};
onMounted(load);
</script>
<style scoped>
.result-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:23px;margin-top:25px}.result-card{min-width:0;border:1px solid var(--s-line,#e6e8e4);border-radius:24px;background:var(--s-surface,#fff);padding:29px;box-shadow:none}.result-card h3{font-size:22px;font-weight:600;letter-spacing:-.035em;line-height:1.5;margin:19px 0 10px;overflow-wrap:anywhere}.result-card .between{flex-wrap:wrap;gap:8px}.result-card .between .badge{font-size:10px;max-width:100%;white-space:normal;overflow-wrap:anywhere}.result-card .consumer-note{font-size:11px;color:var(--s-muted);line-height:1.8}.result-score{font-size:36px;font-weight:600;letter-spacing:-.065em;color:#af8a56;margin:27px 0 20px;padding:22px;background:#f8f2e6;border-radius:17px;line-height:1.3;overflow-wrap:anywhere}.result-card .consumer-muted{font-size:12px;line-height:1.9;color:var(--s-muted)}.result-card .notice{font-size:12px;border-radius:12px;line-height:1.8;background:var(--s-paper);padding:14px;margin:20px 0}.result-card :deep(.el-button){font-size:12px;border-radius:10px;min-height:40px}@media(max-width:750px){.result-grid{grid-template-columns:minmax(0,1fr);gap:18px}.result-card{padding:25px;border-radius:22px}.result-card h3{font-size:20px}.result-score{font-size:31px;padding:20px;margin:23px 0 18px}.result-card .consumer-muted{font-size:11px}}
</style>
