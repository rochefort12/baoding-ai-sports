<template>
  <div class="business-app">
    <button v-if="mobileOpen" class="b-backdrop" aria-label="关闭导航" @click="mobileOpen = false"></button>
    <aside class="b-sidebar" :class="{ open: mobileOpen }">
      <router-link :to="homePath" class="b-brand"
        ><SportBrandMark />
        <div>AI体育<small>主办方工作台</small></div></router-link
      >
      <p class="b-menu-caption">{{ applicant ? '办赛申请' : '赛事运营' }}</p>
      <nav>
        <router-link v-for="item in links" :key="item.to" :to="item.to" @click="mobileOpen = false" :class="{ active: active(item.to) }"
          ><ConsumerIcon :name="item.icon" />{{ item.label }}</router-link
        >
      </nav>
      <div class="b-sidebar-foot">
        <span class="b-dot"></span>{{ applicant ? '平台账号 · 准入前服务' : '当前主办方'
        }}<small>{{ applicant ? '申请通过表示平台准入' : '工作台' }}</small>
      </div>
    </aside>
    <div class="b-main">
      <header class="b-topbar">
        <div class="b-top-left">
          <el-button class="b-menu-toggle" text @click="mobileOpen = !mobileOpen" aria-label="打开导航">☰</el-button
          ><span class="b-identity">{{ applicant ? '平台身份' : '办赛工作台' }}</span
          ><strong>{{ applicant ? '我要办赛' : context?.organizationName || '正在核验组织' }}</strong>
        </div>
        <div class="b-top-actions">
          <el-button v-if="context && !applicant" class="b-ai-button" @click="command('AI办赛')"><img class="sport-assistant-mark" src="/images/sports/assistant-orb-v2.webp" alt="" width="22" height="22" draggable="false"/>准备赛事</el-button
          ><el-button v-if="context && !applicant" class="b-manual-button" @click="command('手动创建')">＋ 手动创建赛事</el-button
          ><el-button text @click="back">返回运动平台</el-button><el-button text @click="logout">退出</el-button>
        </div>
      </header>
      <nav v-if="nested" class="b-breadcrumb" aria-label="当前位置">
        <router-link to="/org-desk/home">工作台</router-link><span>/</span><router-link to="/org-desk/events">赛事管理</router-link><span>/</span
        ><router-link v-if="currentEvent" :to="'/org-desk/workspace/' + currentEvent.id">{{ currentEvent.name || '未命名赛事' }}</router-link
        ><span v-else>{{ route.path.includes('from-document') ? 'AI办赛' : '赛事工作区' }}</span
        ><template v-if="currentEvent && route.query.task && taskTitle"
          ><span>/</span><strong>{{ taskTitle }}</strong></template
        >
      </nav>
      <main id="business-main" class="b-content">
        <section v-if="contextError && !applicant" class="b-state">
          <h2>暂时无法进入办赛工作台</h2>
          <p>{{ contextError }}</p>
          <el-button @click="loadContext">重新核验</el-button><el-button @click="back">返回平台</el-button>
        </section>
        <section v-else-if="!applicant && !context" class="b-state" aria-busy="true">正在核验组织身份…</section>
        <slot v-else />
      </main>
    </div>
    <template v-if="context && !applicant && !contextError">
      <BusinessAssistant :key="context.organizationId" ref="assistant" :context="context" :event="currentEvent" @saved="changed" />
      <div class="b-global-tools"><EventManage :key="context.organizationId" ref="eventTools" mode="controls" @changed="changed" /></div>
    </template>
  </div>
</template>
<script setup lang="ts">
import { computed, onMounted, onUnmounted, provide, ref, watch } from 'vue';
import { useRoute, useRouter, type RouteLocationNormalized } from 'vue-router';
import SportBrandMark from '@/components/sport-ui/SportBrandMark.vue';
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import BusinessAssistant from '@/components/business/BusinessAssistant.vue';
import EventManage from '@/views/sports/event/index.vue';
import { useUserStore } from '@/store/modules/user';
import { useTagsViewStore } from '@/store/modules/tagsView';
import { getDeskContext, type DeskContext } from '@/api/sports/desk';
import { getManagedEvent, type EventCard } from '@/api/sports/event';
import { getPlatformToken } from '@/utils/auth';
import { returnToPlatform } from '@/api/sports/organization';
import { businessAiKey, businessRevisionKey } from '@/utils/businessAi';
const props = defineProps<{ applicant?: boolean }>();
const route = useRoute(),
  router = useRouter(),
  user = useUserStore(),
  tags = useTagsViewStore();
