<template>
  <div class="consumer-app" :class="{ 'auth-page': auth }" @dragstart="preventImageDrag">
    <a class="consumer-skip" href="#consumer-content">跳到主要内容</a>
    <header class="consumer-header">
      <div class="consumer-header-inner">
        <div class="brand-group">
          <router-link class="consumer-brand" to="/portal/home"
            ><SportBrandMark />
            <div><strong>AI体育</strong><span>AI SPORTS</span></div></router-link
          ><span class="consumer-city"><ConsumerIcon name="pin" /><strong>保定</strong><span>城市站</span></span>
        </div>
        <nav v-if="!auth" class="consumer-nav" aria-label="主导航">
          <router-link
            v-for="item in nav.slice(0, 3)"
            :key="item.to"
            :to="item.to"
            :class="{ active: active(item.to) }"
            :aria-current="active(item.to) ? 'page' : undefined"
            >{{ item.label }}</router-link
          >
        </nav>
        <router-link v-if="auth && route.path !== '/login'" class="consumer-work-login" to="/login">管理登录</router-link>
        <div v-if="!auth" class="consumer-tools">
          <el-button v-if="loggedIn && !auth" link @click="openOrganizer">{{ organizerLabel }}</el-button>
          <template v-if="loggedIn"
            ><router-link class="header-notice" to="/portal/notices" :aria-label="unread ? '我的消息，' + unread + '条未读' : '我的消息'"
              ><ConsumerIcon name="bell" /><span v-if="unread" class="notice-count">{{ unread > 99 ? '99+' : unread }}</span></router-link
            ><router-link class="header-account" to="/portal/identity"
              ><img v-if="profileImage" class="account-avatar" :src="profileImage" alt="我的头像" draggable="false" @error="clearProfileImage" />
              <span v-else class="account-avatar">{{ Array.from(summary)[0] }}</span
              ><span class="account-name">{{ summary }}</span></router-link
            ><el-button link @click="logout">退出</el-button></template
          ><template v-else
            ><router-link class="header-login" :to="authLink('/portal/login')"><ConsumerIcon name="user" /><span>登录</span></router-link
            ><router-link class="header-register" :to="authLink('/portal/register')">注册</router-link></template
          >
          <el-dropdown class="consumer-entry-menu" trigger="click" @command="chooseEntry">
            <button type="button" class="consumer-entry-trigger" :disabled="switching" aria-label="切换入口">{{ switching ? '切换中…' : '切换入口' }}<ConsumerIcon name="chevron" /></button>
            <template #dropdown><el-dropdown-menu>
              <el-dropdown-item v-if="!loggedIn" command="login">登录／注册</el-dropdown-item>
              <el-dropdown-item v-if="loggedIn" command="organizer">{{ organizerLabel }}</el-dropdown-item>
              <el-dropdown-item v-if="loggedIn" command="profile">我的资料</el-dropdown-item>
              <el-dropdown-item command="work">平台／政府管理</el-dropdown-item>
              <el-dropdown-item v-if="loggedIn" divided command="logout">退出登录</el-dropdown-item>
            </el-dropdown-menu></template>
          </el-dropdown>
        </div>
      </div>
    </header>
    <main id="consumer-content" class="consumer-main" tabindex="-1"><slot /></main>
    <footer class="consumer-footer">
      <span><strong>AI体育</strong> · 赛事 · 小队 · 成长</span><span>保定城市站</span
      ><button type="button" class="consumer-work-footer" :disabled="switching" @click="chooseEntry('work')">平台／政府管理</button>
    </footer>
    <nav v-if="!auth" class="consumer-mobile-nav" aria-label="手机主导航">
      <template v-for="item in nav" :key="item.to"
        ><router-link :to="item.to" :class="{ active: active(item.to) }" :aria-current="active(item.to) ? 'page' : undefined"
          ><ConsumerIcon :name="item.icon" /><span>{{ item.label }}</span></router-link
        ></template
      >
    </nav>
    <AgentPanel v-if="!auth" v-model="agentVisible" />
    <AssistantBubble v-if="!auth" :open="agentVisible || consumerAi.open" @toggle="openServiceAi" />
  </div>
