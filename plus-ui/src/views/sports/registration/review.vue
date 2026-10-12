<template>
  <div class="app-container">
    <template v-if="!eventKey"><div class="b-heading"><div><h1>{{mode==='projects'?'竞赛项目':'报名管理'}}</h1><p>选择赛事，查看报名名单并办理资格审核、收款和退款。</p></div></div><section class="b-panel"><el-form label-position="top"><el-form-item label="赛事"><el-select v-model="eventId" placeholder="选择赛事" @change="reload" filterable style="width:min(520px,100%)"><el-option v-for="item in events" :key="item.eventId" :label="item.name" :value="item.eventId" class="product-event-option"><span>{{ item.name }}</span><small class="product-object-code">编号 {{ String(item.eventId).slice(-6) }}</small></el-option></el-select></el-form-item></el-form></section></template>
    <el-alert v-if="loadError" :title="loadError" type="error" :closable="false" />
    <el-card v-if="mode === 'projects'" shadow="never" class="mb-4">
      <template #header>竞赛项目</template>
      <p>名额按整单计算。收费报名要先确认足额到账才能通过。资金办理集中在报名详情中，付款声明与实际到账分别核对。</p>
      <p>微信、支付宝、银行及其他收款方式统一在赛事设置中维护。<router-link :to="{path: '/org-desk/workspace/' + eventId, query: {task: 'fields'}}">前往赛事收款设置 →</router-link></p>
      <details v-if="!eventStopped && !approvalClosed" :open="!units.length">
        <summary style="cursor: pointer; font-weight: 600; margin: 12px 0">新增竞赛项目</summary>
        <el-form label-position="top">
          <el-form-item v-if="!eventKey" label="赛事">
            <el-select v-model="eventId" placeholder="选择赛事" @change="loadUnits">
              <el-option v-for="event in events" :key="event.eventId" :label="event.name || '未命名赛事'" :value="event.eventId" />
            </el-select>
          </el-form-item>
          <el-form-item label="项目名称">
            <el-input v-model="form.name" maxlength="200" />
          </el-form-item>
          <el-form-item label="项目类型">
            <el-select v-model="form.entryType">
              <el-option label="单打" value="individual" />
              <el-option label="双打" value="pair" />
            <el-option label="团体" value="team" />
            </el-select>
          </el-form-item>
          <template v-if="form.entryType === 'team'">
            <el-form-item label="最少人数">
              <el-input-number v-model="form.minMembers" :min="1" />
            </el-form-item>
            <el-form-item label="最多人数">
              <el-input-number v-model="form.maxMembers" :min="1" />
            </el-form-item>
          </template>
          <el-form-item label="名额">
            <el-input-number v-model="form.limitCount" :min="1" />
          </el-form-item>
          <el-form-item label="是否收费">
            <FeeChoice v-model="form.charged" :disabled="creating" />
            <p class="b-muted">先选免费还是收费。没选的话，这个项目不会被建成免费。</p>
          </el-form-item>
          <template v-if="form.charged">
            <el-form-item label="报名费">
              <el-input-number v-model="form.amount" :min="0.01" :precision="2" placeholder="输入金额" /><span>元／单</span>
            </el-form-item>
          </template>
          <el-button type="primary" :loading="creating" @click="create">建立项目</el-button>
        </el-form>
      </details>
      <el-table :data="units" class="mt-4">
        <el-table-column prop="name" label="项目" />
        <el-table-column label="项目类型" width="100">
          <template #default="{ row }">{{ entryTypeLabel(row.entryType) }}</template>
        </el-table-column>
        <el-table-column label="名额" width="120">
          <template #default="{ row }">{{ row.usedCount }}/{{ row.limitCount }}</template>
        </el-table-column>
        <el-table-column label="费用" min-width="320">
          <template #default="{ row }">
            <InlineFeeEditor v-if="paymentAllowed" :unit-id="row.id" :payment-mode="row.paymentMode" :amount="row.amount" :disabled="eventStopped || pricingLocked" @saved="loadUnits" />
            <span v-else class="b-muted">需资金办理权限查看和设置费用</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="220">
          <template #default="{ row }">
            <el-button v-if="!eventStopped" link type="primary" @click="adjust(row)">调整名额</el-button>
            <el-button link type="primary" @click="goEntries(row)">报名名单</el-button
            ><el-button v-if="!eventStopped" link @click="editUnit(row)">编辑项目</el-button
            ><el-button v-if="!eventStopped" link type="danger" @click="deleteUnit(row)">删除项目</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <section v-if="mode === 'registrations' && !eventId" class="b-panel"><el-empty description="选择赛事后查看报名名单" /></section>
    <el-card v-if="mode === 'registrations' && eventId" shadow="never">
      <template #header>报名名单 <span class="b-muted">资格、声明与实收分别办理</span></template>
      <div class="b-actions">
        <el-button
          v-for="item in [
            { key: 'submitted', label: '待审核' },
            { key: 'approved', label: '已通过' },
            { key: 'rejected', label: '已拒绝' },
            { key: 'history', label: '撤回历史' },
            { key: 'all', label: '全部' }
          ]"
          :key="item.key"
          :type="statusFilter === item.key ? 'primary' : 'default'"
          @click="statusFilter = item.key"
          >{{ item.label }} · {{ item.key === 'all' ? entries.length : entries.filter((e) => item.key === 'history' ? e.status === 'draft' && e.rosterRevision > 0 : e.status === item.key).length }}</el-button
        >
      </div>
      <div class="b-toolbar">
        <el-select v-model="selectedId" placeholder="选择项目" @change="chooseUnit"
          ><el-option label="全部项目" value="all" /><el-option v-for="unit in units" :key="unit.id" :label="unit.name" :value="unit.id" /></el-select
        ><el-input v-model="query" clearable placeholder="搜索姓名或报名编号" /><el-select v-model="statusFilter"
          ><el-option label="全部资格状态" value="all" /><el-option label="待审核" value="submitted" /><el-option
            label="已通过"
            value="approved" /><el-option label="已拒绝" value="rejected" /><el-option label="撤回历史" value="history" /><el-option
            label="待核对付款声明"
            value="declared" /><el-option label="待资金收尾" value="refund" /></el-select
        ><el-button @click="reload">刷新</el-button>
      </div>
      <p v-if="!units.length" class="b-muted">还没有竞赛项目，请先到项目与费用建立项目。</p>

      <el-table :data="filteredEntries" v-loading="loading">
        <el-table-column label="状态" width="100">
          <template #default="{ row }">{{ entryStatusLabel(row.status) }}</template>
        </el-table-column>
        <el-table-column label="成员">
          <template #default="{ row }">
            <span v-for="member in row.members" :key="member.id" class="member">
              {{ member.legalName || '待确认' }}（{{ memberStatusLabel(member.status) }}）
            </span>
          </template>
        </el-table-column>
        <el-table-column label="付款声明" min-width="120"
          ><template #default="{ row }">{{ row.paymentDeclared ? '已声明' : '未声明' }}</template></el-table-column
        >
        <el-table-column label="资金状态" min-width="180">
          <template #default="{ row }">{{ feeLabel(row) || '未提交' }}</template>
        </el-table-column>
        <el-table-column label="操作" width="120" fixed="right"
          ><template #default="{ row }"><el-button link type="primary" @click="openDetail(row)">查看办理</el-button></template></el-table-column
        >
      </el-table>
    </el-card>

    <el-dialog class="b-dialog" v-model="unitEditVisible" title="编辑项目" width="480px"
      ><p>已有正式提交后，仅可做不改变含义的名称更正；类型及人数由服务端锁定。</p>
      <el-form label-position="top"
        ><el-form-item label="项目名称"><el-input v-model="unitEdit.name" maxlength="200" /></el-form-item
        ><el-form-item label="项目类型"
          ><el-select v-model="unitEdit.entryType"
            ><el-option label="单打" value="individual" /><el-option label="双打" value="pair" /><el-option
              label="团体"
              value="team" /></el-select></el-form-item
        ><template v-if="unitEdit.entryType === 'team'"
          ><el-input-number v-model="unitEdit.minMembers" :min="1" /><el-input-number
            v-model="unitEdit.maxMembers"
            :min="unitEdit.minMembers" /></template></el-form
      ><template #footer
        ><el-button @click="unitEditVisible = false">取消</el-button><el-button type="primary" @click="finishUnitEdit">保存</el-button></template
      ></el-dialog
    >
    <el-drawer v-model="detailVisible" title="报名详情与办理" size="640px" class="b-drawer" :destroy-on-close="true" :modal="false" modal-class="b-registration-overlay" :lock-scroll="false" :close-on-click-modal="false">
      <template v-if="selectedEntry">
        <p class="b-muted">报名 {{ selectedEntry.id }} · {{ selectedEntry.unitName }} · 提交版本 {{ selectedEntry.rosterRevision }}</p>
        <el-alert v-if="eventStopped" title="赛事已取消或结束，停止新审核通过；历史和资金收尾保留。" type="warning" :closable="false" />
        <div class="b-status-line">
          <div>
            <small>参赛资格</small><strong>{{ entryStatusLabel(selectedEntry.status) }}</strong>
          </div>
          <div>
            <small>付款声明</small><strong>{{ selectedEntry.paymentDeclared ? '已声明' : '未声明' }}</strong>
          </div>
          <div>
            <small>资金进度</small><strong>{{ feeLabel(selectedEntry) || '未产生义务' }}</strong>
          </div>
        </div>
        <section class="b-panel">
          <h3>提交名单</h3>
          <p v-if="rosterLoading" role="status">正在读取正式提交资料…</p>
          <div v-else-if="rosterError" class="notice warn" role="alert">{{ rosterError }} <el-button @click="loadRoster">重试</el-button></div>
          <article v-for="member in submittedMembers" :key="member.id" class="review-member" data-testid="submitted-member">
            <div class="review-member-heading"><span class="registration-avatar" aria-hidden="true">{{ (member.legalName || '友').slice(0, 1) }}</span><div><strong>{{ member.legalName || '姓名未记录' }}</strong><p>正式提交资料</p></div></div>
            <dl class="registration-facts"><div><dt>性别</dt><dd>{{ genderText(member.gender) }}</dd></div><div><dt>出生日期</dt><dd>{{ member.birthDate || '未记录' }}</dd></div><div><dt>联系电话</dt><dd>{{ member.mobile || '未记录' }}</dd></div></dl>
            <dl v-if="member.fields.length" class="registration-facts"><div v-for="(field, index) in member.fields" :key="index"><dt>{{ field.label }}</dt><dd>{{ field.value || '未填写' }}</dd></div></dl>
            <p v-if="!member.fieldsCaptured" class="b-muted">旧版报名未保存采集项快照，请结合原始提交资料核对。</p>
          </article>
          <p class="b-muted">提交时间：{{ businessTime(selectedEntry.submittedAt) }}。当前个人档案不覆盖已提交名单。</p>
        </section>
        <section class="b-panel">
          <h3>资格审核</h3>
          <p v-if="selectedEntry.status === 'submitted' && (approvalClosed || eventStopped || !canApprove(selectedEntry))" class="notice warn">
            {{
              approvalClosed || eventStopped
                ? '审核窗口已关闭，不能新增通过；真实资金仍可收尾。'
                : '请先登记实际足额到账，再审核通过。付款声明不能代替到账。'
            }}
          </p>
          <p v-if="selectedEntry.status === 'approved'" class="notice">资格已通过，可以按赛事安排参赛；后续资金更正仍需核对。</p><p v-else-if="selectedEntry.status !== 'submitted'" class="b-muted">当前资格：{{ entryStatusLabel(selectedEntry.status) }}，没有待办理的审核。</p><p class="b-muted">收费通过需实际足额到账；无需审核的有效申请足额到账后自动通过。</p>
          <div class="b-actions">
            <el-button
              v-if="selectedEntry.status === 'submitted'"
              :disabled="approvalClosed || eventStopped || !canApprove(selectedEntry)"
              type="primary"
              @click="approve(selectedEntry)"
              >审核通过</el-button
            ><el-button v-if="!eventStopped && selectedEntry.status === 'submitted'" type="danger" plain @click="reject(selectedEntry)"
              >拒绝报名</el-button
            >
          </div>
        </section>
        <section class="b-panel">
          <h3>收费记录与收尾</h3>
          <p v-if="eventStopped" class="b-muted">历史赛事仍可核对真实资金，到账登记不恢复参赛资格。</p>
          <p v-if="selectedEntry.obligationStatus === 'settled' && selectedFund?.current" class="notice">已足额到账，无需再次登记同一笔款。确有其他实际收款时才使用“补记”，多收款按原规则办理。</p>
          <p v-if="selectedFund?.current">{{ selectedEntry.payInstruction || '暂无付款指引' }}</p>
          <p v-if="!paymentAllowed" class="b-muted">当前身份没有资金办理权限。</p>
          <template v-else
            ><div v-if="fundHistory.length" class="fund-history" data-testid="fund-history">
              <label for="fund-history-selection">付款记录版本</label>
              <el-select id="fund-history-selection" v-model="fundObligationId" aria-label="付款记录版本" @change="loadRecords">
                <el-option v-for="duty in fundHistory" :key="duty.obligationId" :value="duty.obligationId" :label="historyLabel(duty)" />
              </el-select>
              <p v-if="selectedFund && !selectedFund.current" class="b-muted">正在查看原付款义务的收款、退款及异常记录。旧款不抵扣再次提交后的新应付。</p>
              <p v-if="selectedFund?.status === 'void'" class="b-muted">该付款义务已关闭，无需再次付款；已有实际收款与异常仍按原记录核对。</p>
              <p v-if="selectedFund?.pending" class="notice warn">此版本仍有资金待办，请核对收款、退款或异常记录。</p>
            </div>
            <PaymentProofPanel v-if="selectedFund?.current" :key="selectedEntry.obligationId || selectedEntry.id" :registration-id="selectedEntry.id" organizer />
            <div class="b-actions">
              <el-button
                v-if="selectedFund?.current && ['open', 'settled', 'void'].includes(selectedEntry.obligationStatus || '') && selectedEntry.paymentMode !== 'free'"
                :type="selectedEntry.obligationStatus === 'open' ? 'primary' : 'default'"
                :disabled="recordsLoading || !!recordsError"
                @click="receive(selectedEntry)"
                >{{ selectedEntry.obligationStatus === 'open' ? '登记实际到账' : '补记其他实际收款' }}</el-button
              ><el-button @click="loadHistory">刷新记录</el-button>
            </div>
            <p v-if="recordsError" class="b-muted">{{ recordsError }}</p>
            <p v-else-if="recordsLoading" class="b-muted">正在读取真实资金记录…</p>
            <template v-else-if="records"
              ><p>原应付 ¥{{ records.dueAmount }} · 净有效实收 ¥{{ records.netAmount }}（扣除实际退款）</p>
              <article v-for="r in records.receipts" :key="r.paymentId" class="b-record">
                <strong
                  >收款 ¥{{ r.amount }} · {{ r.status === 'reversed' ? '已撤销错误到账' : r.status === 'confirmed' ? '已核对' : r.status }}</strong
                >
                <el-button v-if="r.status === 'confirmed'" link @click="reverse(selectedEntry, r.paymentId)">撤销此笔错误到账</el-button
                ><el-button v-if="r.pendingActionId" link @click="openRefund(r)">登记此笔实际退款</el-button
                ><el-button v-if="r.pendingActionId" link @click="noRefund(selectedEntry, r.pendingActionId)">此笔无需退款结案</el-button>
                <p>累计实退 ¥{{ r.refundedAmount || 0 }}</p>
                <p>付款人 {{ r.payerName || '未提供' }} · 本义务分配 ¥{{ r.allocatedAmount }}</p>
                <p>实际到账 {{ businessTime(r.occurredAt) }} · 核对 {{ businessTime(r.confirmedAt) }}</p>
              </article>
              <article v-for="r in records.refunds" :key="r.refundId" class="b-record">
                <strong>退款 ¥{{ r.amount ?? '—' }} · {{ r.status === 'completed' ? '已登记退款' : r.status }}</strong>
                <p>对应收款 {{ r.paymentId }} · 登记完成 {{ businessTime(r.completedAt) }}</p>
                <p>接收人 {{ r.recipientName || '旧记录未采集' }} · {{ r.reason }}</p>
              </article>
              <PaymentExceptionPanel v-if="fundObligationId" :key="fundObligationId" :obligation-id="fundObligationId" :exceptions="records.exceptions || []" @resolved="refreshFunds" />
              <p v-if="!records.receipts.length && !records.refunds.length" class="b-muted">暂无实际收款或退款记录。</p></template
            ></template
          >
        </section>
      </template>
    </el-drawer>
    <el-dialog class="b-dialog" v-model="refundVisible" title="登记实际退款" width="520px"
      ><p>先在平台外实际退款，再登记；可分次，累计不能超过原款。未退余额不会自动结案。</p>
      <el-form label-position="top"
        ><el-form-item label="实际退款金额（元）"><el-input-number v-model="refundForm.amount" :min="0.01" :precision="2" /></el-form-item
        ><el-form-item label="实际退款时间（北京时间）"
          ><el-date-picker v-model="refundForm.occurredAt" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" /></el-form-item
        ><el-form-item label="实际接收人"><el-input v-model="refundForm.recipientName" maxlength="200" /></el-form-item
        ><el-form-item label="接收人与原付款人不同时的核验授权依据"
          ><el-input v-model="refundForm.recipientBasis" maxlength="1000" type="textarea" /></el-form-item
        ><el-form-item label="原退改规则与本次核对依据"
          ><el-input v-model="refundForm.note" maxlength="1000" type="textarea" /></el-form-item></el-form
      ><template #footer
        ><el-button @click="refundVisible = false">取消</el-button
        ><el-button type="primary" :loading="refundBusy" @click="finishRefund">登记实际退款</el-button></template
      ></el-dialog
    >
    <el-dialog v-model="receiptVisible" title="登记实际到账" width="480px" class="b-dialog">
      <p class="b-muted">每笔真实收款只登记一次。足额后，无需审核的有效申请会自动通过；需要审核的继续办理资格审核。</p><el-alert v-if="extraReceipt" title="本次为额外真实收款，请说明补记原因，不要重复登记同一笔到账。" type="warning" :closable="false" />
      <el-form label-position="top"
        ><el-form-item label="实际付款人" required><el-input v-model="receiptForm.payer" maxlength="200" /></el-form-item
        ><el-form-item label="实际到账金额（元）" required><el-input-number v-model="receiptForm.amount" :min="0.01" :precision="2" /></el-form-item
        ><el-form-item label="实际到账时间（北京时间）" required
          ><el-date-picker v-model="receiptForm.at" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" /></el-form-item
        ><el-form-item label="核对备注"><el-input v-model="receiptForm.note" type="textarea" maxlength="1000" /></el-form-item></el-form
      ><template #footer
        ><el-button @click="receiptVisible = false">取消</el-button
        ><el-button type="primary" :loading="receiptBusy" @click="finishReceipt">确认登记</el-button></template
      >
    </el-dialog>
  </div>
