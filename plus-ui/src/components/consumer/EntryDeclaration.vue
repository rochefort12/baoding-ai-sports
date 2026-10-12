<template>
  <section class="entry-declaration" aria-label="参赛声明">
    <h3>参赛声明</h3>
    <p v-if="text" class="declaration-text">{{ text }}</p>
    <template v-if="imageAvailable">
      <p v-if="loading" class="consumer-muted" role="status">正在读取声明图片…</p>
      <div v-else-if="failure" class="notice warn" role="alert"><p>{{ failure }}</p><button class="btn" type="button" @click="load">重新读取</button></div>
      <button v-else-if="url" type="button" class="declaration-image-button" aria-label="放大参赛声明图片" @click="expanded = true">
        <img :src="url" data-testid="entry-declaration-image" alt="本场参赛声明图片" draggable="false" @load="readable = true" @error="imageFailed" />
        <span>点击放大阅读</span>
      </button>
    </template>
    <p class="consumer-muted">请本人阅读后确认。队长不能代替队员确认。</p>
    <p v-if="acknowledged" class="consumer-muted">你已确认这一版声明。</p>
    <slot :ready="ready" />
    <el-dialog v-model="expanded" title="参赛声明图片" width="min(92vw, 920px)" append-to-body destroy-on-close>
      <img v-if="url" class="declaration-expanded" :src="url" alt="本场参赛声明图片放大视图" draggable="false" />
    </el-dialog>
  </section>
</template>
<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { registrationDeclarationImage } from '@/api/sports/registration';
const props = defineProps<{ registrationId: string; text?: string | null; imageAvailable?: boolean; acknowledged?: boolean }>();
const emit = defineEmits<{ ready: [value: boolean] }>();
const loading = ref(false), failure = ref(''), url = ref(''), readable = ref(false), expanded = ref(false);
let generation = 0;
const ready = computed(() => !props.imageAvailable || readable.value);
watch(ready, value => emit('ready', value), { immediate: true });
const resetImage = () => { if (url.value) URL.revokeObjectURL(url.value); url.value = ''; readable.value = false; };
const imageFailed = () => { readable.value = false; failure.value = '声明图片未能显示，请重新读取后确认。'; };
const load = async () => {
  const current = ++generation; resetImage(); failure.value = ''; loading.value = Boolean(props.imageAvailable);
  if (!props.imageAvailable) return;
  try {
    const response = await registrationDeclarationImage(props.registrationId);
    const body: unknown = response;
    const blob = body instanceof Blob ? body : (body as { data?: Blob })?.data;
    if (!(blob instanceof Blob) || !blob.type.startsWith('image/')) throw new Error('invalid declaration image');
    if (current === generation) url.value = URL.createObjectURL(blob);
  } catch { if (current === generation) failure.value = '声明图片暂时无法读取，请重试。'; }
  finally { if (current === generation) loading.value = false; }
};
watch(() => [props.registrationId, props.imageAvailable], load, { immediate: true });
onBeforeUnmount(() => { generation++; resetImage(); });
</script>
<style scoped>
.entry-declaration{min-width:0}.entry-declaration h3{margin:0 0 14px}.declaration-text{white-space:pre-wrap;overflow-wrap:anywhere;color:var(--s-ink);line-height:1.75}.declaration-image-button{display:block;width:100%;padding:0;overflow:hidden;border:1px solid var(--s-line);border-radius:14px;background:var(--s-paper);cursor:zoom-in}.declaration-image-button img{display:block;width:100%;max-height:320px;object-fit:contain}.declaration-image-button span{display:block;padding:9px;font-size:12px;color:var(--s-muted)}.declaration-expanded{display:block;max-width:100%;height:auto;margin:auto}.entry-declaration .consumer-muted{margin-top:14px}
</style>
