<template>
  <component :is="to ? RouterLink : 'article'" v-bind="to ? { to } : {}" class="sport-metric" :class="{ 'sport-metric--featured': featured }"
    ><div class="sport-metric-top">
      <span>{{ label }}</span
      ><span class="sport-metric-icon"><slot name="icon" /></span>
    </div>
    <strong
      >{{ value }}<small v-if="unit">{{ unit }}</small></strong
    >
    <p v-if="note">{{ note }}</p>
    <span v-if="to" class="sport-metric-arrow" aria-hidden="true">↗</span></component
  >
</template>
<script setup lang="ts">
import { RouterLink } from 'vue-router';
defineProps<{ label: string; value: string | number; unit?: string; note?: string; to?: string; featured?: boolean }>();
</script>