</template>

<script setup lang="ts" name="RegistrationReview">
import PaymentProofPanel from '@/components/business/PaymentProofPanel.vue';
import PaymentExceptionPanel from '@/components/business/PaymentExceptionPanel.vue';
import { businessTime } from '@/utils/business';
import { newRequestKey } from '@/utils/requestKey';
import { computed, inject, onMounted, onUnmounted, watch, reactive, ref, type Ref } from 'vue';

import { ElMessage, ElMessageBox } from 'element-plus';
import {
  EntryCard,
  ManagedEventOption,
  UnitCard,
  adjustUnitLimit,
  approveEntry,
  createUnit,
  updateUnit,
  removeUnit,
  entryStatusLabel,
  entryTypeLabel,
  feeLabel,
  listManagedUnits,
  listRegistrationEvents,
  listUnitEntries,
  memberStatusLabel,
  rejectEntry
} from '@/api/sports/registration';
import {
  UnitPrice,
  getFundHistory,
  type ObligationHistory,
  closeWithoutRefund,
  confirmPayment,
  listFeeUnits,
  paymentModeLabel,
  recordActualRefund,
  reversePayment
} from '@/api/sports/finance';
import FeeChoice from '@/components/business/FeeChoice.vue';
import { getSubmittedRoster, type SubmittedMember } from '@/api/sports/registration';
import InlineFeeEditor from '@/components/business/InlineFeeEditor.vue';

