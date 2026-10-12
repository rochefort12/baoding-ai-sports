<template>
  <section class="sport-card" :class="{ 'sport-card--dark': dark, 'sport-card--flat': flat }">
    <header v-if="title || $slots.header" class="sport-card-head">
      <div>
        <span v-if="eyebrow" class="sport-eyebrow">{{ eyebrow }}</span>
        <h2 v-if="title">{{ title }}</h2>
        <slot name="header" />
      </div>
      <slot name="actions" />
    </header>
    <div class="sport-card-body"><slot /></div>
    <footer v-if="$slots.footer" class="sport-card-foot"><slot name="footer" /></footer>
  </section>
</template>
<script setup lang="ts">
defineProps<{ title?: string; eyebrow?: string; dark?: boolean; flat?: boolean }>();
</script>
