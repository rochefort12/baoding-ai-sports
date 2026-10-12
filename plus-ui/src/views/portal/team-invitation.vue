<template>
  <ConsumerShell><ConsumerPageHeader title="入队邀请" eyebrow="我的队伍 · 本人确认" back-to="/portal/teams" back-label="返回我的队伍" />
    <ConsumerState v-if="error" error title="无法查看这条邀请" :description="error" />
    <ConsumerState v-else-if="!invitation" loading title="正在读取邀请" />
    <section v-else class="consumer-card"><h2>{{ invitation.teamName }}</h2><p class="notice">{{ statusText }}</p><p class="consumer-note">邀请仅限受邀账号本人使用；接受后成为长期队伍成员，不会自动报名任何赛事。</p>
      <div class="action-row"><el-button v-if="invitation.status === 'pending'" type="primary" :loading="busy" @click="respond(true)">接受邀请</el-button><el-button v-if="invitation.status === 'pending'" :disabled="busy" @click="respond(false)">拒绝邀请</el-button><router-link v-if="invitation.status === 'accepted'" class="btn" :to="'/portal/teams/' + invitation.teamId">查看队伍</router-link></div>
    </section>
  </ConsumerShell>
</template>
<script setup lang="ts" name="TeamInvitation">
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { ElMessage } from 'element-plus';
import ConsumerShell from '@/layout/consumer/ConsumerShell.vue';
import ConsumerPageHeader from '@/components/consumer/ConsumerPageHeader.vue';
import ConsumerState from '@/components/consumer/ConsumerState.vue';
import { getInvitation, acceptInvitation, declineInvitation, type InvitationCard } from '@/api/sports/team';
const route = useRoute();
const invitation = ref<InvitationCard>();
const error = ref(''); const busy = ref(false);
const statusText = computed(() => ({ pending: '队长邀请你加入这支队伍，请本人确认。', accepted: '你已接受这条邀请。当前成员可进入队伍查看详情。', declined: '你已拒绝这条邀请。', revoked: '队长已撤回这条邀请。', invalidated: '这条邀请已失效，请联系队长。' } as Record<string, string>)[invitation.value?.status || ''] || '这条邀请已结束。');
const load = async () => { try { invitation.value = (await getInvitation(String(route.params.invitationId))).data; } catch (cause) { error.value = cause instanceof Error ? cause.message : '这条邀请不存在或仅限受邀本人查看。'; } };
const respond = async (accept: boolean) => {
  if (busy.value || !invitation.value || invitation.value.status !== 'pending') return;
  busy.value = true;
  try { await (accept ? acceptInvitation(invitation.value.id) : declineInvitation(invitation.value.id)); ElMessage.success(accept ? '已加入队伍' : '已拒绝邀请'); await load(); }
  catch { /* 共用请求层已提示错误，保留邀请供本人重试。 */ }
  finally { busy.value = false; }
};
onMounted(load);
</script>
