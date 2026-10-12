<template>
  <span class="sport-brand-mark" aria-hidden="true">
    <img v-if="!failed" src="/images/sports/brand-mark-v1.webp" alt="" draggable="false" @error="failed = true" />
    <svg v-else viewBox="0 0 40 40" fill="none">
      <path d="m12 25-5-15 7 2 6-7 6 7 7-2-5 15Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round" />
      <path d="m13 14 3 11m4-13v13m7-11-3 11M12 26h16v4a8 8 0 0 1-16 0Z" stroke="currentColor" stroke-width="1.8" />
    </svg>
  </span>
</template>
<script setup lang="ts">
import { ref } from 'vue';
const failed = ref(false);
</script>
<style scoped>
.sport-brand-mark{display:inline-flex;width:36px;height:36px;align-items:center;justify-content:center;flex-shrink:0;color:var(--s-primary,#ef5936)}
.sport-brand-mark img,.sport-brand-mark svg{display:block;width:100%;height:100%;object-fit:contain}
</style>
