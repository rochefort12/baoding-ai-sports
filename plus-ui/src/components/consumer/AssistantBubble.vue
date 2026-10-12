<template>
  <Teleport to="body">
    <button ref="bubble" v-show="!blockingModal && !open" class="consumer-app assistant-bubble" :class="{ 'is-open': open }" :style="position" type="button" aria-label="打开体育 AI 助手，可拖动或用方向键移动" :aria-expanded="open" @pointerdown="drag" @keydown="moveByKeyboard" @click="toggle">
      <img src="/images/sports/assistant-orb-v2.webp" alt="" draggable="false" @dragstart.prevent />
    </button>
    <Transition name="assistant-greeting">
      <aside v-if="showGreeting" ref="greeting" class="assistant-bubble-greeting" :class="{ 'is-below': below }" :style="greetingPosition" aria-label="体育 AI 助手提示" @mouseenter="hovering = true" @mouseleave="hovering = false">
        <button class="assistant-greeting-copy" type="button" @click="openFromGreeting">{{ greetings[greetingIndex] }}<span>点我聊聊 <span aria-hidden="true">↗</span></span></button>
        <button class="assistant-greeting-mute" type="button" @click="muteForLogin">本次登录不再提示</button>
        <button class="assistant-greeting-dismiss" type="button" aria-label="暂时收起助手提示" @click="dismissGreeting">×</button>
      </aside>
    </Transition>
  </Teleport>
