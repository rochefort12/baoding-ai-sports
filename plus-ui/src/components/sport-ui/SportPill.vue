<template>
  <span class="sport-pill" :class="'sport-pill--' + tone"><span v-if="dot" class="sport-pill-dot" /><slot /></span>
</template>
<script setup lang="ts">
withDefaults(defineProps<{ tone?: 'green' | 'neutral' | 'gold' | 'red'; dot?: boolean }>(), { tone: 'neutral' });
</script>
