<template>
  <section v-if="exceptions.length" class="fund-exceptions" aria-labelledby="fund-exceptions-title">
    <div class="b-heading"><div><h3 id="fund-exceptions-title">需要核对的收款记录</h3><p>核对异常不改变原收款、退款或报名资格。</p></div></div>
    <article v-for="row in exceptions" :key="row.exceptionId" class="b-record">
      <div class="exception-heading"><strong>{{ row.exceptionType === 'duplicate_payment' ? '重复请求与原收款不一致' : '其他收款异常' }}</strong><el-tag :type="row.status === 'resolved' ? 'success' : 'warning'">{{ row.status === 'resolved' ? '已核对结案' : '待人工核对' }}</el-tag></div>
      <p>本次申报 ¥{{ row.reportedAmount ?? '—' }} · 对应原收款 {{ row.paymentId || '未关联' }}</p>
      <template v-if="row.status === 'resolved'"><p>{{ row.resolutionNote || '旧记录未填写核对说明' }}</p><p class="b-muted">核对时间 {{ businessTime(row.resolvedAt) }} · 责任岗位 {{ row.responsibleUserId || '旧记录未采集' }}</p></template>
      <el-button v-else-if="row.exceptionType === 'duplicate_payment'" :disabled="busy" @click="open(row)">核对后结案</el-button>
      <p v-else class="b-muted">此类异常请联系平台核实，当前入口不能直接结案。</p>
    </article>
    <el-dialog v-model="visible" title="核对重复收款请求" width="520px" class="b-dialog" :close-on-click-modal="!busy" :close-on-press-escape="!busy" :show-close="!busy" @closed="closed">
      <p>先核对实际账本与原收款，说明本次重复请求不一致的原因和处理依据。结案只关闭这条异常，不登记到账、不划拨资金，也不代替退款。</p>
      <el-form label-position="top" @submit.prevent="submit"><el-form-item label="实际核对依据与处理说明" required :error="error"><el-input v-model="note" type="textarea" :rows="4" maxlength="1000" show-word-limit :disabled="busy" aria-label="实际核对依据与处理说明" placeholder="填写原记录、本次差异、实际核对结果和责任人处理依据" /></el-form-item></el-form>
      <template #footer><el-button :disabled="busy" @click="visible=false">继续核对</el-button><el-button type="primary" :loading="busy" :disabled="!note.trim()" @click="submit">确认核对并结案</el-button></template>
    </el-dialog>
  </section>
</template>
<script setup lang="ts">
import { ref, watch } from 'vue';
import { ElMessage } from 'element-plus';
import { businessTime } from '@/utils/business';
import { newRequestKey } from '@/utils/requestKey';
import { resolvePaymentException, type PaymentExceptionRecord } from '@/api/sports/finance';
const props = withDefaults(defineProps<{ obligationId: string; exceptions?: PaymentExceptionRecord[] }>(), { exceptions: () => [] });
const emit = defineEmits<{ resolved: [] }>();
const visible = ref(false), busy = ref(false), error = ref(''), note = ref('');
const selected = ref<PaymentExceptionRecord>(), requestKey = ref('');
const open = (row: PaymentExceptionRecord) => { if (busy.value) return; selected.value=row; note.value=''; error.value=''; requestKey.value=newRequestKey(); visible.value=true; };
const closed = () => { if (!busy.value) { selected.value=undefined; note.value=''; error.value=''; } };
watch(() => props.obligationId, () => { if (!busy.value) visible.value=false; });
const submit = async () => {
  if (busy.value || !selected.value || !note.value.trim()) return;
  busy.value=true; error.value=''; const obligationId=props.obligationId;
  try { await resolvePaymentException(obligationId, selected.value.exceptionId, { note: note.value.trim(), expectedVersion: selected.value.version, requestKey: requestKey.value }); visible.value=false; ElMessage.success('核对说明已保存，原资金记录继续保留'); emit('resolved'); }
  catch (cause) { error.value=cause instanceof Error ? cause.message : '结案未完成，请保留说明，核对最新记录后重试'; }
  finally { busy.value=false; }
};
</script>
<style scoped>
.fund-exceptions { margin-top:24px; border-top:1px solid var(--sport-line,#e1e0da); padding-top:20px; }
.fund-exceptions h3 { margin:0; font-size:17px; }.exception-heading { display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap; }.fund-exceptions p { overflow-wrap:anywhere; }.fund-exceptions :deep(.el-textarea) { width:100%; }
</style>
