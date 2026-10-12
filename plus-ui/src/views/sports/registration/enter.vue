<template>
  <ConsumerShell>
    <div class="premium-registration">
    <ConsumerPageHeader
      :title="applyMode ? '填写报名' : registrationId ? '报名详情' : '我的参赛'"
      :back-to="registrationId ? registrationListBack : applyMode ? (route.query.eventId ? '/public/events/' + route.query.eventId : '/public/events') : undefined"
      :back-label="registrationId ? '返回我的参赛' : '返回赛事'"
      eyebrow="我的参赛 · 报名与进度"
      :description="
        applyMode
          ? '选择队伍、核对名单，已有本人资料自动带入。'
          : registrationId
            ? '查看本次名单、资格与资金办理进度。'
            : '每一次上场，从这里继续。'
      "
      ><button v-if="!applyMode" class="btn primary" @click="openConsumerAi('看看我的报名进行到哪一步')"><img class="sport-assistant-mark" src="/images/sports/assistant-orb-v2.webp" alt="" width="22" height="22" draggable="false"/>查看下一步</button><router-link class="btn" to="/public/events">发现赛事<ConsumerIcon name="arrow" /></router-link
    ></ConsumerPageHeader>
    <nav v-if="!applyMode && !registrationId" class="personal-nav">
      <router-link class="active" to="/portal/registration">报名与进度</router-link><router-link to="/portal/teams">我的队伍</router-link
      ><router-link to="/portal/results">正式赛果</router-link><router-link to="/portal/proofs">成绩证明</router-link>
    </nav>
    <EntryHandover v-if="!applyMode && (!registrationId || detailEntry?.canManage)" :registration-id="registrationId || undefined" @changed="load" />
    <ConsumerState v-if="loadError" error title="暂时无法读取报名" :description="loadError"
      ><button class="btn" @click="load">重新加载</button></ConsumerState
    >
    <ConsumerState v-else-if="loading" loading title="正在读取报名信息" />
    <section v-else-if="applyMode" class="consumer-card">
      <ol class="registration-flow" aria-label="报名步骤"><li class="current"><span>1</span>选择项目</li><li><span>2</span>成员资料与声明</li><li><span>3</span>正式提交</li></ol>
      <div class="notice"><ConsumerIcon name="file" />先核对本次参赛名单，已有资料自动带入。正式提交前不占名额，也无需付款。</div>
      <p v-if="pickedUnit" class="consumer-muted">已保留你的选择：{{ pickedUnit.name }}。</p>
      <p v-if="unitError" class="notice warn">{{ unitError }}</p>
      <div class="unit-options">
        <article v-for="unit in units" :key="unit.id" class="unit-option" :class="{ picked: unit.id === preferredUnitId }">
          <div>
            <h3>{{ unit.name }}</h3>
            <p>{{ entryTypeLabel(unit.entryType) }} · {{ unit.minMembers }}—{{ unit.maxMembers }} 人 / 单</p>
            <p>已占名额 {{ unit.usedCount }} / {{ unit.limitCount }}</p>
            <p class="registration-unit-price">{{ quotedPrice(unit.id) }}</p>
          </div>
          <router-link v-if="unit.entryType==='pair'" class="btn" :to="{path:'/portal/rooms',query:{unitId:unit.id,eventId:unit.eventId}}">先找搭档与集结</router-link>
          <el-button type="primary" @click="create(unit)">准备报名<ConsumerIcon name="arrow" /></el-button>
        </article>
      </div>
      <ConsumerState v-if="!units.length && !unitError" title="当前没有可报名的项目" description="请返回赛事详情查看最新安排。" /><router-link
        class="btn text"
        to="/portal/registration"
        ><ConsumerIcon name="back" />返回我的参赛</router-link
      >
    </section>
    <template v-else-if="registrationId"
      ><ConsumerState v-if="!detailEntry" error title="无法查看这条报名" description="记录不存在或当前账号没有查看权限。"
        ><router-link class="btn" to="/portal/registration">返回本人报名</router-link></ConsumerState
      ><template v-else>
        <section class="registration-overview">
          <div class="between">
            <span class="badge" :class="detailEntry.eventHolding === 'cancelled' ? 'red' : detailEntry.status === 'approved' ? '' : 'orange'">{{
              detailEntry.eventHolding === 'cancelled' ? '赛事已取消' : entryStatusLabel(detailEntry.status)
            }}</span
            ><span class="small">{{ entryTypeLabel(detailEntry.entryType) }}</span>
          </div>
          <h1>{{ detailEntry.unitName }}</h1>
          <p v-if="detailEntry.teamName" class="consumer-muted">代表 {{ detailEntry.teamName }}</p>
          <p v-if="detailEntry.eventHolding === 'cancelled'" class="consumer-muted">历史报名保留，请按原费用依据联系承办方办理资金收尾。</p>
          <p v-else-if="detailEntry.eventPublication === 'offline'" class="consumer-muted">赛事已下架，本人报名及提交记录仍可查看。</p>
          <p class="registration-next">{{ nextAction(detailEntry) }}</p>
          <div class="status-cells">
            <div>
              <span>参赛资格</span><strong>{{ entryStatusLabel(detailEntry.status) }}</strong>
            </div>
            <div>
              <span>付款声明</span><strong>{{ declareText(detailEntry) }}</strong>
            </div>
            <div>
              <span>资金核对</span><strong>{{ fundsText(detailEntry) }}</strong>
            </div>
          </div>
        </section>
        <div class="detail-layout">
          <div class="stack">
            <section class="consumer-card">
              <h2>本次参赛名单</h2>
              <p class="consumer-muted">各成员本人填写与确认资料，名单以正式提交依据为准。</p>
              <div class="participant-list">
                <article v-for="member in detailEntry.members" :key="member.id" class="participant-item">
                  <span class="account-avatar">{{ (member.selfMember ? '我' : memberDisplayName(detailEntry, member)).slice(0, 1) }}</span>
                  <div class="participant-main">
                    <strong>{{ memberDisplayName(detailEntry, member) }}<span v-if="member.selfMember" class="registration-self">本人</span></strong>
                    <p v-if="detailEntry.canManage && member.mobileTail" class="registration-invite-identity">手机尾号 {{ member.mobileTail }}<span v-if="member.inviteToken"> · 此链接仅供该成员本人确认</span></p>
                    <p>{{ memberStatusLabel(member.status) }}</p>
                    <template v-if="detailEntry.canManage && member.inviteToken"><p class="consumer-note">{{ invitationDeliveryText(member.notice) }}</p><div class="registration-invite-actions"><el-button type="primary" link @click="copyInvitation('/portal/registration/invite/' + member.inviteToken, invitationRecipient(detailEntry, member))">复制给{{ memberDisplayName(detailEntry, member) }}的邀请链接</el-button><el-button v-if="editable(detailEntry) && member.notice?.inboxStatus !== 'delivered'" link :loading="memberBusy.has(member.id)" @click="remind(detailEntry, member)">发送站内邀请</el-button></div></template>
                  </div>
                  <el-button
                    v-if="detailEntry.canManage && editable(detailEntry) && (detailEntry.teamId || !member.selfMember)"
                    link
                    type="danger"
                    :loading="memberBusy.has(member.id)"
                    @click="remove(detailEntry, member)"
                    >移除</el-button
                  >
                </article>
              </div>
              <div v-if="detailEntry.canManage && editable(detailEntry) && detailEntry.teamId && !detailEntry.members.length" class="invite-row">
                <el-button type="primary" @click="prepareExistingTeam(detailEntry)">选择本次参赛成员</el-button>
              </div>
              <details v-else-if="detailEntry.canManage && editable(detailEntry) && detailEntry.teamId && detailEntry.entryType !== 'individual'" class="team-roster-adjustment">
                <summary>调整参赛成员</summary>
                <div class="invite-row"><el-select v-model="picked[detailEntry.id]" placeholder="选择替补成员"><el-option v-for="person in candidates[detailEntry.teamId] || []" :key="person.accountId" :label="person.legalName" :value="person.accountId" :disabled="!person.selectable || detailEntry.members.some(member => member.accountId === person.accountId)" /></el-select><el-button @click="add(detailEntry)">加入名单</el-button></div>
              </details>
              <div
                v-if="
                  detailEntry.canManage &&
                  editable(detailEntry) &&
                  !detailEntry.teamId &&
                  detailEntry.entryType !== 'individual' &&
                  detailEntry.members.length < (detailEntry.maxMembers ?? (detailEntry.entryType === 'pair' ? 2 : Infinity))
                "
                class="invite-row"
              >
                <el-input v-model="phones[detailEntry.id]" maxlength="11" placeholder="对方已注册的手机号" />
                <el-checkbox v-model="smsRequests[detailEntry.id]">同时申请短信提醒</el-checkbox><el-button :loading="inviting" @click="invite(detailEntry)">邀请</el-button><p class="consumer-note">邀请会发送站内信，也可复制邀请链接联系对方。</p>
              </div>
              <div v-if="fieldSets[detailEntry.id] && fieldSets[detailEntry.id].length" class="field-block">
                <p>本人参赛资料</p>
                <el-form label-position="top" class="form-two-columns">
                  <el-form-item
                    v-for="field in fieldSets[detailEntry.id]"
                    :key="field.eventFieldId"
                    :label="field.label + (field.required ? '（必填）' : '')"
                  >
                    <el-input v-if="field.valueType === 'text'" v-model="field.valueText" maxlength="1000" :disabled="!editable(detailEntry)" />
                    <el-input v-else-if="field.valueType === 'number'" v-model="field.valueText" :disabled="!editable(detailEntry)" />
                    <el-date-picker
                      v-else-if="field.valueType === 'date'"
                      v-model="field.valueText"
                      value-format="YYYY-MM-DD"
                      type="date"
                      :disabled="!editable(detailEntry)"
                    />
                    <el-select v-else v-model="field.valueText" :disabled="!editable(detailEntry)" clearable>
                      <el-option v-for="option in field.options" :key="option" :label="option" :value="option" />
                    </el-select>
                    <p v-if="field.note">{{ field.note }}</p>
                  </el-form-item>
                </el-form>
                <el-button v-if="editable(detailEntry)" @click="saveFields(detailEntry)">保存草稿资料</el-button>
              </div>
            </section>
          </div>
          <aside class="stack">
            <section class="consumer-card">
              <h3>{{ detailEntry.obligationId ? '本次费用' : '预计报名费' }}</h3>
              <p class="money large">{{ money(detailEntry) }}</p>
              <p class="consumer-muted">{{ feeLabel(detailEntry) || '按当前项目费用预览，正式提交时冻结本次应付。草稿无需付款。' }}</p>
              <p v-if="detailEntry.payInstruction" class="consumer-note">{{ detailEntry.payInstruction }}</p>
              <el-button v-if="canPay(detailEntry)" type="primary" style="width: 100%" @click="openPay(detailEntry)"
                >查看付款指引／我已付款</el-button
              >
              <el-button v-else-if="detailEntry.canManage && detailEntry.obligationId && Number(detailEntry.feeAmount) > 0" @click="openPay(detailEntry)">查看付款凭证与指引</el-button>
            </section>
            <section v-if="detailEntry.members.some(member => member.selfMember) && detailEntry.declarationConfirmRequired && (detailEntry.declarationText || detailEntry.declarationImageAvailable)" class="consumer-card">
              <EntryDeclaration :registration-id="detailEntry.id" :text="detailEntry.declarationText" :image-available="detailEntry.declarationImageAvailable" :acknowledged="detailEntry.declarationAcknowledged" v-slot="{ ready }">
                <el-button v-if="!detailEntry.declarationAcknowledged" type="primary" :disabled="!ready" @click="ackDeclaration(detailEntry)">我已阅读并确认</el-button>
              </EntryDeclaration>
            </section>
            <section class="consumer-card">
              <h3>整单办理</h3>
              <p v-if="detailEntry.teamId && !detailEntry.canManage" class="consumer-muted">此报名由当前队长继续办理。</p>
              <p class="consumer-note">正式提交会冻结名单并占用名额。资格、实际到账与退款分别办理。</p>
              <div class="stack" style="gap: 12px">
                <el-button
                  v-if="detailEntry.canManage && editable(detailEntry) && detailEntry.eventHolding !== 'cancelled'"
                  type="primary"
                  @click="submit(detailEntry)"
                  :loading="submitting"
                  :disabled="submitting"
                  >正式提交报名</el-button
                ><el-button
                  v-if="
                    detailEntry.canManage &&
                    (detailEntry.status === 'submitted' || detailEntry.status === 'approved') &&
                    detailEntry.eventHolding !== 'cancelled'
                  "
                  @click="withdraw(detailEntry)"
                  >撤回整单报名</el-button
                ><el-button v-if="canDeleteRegistrationDraft(detailEntry)" @click="removeDraft(detailEntry)">删除草稿</el-button
                ><router-link class="btn" to="/portal/registration">返回报名列表</router-link>
              </div>
            </section>
          </aside>
        </div>
      </template></template
    >
    <template v-else
      ><div class="order-filters sport-chips" style="margin-bottom: 20px">
        <button
          v-for="item in [
            { id: 'all', label: '全部报名' },
            { id: 'active', label: '当前报名' },
            { id: 'history', label: '历史记录' }
          ]"
          :key="item.id"
          class="chip"
          :class="{ active: orderFilter === item.id }"
          :aria-pressed="orderFilter === item.id"
          @click="orderFilter = item.id"
        >
          {{ item.label }}
        </button>
      </div>
      <ConsumerState v-if="!filteredEntries.length" title="这里还没有报名记录" description="看看身边的赛事，找到你的下一次上场。"
        ><router-link class="btn primary" to="/public/events">发现赛事</router-link></ConsumerState
      >
      <div v-else class="order-grid">
        <article v-for="entry in filteredEntries" :key="entry.id" class="order-card">
          <div class="between">
            <span class="small">{{ entry.submittedAt ? '提交于 ' + businessTime(entry.submittedAt) : '尚未正式提交' }}</span
            ><span class="badge" :class="entry.eventHolding === 'cancelled' ? 'red' : entry.status === 'approved' ? '' : 'orange'">{{
              entry.eventHolding === 'cancelled' ? '赛事已取消' : entryStatusLabel(entry.status)
            }}</span>
          </div>
          <h3 class="order-title">
            {{ entry.unitName }}<span v-if="entry.teamName" class="small"> · {{ entry.teamName }}</span>
          </h3>
          <p class="registration-next">{{ nextAction(entry) }}</p>
          <div class="status-cells">
            <div>
              <span>参赛资格</span><strong>{{ entryStatusLabel(entry.status) }}</strong>
            </div>
            <div>
              <span>付款声明</span><strong>{{ declareText(entry) }}</strong>
            </div>
            <div>
              <span>资金进度</span><strong>{{ fundsText(entry) }}</strong>
            </div>
          </div>
          <div class="order-foot">
            <span
              >{{ entryTypeLabel(entry.entryType) }} · {{ entry.members.length }} 人 / 单 · <strong class="money">{{ money(entry) }}</strong></span
            ><el-button v-if="canDeleteRegistrationDraft(entry)" @click="removeDraft(entry)">删除草稿</el-button
            ><router-link class="btn" :to="{ path: '/portal/registration/detail/' + entry.id, query: orderFilter === 'all' ? {} : { listFilter: orderFilter } }">查看报名<ConsumerIcon name="arrow" /></router-link>
          </div>
          <p v-if="entry.eventPublication === 'offline'" class="consumer-note">赛事已下架，本人报名仍可查看。</p>
        </article>
      </div>
      <div v-if="received.length" class="section-head"><h2>收到的参赛邀请</h2></div>
      <div class="order-grid">
        <article v-for="item in received" :key="item.registrationId" class="order-card">
          <div class="between">
            <h3>{{ item.eventName }} · {{ item.unitName }}</h3>
            <span class="badge orange">{{ memberStatusLabel(item.memberStatus) }}</span>
          </div>
          <p class="consumer-muted">{{ inviteSituation(item) }}</p>
          <p v-if="item.initiatorName" class="consumer-note">报名发起人：{{ item.initiatorName }}</p>
          <router-link
            v-if="item.inviteToken"
            class="btn"
            :to="'/portal/registration/invite/' + encodeURIComponent(item.inviteToken)"
            data-testid="received-participation-link"
          >查看本人参赛<ConsumerIcon name="arrow" /></router-link>
        </article>
      </div></template
    >
    <TeamRegistrationDialog :unit="bookingUnit" :teams="captainTeams" :fixed-team-id="bookingFixedTeam" :price="bookingUnit ? quotedPrice(bookingUnit.id) : ''" @close="bookingUnit = undefined" @prepared="prepared" />
    <el-dialog :model-value="!!submitReview" title="确认正式提交报名" width="640px" class="b-dialog registration-team-dialog" :close-on-click-modal="!submitting" :show-close="!submitting" @close="!submitting && (submitReview = undefined)">
      <template v-if="submitReview"><div class="team-booking-summary"><span>{{ submitReview.teamName || '个人报名' }}</span><h3>{{ submitReview.unitName }}</h3><p>本次费用：{{ money(submitReview) }} / 单</p></div><h4>本次完整参赛名单</h4><div class="team-booking-members"><article v-for="member in submitReview.members" :key="member.id"><span class="registration-avatar">{{ memberDisplayName(submitReview, member).slice(0,1) }}</span><div><strong>{{ memberDisplayName(submitReview, member) }}</strong><p>{{ memberStatusLabel(member.status) }}</p></div></article></div><p class="team-booking-note">提交后冻结本次名单和费用、占用整单名额。{{ Number(submitReview.feeAmount || prices[submitReview.unitId]?.amount) > 0 ? '提交后可按指引付款，实际足额到账及资格确认后才报名成功。' : '资格以提交后的办理结果为准。' }}</p></template>
      <template #footer><el-button :disabled="submitting" @click="submitReview = undefined">返回核对</el-button><el-button type="primary" :loading="submitting" @click="submitReview && submitConfirmed(submitReview)">确认提交报名</el-button></template>
    </el-dialog>
    <el-dialog v-model="payVisible" title="付款指引与到账核对" width="460px" class="consumer-dialog payment-proof-dialog" align-center>
      <p>按承办方指引完成付款，可通知承办方核对。通知不是必做条件，也不代表到账或报名成功；以实际足额到账和参赛资格确认为准。</p>
      <p v-if="payEntry && feeLabel(payEntry)">{{ feeLabel(payEntry) }}</p>
      <PaymentChannels v-if="payEntry" :key="payEntry.obligationId || payEntry.id" :registration-id="payEntry.id" />
      <PaymentProofPanel v-if="payEntry" :key="payEntry.obligationId || payEntry.id" :registration-id="payEntry.id" :editable="canPay(payEntry)" />
      <template #footer>
        <el-button @click="payVisible = false">关闭</el-button>
        <el-button v-if="payEntry && canPay(payEntry)" type="primary" :disabled="payEntry.paymentDeclared" @click="finishPay">{{
          payEntry?.paymentDeclared ? '已通知承办方，等待核对' : '我已付款，通知承办方'
        }}</el-button>
      </template>
    </el-dialog></div></ConsumerShell
  >
