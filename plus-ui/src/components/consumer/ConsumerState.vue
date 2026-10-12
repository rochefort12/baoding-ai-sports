<template>
  <SportEmpty :title="title" :description="description" :loading="loading" :error="error"><slot /></SportEmpty>
</template>
<script setup lang="ts">
import SportEmpty from '@/components/sport-ui/SportEmpty.vue';
defineProps<{ title: string; description?: string; icon?: string; loading?: boolean; error?: boolean }>();
</script>
