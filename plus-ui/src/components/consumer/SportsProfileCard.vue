<template>
  <div class="sports-profile-card" :class="{compact}" :data-sport-id="sportId">
    <div v-if="worn.length" class="profile-certified-honors" aria-label="已佩戴认证荣誉">
      <CertifiedHonorBadge v-for="honor in worn" :key="honor.honorId" :data-honor-id="honor.honorId" :title="honor.title" :placement="String(honor.place)" :year="honor.eventYear" :verified="true" :compact="compact" />
    </div>
    <slot />
  </div>
</template>
<script setup lang="ts">
import { computed, provide } from 'vue';
import type { CertifiedHonor } from '@/api/sports/honorCertification';
import CertifiedHonorBadge from './CertifiedHonorBadge.vue';
import {certifiedFrameContext,certifiedFrameDisplay,validWornCertifiedHonors} from '@/utils/honorPresentation';
// Only pass the honor service's approved owner/public projection, never application claims.
const props=defineProps<{honors?:CertifiedHonor[];sportId?:string;compact?:boolean}>();
const worn=computed(()=>validWornCertifiedHonors(props.honors,props.sportId));
const frame=computed(()=>certifiedFrameDisplay(props.honors,props.sportId));
provide(certifiedFrameContext,frame);
</script>
<style scoped>
.sports-profile-card{display:flex;flex-direction:column;align-items:center;gap:12px;min-width:0;max-width:100%}.profile-certified-honors{display:flex;flex-direction:column;align-items:center;gap:8px;max-width:100%;width:230px}.profile-certified-honors :deep(.certified-honor-badge){max-width:100%}.compact .profile-certified-honors{width:136px}@media(max-width:600px){.profile-certified-honors{width:215px}}
</style>