</template>
<script setup lang="ts" name="PortalRegistration">
import '@/assets/styles/registration-invitation.scss';
import PaymentProofPanel from '@/components/business/PaymentProofPanel.vue';
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { copyInvitation, invitationDeliveryText } from '@/utils/invitation';
import { openConsumerAi } from '@/utils/consumerAi';
import { registrationNextAction } from '@/utils/consumerRegistration';
import request from '@/utils/request';
import { registrationPriceText, type RegistrationPrice } from '@/utils/registrationPrice';
import { useRoute, useRouter } from 'vue-router';
import { ElMessage, ElMessageBox } from 'element-plus';
import ConsumerPageHeader from '@/components/consumer/ConsumerPageHeader.vue';
import ConsumerState from '@/components/consumer/ConsumerState.vue';
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import ConsumerShell from '@/layout/consumer/ConsumerShell.vue';
import TeamRegistrationDialog from '@/components/consumer/TeamRegistrationDialog.vue';
import EntryDeclaration from '@/components/consumer/EntryDeclaration.vue';
import EntryHandover from '@/components/consumer/EntryHandover.vue';
import { ensureProfile } from '@/utils/profileGate';
import { newRequestKey } from '@/utils/requestKey';
import { businessTime } from '@/utils/business';
import PaymentChannels from '@/components/business/PaymentChannels.vue';
import {
  EntryCard,
  InviteView,
  MemberCard,
  UnitCard,
  addTeammate,
  createEntry,
  acknowledgeDeclaration,
  declarePaid,
  entryStatusLabel,
  entryTypeLabel,
  feeLabel,
  inviteMember,
  inviteSituation,
  listMyEntries,
  listPublicUnits,
  listReceivedInvites,
  memberStatusLabel,
  removeMember,
  remindRegistrationInvite,
  submitEntry,
  withdrawEntry,
  deleteRegistrationDraft
} from '@/api/sports/registration';
import { canDeleteRegistrationDraft } from '@/utils/registrationDraft';
import { CandidateCard, MembershipCard, listCandidates, listTeams } from '@/api/sports/team';
import { EntryFieldCard, listEntryFields, saveEntryFields } from '@/api/sports/field';

