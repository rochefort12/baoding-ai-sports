<template>
  <div class="assistant-action-rail" :class="{ 'has-before': hasBefore, 'has-after': hasAfter, dragging }">
    <div
      ref="track"
      class="assistant-action-rail-track"
      role="group"
      :aria-label="label"
      aria-description="左右滑动或拖动查看更多，方向键也可滚动"
      tabindex="0"
      @scroll="updateEdges"
      @pointerdown="startDrag"
      @lostpointercapture="endDrag"
      @click.capture="guardClick"
      @keydown="scrollByKeyboard"
      @focusin="updateAfterFocus"
      @dragstart.prevent
    ><slot /></div>
    <span v-if="hasBefore" class="assistant-action-rail-edge before" aria-hidden="true">‹</span>
    <span v-if="hasAfter" class="assistant-action-rail-edge after" aria-hidden="true">›</span>
  </div>
</template>

<script setup lang="ts">
import { nextTick, onMounted, onUnmounted, onUpdated, ref } from 'vue';

defineProps<{ label: string }>();
const track = ref<HTMLDivElement>();
const hasBefore = ref(false), hasAfter = ref(false), dragging = ref(false);
let pointer: { id: number; x: number; y: number; scroll: number } | undefined;
let suppressPointerClick = false;
let observer: ResizeObserver | undefined;

function updateEdges() {
  const el = track.value;
  hasBefore.value = !!el && el.scrollLeft > 1;
  hasAfter.value = !!el && el.scrollWidth - el.clientWidth - el.scrollLeft > 1;
}
const updateAfterFocus = (event: FocusEvent) => nextTick(() => {
  const el = track.value, target = event.target;
  if (el && target instanceof HTMLElement && target !== el && el.contains(target)) {
    const viewport = el.getBoundingClientRect(), button = target.getBoundingClientRect();
    // Some browsers leave a Tab-focused button clipped; move only this rail, never the chat thread.
    if (button.width <= el.clientWidth && button.right > viewport.right) el.scrollLeft += button.right - viewport.right;
    else if (button.left < viewport.left) el.scrollLeft += button.left - viewport.left;
  }
  updateEdges();
});

function startDrag(event: PointerEvent) {
  // Touch keeps native scrolling; only a real horizontal mouse drag takes over a click.
  suppressPointerClick = false;
  const el = track.value;
  if (!el || event.pointerType !== 'mouse' || !event.isPrimary || event.button !== 0 || el.scrollWidth <= el.clientWidth) return;
  pointer = { id: event.pointerId, x: event.clientX, y: event.clientY, scroll: el.scrollLeft };
}
function moveDrag(event: PointerEvent) {
  const el = track.value;
  if (!pointer || !el || pointer.id !== event.pointerId) return;
  if (!(event.buttons & 1)) { endDrag(event); return; }
  const dx = event.clientX - pointer.x, dy = event.clientY - pointer.y;
  if (!dragging.value) {
    if (Math.max(Math.abs(dx), Math.abs(dy)) < 6) return;
    if (Math.abs(dy) >= Math.abs(dx)) { pointer = undefined; return; }
    dragging.value = true;
    el.setPointerCapture(event.pointerId);
  }
  event.preventDefault();
  el.scrollLeft = pointer.scroll - dx;
  updateEdges();
}
function endDrag(event: PointerEvent) {
  if (!pointer || pointer.id !== event.pointerId) return;
  const el = track.value;
  // Capture-phase suppression reaches child buttons before any command or reply is sent.
  if (dragging.value) suppressPointerClick = true;
  pointer = undefined;
  dragging.value = false;
  if (el?.hasPointerCapture(event.pointerId)) el.releasePointerCapture(event.pointerId);
}
function guardClick(event: MouseEvent) {
  if (event.detail > 0 && suppressPointerClick) {
    event.preventDefault();
    event.stopImmediatePropagation();
    suppressPointerClick = false;
  }
}
function clearPointer() {
  if (!pointer) return;
  const id = pointer.id, el = track.value;
  if (dragging.value) suppressPointerClick = true;
  pointer = undefined;
  dragging.value = false;
  if (el?.hasPointerCapture(id)) el.releasePointerCapture(id);
}
function scrollByKeyboard(event: KeyboardEvent) {
  const el = track.value;
  if (!el || event.target !== el || event.altKey || event.ctrlKey || event.metaKey) return;
  const step = Math.max(80, el.clientWidth * .65);
  const targets: Record<string, number> = { ArrowLeft: el.scrollLeft - step, ArrowRight: el.scrollLeft + step, Home: 0, End: el.scrollWidth };
  if (!(event.key in targets)) return;
  event.preventDefault();
  el.scrollLeft = targets[event.key];
  updateEdges();
}
onMounted(() => {
  observer = new ResizeObserver(updateEdges);
  if (track.value) observer.observe(track.value);
  window.addEventListener('pointermove', moveDrag, { passive: false });
  window.addEventListener('pointerup', endDrag);
  window.addEventListener('pointercancel', endDrag);
  window.addEventListener('blur', clearPointer);
  updateEdges();
});
onUpdated(updateEdges);
onUnmounted(() => {
  observer?.disconnect();
  clearPointer();
  window.removeEventListener('pointermove', moveDrag);
  window.removeEventListener('pointerup', endDrag);
  window.removeEventListener('pointercancel', endDrag);
  window.removeEventListener('blur', clearPointer);
});
</script>
