<template>
  <div class="app-container product-admin">
    <el-card shadow="never">
      <template #header>收费记账</template>
      <p>项目只设置金额，收款渠道统一由赛事配置。收费报名需实际足额到账才可通过。</p>
      <el-form label-position="top">
        <el-form-item label="赛事">
          <el-select v-model="eventId" placeholder="选择赛事" @change="loadUnits">
            <el-option v-for="event in events" :key="event.eventId" :label="event.name || '未命名赛事'" :value="event.eventId" />
          </el-select>
        </el-form-item>
      </el-form>
      <el-table :data="units">
        <el-table-column prop="unitName" label="项目" />
        <el-table-column label="费用" min-width="200">
          <template #default="{ row }">
            <InlineFeeEditor :unit-id="row.unitId" :payment-mode="row.paymentMode" :amount="row.amount" @saved="loadUnits" />
          </template>
        </el-table-column>
        <el-table-column label="操作" width="120">
          <template #default="{ row }">
            <el-button link @click="openPayments(row)">报名付款</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <section v-if="eventId" class="b-panel"><h3>赛事统一收款</h3><p>微信、支付宝、银行、自定义收款码和线下付款在赛事设置中统一维护。</p><router-link :to="{path: '/org-desk/workspace/' + eventId, query: {task: 'fields'}}"><el-button>前往赛事收款设置</el-button></router-link></section>

    <el-dialog v-model="paymentVisible" title="报名付款" width="980px">
      <p v-if="!obligations.length">还没有提交后的报名付款。</p>
      <el-table v-else :data="obligations">
        <el-table-column prop="registrationId" label="报名编号" min-width="170" />
        <el-table-column label="报名" width="90">
          <template #default="{ row }">{{ entryStatusLabel(row.registrationStatus) }}</template>
        </el-table-column>
        <el-table-column label="应付金额" width="100">
          <template #default="{ row }">¥{{ row.amount }}</template>
        </el-table-column>
        <el-table-column label="付款方式" width="130">
          <template #default="{ row }">{{ paymentModeLabel(row.paymentMode) }}</template>
        </el-table-column>
        <el-table-column label="付款状态" width="90">
          <template #default="{ row }">{{ paymentDisplay(row) }}</template>
        </el-table-column>
        <el-table-column prop="payerName" label="实际付款人" min-width="110" />
        <el-table-column prop="paidAt" label="到账时间" width="140" />
        <el-table-column prop="confirmerName" label="确认人" width="120" />
        <el-table-column label="操作" min-width="220">
          <template #default="{ row }">
            <el-button v-if="row.obligationStatus === 'open'" link type="primary" @click="openConfirm(row)">确认已到账</el-button>
            <el-button link @click="openRecords(row)">凭证与收款明细</el-button>
            <el-button v-if="row.actionStatus === 'pending'" link @click="noRefund(row)">无需退款</el-button>
            <el-button v-if="row.actionStatus === 'pending'" link type="primary" @click="openRecords(row)">办理实际退款</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-dialog>

    <el-dialog v-model="recordsVisible" title="凭证与收款明细" width="600px" destroy-on-close>
      <template v-if="recordEntry">
        <PaymentProofPanel :registration-id="recordEntry.registrationId" organizer />
        <p v-if="records">应付 ¥{{ records.dueAmount }} · 净有效实收 ¥{{ records.netAmount }}</p>
        <article v-for="receipt in records?.receipts || []" :key="receipt.paymentId" class="b-record">
          <p>{{ receipt.payerName }} · ¥{{ receipt.amount }} · {{ receipt.occurredAt }} · {{ receipt.status === 'reversed' ? '已撤销错误到账' : '已核对' }}</p>
          <p>累计实际退款 ¥{{ receipt.refundedAmount }}</p>
          <el-button v-if="receipt.status === 'confirmed' && !Number(receipt.refundedAmount)" link @click="reverseReceipt(receipt)">撤销此笔错误到账</el-button>
          <el-button v-if="receipt.pendingActionId" link @click="openRefund(receipt)">登记此笔实际退款</el-button>
        </article>
        <p v-if="records && !records.receipts.length">暂无实际收款。</p>
        <PaymentExceptionPanel v-if="records" :key="recordEntry.obligationId" :obligation-id="recordEntry.obligationId" :exceptions="records.exceptions || []" @resolved="openRecords(recordEntry)" />
      </template>
    </el-dialog>
    <el-dialog v-model="refundVisible" title="登记实际退款" width="520px">
      <p>仅登记已经实际发生的退款，累计金额不能超过这笔原收款。</p>
      <el-form label-position="top">
        <el-form-item label="实际退款金额"><el-input-number v-model="refundForm.amount" :min="0.01" :max="refundMaximum" :precision="2" /></el-form-item>
        <el-form-item label="实际退款时间（北京时间）"><el-date-picker v-model="refundForm.occurredAt" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" /></el-form-item>
        <el-form-item label="接收人"><el-input v-model="refundForm.recipientName" maxlength="200" /></el-form-item>
        <el-form-item label="收款人核对依据"><el-input v-model="refundForm.recipientBasis" maxlength="1000" /></el-form-item>
        <el-form-item label="退款原因"><el-input v-model="refundForm.note" maxlength="1000" /></el-form-item>
      </el-form>
      <template #footer><el-button :loading="refundBusy" type="primary" @click="submitRefund">登记实际退款</el-button></template>
    </el-dialog>
    <el-dialog v-model="confirmVisible" title="确认已到账" width="520px">
      <el-form label-position="top">
        <el-form-item label="实际付款人">
          <el-input v-model="confirmForm.payerName" maxlength="200" placeholder="可以不是参赛者本人" />
        </el-form-item>
        <el-form-item label="实际到账金额">
          <el-input-number v-model="confirmForm.amount" :min="0" :precision="2" />
        </el-form-item>
        <el-form-item label="到账时间">
          <el-date-picker v-model="confirmForm.occurredAt" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="confirmForm.note" type="textarea" maxlength="1000" />
        </el-form-item>
        <el-button type="primary" :loading="confirmBusy" @click="submitConfirm">确认已到账</el-button>
      </el-form>
    </el-dialog>
  </div>