const submitting = ref(false);
const route = useRoute();
const router = useRouter();
const eventId = computed(() => String(route.query.eventId || ''));
const preferredUnitId = computed(() => String(route.query.unitId || ''));
const registrationId = computed(() => String(route.params.id || ''));
const applyMode = computed(() => route.name === 'PortalRegistrationApply' || Boolean(eventId.value));
const units = ref<UnitCard[]>([]);
const prices = ref<Record<string, RegistrationPrice>>({});
const quotedPrice = (unitId: string) => prices.value[unitId] ? registrationPriceText(prices.value[unitId]) : '费用暂时无法读取';
const loadPrices = async (id: string) => {
  prices.value = {};
  if (!id) return;
  try {
    const res = await request({ url: `/sports/public/events/${id}/fees`, method: 'get', headers: { isToken: false } });
    prices.value = Object.fromEntries((res.data.units || []).map((unit: RegistrationPrice & { unitId: string }) => [unit.unitId, unit]));
  } catch { /* An unavailable quote never becomes free or a payable obligation. */ }
};
const unitError = ref('');
const loadError = ref('');
const loading = ref(true);
const orderFilter = ref(['active', 'history'].includes(String(route.query.filter)) ? String(route.query.filter) : 'all');
const registrationListBack = computed(() => '/portal/registration' + (['active', 'history'].includes(String(route.query.listFilter)) ? '?filter=' + route.query.listFilter : ''));
watch(() => route.query.filter, value => { orderFilter.value = ['active', 'history'].includes(String(value)) ? String(value) : 'all'; });
const pickedUnit = computed(() => units.value.find((unit) => unit.id === preferredUnitId.value));
const entries = ref<EntryCard[]>([]);
const filteredEntries = computed(() =>
  entries.value.filter(
    (entry) =>
      orderFilter.value === 'all' ||
      (orderFilter.value === 'history'
        ? entry.eventHolding === 'cancelled' || ['rejected', 'withdrawn'].includes(entry.status)
        : entry.eventHolding !== 'cancelled' && ['draft', 'submitted', 'approved'].includes(entry.status))
  )
);
const money = (entry: EntryCard) =>
  entry.paymentMode === 'free' || entry.obligationStatus === 'not_required'
    ? '免费'
    : entry.feeAmount == null
      ? quotedPrice(entry.unitId)
      : '¥' + Number(entry.feeAmount).toFixed(2);
