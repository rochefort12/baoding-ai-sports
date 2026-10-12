<template>
  <button
    class="sport-button"
    :class="['sport-button--' + variant, 'sport-button--' + size, { 'is-block': block, 'is-busy': busy }]"
    :type="type"
    :disabled="disabled || busy"
    :aria-busy="busy || undefined"
  >
    <span v-if="busy" class="sport-spinner" aria-hidden="true" /><span v-else-if="$slots.icon" class="sport-button-icon"><slot name="icon" /></span
    ><slot /><span v-if="$slots.trailing" class="sport-button-icon"><slot name="trailing" /></span>
  </button>
</template>
<script setup lang="ts">
withDefaults(
  defineProps<{
    variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
    size?: 'sm' | 'md' | 'lg';
    type?: 'button' | 'submit' | 'reset';
    block?: boolean;
    busy?: boolean;
    disabled?: boolean;
  }>(),
  { variant: 'primary', size: 'md', type: 'button' }
);
</script>
