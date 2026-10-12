<template>
  <span class="sports-rank-badge" :class="['rank-' + (key || 'novice'), 'size-' + size]" :data-rank="key || 'novice'" :aria-label="'成长段位：' + name">
    <img v-if="source && !failed" :src="source" alt="" draggable="false" @dragstart.prevent @error="failed=true" />
    <span v-else class="rank-basic-mark" aria-hidden="true">•</span>
    <strong v-if="showLabel">{{ name }}</strong>
  </span>
</template>
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { rankArtworkKey, rankBadgePath } from '@/utils/sportsRank';
const props=withDefaults(defineProps<{rankName?:string;size?:'small'|'medium'|'large'|'hero';showLabel?:boolean}>(),{size:'medium',showLabel:true});
const name=computed(()=>props.rankName||'新星'),key=computed(()=>rankArtworkKey(name.value)),source=computed(()=>rankBadgePath(name.value));
const failed=ref(false);watch(source,()=>{failed.value=false;});
</script>
<style scoped>
.sports-rank-badge{display:inline-flex;align-items:center;justify-content:center;gap:8px;color:var(--rank-tone,#737a75);line-height:1.3;max-width:100%;vertical-align:middle;--rank-image:32px}.sports-rank-badge img{display:block;width:var(--rank-image);height:var(--rank-image);max-width:var(--rank-image);object-fit:contain;flex-shrink:0;user-select:none;-webkit-user-drag:none;pointer-events:none}.sports-rank-badge strong{font-size:12px;font-weight:600;overflow-wrap:anywhere}.rank-basic-mark{width:var(--rank-image);height:var(--rank-image);display:grid;place-items:center;font-size:22px;border-radius:50%;background:color-mix(in srgb,var(--rank-tone,#8c958b) 9%,transparent)}.rank-bronze{--rank-tone:#a77749}.rank-silver{--rank-tone:#73808e}.rank-gold{--rank-tone:#a78329}.rank-platinum{--rank-tone:#4c918c}.rank-diamond{--rank-tone:#5d9cbb}.rank-stellar{--rank-tone:#9376bc}.rank-king{--rank-tone:#b48633}.rank-legend{--rank-tone:#ac745d}.size-small{--rank-image:22px;gap:4px}.size-small strong{font-size:10px}.size-large{--rank-image:55px;gap:12px}.size-large strong{font-size:19px}.size-hero{--rank-image:94px;flex-direction:column;gap:10px}.size-hero strong{font-size:20px;letter-spacing:.02em}@media(max-width:600px){.size-hero{--rank-image:76px}.size-hero strong{font-size:18px}}
</style>
