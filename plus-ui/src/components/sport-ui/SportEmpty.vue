<template>
  <section class="sport-empty" :class="{ 'is-loading': loading, 'is-error': error }" :role="error ? 'alert' : 'status'" :aria-busy="loading">
    <div class="sport-empty-visual">
      <svg viewBox="0 0 100 84" fill="none" aria-hidden="true">
        <rect x="20" y="12" width="60" height="58" rx="9" stroke="currentColor" stroke-width="1.5" />
        <path d="M20 30h60M20 52h60M50 12v58M31 12v58M69 12v58" stroke="currentColor" opacity=".35" />
        <circle cx="78" cy="63" r="15" fill="var(--s-lime)" />
        <path :d="error ? 'm73 58 10 10m0-10-10 10' : 'm72 63 4 4 8-8'" stroke="var(--s-primary)" stroke-width="2" stroke-linecap="round" />
        <circle cx="16" cy="18" r="4" fill="var(--s-lime)" />
      </svg>
    </div>
    <h3>{{ title }}</h3>
    <p v-if="description">{{ description }}</p>
    <span v-if="loading" class="sport-loading-track" />
    <div v-if="$slots.default" class="sport-empty-actions"><slot /></div>
  </section>
</template>
<script setup lang="ts">
defineProps<{ title: string; description?: string; loading?: boolean; error?: boolean }>();
</script>
