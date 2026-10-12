<template>
  <div class="sports-avatar-editor">
    <button type="button" class="avatar-edit-trigger" :disabled="busy" @click="selectFile"><span>＋</span> 上传我的头像</button>
    <p class="avatar-edit-hint">JPG、PNG 或 WebP，最大 5MB。可裁剪、旋转；头像展示遵循运动名片的可见范围。</p>
    <input ref="input" hidden type="file" accept="image/jpeg,image/png,image/webp" @change="choose" />
    <el-dialog v-model="visible" title="调整运动头像" width="min(600px,94vw)" append-to-body :close-on-click-modal="!busy" :close-on-press-escape="!busy" :show-close="!busy" @closed="clear">
      <div class="avatar-crop-stage"><VueCropper v-if="visible && source" ref="cropper" :img="source" :auto-crop="true" :auto-crop-width="240" :auto-crop-height="240" :fixed="true" :fixed-number="[1,1]" :center-box="true" :info="false" output-type="png" :output-size="1" /></div>
      <div class="avatar-crop-controls"><button aria-label="放大头像" type="button" @click="cropper?.changeScale(1)">＋</button><button aria-label="缩小头像" type="button" @click="cropper?.changeScale(-1)">－</button><button type="button" @click="cropper?.rotateLeft()">向左旋转</button><button type="button" @click="cropper?.rotateRight()">向右旋转</button><button type="button" :disabled="busy" @click="selectFile">换一张</button></div>
      <p v-if="error" class="avatar-upload-error" role="alert">{{ error }}</p>
      <template #footer><SportButton variant="secondary" :disabled="busy" @click="visible=false">取消</SportButton><SportButton :busy="busy" @click="save">保存头像</SportButton></template>
    </el-dialog>
  </div>
</template>
<script setup lang="ts">
import { onBeforeUnmount, ref } from 'vue';
import { ElMessage } from 'element-plus';
import 'vue-cropper/dist/index.css';
import { VueCropper } from 'vue-cropper';
import SportButton from '@/components/sport-ui/SportButton.vue';
import { uploadSportsAvatar } from '@/api/sports/avatar';
const props = defineProps<{ expectedVersion: number }>();
const emit = defineEmits<{ saved: [] }>();
const input=ref<HTMLInputElement>(),cropper=ref<InstanceType<typeof VueCropper>>(),visible=ref(false),busy=ref(false),source=ref(''),error=ref('');
const selectFile=()=>input.value?.click();
const clear=()=>{if(source.value)URL.revokeObjectURL(source.value);source.value='';error.value='';};
const choose=(event:Event)=>{const field=event.target as HTMLInputElement,file=field.files?.[0];field.value='';if(!file)return;if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>5*1024*1024){ElMessage.error('请选择5MB内的JPG、PNG或WebP图片');return;}clear();source.value=URL.createObjectURL(file);visible.value=true;};
const save=()=>{if(busy.value||!cropper.value)return;busy.value=true;error.value='';cropper.value.getCropBlob(async(blob:Blob)=>{try{await uploadSportsAvatar(blob,props.expectedVersion);visible.value=false;emit('saved');ElMessage.success('头像已更新');}catch(cause){error.value=cause instanceof Error?cause.message:'头像未保存，原来的头像会保留，请稍后重试';}finally{busy.value=false;}});};
onBeforeUnmount(clear);
</script>
<style scoped>
.avatar-edit-trigger{display:inline-flex;align-items:center;gap:8px;padding:11px 16px;border:1px solid var(--s-line,#e6e8e4);border-radius:12px;background:var(--s-surface,#fff);color:var(--s-ink,#202321);font-size:13px;cursor:pointer}.avatar-edit-trigger:focus-visible{outline:3px solid #ef593640;outline-offset:3px}.avatar-edit-trigger span{color:var(--s-primary,#ef5936)}.avatar-edit-hint{font-size:12px;line-height:1.8;color:var(--s-muted,#737a75);margin:10px 0 0}.avatar-crop-stage{height:340px;border-radius:16px;overflow:hidden;background:#f0f0ed}.avatar-crop-controls{display:flex;gap:8px;flex-wrap:wrap;margin:18px 0 8px}.avatar-crop-controls button{border:1px solid #e5e7e3;background:#fff;padding:9px 13px;border-radius:9px;font-size:12px;cursor:pointer}.avatar-upload-error{color:#ba4937;font-size:13px;line-height:1.8}@media(max-width:600px){.avatar-crop-stage{height:280px}.avatar-crop-controls button{padding:9px 11px}}
</style>
