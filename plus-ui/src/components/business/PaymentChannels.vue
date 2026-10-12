<template>
  <div class="b-payment-instructions">
    <p v-if="loading">正在读取本次报名的付款指引…</p>
    <el-alert v-else-if="error" :title="error" type="error" :closable="false"><el-button text @click="load">重试</el-button></el-alert>
    <template v-else-if="settings">
      <p v-if="settings.instruction">{{ settings.instruction }}</p>
      <p v-if="settings.channels.length > 1" class="consumer-muted">选择一种方式付款即可。</p>
      <div class="b-payment-channel-tabs" role="group" aria-label="选择付款方式"><el-button v-for="channel in settings.channels" :key="channel.type" :type="selected === channel.type ? 'primary' : 'default'" @click="selected = channel.type">{{ channel.label }}</el-button></div>
      <section v-if="active" class="b-payment-channel-detail">
        <p v-if="active.type === 'bank'">开户名：{{ active.accountName }}<br />开户行：{{ active.bankName }}<br />账号：{{ active.bankAccount }}</p>
        <img v-if="qrUrl" :src="qrUrl" :alt="active.label + '收款码'" class="b-payment-qr" />
        <p v-else-if="active.qrFileId">{{ qrLoading ? '正在读取收款码…' : '收款码读取失败' }}<el-button v-if="!qrLoading" text @click="loadQr">重试</el-button></p>
        <p v-if="active.instruction">{{ active.instruction }}</p>
      </section>
    </template>
  </div>
</template>
<script setup lang="ts">
import {computed, onBeforeUnmount, ref, watch} from 'vue';
import {getPaymentInstructions, paymentChannelQrBlob, type PaymentSettings, type PaymentChannelType} from '@/api/sports/finance';
const props = defineProps<{registrationId: string}>();
const settings = ref<PaymentSettings>(), selected = ref<PaymentChannelType>(), loading = ref(false), error = ref(''), qrUrl = ref(''), qrLoading = ref(false);
const active = computed(() => settings.value?.channels.find(c => c.type === selected.value));
let epoch = 0, qrEpoch = 0;
const clearQr = () => {qrEpoch++; if (qrUrl.value) URL.revokeObjectURL(qrUrl.value); qrUrl.value = '';};
const load = async () => {
  const id = props.registrationId, version = ++epoch; clearQr(); settings.value = undefined; selected.value = undefined; loading.value = true; error.value = '';
  try {const res = await getPaymentInstructions(id); if (version !== epoch) return; settings.value = res.data; selected.value = res.data.channels[0]?.type;}
  catch {if (version === epoch) error.value = '本次报名的付款指引读取失败，请重试或联系承办方。';}
  finally {if (version === epoch) loading.value = false;}
};
const loadQr = async () => {
  clearQr(); const channel = active.value, version = qrEpoch, id = props.registrationId;
  qrLoading.value = false; if (!channel?.qrFileId) return; qrLoading.value = true;
  try {const blob = await paymentChannelQrBlob(id, channel.type) as unknown as Blob; if (version === qrEpoch) qrUrl.value = URL.createObjectURL(blob);}
  catch { /* 保留当前渠道及重试入口，不换到其他报名的图片。 */ }
  finally {if (version === qrEpoch) qrLoading.value = false;}
};
watch(() => props.registrationId, load, {immediate: true});
watch(selected, loadQr);
onBeforeUnmount(() => {epoch++; clearQr();});
</script>
