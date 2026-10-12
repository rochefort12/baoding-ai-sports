<template>
  <section class="b-panel b-event-payment">
    <div class="b-toolbar"><div><h3>赛事统一收款</h3><p class="b-muted">一次设置，所有收费项目共用。项目中只填写免费或收费及金额。</p></div></div>
    <p v-if="!allowed" class="b-muted">需有资金办理权限的工作人员配置收款渠道。</p>
    <template v-else>
      <el-alert v-if="error" :title="error" type="error" :closable="false"><el-button text @click="load">重新读取</el-button></el-alert>
      <p v-if="locked" class="b-muted">已有正式报名或赛事已停止办理，收款设置已锁定。已提交报名使用当次保存的付款指引。</p>
      <div v-loading="loading" class="b-payment-channel-list">
        <article v-for="option in options" :key="option.type" class="b-payment-channel" :class="{selected: selected.includes(option.type)}">
          <el-checkbox :model-value="selected.includes(option.type)" :disabled="disabled" @change="toggle(option.type)"><strong>{{ option.label }}</strong></el-checkbox>
          <template v-if="selected.includes(option.type)">
            <template v-if="option.qr">
              <el-input v-if="option.type === 'custom_qr'" v-model="channels[option.type].label" placeholder="例如：俱乐部收款码" maxlength="40" :disabled="disabled" aria-label="自定义收款码名称" />
              <img v-if="previews[option.type]" :src="previews[option.type]" :alt="option.label + '收款码'" class="b-payment-qr" />
              <p v-else-if="channels[option.type].qrFileId" class="b-muted">已上传收款码{{ previewErrors[option.type] ? '，预览读取失败，已有文件保留。' : '' }}</p>
              <label v-if="!locked" class="b-payment-upload">{{ channels[option.type].qrFileId ? '更换二维码' : '上传二维码' }}<input type="file" accept="image/png,image/jpeg,image/webp" :disabled="disabled" :aria-label="option.label + '收款码'" @change="upload($event, option.type)" /></label>
            </template>
            <template v-if="option.type === 'bank'">
              <el-input v-model="channels.bank.accountName" placeholder="开户名" maxlength="100" :disabled="disabled" aria-label="银行开户名" />
              <el-input v-model="channels.bank.bankName" placeholder="开户行（含支行）" maxlength="200" :disabled="disabled" aria-label="银行开户行" />
              <el-input v-model="channels.bank.bankAccount" placeholder="银行账号" maxlength="100" :disabled="disabled" aria-label="银行账号" />
            </template>
            <el-input v-model="channels[option.type].instruction" :placeholder="option.type === 'offline' ? '付款地点或联系办理方式（必填）' : '此渠道的补充说明（选填）'" maxlength="500" :disabled="disabled" :aria-label="option.label + '付款说明'" />
          </template>
        </article>
      </div>
      <p class="b-muted">二维码支持 JPG、PNG、WebP，单张最多5MB。参赛者可任选已启用的渠道付款。</p>
      <el-input v-model="instruction" type="textarea" :rows="2" maxlength="1000" placeholder="统一付款说明（选填），例如转账请备注参赛者姓名和项目" :disabled="disabled" aria-label="赛事统一付款说明" />
      <div class="b-actions"><el-button v-if="!locked" type="primary" :disabled="disabled" :loading="saving || uploading" @click="save">保存赛事收款设置</el-button><span class="b-muted">收款码和账户信息仅用于报名付款；上传凭证不代表实际到账。</span></div>
    </template>
  </section>
