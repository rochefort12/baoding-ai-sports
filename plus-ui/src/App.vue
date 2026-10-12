<template>
  <el-config-provider :locale="appStore.locale" :size="appStore.size">
    <router-view />
    <ConsumerAssistant v-if="consumerPage" />
  </el-config-provider>
</template>

<script setup lang="ts">
import { useSettingsStore } from '@/store/modules/settings';
import { handleThemeStyle } from '@/utils/theme';
import { useAppStore } from '@/store/modules/app';
import { computed, defineAsyncComponent } from 'vue';
import { useRoute } from 'vue-router';

const ConsumerAssistant = defineAsyncComponent(() => import('@/components/consumer/ConsumerAssistant.vue'));
const route = useRoute();
const consumerPage = computed(
  () =>
    (route.path.startsWith('/public/events') || route.path.startsWith('/portal/')) &&
    !['/portal/login', '/portal/register', '/portal/forgot', '/portal/organization'].includes(route.path)
);

const appStore = useAppStore();

onMounted(() => {
  nextTick(() => {
    // 初始化主题样式
    handleThemeStyle(useSettingsStore().theme);
  });
});
</script>
