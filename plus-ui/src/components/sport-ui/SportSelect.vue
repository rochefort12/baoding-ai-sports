<template>
  <div ref="root" class="sport-select" :class="{ 'is-open': open, 'is-disabled': disabled, 'has-error': !!error || invalid }">
    <button v-bind="$attrs" :id="controlId" ref="trigger" type="button" class="sport-select__trigger" role="combobox" aria-haspopup="listbox" :aria-expanded="open" :aria-controls="listId" :aria-activedescendant="open && activeIndex >= 0 ? listId + '-option-' + activeIndex : undefined" :aria-required="required || undefined" :aria-invalid="!!error || invalid || undefined" :disabled="disabled" @click="toggle" @keydown="keydown" @blur="emit('blur', $event)">
      <span :class="{ 'is-placeholder': !selected }">{{ selected?.label || placeholder }}</span>
      <svg viewBox="0 0 16 16" aria-hidden="true"><path d="m4 6 4 4 4-4" /></svg>
    </button>
    <!-- Retain required/name browser form semantics without its OS menu. -->
    <select class="sport-select__constraint" :value="modelValue ?? ''" :name="name" :required="required" :disabled="disabled" aria-hidden="true" tabindex="-1" @invalid.prevent="showInvalid" @change="nativeChanged">
      <option v-if="!options.some(option => option.value === '')" value="">{{ placeholder }}</option>
      <option v-for="option in options" :key="String(option.value)" :value="option.value" :disabled="option.disabled">{{ option.label }}</option>
    </select>
    <Teleport to="body">
      <Transition name="sport-select-popover">
        <div v-if="open" ref="popup" :id="listId" class="sport-select__popover" :style="popupStyle" role="listbox" :aria-label="String($attrs['aria-label'] || placeholder)">
          <button v-for="(option, index) in options" :id="listId + '-option-' + index" :key="String(option.value)" type="button" class="sport-select__option" :class="{ 'is-active': index === activeIndex, 'is-selected': option.value === modelValue }" role="option" :aria-selected="option.value === modelValue" :disabled="option.disabled" tabindex="-1" @pointerdown.prevent @pointermove="!option.disabled && (activeIndex = index)" @click="choose(index)">
            <span>{{ option.label }}</span><svg v-if="option.value === modelValue" viewBox="0 0 16 16" aria-hidden="true"><path d="m3 8 3 3 7-7" /></svg>
          </button>
          <p v-if="!options.length" class="sport-select__empty">暂无选项</p>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>
<script setup lang="ts" generic="T extends string | number">
import { computed, nextTick, onMounted, onUnmounted, ref, useId, watch } from 'vue';
defineOptions({ inheritAttrs: false });
const props = withDefaults(defineProps<{
  modelValue?: T | null;
  options: { value: T; label: string; disabled?: boolean }[];
  id?: string; name?: string; placeholder?: string; disabled?: boolean; required?: boolean; error?: string;
}>(), { placeholder: '请选择' });
const emit = defineEmits<{ 'update:modelValue': [value: T]; change: [value: T]; blur: [event: FocusEvent] }>();
const controlId = props.id || 'sport-select-' + useId(), listId = controlId + '-list';
const root = ref<HTMLElement>(), trigger = ref<HTMLButtonElement>(), popup = ref<HTMLElement>();
const open = ref(false), activeIndex = ref(-1), invalid = ref(false);
const selected = computed(() => props.options.find(option => option.value === props.modelValue));
const popupStyle = ref<Record<string, string>>({});
let typed = '', typedAt = 0;
function position() {
  const box = trigger.value?.getBoundingClientRect();
  if (!box || !open.value) return;
  const margin = 8, width = Math.min(Math.max(box.width, 154), innerWidth - margin * 2), left = Math.max(margin, Math.min(box.left, innerWidth - width - margin));
  const below = innerHeight - box.bottom - margin, above = box.top - margin, up = below < 160 && above > below;
  popupStyle.value = { left: left + 'px', width: width + 'px', maxHeight: Math.max(72, Math.min(280, up ? above - 7 : below - 7)) + 'px', ...(up ? { bottom: innerHeight - box.top + 7 + 'px', top: 'auto' } : { top: box.bottom + 7 + 'px', bottom: 'auto' }) };
}
async function scrollActive() { await nextTick(); popup.value?.querySelector('#' + CSS.escape(listId + '-option-' + activeIndex.value))?.scrollIntoView({ block: 'nearest' }); }
function show() {
  if (props.disabled || open.value) return;
  activeIndex.value = props.options.findIndex(option => option.value === props.modelValue && !option.disabled);
  if (activeIndex.value < 0) activeIndex.value = props.options.findIndex(option => !option.disabled);
  open.value = true; position(); void scrollActive();
}
function close() { open.value = false; typed = ''; }
function toggle() { open.value ? close() : show(); }
function choose(index: number) {
  const option = props.options[index]; if (!option || option.disabled) return;
  invalid.value = false; emit('update:modelValue', option.value); emit('change', option.value); close(); trigger.value?.focus({ preventScroll: true });
}
function move(direction: number) {
  const count = props.options.length; if (!count) return;
  for (let step = 1; step <= count; step++) { const index = (activeIndex.value + direction * step + count) % count; if (!props.options[index]?.disabled) { activeIndex.value = index; void scrollActive(); return; } }
}
function keydown(event: KeyboardEvent) {
  if (props.disabled) return;
  if (event.key === 'Escape') { if (open.value) { event.preventDefault(); event.stopPropagation(); close(); } return; }
  if (event.key === 'Tab') { close(); return; }
  if (event.key === 'ArrowDown' || event.key === 'ArrowUp') { event.preventDefault(); if (!open.value) show(); else move(event.key === 'ArrowDown' ? 1 : -1); return; }
  if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); open.value ? choose(activeIndex.value) : show(); return; }
  if (open.value && (event.key === 'Home' || event.key === 'End')) { event.preventDefault(); const enabled = props.options.map((option, index) => option.disabled ? -1 : index).filter(index => index >= 0); activeIndex.value = event.key === 'Home' ? enabled[0] ?? -1 : enabled[enabled.length - 1] ?? -1; void scrollActive(); return; }
  if (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
    if (!open.value) show(); const now = Date.now(); typed = (now - typedAt < 700 ? typed : '') + event.key.toLocaleLowerCase(); typedAt = now;
    const index = props.options.findIndex(option => !option.disabled && option.label.toLocaleLowerCase().startsWith(typed)); if (index >= 0) { activeIndex.value = index; void scrollActive(); }
  }
}
function outside(event: PointerEvent) { if (open.value && !root.value?.contains(event.target as Node) && !popup.value?.contains(event.target as Node)) close(); }
function showInvalid() { invalid.value = true; trigger.value?.focus(); show(); }
function nativeChanged(event: Event) { const raw = (event.target as HTMLSelectElement).value, index = props.options.findIndex(option => String(option.value) === raw); if (index >= 0) choose(index); }
watch(() => props.disabled, value => { if (value) close(); });
watch(() => props.modelValue, () => { invalid.value = false; });
watch(() => props.options, () => { if (open.value) { activeIndex.value = props.options.findIndex(option => option.value === props.modelValue); position(); } });
onMounted(() => { document.addEventListener('pointerdown', outside, true); window.addEventListener('resize', position); window.addEventListener('scroll', position, true); });
onUnmounted(() => { document.removeEventListener('pointerdown', outside, true); window.removeEventListener('resize', position); window.removeEventListener('scroll', position, true); });
</script>