const fundsText = (entry: EntryCard) =>
  !entry.obligationStatus
    ? '暂无付款义务'
    : entry.obligationStatus === 'not_required' || entry.paymentMode === 'free'
      ? '无需付款'
      : entry.obligationStatus === 'settled'
        ? '已核对到账'
        : entry.obligationStatus === 'void'
          ? '义务已失效'
          : entry.paymentDeclared
            ? '待核对到账'
            : '待付款';
const detailEntry = computed(() => entries.value.find((entry) => entry.id === registrationId.value));
const received = ref<InviteView[]>([]);
const phones = reactive<Record<string, string>>({});
const smsRequests = reactive<Record<string, boolean>>({});
const inviting = ref(false);
const picked = reactive<Record<string, string>>({});
const pendingSubmitKeys = reactive<Record<string, string>>({});
const fieldSets = reactive<Record<string, EntryFieldCard[]>>({});
const candidates = reactive<Record<string, CandidateCard[]>>({});
const captainTeams = ref<MembershipCard[]>([]);
const bookingUnit = ref<UnitCard>();
const bookingFixedTeam = ref('');
const submitReview = ref<EntryCard>();
const payVisible = ref(false);
const payEntry = ref<EntryCard>();

const nextAction = (entry: EntryCard) => entry.status === 'draft' && entry.teamId
  ? !entry.members.length ? '下一步：选择本次参赛成员，一次带入完整名单。'
    : entry.members.some(member => member.status === 'pending_confirmation') ? `名单已准备，等待 ${entry.members.filter(member => member.status === 'pending_confirmation').length} 位成员本人确认，随后正式提交。`
      : '名单已确认，请核对资料与本次费用，正式提交报名。'
  : registrationNextAction(entry);
