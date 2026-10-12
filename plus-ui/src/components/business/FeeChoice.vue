<template>
  <div class="b-fee-choice" role="radiogroup" aria-label="项目是否收费" :class="{charged: modelValue === true, free: modelValue === false, unset: modelValue == null}">
    <span class="b-fee-thumb" aria-hidden="true" />
    <button type="button" role="radio" :aria-checked="modelValue === false" :disabled="disabled" @click="$emit('update:modelValue', false)">免费</button>
    <button type="button" role="radio" :aria-checked="modelValue === true" :disabled="disabled" @click="$emit('update:modelValue', true)">收费</button>
  </div>
</template>
<script setup lang="ts">
defineProps<{modelValue: boolean | null; disabled?: boolean}>();
defineEmits<{ 'update:modelValue': [value: boolean] }>();
</script>
