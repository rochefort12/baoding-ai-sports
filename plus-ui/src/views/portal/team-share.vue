<template>
  <ConsumerShell>
    <ConsumerPageHeader title="一起加入队伍" eyebrow="队长邀请 · 本人决定" />
    <ConsumerState v-if="loading" loading title="正在读取入队邀请" />
    <ConsumerState v-else-if="error" error title="邀请暂时无法打开" :description="error">
      <button class="btn" @click="load">重新读取</button>
      <router-link class="btn" to="/portal/teams">我的队伍</router-link>
    </ConsumerState>
    <section v-else-if="invitation" class="consumer-card team-share-card">
      <img class="team-share-art" src="/images/sports/team-welcome-v1.png" alt="" width="132" height="132" decoding="async" />
      <p class="team-share-eyebrow">长期队伍邀请</p>
      <h2>{{ invitation.teamName }}</h2>
      <p class="team-share-description">{{ description }}</p>
      <p v-if="invitation.status === 'pending'" class="consumer-muted">邀请有效至 {{ formatTime(invitation.expiresAt) }}</p>
      <div v-if="joinError" class="team-join-error" role="alert">
        <p>{{ joinError }}</p>
        <p v-if="checkFailed">当前状态暂时无法读取，请再次检查后决定是否继续。</p>
        <button class="btn" :disabled="checking" @click="recheck">{{ checking ? '正在检查…' : '再次检查状态' }}</button>
      </div>
      <div class="team-share-actions">
        <template v-if="invitation.status === 'pending' && !loggedIn">
          <router-link class="btn primary" :to="{ path: '/portal/login', query: { returnTo: safeTarget } }">登录并继续</router-link>
          <router-link class="btn" :to="{ path: '/portal/register', query: { returnTo: safeTarget } }">注册账号</router-link>
        </template>
        <router-link v-else-if="confirmation?.currentMember || joined" class="btn primary" :to="'/portal/teams/' + invitation.teamId">查看队伍</router-link>
        <button v-else-if="canJoin" class="btn primary" @click="dialogVisible = true">查看并确认加入</button>
        <router-link v-else class="btn" to="/portal/teams">返回我的队伍</router-link>
      </div>
      <p class="team-share-note">加入后成为长期队伍成员。每场赛事仍需你本人确认参赛，队伍成员身份不会代替参赛同意。</p>
    </section>

    <el-dialog v-model="dialogVisible" title="确认加入队伍" class="team-join-dialog" width="440px" :close-on-click-modal="!busy" :close-on-press-escape="!busy" :show-close="!busy">
      <div v-if="invitation" class="team-join-summary">
        <span>将加入的队伍</span><h3>{{ invitation.teamName }}</h3>
        <div class="team-join-person"><span class="account-avatar">{{ Array.from(selfName || '我')[0] }}</span><div><strong>{{ selfName }}</strong><p>使用你的本人账号加入</p></div></div>
        <p>确认后，你将成为这支队伍的队员。队长和本队成员可以查看你的队员姓名及运动名片。</p>
        <div v-if="joinError" class="team-join-error" role="alert">
          <p>{{ joinError }}</p>
          <p v-if="checkFailed">当前状态暂时无法读取，请再次检查后决定是否继续。</p>
          <button class="btn" :disabled="checking" @click="recheck">{{ checking ? '正在检查…' : '再次检查状态' }}</button>
        </div>
      </div>
      <template #footer>
        <button class="btn" :disabled="busy" @click="dialogVisible = false">暂不加入</button>
        <button class="btn primary" :disabled="busy || checking || checkFailed" @click="join">{{ busy ? '正在加入…' : '确认加入队伍' }}</button>
      </template>
    </el-dialog>
  </ConsumerShell>
</template>

<script setup lang="ts" name="TeamShareInvitation">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ElMessage } from 'element-plus';
import ConsumerShell from '@/layout/consumer/ConsumerShell.vue';
import ConsumerPageHeader from '@/components/consumer/ConsumerPageHeader.vue';
import ConsumerState from '@/components/consumer/ConsumerState.vue';
import { getToken } from '@/utils/auth';
import { sanitizeReturnTo } from '@/utils/returnTo';
import { profileReady } from '@/utils/profileGate';
import { getIdentity } from '@/api/sports/identity';
import { acceptTeamShare, getTeamShareConfirmation, previewTeamShare, type TeamSharePreview, type TeamShareConfirmation } from '@/api/sports/team';
import '@/assets/styles/team-invitation.scss';