</template>
<script setup lang="ts">
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import SportBrandMark from '@/components/sport-ui/SportBrandMark.vue';
import AgentPanel from '@/components/consumer/AgentPanel.vue';
import AssistantBubble from '@/components/consumer/AssistantBubble.vue';
import { getDisplay } from '@/api/sports/phase1';
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { getApplication, enterOrganization } from '@/api/sports/organization';
import { readSportsAvatar } from '@/api/sports/avatar';
import { listNotices } from '@/api/sports/notice';
import { useUserStore } from '@/store/modules/user';
import { sanitizeReturnTo } from '@/utils/returnTo';
import { consumerAi, openConsumerAi } from '@/utils/consumerAi';
import { openWorkAccountLogin } from '@/utils/workAccountEntry';

const props = defineProps<{ auth?: boolean }>();

const route = useRoute();
const router = useRouter();
const userStore = useUserStore();
const switching = ref(false);
const chooseEntry = async (command: string) => {
  if (switching.value) return;
  switching.value = true;
  try {
    if (command === 'work') await openWorkAccountLogin();
    else if (command === 'organizer') await openOrganizer();
    else if (command === 'profile') await router.push('/portal/identity');
    else if (command === 'login') await router.push(authLink('/portal/login'));
    else if (command === 'logout') await logout();
  } finally { switching.value = false; }
};
// Login writes its token before navigation finishes. A work-account login can
// still be inside this auth shell, so token presence alone cannot authorize
// participant-only profile, notice, or admission queries.
const canReadParticipant = computed(() =>
  !props.auth && Boolean(userStore.token) && userStore.roles.includes('participant') &&
  !userStore.roles.includes('superadmin') &&
  (route.path.startsWith('/portal/') || route.path.startsWith('/public/events') || route.path.startsWith('/public/athletes/'))
);
const organizerReady = ref(false);
const organizerLabel = ref('我要办赛');
const openOrganizer = async () => {
  if (organizerReady.value) await enterOrganization();
  else await router.push('/portal/organization');
};
const summary = ref('已登录');
const profileImage = ref('');
let summarySequence = 0;
function clearProfileImage() {
  if (profileImage.value.startsWith('blob:')) URL.revokeObjectURL(profileImage.value);
  profileImage.value = '';
}
function hideBrokenImage(event: Event) {
  (event.target as HTMLImageElement).style.display = 'none';
}
const unread = ref(0);
let unreadSequence = 0;
let unreadLoadingFor = '';
let noticeTimer: number | undefined;
const agentVisible = ref(false);
const preventImageDrag = (event: DragEvent) => {
  // Native browser image ghosts are not product interactions. File-drop upload
  // remains available, and text selection / links retain their normal behavior.
  if (event.target instanceof HTMLImageElement) event.preventDefault();
};
function openServiceAi() { if (userStore.token) { consumerAi.open = false; agentVisible.value = !agentVisible.value; } else if (consumerAi.open) consumerAi.open = false; else openConsumerAi(); }
const nav = [
  { to: '/portal/home', label: '发现', icon: 'home' },
  { to: '/public/events', label: '赛事', icon: 'events' },
  { to: '/portal/registration', label: '我的参赛', icon: 'events' },
  { to: '/portal/identity', label: '我的', icon: 'user' }
];

const loggedIn = computed(() => Boolean(userStore.token));

const active = (path: string) => {
  if (path === '/portal/registration')
    return ['/portal/registration', '/portal/teams', '/portal/rooms', '/portal/results', '/portal/proofs'].some((group) => route.path.startsWith(group));
  if (path === '/portal/identity')
    return ['/portal/identity', '/portal/growth', '/portal/issues', '/portal/notices', '/portal/feedback', '/portal/organization'].some((group) => route.path.startsWith(group));
  return route.path === path || (path === '/public/events' && route.path.startsWith(path));
};

