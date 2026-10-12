<template>
  <div class="sport-field" :class="{ 'has-error': error, 'is-disabled': disabled }">
    <label :for="fieldId">{{ label }}<span v-if="required" class="sport-required" aria-hidden="true"> *</span></label>
    <div class="sport-field-control">
      <span v-if="$slots.prefix" class="sport-field-prefix"><slot name="prefix" /></span>
      <input
        v-bind="$attrs"
        :id="fieldId"
        :name="name"
        :value="modelValue"
        :type="type === 'password' && revealed ? 'text' : type"
        :placeholder="placeholder"
        :autocomplete="autocomplete"
        :maxlength="maxlength"
        :disabled="disabled"
        :aria-invalid="!!error"
        :aria-required="required || undefined"
        :aria-describedby="error || hint ? fieldId + '-help' : undefined"
        @input="$emit('update:modelValue', ($event.target as HTMLInputElement).value)"
        @blur="$emit('blur', $event)"
      />
      <button
        v-if="type === 'password'"
        type="button"
        class="sport-field-reveal"
        :disabled="disabled"
        :aria-label="revealed ? '隐藏密码' : '显示密码'"
        :aria-pressed="revealed"
        @click="revealed = !revealed"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">
          <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z" />
          <circle cx="12" cy="12" r="3" />
          <path v-if="revealed" d="m3 3 18 18" />
        </svg>
      </button>
      <slot name="suffix" />
    </div>
    <p v-if="error || hint" :id="fieldId + '-help'" class="sport-field-help" :role="error ? 'alert' : undefined">{{ error || hint }}</p>
  </div>
</template>
<script setup lang="ts">
import { ref, useId } from 'vue';
defineOptions({ inheritAttrs: false });
const props = withDefaults(
  defineProps<{
    modelValue: string;
    label: string;
    id?: string;
    name?: string;
    type?: string;
    placeholder?: string;
    autocomplete?: string;
    maxlength?: number;
    error?: string;
    hint?: string;
    disabled?: boolean;
    required?: boolean;
  }>(),
  { type: 'text' }
);
defineEmits<{ 'update:modelValue': [value: string]; blur: [event: FocusEvent] }>();
const fieldId = props.id || 'sport-field-' + useId(),
  revealed = ref(false);
</script>
