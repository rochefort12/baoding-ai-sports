<template>
  <ConsumerShell>
    <div class="premium-teams">
    <ConsumerPageHeader
      :title="teamId ? detail?.name || '小队详情' : '我的小队'"
      eyebrow="我的参赛"

      ><router-link v-if="teamId" class="btn" to="/portal/teams"><ConsumerIcon name="back" />返回我的队伍</router-link></ConsumerPageHeader
    >
    <nav v-if="!teamId" class="personal-nav">
      <router-link to="/portal/registration">报名与进度</router-link><router-link class="active" to="/portal/teams">我的队伍</router-link
      ><router-link to="/portal/results">正式赛果</router-link><router-link to="/portal/proofs">成绩证明</router-link>
    </nav>
    <template v-if="!teamId && !teamError"
      ><div class="team-create-grid">
        <section class="card">
          <h3>创建一支队伍</h3>

          <div class="action-row">
            <el-input v-model="teamName" maxlength="200" aria-label="新队伍名称" placeholder="给队伍起个名字" /><el-button
              type="primary"
              :loading="teamBusy" :disabled="!teamName.trim()" @click="create"
              >创建队伍</el-button
            >
          </div>
        </section>
        <section class="card">
          <h3>加入已有队伍</h3>
          <p class="consumer-muted">向队长获取队伍编号，再申请加入。</p>
          <div class="action-row">
            <el-input v-model="applyId" aria-label="申请加入的队伍编号" placeholder="输入队伍编号" /><el-button @click="lookup">查找队伍</el-button>
          </div>
          <div v-if="preview" class="action-row">
            <span>{{ preview.name }} · {{ teamStatusLabel(preview.status) }}</span
            ><el-button type="primary" :disabled="preview.status !== 'active'" @click="apply">申请加入</el-button>
          </div>
        </section>
      </div>
      <div class="section-head">
        <h2>当前队伍</h2>
        <span class="small">{{ currentMemberships.length }} 支</span>
      </div>
      <ConsumerState v-if="!home" loading title="正在读取队伍" icon="team" /><ConsumerState
        v-else-if="!currentMemberships.length"
        title="暂无队伍"
        description="还没有当前队伍，可以创建队伍或通过编号申请加入。"
        icon="team"
      />
      <div v-else class="team-cards">
        <router-link v-for="row in currentMemberships" :key="row.teamId" class="team-card" :to="'/portal/teams/' + row.teamId"
          ><span class="shortcut-icon"><ConsumerIcon name="team" /></span>
          <div>
            <h3>{{ row.name }}</h3>
            <p>{{ roleLabel(row.role) }} · {{ teamStatusLabel(row.teamStatus) }}</p>
          </div>
          <ConsumerIcon name="chevron"
        /></router-link>
      </div>
      <details class="history-block">
        <summary>本人加入 / 退出记录 · {{ pastMemberships.length }} 条</summary>
        <p class="consumer-note">仅展示本人的已结束队伍关系，退出后不恢复完整队伍详情权限。</p>
        <div class="team-cards">
          <article v-for="row in pastMemberships" :key="row.teamId" class="team-card">
            <span class="shortcut-icon"><ConsumerIcon name="clock" /></span>
            <div>
              <h3>{{ row.name }}</h3>
              <p>
                {{ roleLabel(row.role) }} · {{ membershipStatusLabel(row.membershipStatus)
                }}{{ row.endReason ? ' · ' + endReasonLabel(row.endReason) : '' }}
              </p>
            </div>
          </article>
        </div>
        <p v-if="!pastMemberships.length" class="consumer-muted">还没有已结束的队伍关系。</p>
      </details>
      <section v-if="home?.myInvitations.length || home?.myApplications.length" class="consumer-card" style="margin-top: 24px">
        <h3>待办理事项</h3>
        <div v-for="item in home?.myInvitations || []" :key="item.id" class="action-row">
          <span>{{ item.teamName }} · 邀请加入</span><el-button type="primary" @click="accept(item.id)">接受</el-button
          ><el-button @click="decline(item.id)">拒绝</el-button>
        </div>
        <div v-for="item in home?.myApplications || []" :key="item.id" class="action-row">
          <span>{{ item.teamName }} · 我的申请</span><el-button @click="cancel(item.id)">撤销申请</el-button>
        </div>
      </section>
      <p class="consumer-note" style="margin-top: 20px">
        申请需要队长同意，邀请需要本人接受。长期队伍成员不会自动进入每场赛事名单；临时双打无需建队。
      </p></template
    >
    <ConsumerState v-else-if="teamError" error title="暂时无法查看队伍" :description="teamError" icon="team"
      ><button v-if="!teamId" class="btn" @click="load">重新读取</button
      ><router-link v-else class="btn" to="/portal/teams">返回我的队伍</router-link></ConsumerState
    >
    <section v-else-if="detail" class="consumer-card">
      <div class="between">
        <span class="badge">{{ roleLabel(detail.myRole) }} · {{ membershipStatusLabel(detail.myMembershipStatus) }}</span
        ><span class="small">{{ teamStatusLabel(detail.status) }}</span>
      </div>
      <p class="consumer-note">
        队伍编号 {{ detail.id }}<span v-if="detail.myEndReason"> · {{ endReasonLabel(detail.myEndReason) }}</span>
      </p>
      <div v-if="detail.captain" class="team-create-grid" style="margin-top: 20px">
        <div>
          <label class="small">修改队名</label>
          <div class="action-row">
            <el-input v-model="rename" maxlength="200" aria-label="修改队伍名称" /><el-button @click="saveName">保存队名</el-button>
          </div>
        </div>
        <div>
          <label class="small">邀请队员</label><p class="consumer-note">邀请会发送站内信，也可复制邀请链接联系队员。</p><el-checkbox v-model="requestSms">同时申请短信提醒</el-checkbox>
          <div class="action-row">
            <el-input v-model="phone" maxlength="11" placeholder="对方已注册的手机号" /><el-button type="primary" :loading="inviting" @click="invite">发出邀请</el-button>
          </div>
        </div>
      </div>
      <section v-if="detail.captain" class="team-share-manager">
        <h3>分享入队邀请</h3>
        <p>复制链接发给想邀请的队员。对方可登录或注册，完善本人资料后确认加入，无需再提交入队申请。</p>
        <p v-if="shareLink">有效至 {{ shareExpiry }}。撤销或更换后，旧链接立即失效。</p>
        <p v-else>链接有效期为 7 天，你可以随时撤销。</p>
        <div class="action-row">
          <el-button type="primary" :loading="shareBusy" @click="copyShare">{{ shareLink ? '复制入队邀请链接' : '生成并复制邀请链接' }}</el-button>
          <el-button v-if="shareLink" :disabled="shareBusy" @click="replaceShare">更换链接</el-button>
          <el-button v-if="shareLink" :disabled="shareBusy" @click="revokeShare">撤销链接</el-button>
        </div>
      </section>
      <TeamGrowthPanel :team-id="teamId" :team-name="detail.name" :captain="detail.captain" @members="shownMembers=$event" />
      <el-tabs
        ><el-tab-pane label="当前成员"
          ><div class="participant-list">
            <article v-for="row in activeMembers" :key="row.id" class="participant-item">
              <SportsAvatar :nickname="shownMember(row.accountId).nickname" :account-id="row.accountId||undefined" :avatar-file-id="shownMember(row.accountId).avatar_file_id" :tone="shownMember(row.accountId).avatar_style" :title="titleLabels[shownMember(row.accountId).title_code||'']" :title-code="shownMember(row.accountId).title_code" :points="Number(shownMember(row.accountId).points||0)" :rank-level="shownMember(row.accountId).rank_index" :rank-name="shownMember(row.accountId).rank_name" :captain="row.role==='captain'" compact />
              <div class="participant-main">
                <strong>{{ shownMember(row.accountId).nickname || '球友' }}</strong>
                <p>{{ roleLabel(row.role) }} · {{ membershipStatusLabel(row.status) }}</p>
              </div>
              <template v-if="detail.captain && row.status === 'active' && row.role === 'member'"
                ><el-button link type="primary" @click="transfer(row.id)">转让队长</el-button
                ><el-button link type="danger" @click="remove(row.id)">移除</el-button></template
              >
            </article>
          </div>
          <p v-if="!activeMembers.length" class="consumer-muted">当前没有有效成员。</p></el-tab-pane
        ><el-tab-pane label="加入/退出记录"
          ><p class="consumer-muted">保留已结束的成员关系，不影响此前正式提交的赛事名单。</p>
          <div class="participant-list">
            <article v-for="row in historyMembers" :key="row.id" class="participant-item">
              <span class="account-avatar">{{ (row.legalName || '队').slice(0, 1) }}</span>
              <div class="participant-main">
                <strong>{{ row.legalName }}</strong>
                <p>
                  {{ roleLabel(row.role) }} · {{ membershipStatusLabel(row.status) }}{{ row.endReason ? ' · ' + endReasonLabel(row.endReason) : '' }}
                </p>
              </div>
              <span class="badge gray">历史成员</span>
            </article>
          </div>
          <p v-if="!historyMembers.length" class="consumer-muted">还没有已结束的成员记录。</p></el-tab-pane
        ></el-tabs
      >
      <template v-if="detail.captain">
        <h3 style="margin-top: 26px">待审批申请</h3>
        <p v-if="!detail.applications.length">没有待审批的申请。</p>
        <div v-for="item in detail.applications" :key="item.id" class="action-row">
          <span>{{ item.personName }}</span>
          <el-button type="primary" @click="approve(item.id)">同意</el-button>
          <el-button @click="reject(item.id)">拒绝</el-button>
        </div>
        <h3 style="margin-top: 26px">待接受邀请</h3>
        <p v-if="!detail.invitations.length">没有待接受的邀请。</p>
        <div v-for="item in detail.invitations" :key="item.id" class="action-row">
          <div><strong>{{ item.personName }}</strong><p class="consumer-note">{{ invitationDeliveryText(item.notice) }}</p></div><el-button @click="copyInvitation('/portal/teams/invitations/' + item.id)">复制邀请链接</el-button>
          <el-button @click="revoke(item.id)">撤回</el-button>
        </div>
        <div class="action-row">
          <el-button type="danger" @click="disband">解散队伍</el-button>
        </div>
      </template>
      <div v-if="detail.canLeave" class="action-row">
        <el-button @click="leave">退出队伍</el-button>
      </div>
    </section>
    <ConsumerState v-else loading title="正在读取队伍详情" icon="team"
  /></div></ConsumerShell>
