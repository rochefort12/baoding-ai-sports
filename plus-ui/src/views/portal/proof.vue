<template>
  <ConsumerShell
    ><ConsumerPageHeader title="成绩证明" eyebrow="我的参赛 · 运动记录" description="查看和下载主办方签发的获奖证明。"
      ><router-link class="btn" to="/portal/results">查看本人赛果<ConsumerIcon name="arrow" /></router-link
    ></ConsumerPageHeader>
    <nav class="personal-nav">
      <router-link to="/portal/registration">报名与进度</router-link><router-link to="/portal/teams">我的队伍</router-link
      ><router-link to="/portal/results">正式赛果</router-link><router-link to="/portal/proofs" class="active">成绩证明</router-link>
    </nav>
    <div class="honor-proof-tabs" role="tablist" aria-label="成绩证明分类"><button role="tab" :aria-selected="!showHistory" @click="showHistory=false">当前有效 · {{ allProofs.filter(p=>p.current).length }}</button><button role="tab" :aria-selected="showHistory" @click="showHistory=true">历史记录 · {{ allProofs.filter(p=>!p.current).length }}</button></div>
    <ConsumerState v-if="error" error title="证明暂时无法读取" :description="error"><button class="btn" @click="load">重新读取</button></ConsumerState><ConsumerState
      v-else-if="loading"
      loading
      title="正在读取证明"
      icon="award"
    /><ConsumerState v-else-if="!proofs.length" :title="showHistory ? '暂无历史证明' : '暂无有效获奖证明'" :description="showHistory ? '被更正、待复核或撤销的证明会保留在这里。' : '主办方确认获奖并签发后，本人成绩证明会显示在这里。'" icon="award"
      ><router-link class="btn primary" to="/public/events">发现赛事</router-link></ConsumerState
    >
    <div v-else class="result-grid">
      <article v-for="proof in proofs" :key="proof.honorId" class="result-card proof-card" :class="{'proof-history-card': !proof.current}">
        <span class="honor-proof-status">{{ proofStatus(proof) }}</span>
        <OfficialAwardMedal :title="proof.title"/><span class="eyebrow" style="margin-top: 16px">赛事成绩证明</span>
        <h3>{{ proof.title }}</h3>
        <p class="consumer-muted">{{ proof.eventName }} · {{ proof.unitName }}</p>
        <div class="result-score" style="font-size: 18px; letter-spacing: 0">{{ proof.names }}</div>
        <p class="consumer-note">签发时间：{{ businessTime(proof.awardedAt) }}</p><ProofCardButton v-if="proof.current" :proof="proof" /><p v-else class="honor-history-note">{{ proof.reason || '历史证明已停止使用，以当前有效证明为准。' }}</p>
      </article>
    </div>
    <p class="consumer-note" style="margin-top: 20px">证明来自具体赛事奖项，不代表平台认证的外部头衔。</p></ConsumerShell
  >
</template>
<script setup lang="ts" name="PortalProof">
import { computed, onMounted, ref } from 'vue';
import ConsumerPageHeader from '@/components/consumer/ConsumerPageHeader.vue';
import ConsumerState from '@/components/consumer/ConsumerState.vue';
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import ConsumerShell from '@/layout/consumer/ConsumerShell.vue';
import { ProofCard, listMyProofs } from '@/api/sports/competition';
import ProofCardButton from '@/components/consumer/ProofCardButton.vue';
import OfficialAwardMedal from '@/components/consumer/OfficialAwardMedal.vue';
import { businessTime } from '@/utils/business';

const error = ref('');
const loading = ref(true);
const allProofs = ref<ProofCard[]>([]);
const showHistory = ref(false);
const proofs = computed(() => allProofs.value.filter(proof => showHistory.value ? !proof.current : proof.current));
const proofStatus = (proof: ProofCard) => (({verified:'当前有效',replaced:'已被新版替换',revoked:'已撤销',suspended:'待主办方复核',pending:'待核实',revised:'待复核'} as Record<string,string>)[proof.status] || '历史记录');

const load=async () => {
  loading.value=true;error.value='';
  try {
    const res = await listMyProofs(true);
    allProofs.value = res.data || [];
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '证明暂时无法读取。';
  } finally {
    loading.value = false;
  }
};
onMounted(load);
</script>
<style scoped>
.result-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:23px;margin-top:26px}.result-card.proof-card{border-radius:24px;padding:33px;background:linear-gradient(145deg,#fffdf6,#efe7d7);border:1px solid #e2d5b9;text-align:center;box-shadow:none}.proof-emblem{width:65px;height:65px;border-radius:50%;margin:0 auto;background:#eee5d1;color:#ac905a;display:grid;place-items:center}.proof-emblem svg{width:28px;height:28px}.proof-card .eyebrow{font-size:13px;letter-spacing:.06em;color:#a39375;display:block}.proof-card h3{font-size:29px;line-height:1.4;font-weight:600;letter-spacing:-.04em;margin:22px 0 14px;color:#7d6540;overflow-wrap:anywhere}.proof-card .consumer-muted{font-size:14px;line-height:1.8;color:#a19379}.proof-card .result-score{font-size:19px;color:#8b7655;margin:25px 0}.proof-card .consumer-note{font-size:13px;color:#ab9b7c;line-height:1.8;margin:15px 0 24px}@media(max-width:750px){.result-grid{grid-template-columns:1fr;gap:19px}.result-card.proof-card{padding:29px 25px;border-radius:22px}.proof-card h3{font-size:27px}.proof-card .consumer-muted{font-size:14px}}
</style>