import { useRoute, useRouter } from 'vue-router';
import { getFundRecords, type FundRecords, type DeskContext } from '@/api/sports/desk';
const router = useRouter(),
  currentRoute = useRoute();
const goEntries = (row: UnitRow) => router.push({ path: '/org-desk/workspace/' + eventId.value, query: { task: 'registrations', unitId: row.id } });
const props = withDefaults(defineProps<{ eventKey?: string; mode?: string; eventStopped?: boolean; approvalClosed?: boolean; pricingLocked?: boolean }>(), {
  mode: 'registrations'
});
const context = inject<Ref<DeskContext | undefined>>('deskContext', ref());
const paymentAllowed = computed(() => Boolean(context.value?.payment));
const loading = ref(false),
  loadError = ref(''),
  selectedId = ref(String(currentRoute.query.unitId || 'all')),
  query = ref(''),
  statusFilter = ref(['submitted', 'declared', 'refund'].includes(String(useRoute().query.filter)) ? String(useRoute().query.filter) : 'submitted');
const detailVisible = ref(false),
  selectedEntry = ref<EntryCard>(),
  records = ref<FundRecords>(),
  recordsError = ref(''),
  recordsLoading = ref(false);
const fundHistory = ref<ObligationHistory[]>([]), fundObligationId = ref('');
const submittedMembers = ref<SubmittedMember[]>([]), rosterLoading = ref(false), rosterError = ref('');
const genderText = (value: string) => ({ male: '男', female: '女', other: '其他', unknown: '未说明', '1': '男', '2': '女' } as Record<string, string>)[value] || value || '未记录';
const loadRoster = async () => {
  const id = selectedEntry.value?.id; if (!id) return;
  submittedMembers.value = []; rosterError.value = ''; rosterLoading.value = true;
  try { const res = await getSubmittedRoster(id); if (selectedEntry.value?.id === id) submittedMembers.value = res.data; }
  catch { if (selectedEntry.value?.id === id) rosterError.value = '提交资料读取失败，请重试后再核对资格。'; }
  finally { if (selectedEntry.value?.id === id) rosterLoading.value = false; }
};
const selectedFund = computed(() => fundHistory.value.find(duty => duty.obligationId === fundObligationId.value));
const historyLabel = (duty: ObligationHistory) => {
  const version = duty.rosterRevision == null ? '原付款 · ' + businessTime(duty.createdAt) : '提交版本 ' + duty.rosterRevision;
  const state = ({ open: '待付款', settled: '已收款', void: '已关闭', not_required: '免费' } as Record<string,string>)[duty.status] || duty.status;
  return `${version} · ¥${duty.dueAmount} · ${state}${duty.current ? ' · 当前' : ''}${duty.pending ? ' · 有待办' : ''}`;
};
const filteredEntries = computed(() =>
  entries.value.filter(
    (e) =>
      (statusFilter.value === 'all' ||
        (statusFilter.value === 'declared'
          ? e.paymentDeclared && e.obligationStatus === 'open'
          : statusFilter.value === 'refund'
            ? Boolean(e.fundsPending || e.pendingActionId)
            : statusFilter.value === 'history' ? e.status === 'draft' && e.rosterRevision > 0 : e.status === statusFilter.value)) &&
      (!query.value || e.id.includes(query.value) || e.members.some((m) => m.legalName?.includes(query.value)))
  )
);
const chooseUnit = async () => {
  loading.value = true;
  loadError.value = '';
  try {
    if (selectedId.value === 'all') {
      const results = await Promise.all(units.value.map((u) => listUnitEntries(u.id)));
      entries.value = results.flatMap((r) => r.data);
    } else {
      const unit = units.value.find((u) => u.id === selectedId.value);
      if (unit) await openEntries(unit);
      else entries.value = [];
    }
  } catch {
    entries.value = [];
    loadError.value = '报名读取失败，请刷新重试。';
  } finally {
    loading.value = false;
  }
};
const reload = async () => {
  loading.value = true;
  loadError.value = '';
  try {
    await loadUnits();
    if (units.value.length) {
      selectedId.value = selectedId.value === 'all' || units.value.some((u) => u.id === selectedId.value) ? selectedId.value : 'all';
      await chooseUnit();
    }
  } catch {
    loadError.value = '项目或报名读取失败，请刷新重试。';
  } finally {
    loading.value = false;
  }
};
const loadHistory = async () => {
  const entry = selectedEntry.value;
  if (!paymentAllowed.value || !entry) return;
  recordsError.value = '';
  recordsLoading.value = true;
  try {
    const res = await getFundHistory(entry.id);
    if (selectedEntry.value?.id !== entry.id) return;
    fundHistory.value = res.data;
    if (!res.data.some(duty => duty.obligationId === fundObligationId.value))
      fundObligationId.value = (res.data.find(duty => duty.pending && !duty.current) || res.data.find(duty => duty.current))?.obligationId || '';
    await loadRecords();
  } catch {
    fundHistory.value = []; records.value = undefined;
    recordsError.value = '资金历史读取失败，请重试。';
  } finally { recordsLoading.value = false; }
};
const refreshFunds = async () => {
  if (selectedEntry.value) await refreshEntries(selectedEntry.value.unitId);
};
const loadRecords = async () => {
  records.value = undefined;
  recordsError.value = '';
  if (!paymentAllowed.value || !fundObligationId.value) return;
  const id = fundObligationId.value;
  recordsLoading.value = true;
  try {
    const res = await getFundRecords(id);
    if (fundObligationId.value === id) records.value = res.data;
  } catch {
    recordsError.value = '资金记录读取失败，请重试。';
  } finally {
    recordsLoading.value = false;
  }
};
const openDetail = async (e: EntryCard) => {
  fundHistory.value = []; fundObligationId.value = ''; records.value = undefined;
  selectedEntry.value = e;
  detailVisible.value = true;
  await Promise.all([loadHistory(), loadRoster()]);
};
type UnitRow = UnitCard & { amount: number | null; paymentMode: string | null; payInstruction: string | null; qrFileId: string | null };

