<template>
  <span class="official-award-medal" :class="{ neutral: !source || failed }">
    <img v-if="source && !failed" :src="source" alt="" draggable="false" @dragstart.prevent @error="failed=true" />
    <ConsumerIcon v-else name="award" />
  </span>
</template>
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { officialMedalPath } from '@/utils/sportsRank';
import ConsumerIcon from './ConsumerIcon.vue';
const props=defineProps<{title?:string|null}>();
const source=computed(()=>officialMedalPath(props.title)),failed=ref(false);
watch(source,()=>{failed.value=false;});
</script>
<style scoped>
.official-award-medal{display:grid;place-items:center;width:91px;height:102px;margin:0 auto;flex-shrink:0}
.official-award-medal img{display:block;width:100%;height:100%;object-fit:contain;pointer-events:none;user-select:none;-webkit-user-drag:none}
.official-award-medal.neutral{width:65px;height:65px;border-radius:50%;background:#eee5d1;color:#ac905a}
.official-award-medal svg{width:28px;height:28px}
</style>