</template>
<script setup lang="ts" name="PortalTeam">
import { computed, onMounted, ref, watch } from 'vue';
import { copyInvitation, invitationDeliveryText } from '@/utils/invitation';
import { useRoute, useRouter } from 'vue-router';
import ConsumerPageHeader from '@/components/consumer/ConsumerPageHeader.vue';
import ConsumerState from '@/components/consumer/ConsumerState.vue';
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import ConsumerShell from '@/layout/consumer/ConsumerShell.vue';
import TeamGrowthPanel from '@/components/consumer/TeamGrowthPanel.vue';
import SportsAvatar from '@/components/consumer/SportsAvatar.vue';
import {titleLabels} from '@/api/sports/phase1';
interface ShownMember {account_id:string;nickname:string;avatar_style:string;avatar_file_id?:string|null;points:number;rank_index?:number;rank_name?:string;title_code:string|null}
const shownMembers=ref<ShownMember[]>([]);
const shownMember=(accountId:string|number|null):ShownMember=>shownMembers.value.find(m=>String(m.account_id)===String(accountId))||{account_id:String(accountId||''),nickname:'球友',avatar_style:'mint',avatar_file_id:null,points:0,title_code:null};
import { ensureProfile } from '@/utils/profileGate';
import { ElMessage, ElMessageBox } from 'element-plus';
import '@/assets/styles/team-invitation.scss';
import {
  PreviewCard,
  TeamDetail,
  TeamHome,
  acceptInvitation,
  applyTeam,
  approveApplication,
  cancelApplication,
  createTeam,
  declineInvitation,
  disbandTeam,
  endReasonLabel,
  getTeam,
  inviteTeammate,
  leaveTeam,
  listTeams,
  membershipStatusLabel,
  previewTeam,
  rejectApplication,
  removeTeammate,
  renameTeam,
  revokeInvitation,
  roleLabel,
  teamStatusLabel,
  transferCaptain
} from '@/api/sports/team';
import { createTeamShare, getTeamShare, revokeTeamShare, type TeamShareLink } from '@/api/sports/team';

