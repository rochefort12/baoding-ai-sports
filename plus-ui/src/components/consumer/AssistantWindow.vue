<template>
  <Teleport to="body"><Transition name="assistant-window"><section v-if="visible" v-show="!blockingModal" ref="panel" v-bind="$attrs" class="consumer-app assistant-window" :class="{ 'is-expanded': expanded }" :style="style" role="dialog" aria-label="体育助手聊天窗口" tabindex="-1" @keydown.esc.stop="visible = false">
    <header class="assistant-window-heading" tabindex="0" aria-label="拖动聊天窗口，方向键移动" @pointerdown="moveWindow" @keydown="keyboardMove"><div class="assistant-window-title"><slot name="heading" /></div><div class="assistant-window-controls"><button type="button" :aria-label="expanded ? '缩小聊天窗口' : '放大聊天窗口'" :aria-pressed="expanded" @click="toggleSize"><svg viewBox="0 0 24 24" aria-hidden="true"><path v-if="expanded" d="M9 3v6H3m12-6v6h6M9 21v-6H3m12 6v-6h6"/><path v-else d="M9 3H3v6m12-6h6v6M3 15v6h6m12-6v6h-6"/></svg></button><button type="button" aria-label="关闭聊天窗口" @click="visible = false"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 6 12 12M6 18 18 6"/></svg></button></div></header>
    <div class="assistant-window-body"><slot /></div><button v-if="!expanded" class="assistant-window-resize" type="button" aria-label="调整聊天窗口尺寸，方向键调整" @pointerdown="resizeWindow" @keydown="keyboardResize"><svg viewBox="0 0 16 16" aria-hidden="true"><path d="m5 13 8-8m-3 8 3-3"/></svg></button>
  </section></Transition></Teleport>
</template>
<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue';
import { useAssistantModalBoundary } from '@/hooks/useAssistantModalBoundary';
import '@/assets/styles/sports-assistant.scss';
const visible=defineModel<boolean>({default:false});
defineOptions({inheritAttrs:false});
const blockingModal=useAssistantModalBoundary();
const panel=ref<HTMLElement>(),expanded=ref(false),viewport=ref({width:window.innerWidth,height:window.innerHeight});
const geometry=ref<{left:number;top:number;width:number;height:number}>();
function bounds(box: {left:number;top:number;width:number;height:number}) {
  const w=viewport.value.width,h=viewport.value.height,width=Math.max(Math.min(330,w-16),Math.min(box.width,w-16)),height=Math.max(Math.min(390,h-24),Math.min(box.height,h-24));
  return {width,height,left:Math.max(8,Math.min(box.left,w-width-8)),top:Math.max(8,Math.min(box.top,h-height-8))};
}
const normal=computed(()=>bounds(geometry.value||{left:viewport.value.width-584,top:viewport.value.height-824,width:560,height:800}));
const style=computed(()=>{const w=viewport.value.width,h=viewport.value.height;const box=expanded.value?bounds({left:(w-Math.min(820,w-16))/2,top:12,width:Math.min(820,w-16),height:h-24}):normal.value;return {left:box.left+'px',top:box.top+'px',width:box.width+'px',height:box.height+'px'};});
let cleanupGesture=()=>{},returnFocus:HTMLElement|null=null;
let sizeMotion:Animation|undefined,sizeRevision=0;
function cancelSizeMotion() {sizeRevision++;sizeMotion?.cancel();sizeMotion=undefined;}
// Commit the final responsive layout once, then animate its visual geometry.
// No width/height animation or re-render loop; interruption starts at the visible box.
async function toggleSize() {
  const node=panel.value;if(!node)return;
  const before=node.getBoundingClientRect();cancelSizeMotion();const revision=sizeRevision;
  expanded.value=!expanded.value;await nextTick();
  if(revision!==sizeRevision||!visible.value||!panel.value)return;
  const after=node.getBoundingClientRect();
  if(matchMedia('(prefers-reduced-motion: reduce)').matches||!node.animate)return;
  const dx=before.left-after.left,dy=before.top-after.top,sx=before.width/after.width,sy=before.height/after.height;
  sizeMotion=node.animate([
    {transform:`translate(${dx}px,${dy}px) scale(${sx},${sy})`,transformOrigin:'0 0'},
    {transform:`translate(${dx*.008}px,${dy*.008}px) scale(${1+(sx-1)*.008},${1+(sy-1)*.008})`,transformOrigin:'0 0',offset:.78},
    {transform:'none',transformOrigin:'0 0'}
  ],{duration:540,easing:'cubic-bezier(.22,1,.36,1)'});
  const motion=sizeMotion;motion.onfinish=()=>{if(sizeMotion===motion)sizeMotion=undefined;};
}
function gesture(event:PointerEvent,resize:boolean) {
  if(event.button!==0||expanded.value||(!resize&&(event.target as HTMLElement).closest('button,a,input,textarea')))return;
  const box=panel.value?.getBoundingClientRect();if(!box)return;cancelSizeMotion();const node=event.currentTarget as HTMLElement;event.preventDefault();node.setPointerCapture(event.pointerId);cleanupGesture();
  const move=(e:PointerEvent)=>{geometry.value=bounds({left:box.left+(resize?0:e.clientX-event.clientX),top:box.top+(resize?0:e.clientY-event.clientY),width:box.width+(resize?e.clientX-event.clientX:0),height:box.height+(resize?e.clientY-event.clientY:0)});};
  const end=()=>{node.removeEventListener('pointermove',move);node.removeEventListener('pointerup',end);node.removeEventListener('pointercancel',end);cleanupGesture=()=>{};};
  cleanupGesture=end;node.addEventListener('pointermove',move);node.addEventListener('pointerup',end);node.addEventListener('pointercancel',end);
}
const moveWindow=(event:PointerEvent)=>gesture(event,false),resizeWindow=(event:PointerEvent)=>gesture(event,true);
function keyboard(event:KeyboardEvent,resize:boolean) {if(expanded.value||!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(event.key)||(event.target as HTMLElement).closest('.assistant-window-controls'))return;event.preventDefault();const dx=event.key==='ArrowLeft'?-24:event.key==='ArrowRight'?24:0,dy=event.key==='ArrowUp'?-24:event.key==='ArrowDown'?24:0,b=normal.value;geometry.value=bounds({...b,left:b.left+(resize?0:dx),top:b.top+(resize?0:dy),width:b.width+(resize?dx:0),height:b.height+(resize?dy:0)});}
const keyboardMove=(event:KeyboardEvent)=>keyboard(event,false),keyboardResize=(event:KeyboardEvent)=>keyboard(event,true);
const updateViewport=()=>{cancelSizeMotion();viewport.value={width:window.innerWidth,height:window.innerHeight};if(geometry.value)geometry.value=bounds(geometry.value);};
watch(visible,async(value)=>{if(value){returnFocus=document.activeElement instanceof HTMLElement?document.activeElement:null;await nextTick();panel.value?.focus({preventScroll:true});}else{cancelSizeMotion();cleanupGesture();returnFocus?.focus({preventScroll:true});}});
onMounted(()=>window.addEventListener('resize',updateViewport));onUnmounted(()=>{cancelSizeMotion();cleanupGesture();window.removeEventListener('resize',updateViewport);});
</script>