const mobileOpen = ref(false),
  context = ref<DeskContext>(),
  contextError = ref(''),
  currentEvent = ref<EventCard>(),
  revision = ref(0);
const assistant = ref<InstanceType<typeof BusinessAssistant>>(),
  eventTools = ref<InstanceType<typeof EventManage>>();
provide('deskContext', context);
provide(businessRevisionKey, revision);
const command = (name: string) => (name === '手动创建' ? eventTools.value?.openCreate() : assistant.value?.command(name));
provide(businessAiKey, command);
const homePath = computed(() => (props.applicant ? '/portal/organization' : '/org-desk/home'));
const links = computed(() =>
  props.applicant
    ? [{ to: '/portal/organization', label: '申请与审核进度', icon: 'file' }]
    : [
        { to: '/org-desk/home', label: '运营概览', icon: 'home' },
        { to: '/org-desk/events', label: '赛事管理', icon: 'events' },
        { to: '/org-desk/registrations', label: '报名管理', icon: 'team' },
        { to: '/org-desk/competition', label: '现场执行', icon: 'award' },
        { to: '/org-desk/catalog', label: '报名字段', icon: 'file' },
        { to: '/org-desk/issues', label: '投诉处理', icon: 'file' }
      ]
);
const nested = computed(() => !props.applicant && (route.path.startsWith('/org-desk/workspace') || route.path.includes('from-document')));
const active = (path: string) => route.path === path || (path === '/org-desk/events' && nested.value);
const taskTitle = computed(
  () =>
    (
      ({
        overview: '概览',
        projects: '项目与费用',
        registrations: '报名名单',
        fields: '报名设置',
        checkin: '赛事报到',
        matches: '场次与录分',
        awards: '获奖证明',
        publication: '发布管理',
        notifications: '取消通知'
      }) as Record<string, string>
    )[String(route.query.task)]
);
let contextSequence = 0,
  eventSequence = 0;
// 路由变化重新核验授权，但同组织保持助手任务；失败即移除全部组织组件。
async function loadContext() {
  const sequence = ++contextSequence;
  try {
    const res = await getDeskContext();
    if (sequence !== contextSequence) return;
    if (context.value && context.value.organizationId !== res.data.organizationId) currentEvent.value = undefined;
    context.value = res.data;
    contextError.value = '';
  } catch {
    if (sequence !== contextSequence) return;
    context.value = undefined;
    currentEvent.value = undefined;
    contextError.value = '当前组织授权不可用，或会话已失效。请重新进入组织后重试。';
  }
}
async function loadEvent() {
  const sequence = ++eventSequence;
  currentEvent.value = undefined;
  if (!route.path.startsWith('/org-desk/workspace') || !route.params.eventId || !context.value) return;
  const id = String(route.params.eventId),
    org = context.value.organizationId;
  try {
    const { data } = await getManagedEvent(id);
    if (sequence === eventSequence && org === context.value?.organizationId && id === String(route.params.eventId)) currentEvent.value = data;
  } catch {
    /* 工作区显示正式错误，不沿用旧赛事上下文。 */
  }
}
const changed = () => {
  revision.value++;
  loadEvent();
};
const back = () => (getPlatformToken() ? returnToPlatform() : router.push('/portal/home'));
const logout = async () => {
  await user.logout();
  tags.delAllViews();
  window.location.href = '/portal/home';
};
watch(
  () => route.fullPath,
  () => {
    mobileOpen.value = false;
    // 保留 RuoYi 缓存管理，只隐藏已打开页面标签；业务页使用侧栏与面包屑定位。
    tags.addView({
      ...route,
      meta: { ...route.meta, title: route.path.startsWith('/org-desk/workspace') ? '赛事工作区' : route.meta.title }
    } as RouteLocationNormalized);
    if (!props.applicant) {
      loadEvent();
      loadContext();
    }
  },
  { immediate: true }
);
watch(() => context.value?.organizationId, loadEvent);
const escape = (event: KeyboardEvent) => {
  if (event.key === 'Escape') mobileOpen.value = false;
};
onMounted(() => document.addEventListener('keydown', escape));
onUnmounted(() => {
  contextSequence++;
  eventSequence++;
  document.removeEventListener('keydown', escape);
});
</script>