</template>

<script setup lang="ts" name="FeeDesk">
import PaymentProofPanel from '@/components/business/PaymentProofPanel.vue';
import PaymentExceptionPanel from '@/components/business/PaymentExceptionPanel.vue';
import { onMounted, reactive, ref } from 'vue';
import { newRequestKey } from '@/utils/requestKey';
import { ElMessage, ElMessageBox } from 'element-plus';
import { entryStatusLabel } from '@/api/sports/registration';
import InlineFeeEditor from '@/components/business/InlineFeeEditor.vue';
import {
  FeeEvent,
  ObligationCard,
  UnitPrice,
  closeWithoutRefund,
  confirmPayment,
  listFeeEvents,
  listFeeUnits,
  listObligations,
  paymentDisplay,
  paymentModeLabel,
  fundRecords,
  recordActualRefund,
  type FundRecords,
  type ReceiptRecord,
  reversePayment
} from '@/api/sports/finance';

const events = ref<FeeEvent[]>([]);
const recordsVisible = ref(false), records = ref<FundRecords>(), recordEntry = ref<ObligationCard>();
const confirmBusy = ref(false), confirmKey = ref(''), refundBusy = ref(false), refundVisible = ref(false), refundMaximum = ref(0);
const refundReceipt = ref<ReceiptRecord>();
const refundForm = reactive({ amount: 0, occurredAt: '', recipientName: '', recipientBasis: '', note: '', requestKey: '' });
const openRecords = async (row: ObligationCard) => {
  records.value = undefined; recordEntry.value = row;
  records.value = (await fundRecords(row.obligationId)).data;
  recordsVisible.value = true;
};
const reverseReceipt = async (receipt: ReceiptRecord) => {
  if (!recordEntry.value) return;
  const confirmed = await ElMessageBox.confirm('仅撤销此笔记错的到账。实际退款请登记退款。', '撤销错误到账').then(() => true).catch(() => false);
  if (!confirmed) return;
  await reversePayment(recordEntry.value.obligationId, newRequestKey(), receipt.paymentId);
  await openRecords(recordEntry.value); await reloadPayments();
};
const openRefund = (receipt: ReceiptRecord) => {
  refundReceipt.value = receipt;
  refundMaximum.value = Number(receipt.amount) - Number(receipt.refundedAmount);
  Object.assign(refundForm, { amount: refundMaximum.value, occurredAt: nowText(), recipientName: '', recipientBasis: '', note: '', requestKey: newRequestKey() });
  refundVisible.value = true;
};
const submitRefund = async () => {
  if (refundBusy.value || !refundReceipt.value?.pendingActionId || !recordEntry.value) return;
  if (!refundForm.recipientName.trim() || !refundForm.note.trim() || !refundForm.occurredAt || refundForm.amount <= 0 || refundForm.amount > refundMaximum.value) {
    ElMessage.warning('请填写退款金额、时间、接收人和原因'); return;
  }
  refundBusy.value = true;
  try { await recordActualRefund(refundReceipt.value.pendingActionId, { ...refundForm }); refundVisible.value = false;
    await openRecords(recordEntry.value); await reloadPayments(); }
  finally { refundBusy.value = false; }
};
const units = ref<UnitPrice[]>([]);
const obligations = ref<ObligationCard[]>([]);
const eventId = ref('');
const paymentVisible = ref(false);
const confirmVisible = ref(false);
const currentUnit = ref<UnitPrice>();
const currentPayment = ref<ObligationCard>();
const confirmForm = reactive({ payerName: '', amount: 0, occurredAt: '', note: '' });