const events = ref<ManagedEventOption[]>([]);
const eventId = ref('');
const units = ref<UnitRow[]>([]);
const selectedUnit = ref<UnitRow>();
const entries = ref<EntryCard[]>([]);
const creating = ref(false);
const createKey = ref('');
const createMark = ref('');
const form = reactive({
  name: '',
  entryType: 'individual',
  minMembers: 3,
  maxMembers: 5,
  limitCount: 16,
  charged: null as boolean | null,
  amount: undefined as number | undefined
});
const loadEvents = async () => {
  const res = await listRegistrationEvents();
  events.value = res.data;
};

const loadUnits = async () => {
  selectedUnit.value = undefined;
  entries.value = [];
  if (!eventId.value) {
    units.value = [];
    return;
  }
  const [unitRes, feeRes] = await Promise.all([
    listManagedUnits(eventId.value),
    paymentAllowed.value ? listFeeUnits(eventId.value) : Promise.resolve({ data: [] })
  ]);
  const fees = new Map((feeRes.data as UnitPrice[]).map((item) => [item.unitId, item]));
  units.value = (unitRes.data as UnitCard[]).map((unit) => {
    const fee = fees.get(unit.id);
    return {
      ...unit,
      amount: fee?.amount ?? null,
      paymentMode: fee?.paymentMode ?? null,
      payInstruction: fee?.payInstruction ?? null,
      qrFileId: fee?.qrFileId ?? null
    };
  });
};