</template>
<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue';
import { useAssistantModalBoundary } from '@/hooks/useAssistantModalBoundary';
import '@/assets/styles/sports-assistant.scss';
import '@/assets/styles/assistant-greeting.scss';
import { assistantGreetingMuted, muteAssistantGreetingForLogin } from '@/utils/assistantGreetingPreference';
const props = defineProps<{ open?: boolean }>();
const emit = defineEmits<{ toggle: [] }>();
const blockingModal = useAssistantModalBoundary();
const bubble = ref<HTMLElement>(), greeting = ref<HTMLElement>();
const xy = ref<{ left: number; top: number }>();
const position = computed(() => xy.value ? { left: xy.value.left + 'px', top: xy.value.top + 'px', right: 'auto', bottom: 'auto' } : {});
const greetings = [
  '你好呀，我是体育 AI 助手。找比赛、聊参赛，或一起筹备赛事，都可以找我。',
  '想办一场比赛？把通知或规程发给我，我们一起整理办赛资料。',
  '报名进度、队伍邀请、赛事安排，想了解什么就点我聊聊。',
  '规程有点长？我帮你找报名条件、费用和时间。'
];
const greetingIndex = ref(0), greetingVisible = ref(false), hovering = ref(false), moving = ref(false);
const showGreeting = computed(() => greetingVisible.value && !assistantGreetingMuted.value && !props.open && !blockingModal.value && !moving.value);
const greetingPosition = ref<Record<string, string>>({}), below = ref(false);
let dragged = false, cleanup = () => {}, timer: number | undefined, frame: number | undefined;
let mounted = false;
const clamp = (left: number, top: number, width = 64, height = 64) => ({ left: Math.max(8, Math.min(innerWidth - width - 8, left)), top: Math.max(8, Math.min(innerHeight - height - 8, top)) });
// Only viewport coordinates are saved. Greeting cycles carry no account or task data.
const positionKey = 'sports-assistant-bubble-position';
function clearTimer() { if (timer !== undefined) window.clearTimeout(timer); timer = undefined; }
function schedule(delay: number) {
  clearTimer();
  if (!mounted || assistantGreetingMuted.value || props.open || blockingModal.value || document.hidden) return;
  timer = window.setTimeout(() => {
    if (hovering.value) { schedule(1500); return; }
    if (greetingVisible.value) { greetingVisible.value = false; greetingIndex.value = (greetingIndex.value + 1) % greetings.length; schedule(16000); }
    else { greetingVisible.value = true; schedule(6500); }
  }, delay);
}
function repositionGreeting() {
  if (frame !== undefined) cancelAnimationFrame(frame);
  frame = requestAnimationFrame(() => {
    frame = undefined;
    const anchor = bubble.value?.getBoundingClientRect();
    if (!anchor || !showGreeting.value) return;
    const width = Math.min(276, innerWidth - 24), height = greeting.value?.getBoundingClientRect().height || 142;
    const left = Math.max(12, Math.min(innerWidth - width - 12, anchor.right - width));
    below.value = anchor.top < height + 20;
    const top = below.value ? Math.min(innerHeight - height - 12, anchor.bottom + 12) : anchor.top - height - 12;
    greetingPosition.value = { left: left + 'px', top: Math.max(12, top) + 'px', width: width + 'px', '--greeting-tail': Math.max(18, Math.min(width - 18, anchor.left + anchor.width / 2 - left)) + 'px' };
  });
}
function pauseGreeting() { greetingVisible.value = false; hovering.value = false; clearTimer(); }
function toggle() { if (dragged) { dragged = false; return; } pauseGreeting(); emit('toggle'); }
function openFromGreeting() { pauseGreeting(); emit('toggle'); }
function dismissGreeting() { pauseGreeting(); greetingIndex.value = (greetingIndex.value + 1) % greetings.length; schedule(60000); }
function muteForLogin() { pauseGreeting(); muteAssistantGreetingForLogin(); }
function drag(event: PointerEvent) {
  if (event.button !== 0) return;
  dragged = false;
  const node = event.currentTarget as HTMLElement, box = node.getBoundingClientRect();
  node.setPointerCapture(event.pointerId); cleanup();
  const move = (e: PointerEvent) => {
    if (!dragged && Math.abs(e.clientX - event.clientX) + Math.abs(e.clientY - event.clientY) < 5) return;
    dragged = true; moving.value = true; pauseGreeting();
    xy.value = clamp(box.left + e.clientX - event.clientX, box.top + e.clientY - event.clientY, box.width, box.height);
  };
  const end = () => { node.removeEventListener('pointermove', move); node.removeEventListener('pointerup', end); node.removeEventListener('pointercancel', end); cleanup = () => {}; moving.value = false; if (dragged) schedule(16000); };
  cleanup = end; node.addEventListener('pointermove', move); node.addEventListener('pointerup', end); node.addEventListener('pointercancel', end);
}
function moveByKeyboard(event: KeyboardEvent) {
  if (!['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key)) return;
  event.preventDefault(); const box = (event.currentTarget as HTMLElement).getBoundingClientRect();
  xy.value = clamp(box.left + (event.key === 'ArrowLeft' ? -20 : event.key === 'ArrowRight' ? 20 : 0), box.top + (event.key === 'ArrowUp' ? -20 : event.key === 'ArrowDown' ? 20 : 0), box.width, box.height);
}
function resized() { if (xy.value) xy.value = clamp(xy.value.left, xy.value.top); repositionGreeting(); }
function visibilityChanged() { pauseGreeting(); if (!document.hidden) schedule(2000); }
watch(xy, value => { try { if (value) localStorage.setItem(positionKey, JSON.stringify(value)); } catch { /* A blocked preference store does not interrupt chat. */ } repositionGreeting(); });
watch(showGreeting, async value => { if (value) { await nextTick(); repositionGreeting(); } });
watch(() => [props.open, blockingModal.value], () => { pauseGreeting(); schedule(12000); });
watch(assistantGreetingMuted, () => { pauseGreeting(); schedule(1800); });
onMounted(() => {
  mounted = true;
  try { const value = JSON.parse(localStorage.getItem(positionKey) || 'null'); if (value && Number.isFinite(value.left) && Number.isFinite(value.top)) xy.value = clamp(value.left, value.top); } catch {}
  window.addEventListener('resize', resized); document.addEventListener('visibilitychange', visibilityChanged); schedule(1800);
});
onUnmounted(() => { mounted = false; clearTimer(); if (frame !== undefined) cancelAnimationFrame(frame); cleanup(); window.removeEventListener('resize', resized); document.removeEventListener('visibilitychange', visibilityChanged); });
</script>
