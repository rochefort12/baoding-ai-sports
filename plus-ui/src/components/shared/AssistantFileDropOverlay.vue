<template>
  <div class="assistant-file-drop-overlay" :class="{blocked: !!blockedReason}" role="status" aria-label="拖入资料提示">
    <div><span aria-hidden="true">{{ blockedReason ? '!' : '↓' }}</span><strong>{{ blockedReason ? '暂时不能添加资料' : '松开添加资料' }}</strong><p>{{ blockedReason || description }}</p><small>{{ fileTypes }}。请选择实际文件，不支持文件夹或网页链接。</small><small v-if="!blockedReason">加入待发送列表后，核对并点击发送。</small></div>
  </div>
</template>
<script setup lang="ts">
import { assistantFileTypesLabel } from '@/hooks/useAssistantFileDrop';
import '@/assets/styles/assistant-file-drop.scss';
defineProps<{blockedReason?:string;description:string}>();
const fileTypes=assistantFileTypesLabel;
</script>
