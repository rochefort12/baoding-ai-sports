<template>
  <ConsumerShell auth>
    <div class="consumer-auth-layout sport-auth-layout">
      <aside class="sport-auth-visual" aria-label="AI体育羽毛球主题">
        <img
          v-if="!imageUnavailable"
          class="sport-auth-image"
          src="/images/sports/sports-login-v1.webp"
          alt=""
          draggable="false"
          fetchpriority="high"
          @error="imageUnavailable = true"
        />
        <CourtScene v-else class="sport-auth-fallback" />
        <div class="sport-auth-wordmark"><span />AI SPORTS</div>
        <h2>AI体育</h2>
        <p>报名 · 集结 · 战绩</p>
        <nav class="sport-auth-destinations" aria-label="体育服务">
          <router-link to="/public/events"><ConsumerIcon name="events" />先浏览赛事<ConsumerIcon name="arrow" /></router-link>
        </nav>
      </aside>
      <section class="consumer-auth sport-auth-form">
        <router-link class="auth-back" :to="backTarget"><ConsumerIcon name="back" />{{ hasTask ? '返回刚才的页面' : '返回首页' }}</router-link>
        <h1>{{ title }}</h1>
        <p class="auth-description">{{ description }}</p>
        <div v-if="hasTask" class="auth-context"><ConsumerIcon name="events" />完成登录后，继续刚才的任务</div>
        <slot />
      </section>
    </div>
  </ConsumerShell>
</template>
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import ConsumerShell from '@/layout/consumer/ConsumerShell.vue';
import ConsumerIcon from './ConsumerIcon.vue';
import CourtScene from '@/components/sport-ui/CourtScene.vue';
import { sanitizeReturnTo, PLATFORM_HOME } from '@/utils/returnTo';
defineProps<{ title: string; description: string }>();
const route = useRoute();
const hasTask = computed(() => sanitizeReturnTo(route.query.returnTo) !== PLATFORM_HOME);
const backTarget = computed(() => sanitizeReturnTo(route.query.returnTo));
const imageUnavailable = ref(false);
</script>
