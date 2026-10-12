<template>
  <section class="payment-proof-panel" v-loading="loading">
    <p><strong>付款凭证 / 回执</strong></p>
    <p v-if="!organizer">强烈推荐上传付款凭证，便于承办方核对；平台不强制上传。凭证不代表到账或报名成功。</p>
    <p v-else>凭证由报名管理人上传，请与实际收款记录核对。上传凭证不是到账确认。</p>
    <el-upload v-if="!organizer && editable" :auto-upload="false" :show-file-list="false" accept="image/png,image/jpeg,image/webp" :on-change="choose" :disabled="uploading">
      <el-button :loading="uploading" :disabled="items.length >= 5">上传凭证（选填）</el-button>
      <template #tip><span>JPG、PNG、WebP，每张不超过 5MB，最多 5 张。</span></template>
    </el-upload>
    <p v-if="error" role="alert">{{ error }} <el-button link @click="load">重新加载</el-button></p>
    <p v-else-if="!items.length && !loading">尚未上传凭证。</p>
    <div class="payment-proof-images">
      <figure v-for="item in items" :key="item.id">
        <el-image v-if="item.url" :src="item.url" :preview-src-list="urls" fit="contain" :alt="'付款凭证 ' + item.id" />
        <figcaption>{{ item.uploadedAt.replace('T', ' ').slice(0, 19) }}</figcaption>
      </figure>
    </div>
  </section>
</template>
<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { ElMessage } from 'element-plus';
import type { UploadFile } from 'element-plus';
import { listPaymentProofs, paymentProofImage, uploadPaymentProof, type PaymentProof } from '@/api/sports/registration';
import { newRequestKey } from '@/utils/requestKey';
const props = withDefaults(defineProps<{ registrationId: string; organizer?: boolean; editable?: boolean }>(), { organizer: false, editable: false });
const items = ref<(PaymentProof & { url: string })[]>([]), loading = ref(false), uploading = ref(false), error = ref('');
const urls = computed(() => items.value.map(item => item.url).filter(Boolean));
let epoch = 0;
const release = () => { items.value.forEach(item => URL.revokeObjectURL(item.url)); items.value = []; };
const load = async () => {
  const current = ++epoch, id = props.registrationId, organizer = props.organizer;
  release(); error.value = ''; loading.value = true;
  try {
    const result = await listPaymentProofs(id, organizer);
    let incomplete = false;
    const next = await Promise.all((result.data as PaymentProof[]).map(async item => {
      try {
        const blob = await paymentProofImage(id, item.id, organizer) as unknown as Blob;
        return { ...item, url: URL.createObjectURL(blob) };
      } catch { incomplete = true; return { ...item, url: '' }; }
    }));
    if (current !== epoch) { next.forEach(item => URL.revokeObjectURL(item.url)); return; }
    items.value = next;
    if (incomplete) error.value = '部分凭证暂时未加载，请重试。';
  } catch { if (current === epoch) error.value = '凭证暂时未加载，请重试。'; }
  finally { if (current === epoch) loading.value = false; }
};
const choose = async (file: UploadFile) => {
  if (!file.raw || uploading.value) return;
  if (!['image/png', 'image/jpeg', 'image/webp'].includes(file.raw.type) || file.raw.size > 5 * 1024 * 1024) {
    ElMessage.warning('请上传不超过 5MB 的 JPG、PNG 或 WebP 图片'); return;
  }
  const id = props.registrationId; uploading.value = true;
  try {
    await uploadPaymentProof(id, file.raw, newRequestKey());
    ElMessage.success('凭证已上传，等待承办方核对实际到账');
    if (props.registrationId === id) await load();
  } finally { uploading.value = false; }
};
watch(() => [props.registrationId, props.organizer], () => void load(), { immediate: true });
onBeforeUnmount(() => { ++epoch; release(); });
</script>