const adjust = async (unit: UnitRow) => {
  try {
    const result = await ElMessageBox.prompt('新名额不能低于已经占用的 ' + unit.usedCount, '调整名额', {
      inputValue: String(unit.limitCount)
    });
    const limit = Number(result.value);
    if (!Number.isInteger(limit) || limit < 1) {
      ElMessage.warning('名额需要是不小于 1 的整数');
      return;
    }
    await adjustUnitLimit(unit.id, limit);
    ElMessage.success('已调整名额');
    await loadUnits();
  } catch {
    return;
  }
};

const priceReady = (charged: boolean | null, amount: number | undefined) => {
  if (charged == null) {
    ElMessage.warning('请先选择免费或收费。');
    return false;
  }
  if (charged && (!amount || amount <= 0)) {
    ElMessage.warning('请填写报名费');
    return false;
  }
  return true;
};

const createMarkOf = () =>
  [
    eventId.value,
    form.name,
    form.entryType,
    form.entryType === 'team' ? form.minMembers : '',
    form.entryType === 'team' ? form.maxMembers : '',
    form.limitCount,
    form.charged,
    form.charged ? form.amount : 0
  ].join('\n');

const editUnit = async (unit: UnitRow) => {
  editingUnit.value = unit;
  unitEdit.name = unit.name;
  unitEdit.entryType = unit.entryType;
  unitEdit.minMembers = unit.minMembers;
  unitEdit.maxMembers = unit.maxMembers;
  unitEditVisible.value = true;
};
const deleteUnit = async (unit: UnitRow) => {
  await ElMessageBox.confirm('只有无正式提交历史的项目可删除。旧草稿将不能继续提交。', '删除项目');
  await removeUnit(unit.id);
  await reload();
};
const editingUnit = ref<UnitRow>();
const unitEditVisible = ref(false);
const unitEdit = reactive({ name: '', entryType: 'individual', minMembers: 1, maxMembers: 1 });
const finishUnitEdit = async () => {
  if (!editingUnit.value || !unitEdit.name.trim()) return;
  const n = unitEdit.entryType === 'individual' ? 1 : unitEdit.entryType === 'pair' ? 2 : null;
  await updateUnit(editingUnit.value.id, { ...unitEdit, minMembers: n ?? unitEdit.minMembers, maxMembers: n ?? unitEdit.maxMembers });
  unitEditVisible.value = false;
  await reload();
};
const create = async () => {
  if (!form.name.trim() || units.value.some((u) => u.name.trim().toLowerCase() === form.name.trim().toLowerCase())) {
    ElMessage.warning('请填写本赛事内不重复的项目名称');
    return;
  }
  if (!priceReady(form.charged, form.amount)) {
    return;
  }
  const mark = createMarkOf();
  if (!createKey.value || createMark.value !== mark) {
    createKey.value = newRequestKey();
    createMark.value = mark;
  }
  creating.value = true;
  try {
    await createUnit({
      eventId: eventId.value,
      name: form.name,
      entryType: form.entryType,
      minMembers: form.entryType === 'team' ? form.minMembers : null,
      maxMembers: form.entryType === 'team' ? form.maxMembers : null,
      limitCount: form.limitCount,
      requestKey: createKey.value,
      charged: form.charged,
      amount: form.charged ? form.amount! : 0,
      paymentMode: form.charged ? 'event' : 'free',
      payInstruction: '',
      qrFileId: null
    });
    createKey.value = '';
    createMark.value = '';
    ElMessage.success('已建立竞赛项目');
    form.name = '';
  } finally {
    creating.value = false;
    await loadUnits();
  }
};