const authLink = (path: string) => {
  if (route.path === '/portal/login' || route.path === '/portal/register' || route.path === '/portal/forgot') {
    return { path, query: route.query.returnTo ? { returnTo: String(route.query.returnTo) } : {} };
  }
  return { path, query: { returnTo: sanitizeReturnTo(route.fullPath) } };
};

const loadUnread = async () => {
  if (!canReadParticipant.value) {
    unreadSequence++;
    unreadLoadingFor = '';
    unread.value = 0;
    return;
  }
  const expectedToken = userStore.token;
  if (unreadLoadingFor === expectedToken) return;
  const sequence = ++unreadSequence;
  unreadLoadingFor = expectedToken;
  try {
    const notices = await listNotices();
    if (!canReadParticipant.value || sequence !== unreadSequence || userStore.token !== expectedToken) return;
    unread.value = (notices.data || []).filter((item: { read: boolean }) => !item.read).length;
  } catch {
    // A temporary fetch failure does not falsely turn known unread messages into zero.
  } finally {
    if (sequence === unreadSequence) unreadLoadingFor = '';
  }
};
const refreshVisibleNotices = () => {
  if (document.visibilityState === 'visible' && canReadParticipant.value) void loadUnread();
};
const loadSummary = async () => {
  const sequence = ++summarySequence;
  clearProfileImage();
  if (!canReadParticipant.value) {
    summary.value = '已登录';
    return;
  }
  try {
    const res = await getDisplay();
    if (sequence !== summarySequence) return;
    summary.value = res.data?.display?.nickname || '球友';
    if (res.data?.display?.avatar_file_id) {
      try {
        const blob = await readSportsAvatar(res.data.accountId);
        if (sequence === summarySequence) profileImage.value = URL.createObjectURL(blob as unknown as Blob);
      } catch {
        /* 本人头像受控读取失败时用昵称首字，不显示虚构头像。 */
      }
    }
  } catch {
    if (sequence === summarySequence) summary.value = '球友';
  }
};

const logout = async () => {
  await userStore.logout();
  await router.replace('/portal/home');
};

watch([() => userStore.token, () => canReadParticipant.value], async () => {
  unreadSequence++;
  unreadLoadingFor = '';
  unread.value = 0;
  await loadSummary();
  await loadUnread();
});
watch(() => route.fullPath, () => {
  if (canReadParticipant.value) loadUnread();
});
onMounted(async () => {
  window.addEventListener('sports-notices-changed', loadUnread);
  window.addEventListener('focus', refreshVisibleNotices);
  document.addEventListener('visibilitychange', refreshVisibleNotices);
  noticeTimer = window.setInterval(refreshVisibleNotices, 30000);
  window.addEventListener('sports-display-changed', loadSummary);
  await loadSummary();
  await loadUnread();
  if (canReadParticipant.value) {
    try {
      const res = await getApplication();
      organizerReady.value = Boolean(res.data?.canEnter);
      organizerLabel.value = organizerReady.value ? '办赛工作台' : res.data?.status === 'submitted' ? '申请进度' : '我要办赛';
    } catch {
      /* 失败不授予组织入口，保留申请页重新核验。 */
    }
  }
});
onUnmounted(() => {
  summarySequence++;
  unreadSequence++;
  if (noticeTimer !== undefined) window.clearInterval(noticeTimer);
  clearProfileImage();
  window.removeEventListener('sports-notices-changed', loadUnread);
  window.removeEventListener('focus', refreshVisibleNotices);
  document.removeEventListener('visibilitychange', refreshVisibleNotices);
  window.removeEventListener('sports-display-changed', loadSummary);
});
</script>