const memberDisplayName = (entry: EntryCard, member: MemberCard) => member.legalName || member.invitationName || (entry.teamId ? candidates[entry.teamId]?.find(person => person.accountId === member.accountId)?.legalName : '') || (member.selfMember ? '本人' : '待确认成员');
const invitationRecipient = (entry: EntryCard, member: MemberCard) => memberDisplayName(entry, member) + (member.mobileTail ? `（手机尾号 ${member.mobileTail}）` : '');
const memberBusy = ref(new Set<string>());
const declareText = (entry: EntryCard) => {
  if (!entry.obligationStatus || entry.obligationStatus === 'not_required' || entry.paymentMode === 'free') {
    return '无需付款';
  }
  return entry.paymentDeclared ? '已提交声明' : '尚未声明';
};

const loadData = async () => {
  loadError.value = '';
  unitError.value = '';
  const currentEventId = applyMode.value ? eventId.value : '';
  if (currentEventId) {
    const ready = await ensureProfile(router, route.fullPath);
    if (!ready) {
      return;
    }
    try {
      const unitRes = await listPublicUnits(currentEventId);
      units.value = unitRes.data;
      await loadPrices(currentEventId);
      if (preferredUnitId.value && !pickedUnit.value) {
        unitError.value = '刚才选择的项目现在不能报名。请重新选择。系统没有新建报名。';
      }
    } catch (cause) {
      units.value = [];
      unitError.value = cause instanceof Error ? cause.message : '项目暂时无法读取。系统没有新建报名。';
    }
  } else {
    units.value = [];
  }
  try {
    const entryRes = await listMyEntries(currentEventId || undefined);
    entries.value = entryRes.data || [];
    if (registrationId.value) await loadPrices(detailEntry.value?.eventId || '');
    if (!registrationId.value) {
      const receivedRes = await listReceivedInvites();
      received.value = receivedRes.data || [];
    }
    const teamRes = await listTeams();
    captainTeams.value = (teamRes.data.memberships || []).filter(
      (item: MembershipCard) => item.teamStatus === 'active' && item.role === 'captain' && item.membershipStatus === 'active'
    );
  } catch (cause) {
    loadError.value = cause instanceof Error ? cause.message : '报名暂时无法读取。';
    return;
  }
  const visible = registrationId.value ? entries.value.filter((entry) => entry.id === registrationId.value) : entries.value;
  for (const entry of visible) {
    if (entry.teamId && entry.canManage && editable(entry)) {
      const candidateRes = await listCandidates(entry.teamId);
      candidates[entry.teamId] = candidateRes.data;
    }
    if (!entry.members.some(member => member.selfMember)) { fieldSets[entry.id] = []; continue; }
    try {
      const fieldRes = await listEntryFields(entry.id);
      fieldSets[entry.id] = fieldRes.data;
    } catch {
      fieldSets[entry.id] = [];
    }
  }
};