const loadUnits = async () => {
  if (!eventId.value) {
    units.value = [];
    return;
  }
  const res = await listFeeUnits(eventId.value);
  units.value = res.data;
};

const openPayments = async (row: UnitPrice) => {
  currentUnit.value = row;
  const res = await listObligations(row.unitId);
  obligations.value = res.data;
  paymentVisible.value = true;
};

const reloadPayments = async () => {
  if (!currentUnit.value) {
    return;
  }
  const res = await listObligations(currentUnit.value.unitId);
  obligations.value = res.data;
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

const openConfirm = async (row: ObligationCard) => {
  const actual = (await fundRecords(row.obligationId)).data as FundRecords;
  currentPayment.value = row;
  confirmForm.payerName = '';
  confirmForm.amount = Math.max(0.01, Number(actual.dueAmount) - Number(actual.netAmount));
  confirmForm.occurredAt = nowText();
  confirmForm.note = '';
  confirmKey.value = newRequestKey();
  confirmVisible.value = true;
};

const submitConfirm = async () => {
  if (!currentPayment.value || confirmBusy.value) {
    return;
  }
  if (!confirmForm.payerName.trim() || !confirmForm.occurredAt || confirmForm.amount <= 0) {
    ElMessage.warning('请填写实际付款人、正金额和到账时间');
    return;
  }
  confirmBusy.value = true;
  try { await confirmPayment(
    currentPayment.value.obligationId,
    confirmForm.payerName.trim(),
    confirmForm.amount,
    confirmForm.occurredAt,
    confirmForm.note,
    confirmKey.value
  );
  ElMessage.success('已确认到账');
  confirmVisible.value = false;
  await reloadPayments();
  } finally { confirmBusy.value = false; }
};

const noRefund = async (row: ObligationCard) => {
  if (!row.actionId) {
    return;
  }
  await closeWithoutRefund(row.actionId);
  ElMessage.success('已记录无需退款');
  await reloadPayments();
};


onMounted(async () => {
  const res = await listFeeEvents();
  events.value = res.data;
});
</script>
