<template>
  <div class="avatar-frame" :class="'frame-' + frameKey" :data-frame="frameKey" :data-growth-rank="key || 'novice'" :data-certified-frame="certified?.honorId">
    <div class="avatar-picture"><slot /></div>
    <img v-if="source && !failed" class="avatar-frame-art" :src="source" alt="" aria-hidden="true" draggable="false" @dragstart.prevent @error="failed=true" />
    <span v-if="certified || ['diamond','stellar','king','legend'].includes(key || '')" class="avatar-energy" aria-hidden="true" />
    <span v-if="certified || ['stellar','king','legend'].includes(key || '')" class="avatar-particles" aria-hidden="true"><i v-for="particle in 8" :key="particle" :style="{'--orbit-angle': particle * 45 + 'deg', '--spark-delay': -particle * .43 + 's'}" /></span>
    <slot name="markers" />
  </div>
</template>
<script setup lang="ts">
import { computed, inject, ref, watch } from 'vue';
import { rankArtworkKey, rankFramePath } from '@/utils/sportsRank';
import {certifiedFrameContext} from '@/utils/honorPresentation';
const props=defineProps<{rankName?:string;rankOnly?:boolean}>();
const context=inject(certifiedFrameContext,undefined);
const certified=computed(()=>props.rankOnly?undefined:context?.value);
const key=computed(()=>rankArtworkKey(props.rankName));
const frameKey=computed(()=>certified.value?'world-'+certified.value.artwork:key.value||'novice');
const source=computed(()=>certified.value?.source||rankFramePath(props.rankName));
const failed=ref(false);watch(source,()=>{failed.value=false;});
</script>
<style scoped>
.avatar-frame{width:var(--avatar-size,100px);height:var(--avatar-size,100px);position:relative;border-radius:50%;isolation:isolate;flex-shrink:0}.avatar-picture{width:100%;height:100%;overflow:hidden;border-radius:50%;background:var(--avatar-fill,#e9e5de);color:var(--avatar-ink,#79674d);box-shadow:0 0 0 4px var(--s-surface,#fff),0 0 0 5px var(--s-line,#e6e8e4)}.avatar-picture :deep(.avatar-photo){width:100%;height:100%;display:block;object-fit:cover;user-select:none;-webkit-user-drag:none}.avatar-frame-art{position:absolute;z-index:1;inset:-18%;width:136%;height:136%;max-width:none;object-fit:contain;pointer-events:none;user-select:none;-webkit-user-drag:none}.frame-king .avatar-picture{box-shadow:0 0 0 4px var(--s-surface,#fff),0 0 0 6px #c6a052,0 9px 24px #b5943123}.frame-stellar .avatar-picture{box-shadow:0 0 0 4px var(--s-surface,#fff),0 0 0 6px #ab93c9}.frame-diamond .avatar-picture{box-shadow:0 0 0 4px var(--s-surface,#fff),0 0 0 6px #93c4d5}
.frame-world-champion{--energy:#e7cb7f}.frame-world-runner-up{--energy:#bfdce9}.frame-world-third-place{--energy:#d5a286}.avatar-energy,.avatar-particles{position:absolute;inset:-17%;pointer-events:none;z-index:2;border-radius:50%}.frame-diamond{--energy:#8bcee6}.frame-stellar{--energy:#b49be7}.frame-legend{--energy:#eea779}.avatar-energy{background:conic-gradient(from 0deg,transparent 12%,var(--energy,#d9b768) 24%,transparent 35%,transparent 61%,#fff7d7 74%,transparent 88%);mask-image:radial-gradient(circle,transparent 58%,#000 61%,#000 64%,transparent 67%);animation:avatar-fluid 8s linear infinite;opacity:.62;filter:blur(.6px)}.avatar-particles i{position:absolute;inset:0;transform:rotate(var(--orbit-angle))}.avatar-particles i::before{content:'';position:absolute;left:50%;top:2%;width:3px;height:3px;border-radius:50%;background:#fff3c4;box-shadow:0 0 6px 2px var(--energy,#d9b768);animation:avatar-spark 3.8s ease-in-out infinite;animation-delay:var(--spark-delay)}.frame-legend .avatar-energy{animation-duration:5.5s;opacity:.8}.frame-legend .avatar-particles i::before{width:4px;height:4px}.avatar-particles{animation:avatar-fluid 28s linear infinite}.frame-king .avatar-frame-art,.frame-legend .avatar-frame-art{filter:drop-shadow(0 2px 5px #b5872c22)}
@keyframes avatar-fluid{to{transform:rotate(360deg)}}@keyframes avatar-spark{0%,100%{opacity:.15;scale:.55}45%{opacity:1;scale:1.1}65%{opacity:.55;scale:.85}}@media(prefers-reduced-motion:reduce){.avatar-energy,.avatar-particles,.avatar-particles i::before{animation:none}.avatar-particles i:nth-child(even){display:none}}
</style>
