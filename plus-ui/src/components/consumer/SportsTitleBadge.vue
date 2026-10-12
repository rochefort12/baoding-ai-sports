<template>
  <span v-if="title" class="sports-title-badge" :class="{compact}" :data-title-code="code||undefined">
    <img v-if="source && !failed" :src="source" alt="" draggable="false" @dragstart.prevent @error="failed=true" />
    <strong>{{ title }}</strong>
  </span>
</template>
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { titleArtworkPath } from '@/utils/sportsRank';
const props=defineProps<{title?:string|null;code?:string|null;compact?:boolean}>();
const source=computed(()=>titleArtworkPath(props.code)),failed=ref(false);watch(source,()=>{failed.value=false;});
</script>
<style scoped>
.sports-title-badge{display:inline-flex;align-items:center;justify-content:center;gap:7px;max-width:100%;min-height:25px;color:#a4773f;padding:3px 10px;border-radius:20px;background:linear-gradient(120deg,#f4eddf,#fffdf8);border:1px solid #e8ddc4;line-height:1.5}.sports-title-badge img{width:24px;height:24px;object-fit:contain;flex-shrink:0;pointer-events:none;user-select:none;-webkit-user-drag:none}.sports-title-badge strong{font-size:11px;font-weight:600;overflow-wrap:anywhere}.sports-title-badge.compact{padding:2px 7px;gap:4px;min-height:22px}.compact img{width:20px;height:20px}.compact strong{font-size:10px}
</style>