const saveFields = async (entry: EntryCard) => {
  const fields = fieldSets[entry.id] || [];
  await saveEntryFields(
    entry.id,
    fields.map((field) => ({ eventFieldId: field.eventFieldId, valueText: field.valueText || '' }))
  );
  ElMessage.success('已保存草稿资料');
  await load();
};

const preparedUnit = ref('');
const load = async () => {
  loading.value = true;
  try {
    await loadData();
    if (
      applyMode.value &&
      pickedUnit.value &&
      !loadError.value &&
      !unitError.value &&
      preparedUnit.value !== pickedUnit.value.id
    ) {
      const unit = pickedUnit.value;
      preparedUnit.value = unit.id;
      const existing = entries.value.find((e) => e.unitId === unit.id && e.canManage && e.status === 'draft');
      try {
        if (existing) await router.replace('/portal/registration/detail/' + existing.id);
        else await create(unit);
      } catch (cause) {
        // 深链会自动准备草稿；请求失败留在项目页提示，不自动重发或冒充已创建。
        unitError.value = cause instanceof Error ? cause.message : '报名草稿未能创建，请核对后重新尝试。';
      }
    }
  } finally {
    loading.value = false;
  }
};

const create = async (unit: UnitCard) => {
  const ready = await ensureProfile(router, route.fullPath);
  if (!ready) {
    return;
  }
  if (captainTeams.value.length) { bookingFixedTeam.value = ''; bookingUnit.value = unit; return; }
  const res = await createEntry(unit.id, newRequestKey());
  ElMessage.success('已创建报名草稿');
  await router.push('/portal/registration/detail/' + res.data.id);
};

