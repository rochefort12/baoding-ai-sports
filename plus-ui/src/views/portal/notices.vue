<template>
  <ConsumerShell
    ><ConsumerPageHeader title="我的消息" eyebrow="消息中心" description="赛事进展与重要通知，都在这里留存。" />
    <ConsumerState v-if="error" error title="消息暂时无法读取" :description="error"
      ><button class="btn" @click="load()">重新加载</button></ConsumerState
    >
    <ConsumerState v-else-if="loading" loading title="正在读取消息" icon="bell" />
    <ConsumerState v-else-if="!rows.length" title="暂时没有新消息" description="赛事重要通知将在这里保留。" icon="bell" />
    <div v-else class="notice-list">
      <article v-for="row in rows" :key="row.id" class="notice-card">
        <span class="shortcut-icon"><ConsumerIcon name="bell" /></span>
        <div class="notice-content">
          <div class="between">
            <h3>{{ row.title }}</h3>
            <span class="badge" :class="row.read ? 'gray' : 'orange'">{{ row.read ? '已读' : '未读' }}</span>
          </div>
          <p>{{ row.body }}</p>
          <div class="action-row">
            <el-button v-if="!row.read" link type="primary" @click="mark(row)">标为已读</el-button
            ><el-button v-if="noticeTarget(row)" link type="primary" @click="openEvent(row)"
              >{{ noticeLabel(row) }}<ConsumerIcon name="chevron"
            /></el-button>
          </div>
        </div>
      </article>
    </div>
    <p class="consumer-note" style="margin-top: 22px">这些是站内消息。短信如果没发出去，这里不会显示成已送达。付款进度请到「我的报名」查看。</p></ConsumerShell
  >
</template>
<script setup lang="ts" name="PortalNotices">
import { onMounted, onUnmounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import ConsumerPageHeader from '@/components/consumer/ConsumerPageHeader.vue';
import ConsumerState from '@/components/consumer/ConsumerState.vue';
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import ConsumerShell from '@/layout/consumer/ConsumerShell.vue';
import { NoticeCard, listNotices, markNoticeRead } from '@/api/sports/notice';
import { useUserStore } from '@/store/modules/user';

const router = useRouter();
const rows = ref<NoticeCard[]>([]);
const error = ref('');
const loading = ref(true);
const userStore = useUserStore();
let noticeTimer: number | undefined;
let requestSequence = 0;
let pendingSequence = 0;

const load = async (background = false) => {
  if (background && pendingSequence) return;
  const sequence = ++requestSequence;
  const expectedToken = userStore.token;
  if (!expectedToken) { rows.value = []; loading.value = false; return; }
  pendingSequence = sequence;
  if (!background) { error.value = ''; loading.value = true; }
  try {
    const res = await listNotices();
    if (sequence !== requestSequence || userStore.token !== expectedToken) return;
    rows.value = res.data || [];
    error.value = '';
    window.dispatchEvent(new Event('sports-notices-changed'));
  } catch (cause) {
    if (sequence === requestSequence && (!background || !rows.value.length)) error.value = cause instanceof Error ? cause.message : '消息暂时无法读取。';
  } finally {
    if (sequence === requestSequence) { loading.value = false; pendingSequence = 0; }
  }
};
const refreshVisible = () => { if (document.visibilityState === 'visible') void load(true); };
watch(() => userStore.token, () => { rows.value = []; error.value = ''; requestSequence++; pendingSequence = 0; void load(); });

const mark = async (row: NoticeCard) => {
  await markNoticeRead(row.id);
  await load();
  window.dispatchEvent(new Event('sports-notices-changed'));
};

// 仅允许已知的站内目标；服务端仍逐条验证当前账号与受邀对象。
const noticeTarget = (row: NoticeCard) => {
  if (row.businessType === 'event' && /^\d+$/.test(row.businessId)) return '/public/events/' + row.businessId;
  if (row.businessType === 'complaint' && /^\d+$/.test(row.businessId) && row.targetPath === '/portal/issues/' + row.businessId) return row.targetPath;
  if (row.businessType === 'organization' && row.purpose === 'qualification' && row.targetPath === '/portal/organization') return row.targetPath;
  if (row.businessType === 'registration-invite' && /^\/portal\/registration\/invite\/[a-zA-Z0-9-]+$/.test(row.targetPath || '')) return row.targetPath!;
  if (row.businessType === 'team-invite' && /^\/portal\/teams\/invitations\/\d+$/.test(row.targetPath || '')) return row.targetPath!;
  if (row.businessType === 'registration-roster-removed' && row.targetPath === '/portal/registration') return row.targetPath;
  if (row.businessType === 'team-joined' && /^\/portal\/teams\/\d+$/.test(row.targetPath || '')) return row.targetPath!;
  if (row.businessType === 'team-member-removed' && row.targetPath === '/portal/teams') return row.targetPath;
  return '';
};
const noticeLabel = (row: NoticeCard) => row.businessType === 'event' ? '查看赛事' : row.businessType === 'complaint' ? '查看处理进度' : row.businessType === 'organization' ? '查看办赛资格' : row.businessType === 'registration-roster-removed' ? '查看我的报名' : row.businessType === 'team-joined' ? '查看队伍成员' : row.businessType === 'team-member-removed' ? '查看我的队伍' : '查看邀请';
const openEvent = (row: NoticeCard) => { const target = noticeTarget(row); if (target) router.push(target); };

onMounted(() => {
  void load();
  window.addEventListener('focus', refreshVisible);
  document.addEventListener('visibilitychange', refreshVisible);
  noticeTimer = window.setInterval(refreshVisible, 30000);
});
onUnmounted(() => {
  requestSequence++;
  if (noticeTimer !== undefined) window.clearInterval(noticeTimer);
  window.removeEventListener('focus', refreshVisible);
  document.removeEventListener('visibilitychange', refreshVisible);
});
</script>
