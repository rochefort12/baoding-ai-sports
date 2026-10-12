<template>
  <ConsumerShell
    ><ConsumerPageHeader title="参赛邀请" back-to="/portal/registration" back-label="返回我的参赛" eyebrow="我的参赛 · 本人确认" description="核对赛事与报名项目，接受或拒绝邀请。" /><ConsumerState
      v-if="error"
      error
      title="无法查看这条邀请"
      :description="error"
    /><ConsumerState v-else-if="!invite" loading title="正在读取邀请" />
    <section v-else class="consumer-card" style="max-width: 740px; margin: 0 auto">
      <span class="shortcut-icon"><ConsumerIcon name="team" /></span>
      <h2 style="margin-top: 18px">{{ invite.eventName }}</h2>
      <p class="consumer-muted">{{ invite.unitName }} · {{ entryTypeLabel(invite.entryType) }}</p>
      <div class="registration-invite-person" data-testid="invited-person-summary"><span class="registration-avatar">{{ (invite.inviteeName || '我').slice(0, 1) }}</span><div><strong>{{ invite.inviteeName || '本人参赛邀请' }}</strong><p v-if="invite.inviteeMobileTail">受邀账号手机尾号 {{ invite.inviteeMobileTail }}</p><p>{{ invite.initiatorName ? `报名发起人：${invite.initiatorName}` : '请本人核对并确认参加' }}</p></div></div>
      <div class="status-cells" style="grid-template-columns: 1fr 1fr">
        <div>
          <span>整单报名</span><strong>{{ entryStatusLabel(invite.registrationStatus) }}</strong>
        </div>
        <div>
          <span>本人确认</span><strong>{{ memberStatusLabel(invite.memberStatus) }}</strong>
        </div>
      </div>
      <p class="notice">{{ inviteSituation(invite) }}</p>
      <EntryPersonalFields v-if="invite.memberStatus !== 'declined'" ref="personalFields" :registration-id="invite.registrationId" :editable="['draft', 'rejected'].includes(invite.registrationStatus)" />
      <EntryDeclaration v-if="invite.memberStatus !== 'declined' && invite.declarationConfirmRequired && (invite.declarationText || invite.declarationImageAvailable)" :registration-id="invite.registrationId" :text="invite.declarationText" :image-available="invite.declarationImageAvailable" :acknowledged="invite.declarationAcknowledged" @ready="declarationReady = $event" />
      <section v-if="invite.memberStatus === 'confirmed' && invite.members?.length" class="invitation-roster"><h3>当前参赛伙伴</h3><p class="consumer-note">正式提交前名单仍可能调整，以最终提交名单为准。</p><div class="participant-list"><article v-for="(member, index) in invite.members" :key="index" class="participant-item"><strong>{{ member.selfMember ? '本人' : member.legalName || '待确认伙伴' }}</strong><span>{{ memberStatusLabel(member.status) }}</span></article></div></section>
      <div class="action-row">
        <el-button v-if="invite.canRespond && invite.declarationConfirmRequired && !invite.declarationAcknowledged" type="primary" :loading="busy" :disabled="!declarationReady" @click="ackThenConfirm">我已阅读并确认参加</el-button
        ><el-button v-else-if="invite.canRespond" type="primary" :loading="busy" @click="confirm">确认参加</el-button
        ><el-button v-if="invite.canRespond" :disabled="busy" @click="decline">拒绝邀请</el-button
        ><router-link class="btn text" to="/portal/registration">返回我的参赛</router-link>
      </div>
    </section></ConsumerShell
  >
</template>
<script setup lang="ts" name="RegistrationInvite">
import '@/assets/styles/registration-invitation.scss';
import { onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { ElMessage } from 'element-plus';
import ConsumerPageHeader from '@/components/consumer/ConsumerPageHeader.vue';
import ConsumerState from '@/components/consumer/ConsumerState.vue';
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import ConsumerShell from '@/layout/consumer/ConsumerShell.vue';
import EntryDeclaration from '@/components/consumer/EntryDeclaration.vue';
import EntryPersonalFields from '@/components/consumer/EntryPersonalFields.vue';
import {
  InviteView,
  acknowledgeDeclaration,
  confirmInvite,
  declineInvite,
  entryStatusLabel,
  entryTypeLabel,
  getInvite,
  inviteSituation,
  memberStatusLabel
} from '@/api/sports/registration';

const route = useRoute();
const token = String(route.params.token || '');
const invite = ref<InviteView>();
const error = ref('');
const busy = ref(false);
const declarationReady = ref(false);
const personalFields = ref<InstanceType<typeof EntryPersonalFields>>();

const load = async () => {
  error.value = '';
  try {
    const res = await getInvite(token);
    invite.value = res.data;
    if (!invite.value) {
      error.value = '这条邀请不存在，或当前账号不能查看。';
    }
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '邀请暂时无法查看。';
  }
};

/** 同一邀请的接受/拒绝互斥；接口已经显示错误，失败后允许本人重试。 */
const ackThenConfirm = async () => {
  if (busy.value || !invite.value?.registrationId || !declarationReady.value) return;
  busy.value = true;
  try {
    if (personalFields.value && !(await personalFields.value.save(true))) return;
    await acknowledgeDeclaration(invite.value.registrationId);
    const res = await confirmInvite(token);
    invite.value = res.data;
    ElMessage.success('已确认');
  } catch {
    await load();
  } finally {
    busy.value = false;
  }
};
const respond = async (accepted: boolean) => {
  if (busy.value || !invite.value?.canRespond) return;
  busy.value = true;
  try {
    if (accepted && personalFields.value && !(await personalFields.value.save(true))) return;
    const res = await (accepted ? confirmInvite(token) : declineInvite(token));
    invite.value = res.data;
    ElMessage.success(accepted ? '已确认' : '已拒绝');
  } catch {
    // 保留当前邀请；共用请求层负责错误提示，避免再次抛成页面脚本异常。
  } finally {
    busy.value = false;
  }
};
const confirm = () => respond(true);
const decline = () => respond(false);

onMounted(load);
</script>