const prepared = async (entry: EntryCard) => {
  bookingUnit.value = undefined;
  ElMessage.success(entry.members.some(member => member.status === 'pending_confirmation') ? '名单已带入，已通知队员本人确认' : '名单已带入，请核对后正式提交');
  if (registrationId.value === entry.id) await load();
  else await router.push('/portal/registration/detail/' + entry.id);
};
const prepareExistingTeam = (entry: EntryCard) => {
  bookingFixedTeam.value = entry.teamId || '';
  bookingUnit.value = {id:entry.unitId,eventId:entry.eventId,name:entry.unitName,entryType:entry.entryType,minMembers:entry.entryType === 'individual' ? 1 : 2,maxMembers:entry.maxMembers || 2,limitCount:0,usedCount:0};
};
const add = async (entry: EntryCard) => {
  await addTeammate(entry.id, picked[entry.id] || '');
  picked[entry.id] = '';
  ElMessage.success('已加入名单');
  await load();
};

const invite = async (entry: EntryCard) => {
  if (inviting.value) return;
  inviting.value = true;
  try {
    await inviteMember(entry.id, phones[entry.id] || '', !!smsRequests[entry.id]);
    phones[entry.id] = '';
    ElMessage.success('邀请已发出，站内信已生成');
    if (smsRequests[entry.id]) ElMessage.warning('短信通道未接通，请复制链接联系对方');
    smsRequests[entry.id] = false;
    await load();
  } finally { inviting.value = false; }
};

const remove = async (entry: EntryCard, member: MemberCard) => {
  if (memberBusy.value.has(member.id)) return;
  memberBusy.value.add(member.id);
  try {
    const notice = member.selfMember ? '这次调整仅移出你本人的参赛名单。' : '对方会收到站内通知，原邀请链接将失效。';
    const confirmed = await ElMessageBox.confirm(`将${invitationRecipient(entry, member)}移出“${entry.unitName}”的本次名单。${notice}`, '确认调整参赛名单', { confirmButtonText: member.selfMember ? '移出本次名单' : '移出并通知本人', cancelButtonText: '保留成员', type: 'warning' }).then(() => true).catch(() => false);
    if (!confirmed) return;
    await removeMember(entry.id, member.id);
    ElMessage.success(member.selfMember ? '已移出本次名单' : '已移出本次名单，站内通知已生成');
    await load();
  } catch {
    // The shared request layer explains the failure; preserve the current roster for a deliberate retry.
  } finally { memberBusy.value.delete(member.id); }
};