const nowText = () => {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23'
  }).formatToParts(new Date());
  const pick = (type: Intl.DateTimeFormatPartTypes) => parts.find((part) => part.type === type)?.value ?? '00';
  return `${pick('year')}-${pick('month')}-${pick('day')} ${pick('hour')}:${pick('minute')}:${pick('second')}`;
};

const receiptVisible = ref(false),
  receiptBusy = ref(false),
  receiptEntry = ref<EntryCard>(),
  receiptKey = ref('');
const extraReceipt = ref(false);
const receiptForm = reactive({ payer: '', amount: undefined as number | undefined, at: '', note: '' });
const receive = async (entry: EntryCard) => {
  receiptEntry.value = entry;
  receiptForm.payer = '';
  extraReceipt.value = entry.obligationStatus !== 'open';
  receiptForm.amount = extraReceipt.value ? undefined : Math.max(0.01, Number(entry.feeAmount || 0) - Number(records.value?.netAmount || 0));
  receiptForm.at = '';
  receiptForm.note = '';
  receiptKey.value = newRequestKey();
  receiptVisible.value = true;
};
const finishReceipt = async () => {
  if (receiptBusy.value) return;
  if (!receiptEntry.value?.obligationId || !receiptForm.payer.trim() || !receiptForm.at || !receiptForm.amount || receiptForm.amount <= 0) {
    ElMessage.warning('请填写实际付款人、金额和到账时间');
    return;
  }
  if (extraReceipt.value && !receiptForm.note.trim()) { ElMessage.warning('请填写补记原因，确认是另一笔实际收款'); return; }
  receiptBusy.value = true;
  try {
    const duplicate = records.value?.receipts.some(r => r.status === 'confirmed' && r.payerName === receiptForm.payer.trim() && Number(r.amount) === receiptForm.amount && Date.parse(r.occurredAt) === Date.parse(receiptForm.at.replace(' ', 'T') + '+08:00'));
    if (extraReceipt.value || duplicate) {
      try { await ElMessageBox.confirm(duplicate ? '已有付款人、金额和时间相同的到账，请核对是否重复。同一笔款不能再次登记。确为另一笔实际收款才继续。' : '此报名已足额或付款义务已关闭。确认这是一笔尚未登记的其他实际收款？', '核对实际收款', { confirmButtonText: '确为其他实际收款', cancelButtonText: '返回核对' }); }
      catch { return; }
    }
    const beforeStatus = receiptEntry.value.status;
    await confirmPayment(
      receiptEntry.value.obligationId,
      receiptForm.payer.trim(),
      receiptForm.amount,
      receiptForm.at,
      receiptForm.note,
      receiptKey.value
    );
    receiptVisible.value = false;
    await refreshEntries(receiptEntry.value.unitId);
    ElMessage.success(beforeStatus !== 'approved' && selectedEntry.value?.status === 'approved' ? '实际到账已登记，报名已自动通过' : '实际到账已登记，请查看资格审核与资金进度');
  } catch {
    // 请求层已提示失败。保留表单与请求键，便于核对后安全重试。
  } finally {
    receiptBusy.value = false;
  }
};
const reverse = async (entry: EntryCard, paymentId?: string) => {
  const originalObligationId = fundObligationId.value;
  if (!originalObligationId || !paymentId) {
    return;
  }
  try {
    await ElMessageBox.confirm('只用于纠正这笔错误到账记录，保留原记录。它不表示已经退钱；已有参赛资格、报到或场次请另外协调。', '撤销错误到账记录');
  } catch {
    return;
  }
  await reversePayment(originalObligationId, newRequestKey(), paymentId);
  ElMessage.success('已撤销错误到账记录');
  await refreshEntries(entry.unitId);
};

