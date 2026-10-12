<template>
  <div class="sport-page-header">
    <div>
      <span v-if="eyebrow" class="sport-eyebrow">{{ eyebrow }}</span>
      <h1>{{ title }}</h1>
      <p v-if="description">{{ description }}</p>
    </div>
    <div v-if="$slots.default" class="sport-page-actions"><slot /></div>
  </div>
</template>
<script setup lang="ts">
defineProps<{ title: string; description?: string; eyebrow?: string }>();
</script>