const route = useRoute();
const router = useRouter();
const token = computed(() => String(route.params.token || ''));
const safeTarget = computed(() => sanitizeReturnTo(route.fullPath));
const loggedIn = computed(() => Boolean(getToken()));
const invitation = ref<TeamSharePreview>();
const confirmation = ref<TeamShareConfirmation>();
const selfName = ref('');
const loading = ref(false);
const error = ref('');
const busy = ref(false);
const dialogVisible = ref(false);
const joined = ref(false);
const joinError = ref('');
const checkFailed = ref(false);
const checking = ref(false);
let generation = 0;
const canJoin = computed(() => invitation.value?.status === 'pending' && Boolean(confirmation.value) && !confirmation.value?.currentMember && !confirmation.value?.previouslyUsed);
const description = computed(() => {
  if (joined.value || confirmation.value?.currentMember) return '你已经是这支队伍的成员，可以直接查看队伍。';
  if (confirmation.value?.previouslyUsed) return '你曾使用这条邀请入队，离队后需要队长重新邀请。';
  if (invitation.value?.status === 'expired') return '这条邀请已过期，请向队长获取新的邀请链接。';
  if (invitation.value?.status !== 'pending') return '这条邀请已经失效，请联系队长重新邀请。';
  return loggedIn.value ? '队长邀请你成为队员，请核对队伍并决定是否加入。' : '登录或注册后，补齐本人资料，再确认是否加入这支队伍。';
});
const formatTime = (value: string) => new Intl.DateTimeFormat('zh-CN', { timeZone: 'Asia/Shanghai', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date(value));

async function load() {
  const turn = ++generation;
  error.value = ''; loading.value = true; invitation.value = undefined; confirmation.value = undefined; dialogVisible.value = false; joined.value = false; busy.value = false;
  joinError.value = ''; checkFailed.value = false; checking.value = false;
  if (!/^[a-f0-9]{64}$/.test(token.value)) { error.value = '邀请链接不完整，请向队长重新获取。'; loading.value = false; return; }
  try {
    const preview = (await previewTeamShare(token.value)).data as TeamSharePreview;
    if (turn !== generation) return;
    invitation.value = preview;
    if (!loggedIn.value || preview.status !== 'pending') return;
    const identity = (await getIdentity()).data;
    if (turn !== generation) return;
    if (!profileReady(identity)) {
      await router.replace({ path: '/portal/identity', query: { returnTo: safeTarget.value } });
      return;
    }
    selfName.value = identity.self?.legalName || '';
    const response = await getTeamShareConfirmation(token.value);
    if (turn !== generation) return;
    confirmation.value = response.data;
    invitation.value = response.data;
    dialogVisible.value = canJoin.value;
  } catch (cause) {
    if (turn === generation) error.value = cause instanceof Error ? cause.message : '这条邀请无法读取，请联系队长。';
  } finally { if (turn === generation) loading.value = false; }
}

async function join() {
  if (busy.value || checking.value || checkFailed.value || !canJoin.value) return;
  const joinGeneration = generation;
  const joinToken = token.value;
  busy.value = true;
  try {
    await acceptTeamShare(joinToken);
    if (generation !== joinGeneration) return;
    joined.value = true; dialogVisible.value = false; joinError.value = ''; checkFailed.value = false;
    ElMessage.success('已加入队伍');
  } catch (cause) {
    if (generation !== joinGeneration) return;
    joinError.value = cause instanceof Error ? cause.message : '本次加入未能确认，请检查当前状态。';
    // 成功响应丢失、撤销或到期均先只读核对；不会自动重发加入或重新打开确认。
    await recheck();
  }
  finally { if (generation === joinGeneration) busy.value = false; }
}

async function recheck() {
  if (checking.value) return;
  const checkGeneration = generation;
  const checkToken = token.value;
  checking.value = true;
  try {
    const response = await getTeamShareConfirmation(checkToken);
    if (generation !== checkGeneration) return;
    confirmation.value = response.data; invitation.value = response.data; checkFailed.value = false;
    if (!canJoin.value) dialogVisible.value = false;
  } catch {
    if (generation === checkGeneration) checkFailed.value = true;
  } finally { if (generation === checkGeneration) checking.value = false; }
}

watch(token, load);
onMounted(load);
onBeforeUnmount(() => { generation += 1; });
</script>