type ReceiptRecord = FundRecords['receipts'][number];
const refundVisible = ref(false),
  refundBusy = ref(false),
  refundReceipt = ref<ReceiptRecord>();
const refundForm = reactive({ amount: 0.01, occurredAt: '', recipientName: '', recipientBasis: '', note: '', requestKey: '' });
const openRefund = (r: ReceiptRecord) => {
  refundReceipt.value = r;
  Object.assign(refundForm, {
    amount: Number(r.amount) - Number(r.refundedAmount || 0),
    occurredAt: '',
    recipientName: r.payerName || '',
    recipientBasis: '',
    note: '',
    requestKey: newRequestKey()
  });
  refundVisible.value = true;
};
const finishRefund = async () => {
  if (
    refundBusy.value ||
    !refundReceipt.value?.pendingActionId ||
    !refundForm.occurredAt ||
    !refundForm.recipientName.trim() ||
    !refundForm.note.trim() ||
    refundForm.amount <= 0
  ) {
    ElMessage.warning('请填写实际退款金额、时间、接收人和依据');
    return;
  }
  refundBusy.value = true;
  try {
    await recordActualRefund(refundReceipt.value.pendingActionId, { ...refundForm });
    refundVisible.value = false;
    ElMessage.success('实际退款已登记，剩余款项仍需按政策处理');
    if (selectedEntry.value) await refreshEntries(selectedEntry.value.unitId);
  } finally {
    refundBusy.value = false;
  }
};