const remind = async (entry: EntryCard, member: MemberCard) => {
  if (memberBusy.value.has(member.id)) return;
  memberBusy.value.add(member.id);
  try {
    await remindRegistrationInvite(entry.id, member.id);
    ElMessage.success(`已向${memberDisplayName(entry, member)}生成站内邀请`);
    await load();
  } catch {
    // Keep the intended recipient and original invitation visible if recovery fails.
  } finally { memberBusy.value.delete(member.id); }
};

const canPay = (entry: EntryCard) => entry.canManage && entry.eventHolding !== 'cancelled' && entry.obligationStatus === 'open';

const openPay = async (entry: EntryCard) => {
  payEntry.value = entry;
  payVisible.value = true;
};

const activeResubmit = (entry: EntryCard) => entry.status === 'rejected' || (entry.status === 'draft' && entry.requestKeyConsumed);

const submitKeyFor = (entry: EntryCard) => {
  if (!activeResubmit(entry)) {
    return entry.requestKey;
  }
  if (!pendingSubmitKeys[entry.id]) {
    pendingSubmitKeys[entry.id] = newRequestKey();
  }
  return pendingSubmitKeys[entry.id];
};

const ackDeclaration = async (entry: EntryCard) => {
  const res = await acknowledgeDeclaration(entry.id);
  const index = entries.value.findIndex((item) => item.id === entry.id);
  if (index >= 0 && res.data) entries.value[index] = res.data;
  ElMessage.success('已确认参赛声明');
};
const submit = async (entry: EntryCard) => {
  if (submitting.value) return;
  await load();
  const latest = entries.value.find(item => item.id === entry.id);
  if (!latest) return;
  if (latest.members.some(member => member.status === 'pending_confirmation') || !latest.members.some(member => member.status === 'confirmed')) {
    ElMessage.warning('请先完成名单和所有成员的本人确认，再正式提交。'); return;
  }
  submitReview.value = latest;
};
const submitConfirmed = async (entry: EntryCard) => {
  if (submitting.value) return;
  submitting.value = true;
  try {
    if (editable(entry) && entry.members.some(member => member.selfMember)) {
      await saveEntryFields(
        entry.id,
        (fieldSets[entry.id] || []).map((f) => ({ eventFieldId: f.eventFieldId, valueText: f.valueText || '' }))
      );
    }
    const requestKey = submitKeyFor(entry);
    const res = await submitEntry(entry.id, requestKey);
    const submitted = res.data.status === 'submitted' || res.data.status === 'approved';
    if (submitted) {
      delete pendingSubmitKeys[entry.id];
    }
    submitReview.value = undefined;
    ElMessage.success(submitted ? '已提交。资格和到账仍分别办理。' : '这条请求没有重新提交');
    if (route.name !== 'PortalRegistrationDetail') {
      await router.push('/portal/registration/detail/' + res.data.id);
      return;
    }
    await load();
    const latest = entries.value.find((e) => e.id === entry.id);
    if (latest && canPay(latest)) await openPay(latest);
  } finally {
    submitting.value = false;
  }
};

const finishPay = async () => {
  if (!payEntry.value) {
    return;
  }
  await declarePaid(payEntry.value.id);
  ElMessage.success('已记录付款声明，等待承办方核对到账');
  payVisible.value = false;
  await load();
};

const removeDraft = async (entry: EntryCard) => {
  if (!canDeleteRegistrationDraft(entry)) return;
  const confirmed = await ElMessageBox.confirm('将删除这份从未提交的报名草稿，并移除其中的成员邀请。已提交或已有资金记录的报名不会从这里删除。', '删除草稿', {
    confirmButtonText: '删除草稿',
    cancelButtonText: '留下',
    type: 'warning'
  })
    .then(() => true)
    .catch(() => false);
  if (!confirmed) return;
  try {
    await deleteRegistrationDraft(entry.id);
    ElMessage.success('已删除报名草稿');
    if (registrationId.value === entry.id) await router.replace('/portal/registration');
    else await load();
  } catch {
    // 请求层已显示服务端返回的失败原因。
  }
};

const withdraw = async (entry: EntryCard) => {
  const confirmed = await ElMessageBox.confirm('撤回针对整单，原报名和资金记录会保留。退款由承办方按原规则核对办理。', '撤回整单报名', {
    confirmButtonText: '确认撤回',
    cancelButtonText: '暂不撤回',
    type: 'warning'
  })
    .then(() => true)
    .catch(() => false);
  if (!confirmed) return;
  await withdrawEntry(entry.id);
  ElMessage.success('已撤回。名额是否释放以服务端结果为准。');
  await load();
};

const editable = (entry: EntryCard) => entry.status === 'draft' || entry.status === 'rejected';

const inviteLink = (token: string) => `${window.location.origin}/portal/registration/invite/${token}`;

watch(
  () => route.fullPath,
  () => load()
);
onMounted(load);
</script>
