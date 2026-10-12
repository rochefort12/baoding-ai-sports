<template>
  <div ref="root" class="sport-tabs" :class="{ 'sport-tabs--line': line }" role="group" :aria-label="label">
    <button
      v-for="(item, index) in options"
      :key="item.value"
      type="button"
      :class="{ 'is-selected': modelValue === item.value }"
      :aria-pressed="modelValue === item.value"
      @click="$emit('update:modelValue', item.value)"
      @keydown="navigate($event, index)"
    >
      {{ item.label }}<span v-if="item.count !== undefined">{{ item.count }}</span>
    </button>
  </div>
</template>
<script setup lang="ts">
import { ref } from 'vue';
const props = defineProps<{ modelValue: string; options: { value: string; label: string; count?: number }[]; label: string; line?: boolean }>();
const emit = defineEmits<{ 'update:modelValue': [value: string] }>(),
  root = ref<HTMLElement>();
function navigate(event: KeyboardEvent, index: number) {
  let next = index;
  if (event.key === 'ArrowRight') next = (index + 1) % props.options.length;
  else if (event.key === 'ArrowLeft') next = (index - 1 + props.options.length) % props.options.length;
  else if (event.key === 'Home') next = 0;
  else if (event.key === 'End') next = props.options.length - 1;
  else return;
  event.preventDefault();
  emit('update:modelValue', props.options[next].value);
  root.value?.querySelectorAll('button')[next]?.focus();
}
</script>
