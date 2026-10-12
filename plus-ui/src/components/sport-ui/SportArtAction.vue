<template>
  <component
    :is="to ? RouterLink : 'button'"
    v-bind="$attrs"
    :to="to"
    :type="to ? undefined : 'button'"
    :disabled="to ? undefined : blocked"
    :aria-disabled="blocked || undefined"
    :aria-busy="busy || undefined"
    :tabindex="blocked ? -1 : undefined"
    class="sport-art-action"
    :class="[`sport-art-action--${layout}`, `sport-art-action--${tone}`, { 'is-blocked': blocked, 'is-small': small }]"
    @pointerdown="beginPointer"
    @pointermove="trackPointer"
    @pointercancel="pointerMoved = true"
    @click="activate"
  >
    <span class="sport-art-action__scene" aria-hidden="true"><img :src="sportEntryArt[art].src" alt="" draggable="false" /></span>
    <span class="sport-art-action__label"><slot>{{ sportEntryArt[art].label }}</slot></span>
    <span v-if="layout === 'inline'" class="sport-art-action__arrow" aria-hidden="true">↗</span>
  </component>
</template>
<script setup lang="ts">
import { computed, ref } from 'vue';
import { RouterLink, type RouteLocationRaw } from 'vue-router';
import { sportEntryArt, type SportEntryArtKey } from './sportEntryArt';
defineOptions({ inheritAttrs: false });
const props = withDefaults(defineProps<{ art: SportEntryArtKey; to?: RouteLocationRaw; layout?: 'tile' | 'inline'; tone?: 'neutral' | 'primary'; small?: boolean; disabled?: boolean; busy?: boolean }>(), { layout: 'inline', tone: 'neutral' });
const emit = defineEmits<{ click: [event: MouseEvent] }>();
const blocked = computed(() => props.disabled || props.busy);
let pointerOrigin: { x: number; y: number } | undefined;
const pointerMoved = ref(false);
function beginPointer(event: PointerEvent) { pointerOrigin = { x: event.clientX, y: event.clientY }; pointerMoved.value = false; }
function trackPointer(event: PointerEvent) { if (pointerOrigin && Math.hypot(event.clientX - pointerOrigin.x, event.clientY - pointerOrigin.y) > 8) pointerMoved.value = true; }
function activate(event: MouseEvent) {
  if (blocked.value || (event.detail > 0 && pointerMoved.value)) { event.preventDefault(); event.stopImmediatePropagation(); return; }
  emit('click', event);
}
</script>
<style scoped>
.sport-art-action{--action-art-size:48px;display:inline-flex;align-items:center;justify-content:center;gap:8px;min-width:0;min-height:46px;padding:5px 14px 5px 7px;border:1px solid var(--s-line,#e6e8e4);border-radius:16px;background:var(--s-surface,#fff);color:var(--s-ink,#202321);font:600 12px/1.45 var(--s-font,system-ui);text-decoration:none;cursor:pointer;isolation:isolate;transition:transform .22s var(--s-ease,ease),box-shadow .22s,border-color .22s;touch-action:manipulation}
.sport-art-action__scene{width:var(--action-art-size);height:calc(var(--action-art-size)*.8);display:block;flex-shrink:0;pointer-events:none}
.sport-art-action__scene img{width:100%;height:100%;object-fit:contain;display:block;pointer-events:none;user-select:none;-webkit-user-drag:none;transition:transform .28s var(--s-ease,ease)}
.sport-art-action__label{min-width:0;overflow-wrap:anywhere}.sport-art-action__arrow{flex-shrink:0;margin-left:3px;font-size:15px;color:var(--s-primary,#ef5936)}
.sport-art-action:hover{transform:translateY(-2px);border-color:#e4c5b5;box-shadow:0 7px 18px #b7876512}.sport-art-action:hover img{transform:translateY(-2px) rotate(-3deg)}.sport-art-action:active{transform:translateY(0) scale(.985)}
.sport-art-action:focus-visible{outline:3px solid #ed835d;outline-offset:4px}.sport-art-action--primary{background:#fff6ef;border-color:#f0cab7;color:#773d23}.sport-art-action--primary .sport-art-action__arrow{color:#a34222}
.sport-art-action--tile{--action-art-size:68px;flex-direction:column;gap:1px;min-height:104px;width:100%;padding:10px 8px 13px;border-radius:20px;font-size:13px;background:linear-gradient(150deg,#fff 35%,#f9f7f2)}
.sport-art-action.is-small{--action-art-size:36px;min-height:42px;padding:4px 11px 4px 5px;border-radius:13px;font-size:11px;gap:5px}.sport-art-action.is-blocked{opacity:.55;cursor:default;box-shadow:none;transform:none}.sport-art-action.is-blocked img{transform:none}
@media(max-width:700px){.sport-art-action--tile{--action-art-size:49px;min-height:85px;padding:9px 3px 11px;font-size:10px;border-radius:16px}.sport-art-action--tile .sport-art-action__label{white-space:nowrap}}
@media(prefers-reduced-motion:reduce){.sport-art-action,.sport-art-action__scene img{transition:none}.sport-art-action:hover,.sport-art-action:active,.sport-art-action:hover img{transform:none}}
</style>