const route = useRoute();
const router = useRouter();
const teamId = computed(() => String(route.params.id || ''));
const home = ref<TeamHome>();
const currentMemberships = computed(() =>
  (home.value?.memberships || []).filter((row) => row.membershipStatus === 'active' && row.teamStatus === 'active')
);
const pastMemberships = computed(() =>
  (home.value?.memberships || []).filter((row) => row.membershipStatus !== 'active' || row.teamStatus !== 'active')
);
const activeMembers = computed(() => (detail.value?.members || []).filter((row) => row.status === 'active'));
const historyMembers = computed(() => (detail.value?.members || []).filter((row) => row.status !== 'active'));
const detail = ref<TeamDetail>();
const preview = ref<PreviewCard>();
const teamName = ref('');
const applyId = ref('');
const rename = ref('');
const phone = ref('');
const requestSms = ref(false);
const inviting = ref(false);
const shareLink = ref<TeamShareLink>();
const shareBusy = ref(false);
const shareExpiry = computed(() => shareLink.value ? new Intl.DateTimeFormat('zh-CN', { timeZone: 'Asia/Shanghai', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date(shareLink.value.expiresAt)) : '');

async function copyShare() {
  if (shareBusy.value) return;
  shareBusy.value = true;
  try {
    const result = await createTeamShare(teamId.value);
    shareLink.value = result.data;
    const address = window.location.origin + result.data.path;
    try { await navigator.clipboard.writeText(address); ElMessage.success('入队邀请链接已复制，请发给想邀请的队员'); }
    catch { await ElMessageBox.alert(address, '请复制入队邀请链接', { confirmButtonText: '知道了' }); }
  } finally { shareBusy.value = false; }
}

async function replaceShare() {
  if (shareBusy.value) return;
  const accepted = await ElMessageBox.confirm('更换后，已经发出的旧链接立即失效。', '更换入队邀请链接', { confirmButtonText: '更换链接', cancelButtonText: '取消' }).then(() => true, () => false);
  if (!accepted) return;
  shareBusy.value = true;
  try { shareLink.value = (await createTeamShare(teamId.value, true)).data; ElMessage.success('已更换，请复制新链接重新发送'); }
  finally { shareBusy.value = false; }
}

async function revokeShare() {
  if (shareBusy.value) return;
  const accepted = await ElMessageBox.confirm('撤销后，已经发出的链接无法再加入队伍。当前队员不受影响。', '撤销入队邀请链接', { confirmButtonText: '撤销链接', cancelButtonText: '保留' }).then(() => true, () => false);
  if (!accepted) return;
  shareBusy.value = true;
  try { await revokeTeamShare(teamId.value); shareLink.value = undefined; ElMessage.success('入队邀请链接已撤销'); }
  finally { shareBusy.value = false; }
}

const requireProfile = () => ensureProfile(router, route.fullPath);

const teamError = ref('');
const teamBusy = ref(false);

const load = async () => {
  teamError.value = '';
  shareLink.value = undefined;
  if (teamId.value) {
    const ready = await requireProfile();
    if (!ready) {
      return;
    }
    try {
      const res = await getTeam(teamId.value);
      detail.value = res.data;
      rename.value = res.data.name;
      if (res.data.captain) shareLink.value = (await getTeamShare(teamId.value)).data || undefined;
    } catch (cause) {
      detail.value = undefined;
      teamError.value = cause instanceof Error ? cause.message : '这支队伍暂时无法查看，可能已退出或无访问权限。请返回本人队伍记录。';
    }
    return;
  }
  detail.value = undefined;
  try {
    const res = await listTeams();
    home.value = res.data;
  } catch {
    home.value = undefined;
    teamError.value = '队伍记录暂时无法读取，请稍后重试。';
  }
};

const create = async () => {
  if(teamBusy.value || !teamName.value.trim()) return;
  teamBusy.value=true;
  try {
  const ready = await requireProfile();
  if (!ready) {
    return;
  }
  const res = await createTeam(teamName.value);
  ElMessage.success('已创建队伍');
  await router.push('/portal/teams/' + res.data.id);
  } finally { teamBusy.value=false; }
};

const lookup = async () => {
  const ready = await requireProfile();
  if (!ready) {
    return;
  }
  const res = await previewTeam(applyId.value.trim());
  preview.value = res.data;
};

const apply = async () => {
  if (!preview.value) {
    return;
  }
  const ready = await requireProfile();
  if (!ready) {
    return;
  }
  await applyTeam(preview.value.id);
  ElMessage.success('已提交申请');
  preview.value = undefined;
  await load();
};

const openTeam = (id: string) => router.push('/portal/teams/' + id);

const accept = async (id: string) => {
  const ready = await requireProfile();
  if (!ready) {
    return;
  }
  await acceptInvitation(id);
  ElMessage.success('已加入队伍');
  await load();
};

const decline = async (id: string) => {
  await declineInvitation(id);
  ElMessage.success('已拒绝邀请');
  await load();
};

const cancel = async (id: string) => {
  await cancelApplication(id);
  ElMessage.success('已撤销申请');
  await load();
};

const saveName = async () => {
  const res = await renameTeam(teamId.value, rename.value);
  detail.value = res.data;
  ElMessage.success('已修改队名');
};

const invite = async () => {
  if (inviting.value) return;
  inviting.value = true;
  try {
    const res = await inviteTeammate(teamId.value, phone.value, requestSms.value);
    detail.value = res.data; phone.value = '';
    ElMessage.success('邀请已发出，站内信已生成');
    if (requestSms.value) ElMessage.warning('短信通道未接通，请复制链接联系对方');
    requestSms.value = false;
  } finally { inviting.value = false; }
};

const approve = async (id: string) => {
  const res = await approveApplication(id);
  detail.value = res.data;
  ElMessage.success('已同意加入');
};

const reject = async (id: string) => {
  const res = await rejectApplication(id, '');
  detail.value = res.data;
  ElMessage.success('已拒绝申请');
};

const revoke = async (id: string) => {
  const res = await revokeInvitation(id);
  detail.value = res.data;
  ElMessage.success('已撤回邀请');
};

const transfer = async (memberId: string) => {
  const accepted=await ElMessageBox.confirm('队长身份将交给该成员。已有赛事报名的管理责任仍需在报名详情按实际责任办理。', '转让队长', {confirmButtonText:'确认转让',cancelButtonText:'取消'}).then(()=>true,()=>false); if(!accepted)return;
  const res = await transferCaptain(teamId.value, memberId);
  detail.value = res.data;
  ElMessage.success('已转让队长');
};

const remove = async (memberId: string) => {
  const accepted=await ElMessageBox.confirm('该成员将离开长期小队，已有正式报名名单不会自动改变。', '移除队员', {confirmButtonText:'确认移除',cancelButtonText:'取消'}).then(()=>true,()=>false); if(!accepted)return;
  const res = await removeTeammate(teamId.value, memberId);
  detail.value = res.data;
  ElMessage.success('已移除队员');
};

const leave = async () => {
  const accepted=await ElMessageBox.confirm('退出长期小队后，历史报名仍保留。未完成的管理交接需要先在报名详情办理。', '退出小队', {confirmButtonText:'确认退出',cancelButtonText:'取消'}).then(()=>true,()=>false); if(!accepted)return;
  await leaveTeam(teamId.value);
  ElMessage.success('已退出队伍');
  await router.push('/portal/teams');
};

const disband = async () => {
  await ElMessageBox.confirm('解散后不能恢复。已提交的报名不会撤销。', '解散队伍');
  await disbandTeam(teamId.value);
  ElMessage.success('已解散');
  await router.push('/portal/teams');
};

watch(teamId, () => load());
onMounted(load);
</script>
<style scoped>
.premium-teams .team-create-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px;margin:27px 0}.team-create-grid>.card{border:0;border-radius:23px;background:var(--s-surface);padding:28px}.team-create-grid h3{font-size:20px;font-weight:600;letter-spacing:-.035em;margin:0 0 11px}.team-create-grid .consumer-muted{font-size:12px;line-height:1.8;margin:0 0 19px}.team-create-grid .action-row{gap:10px;margin:12px 0 0;align-items:center}.team-create-grid :deep(.el-input__wrapper){min-height:42px;border-radius:10px}.premium-teams .team-cards{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:17px;margin:22px 0}.premium-teams .team-card{display:flex;align-items:center;gap:16px;border:1px solid var(--s-line);padding:25px;border-radius:21px;background:var(--s-surface);color:var(--s-ink);transition:transform .3s,box-shadow .3s}.premium-teams .team-card:hover{transform:translateY(-3px);box-shadow:0 12px 25px #20232107}.team-card>div{flex:1;min-width:0}.team-card h3{font-size:19px;line-height:1.5;font-weight:600;letter-spacing:-.03em;margin:0 0 7px;overflow-wrap:anywhere}.team-card p{font-size:11px;color:var(--s-muted);margin:0;line-height:1.8}.team-card>.shortcut-icon{width:48px;height:48px;border-radius:14px;background:#e5eadd;color:#91a17a;flex-shrink:0;display:grid;place-items:center}.team-card>.shortcut-icon svg{width:23px;height:23px}.team-card>svg{width:15px;height:15px;color:var(--s-muted)}.history-block{margin:27px 0}.history-block>summary{font-size:12px;color:var(--s-muted);cursor:pointer;border-top:1px solid var(--s-line);padding:20px 0 3px}.history-block .consumer-note{font-size:11px;margin:14px 0}.premium-teams .consumer-card>.between .badge{font-size:11px}.premium-teams .participant-list{margin-top:21px}.premium-teams .participant-item{padding:21px 0;gap:20px;align-items:center;border-bottom:1px solid var(--s-line)}.premium-teams .participant-main{flex:1;min-width:0}.premium-teams .participant-main strong{font-size:14px}.premium-teams .participant-main p{font-size:11px;line-height:1.8;color:var(--s-muted)}.premium-teams :deep(.el-tabs__header){margin:24px 0 15px}.premium-teams :deep(.el-tabs__item){font-size:13px}.premium-teams .section-head h2{font-size:21px;font-weight:600;letter-spacing:-.03em}.premium-teams .consumer-note{font-size:11px;line-height:1.9}.premium-teams .action-row{flex-wrap:wrap}@media(max-width:800px){.premium-teams .team-create-grid{grid-template-columns:1fr;gap:17px;margin:24px 0}.team-create-grid>.card{padding:24px;border-radius:21px}.team-create-grid h3{font-size:18px}.premium-teams .team-cards{grid-template-columns:1fr;gap:14px;margin-top:18px}.premium-teams .team-card{padding:23px;border-radius:20px}.premium-teams .participant-item{gap:13px;flex-wrap:wrap}.premium-teams .participant-item :deep(.sports-avatar){min-width:75px}.premium-teams .participant-main{min-width:120px}.premium-teams .participant-item>.el-button{margin-left:auto}.team-create-grid .action-row{flex-wrap:wrap}.team-create-grid .action-row :deep(.el-input){min-width:170px;flex:1}.premium-teams .team-card h3{font-size:18px}}@media(prefers-reduced-motion:reduce){.premium-teams .team-card{transition:none}.premium-teams .team-card:hover{transform:none}}
</style>
