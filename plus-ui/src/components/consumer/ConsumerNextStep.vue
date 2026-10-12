<template>
  <section class="c-next-step">
    <div class="section-head">
      <h2>待办与报名进度</h2>
      <router-link class="btn text" to="/portal/registration">全部 →</router-link>
    </div>
    <article v-if="!loggedIn" class="c-task-card c-task-welcome">
      <span class="c-task-symbol"><ConsumerIcon name="user" /></span>
      <h3>登录查看报名进度</h3>
      <p>登录后，继续报名、确认伙伴，查看参赛进度。</p>
      <SportArtAction art="registration" small :to="{ path: '/portal/login', query: { returnTo: '/portal/registration' } }">登录</SportArtAction>
    </article>
    <ConsumerState v-else-if="loading" loading title="正在读取本人进度" />
    <ConsumerState v-else-if="error" error title="参赛进度暂时无法读取" :description="error"
      ><button class="btn" @click="load">重新读取</button></ConsumerState
    >
    <article v-else-if="current" class="c-task-card">
      <span class="badge" :class="current.status === 'approved' ? '' : 'orange'">{{
        current.eventHolding === 'cancelled' ? '赛事已取消' : entryStatusLabel(current.status)
      }}</span>
      <h3>{{ current.unitName }}</h3>
      <p>{{ registrationNextAction(current) }}</p>
      <div class="c-task-members">
        <span class="account-avatar">我</span><span>成员确认 {{ confirmed }} / {{ current.members.length }}</span>
      </div>
      <div class="c-task-progress" aria-label="报名进度">
        <span :class="{ done: confirmed === current.members.length && confirmed > 0 }">1 · 确认成员</span
        ><span :class="{ done: current.status !== 'draft' }">2 · 正式提交</span
        ><span :class="{ done: current.status === 'approved' }">3 · 资格通过</span>
      </div>
      <SportArtAction art="registration" tone="primary" small :to="'/portal/registration/detail/' + current.id">查看详情</SportArtAction>
    </article>
    <article v-else class="c-task-card">
      <h3>暂无报名</h3>
      <p>选择赛事项目后提交报名。</p>
      <SportArtAction art="registration" tone="primary" small to="/public/events">发现赛事</SportArtAction>
    </article>
    <router-link v-if="invites" class="c-help-card" to="/portal/registration"
      ><ConsumerIcon name="team" /><span
        ><strong>{{ invites }} 条邀请待确认</strong><small>由本人查看并确认参加</small></span
      ><ConsumerIcon name="arrow"
    /></router-link>
  </section>
</template>
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useUserStore } from '@/store/modules/user';
import { EntryCard, entryStatusLabel, listMyEntries, listReceivedInvites } from '@/api/sports/registration';
import { registrationNextAction } from '@/utils/consumerRegistration';
import ConsumerIcon from './ConsumerIcon.vue';
import ConsumerState from './ConsumerState.vue';
import SportArtAction from '@/components/sport-ui/SportArtAction.vue';
const store = useUserStore();
const loggedIn = computed(() => Boolean(store.token));
const entries = ref<EntryCard[]>([]),
  invites = ref(0),
  loading = ref(false),
  error = ref('');
const current = computed(
  () => entries.value.find((e) => !['withdrawn', 'rejected'].includes(e.status) && e.eventHolding !== 'cancelled') || entries.value[0]
);
const confirmed = computed(() => current.value?.members.filter((m) => m.status === 'confirmed').length || 0);
let revision = 0;
const load = async () => {
  const seq = ++revision;
  entries.value = [];
  invites.value = 0;
  error.value = '';
  if (!loggedIn.value) {
    loading.value = false;
    return;
  }
  loading.value = true;
  try {
    const [a, b] = await Promise.all([listMyEntries(), listReceivedInvites()]);
    if (seq !== revision) return;
    entries.value = a.data || [];
    invites.value = (b.data || []).filter(
      (i: { canRespond: boolean; memberStatus: string }) => i.canRespond && i.memberStatus === 'pending_confirmation'
    ).length;
  } catch {
    if (seq === revision) error.value = '请稍后重试，或进入我的参赛查看。';
  } finally {
    if (seq === revision) loading.value = false;
  }
};
watch(() => store.token, load, { immediate: true });
</script>
