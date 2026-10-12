<template>
  <section v-if="goals?.length" class="growth-title-goals" aria-label="称号获得条件">
    <div class="goal-heading"><h3>称号目标</h3><p v-if="next">距离「{{ next.title }}」还需{{ milestone(next) }} {{ next.remaining }} 场</p><p v-else>当前称号条件已完成，以已授予记录为准。</p></div>
    <div class="goal-list"><article v-for="goal in goals" :key="goal.code" :class="{awarded:goal.awarded}">
      <SportsTitleBadge :title="goal.title" :code="goal.code" />
      <p>{{ milestone(goal) }} {{ goal.required }} 场</p>
      <div class="goal-progress" role="progressbar" :aria-label="goal.title+'获得进度'" :aria-valuemin="0" :aria-valuemax="goal.required" :aria-valuenow="Math.min(goal.current,goal.required)"><i :style="{width:Math.min(100,goal.current/goal.required*100)+'%'}" /></div>
      <span>{{ goal.awarded ? '已获得' : goal.remaining ? '已完成 '+goal.current+' / '+goal.required+' 场' : '条件已达到，记录待核对' }}</span>
    </article></div>
  </section>
</template>
<script setup lang="ts">
import { computed } from 'vue';
import type { GrowthTitleGoal } from '@/api/sports/growth';
import SportsTitleBadge from './SportsTitleBadge.vue';
const props=defineProps<{goals?:GrowthTitleGoal[]}>();
const next=computed(()=>props.goals?.filter(goal=>!goal.awarded&&goal.remaining>0).sort((a,b)=>a.remaining-b.remaining)[0]);
const milestone=(goal:GrowthTitleGoal)=>goal.milestone==='checkin'?'赛事报到':goal.milestone==='team_finish'?'小队有效完赛':'有效完赛';
</script>
<style scoped>
.growth-title-goals{margin:26px 0}.goal-heading h3{font-size:15px;margin:0}.goal-heading p{font-size:11px;color:var(--s-muted);line-height:1.8;margin:8px 0 16px}.goal-list{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}.goal-list article{padding:17px 14px;border:1px solid var(--s-line);border-radius:16px;min-width:0;background:#f9f9f7}.goal-list article.awarded{border-color:#dbc79f;background:#fffdf7}.goal-list p{font-size:11px;color:var(--s-muted);margin:13px 0}.goal-list span{display:block;font-size:10px;color:var(--s-muted);line-height:1.7}.goal-progress{height:4px;overflow:hidden;border-radius:4px;background:#e8e8e2;margin:12px 0}.goal-progress i{display:block;height:100%;border-radius:inherit;background:#b99b60}@media(max-width:650px){.goal-list{grid-template-columns:1fr}.goal-list article{padding:17px}.goal-list p{margin:10px 0}.goal-heading p{font-size:12px}}
</style>