</template>
<script setup lang="ts">
import {computed, inject, onBeforeUnmount, reactive, ref, watch, type Ref} from 'vue';
import {ElMessage} from 'element-plus';
import type {DeskContext} from '@/api/sports/desk';
import {getEventPaymentConfig, saveEventPaymentConfig, eventPaymentQrBlob, type PaymentChannel, type PaymentChannelType} from '@/api/sports/finance';
import {uploadOrganizerImage} from '@/api/sports/media';
const props = defineProps<{eventKey: string; locked?: boolean}>();
const options = [{type: 'wechat', label: '微信', qr: true}, {type: 'alipay', label: '支付宝', qr: true}, {type: 'bank', label: '银行转账', qr: false}, {type: 'custom_qr', label: '自定义收款码', qr: true}, {type: 'offline', label: '线下付款', qr: false}] as const;
const context = inject<Ref<DeskContext | undefined>>('deskContext', ref());
const allowed = computed(() => Boolean(context.value?.payment));
const selected = ref<PaymentChannelType[]>([]), instruction = ref(''), revision = ref(0), loading = ref(false), saving = ref(false), uploading = ref(false), error = ref('');
const disabled = computed(() => props.locked || loading.value || saving.value || uploading.value || Boolean(error.value));
const channels = reactive(Object.fromEntries(options.map(o => [o.type, {type: o.type, label: o.label, qrFileId: null, accountName: '', bankName: '', bankAccount: '', instruction: ''}])) as Record<PaymentChannelType, PaymentChannel>);
const previews = reactive<Partial<Record<PaymentChannelType, string>>>({}), previewErrors = reactive<Partial<Record<PaymentChannelType, boolean>>>({});
const toggle = (type: PaymentChannelType) => {if (!disabled.value) selected.value = selected.value.includes(type) ? selected.value.filter(c => c !== type) : [...selected.value, type];};
let epoch = 0;
const clear = () => {for (const option of options) {if (previews[option.type]) URL.revokeObjectURL(previews[option.type]!); delete previews[option.type]; delete previewErrors[option.type];}};
const load = async () => {
  const id = props.eventKey, version = ++epoch;
  clear(); selected.value = []; instruction.value = ''; revision.value = 0; error.value = '';
  for (const option of options) Object.assign(channels[option.type], {type: option.type, label: option.label, qrFileId: null, accountName: '', bankName: '', bankAccount: '', instruction: ''});
  if (!allowed.value || !id) return;
  loading.value = true;
  try {
    const res = await getEventPaymentConfig(id);
    if (version !== epoch) return;
    revision.value = res.data.revision; instruction.value = res.data.instruction; selected.value = res.data.channels.map(c => c.type);
    for (const channel of res.data.channels) Object.assign(channels[channel.type], channel);
    await Promise.all(res.data.channels.filter(c => c.qrFileId).map(async channel => {
      try {const blob = await eventPaymentQrBlob(id, channel.type) as unknown as Blob; if (version === epoch) previews[channel.type] = URL.createObjectURL(blob);}
      catch {if (version === epoch) previewErrors[channel.type] = true;}
    }));
  } catch {if (version === epoch) error.value = '赛事收款设置读取失败，请重试；不会用空值覆盖已有设置。';}
  finally {if (version === epoch) loading.value = false;}
};
const upload = async (event: Event, type: PaymentChannelType) => {
  const input = event.target as HTMLInputElement, file = input.files?.[0]; input.value = '';
  if (!file || disabled.value) return;
  if (file.size > 5 * 1024 * 1024) {ElMessage.warning('收款码图片最多5MB'); return;}
  const version = epoch; uploading.value = true;
  try {const res = await uploadOrganizerImage('payment-qr', file); if (version !== epoch) return; channels[type].qrFileId = res.data.fileId; if (previews[type]) URL.revokeObjectURL(previews[type]!); previews[type] = URL.createObjectURL(file); delete previewErrors[type];}
  finally {uploading.value = false;}
};
const save = async () => {
  if (disabled.value) return;
  const picked = selected.value.map(type => ({...channels[type]}));
  if (picked.some(c => ['wechat', 'alipay', 'custom_qr'].includes(c.type) && !c.qrFileId)) {ElMessage.warning('请为已选择的二维码渠道上传收款码'); return;}
  if (picked.some(c => c.type === 'bank' && (!c.accountName?.trim() || !c.bankName?.trim() || !c.bankAccount?.trim()))) {ElMessage.warning('请填写银行开户名、开户行和账号'); return;}
  if (picked.some(c => c.type === 'offline' && !c.instruction.trim())) {ElMessage.warning('请填写线下付款的地点或联系办理方式'); return;}
  const version = epoch; saving.value = true;
  try {const res = await saveEventPaymentConfig(props.eventKey, {revision: revision.value, instruction: instruction.value, channels: picked}); if (version === epoch) {revision.value = res.data.revision; ElMessage.success('已保存赛事统一收款设置');}}
  finally {saving.value = false;}
};
watch(() => [props.eventKey, allowed.value], load, {immediate: true});
onBeforeUnmount(() => {epoch++; clear();});
</script>