const noRefund = async (entry: EntryCard, actionId: string) => {
  if (!actionId) {
    return;
  }
  let note = '';
  try {
    const result = await ElMessageBox.prompt('按原退改依据填写无需退款的原因，不以取消赛事自动结案。', '无需退款结案', {
      inputValidator: (v) => Boolean(v?.trim()) || '请填写结案原因'
    });
    note = result.value;
  } catch {
    return;
  }
  await closeWithoutRefund(actionId, note);
  ElMessage.success('已登记无需退款');
  await refreshEntries(entry.unitId);
};

const openEntries = async (unit: UnitRow) => {
  selectedUnit.value = unit;
  const res = await listUnitEntries(unit.id);
  entries.value = res.data;
};

const canApprove = (entry: EntryCard) =>
  entry.status === 'submitted' && (entry.obligationStatus === 'not_required' || entry.obligationStatus === 'settled' || entry.paymentMode === 'free');

const approve = async (entry: EntryCard) => {
  const unitId = entry.unitId;
  await approveEntry(entry.id);
  ElMessage.success('已通过');
  await refreshEntries(unitId);
};

const reject = async (entry: EntryCard) => {
  try {
    const result = await ElMessageBox.prompt('拒绝只处理资格与名额，不自动退款。已到账或随后到账的真实款项仍须核对收尾。请填写拒绝原因', '拒绝报名');
    const unitId = entry.unitId;
    await rejectEntry(entry.id, result.value);
    ElMessage.success('已拒绝，名额已释放');
    await refreshEntries(unitId);
  } catch {
    return;
  }
};

const refreshEntries = async (_unitId: string) => {
  const id = selectedEntry.value?.id;
  await reload();
  if (id) {
    selectedEntry.value = entries.value.find((e) => e.id === id);
    await loadHistory();
  }
};

onMounted(async () => {
  if (props.eventKey) {
    eventId.value = props.eventKey;
    await reload();
  } else await loadEvents();
});
// 点击左侧内容可收起详情；资金表单和确认框办理期间保留上下文。
const closeDetailOutside = (event: MouseEvent) => {
  if (!detailVisible.value || receiptVisible.value || refundVisible.value || receiptBusy.value || refundBusy.value) return;
  const target = event.target as HTMLElement;
  if (!target.closest('.el-drawer, .el-dialog, .el-message-box, .el-popper, .el-overlay, .el-button')) detailVisible.value = false;
};
watch(() => currentRoute.fullPath, () => { detailVisible.value = false; });
onMounted(() => document.addEventListener('click', closeDetailOutside));
onUnmounted(() => document.removeEventListener('click', closeDetailOutside));
</script>

<style scoped>
.member {
  display: inline-block;
  margin-right: 12px;
}
.fund-history { display: grid; gap: 8px; margin-bottom: 16px; }
.fund-history label { font-weight: 600; }
.fund-history .el-select { width: 100%; }
.fund-history p { margin: 0; }
</style>
