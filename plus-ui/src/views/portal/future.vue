<template>
  <ConsumerShell>
    <section class="consumer-hero">
      <p class="consumer-kicker">暂未开放</p>
      <h1>{{ page.title }}</h1>
      <p class="consumer-muted">{{ page.copy }}</p>
    </section>
    <section class="consumer-card" style="margin-top: 16px">
      <div class="consumer-actions">
        <el-button @click="router.push('/portal/home')">回到首页</el-button>
        <el-button type="primary" @click="router.push('/public/events')">查看赛事</el-button>
      </div>
    </section>
  </ConsumerShell>
</template>

<script setup lang="ts" name="PortalFuture">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import ConsumerShell from '@/layout/consumer/ConsumerShell.vue';

const route = useRoute();
const router = useRouter();
const pages = {
  venues: {
    title: '场馆服务',
    copy: '场馆预约暂未开放，可先在赛事详情查看比赛地点。'
  },
  life: {
    title: '运动生活',
    copy: '运动生活暂未开放，可先查看赛事或寻找参赛搭档。'
  }
};
const page = computed(() => pages[route.params.kind === 'life' ? 'life' : 'venues']);
</script>
