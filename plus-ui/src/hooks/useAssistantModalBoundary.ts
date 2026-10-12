import { onMounted, onUnmounted, readonly, ref } from 'vue';

// Business confirmations own the screen while open. Keep the assistant task alive
// but take its floating controls out of the focus and pointer path until they close.
const blockingModal = ref(false);
let consumers = 0;
let observer: MutationObserver | undefined;
let frame = 0;
function inspect() {
  frame = 0;
  blockingModal.value = Array.from(document.querySelectorAll<HTMLElement>('.el-overlay')).some((overlay) => {
    if (!overlay.querySelector('.el-dialog, .el-message-box, .el-drawer')) return false;
    const style = getComputedStyle(overlay);
    const box = overlay.getBoundingClientRect();
    return style.display !== 'none' && style.visibility !== 'hidden' && box.width > 0 && box.height > 0;
  });
}
function schedule() {
  if (!frame) frame = requestAnimationFrame(inspect);
}
export function useAssistantModalBoundary() {
  onMounted(() => {
    if (++consumers === 1) {
      observer = new MutationObserver(schedule);
      observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['style', 'class'] });
    }
    schedule();
  });
  onUnmounted(() => {
    if (--consumers === 0) {
      observer?.disconnect();
      observer = undefined;
      if (frame) cancelAnimationFrame(frame);
      frame = 0;
      blockingModal.value = false;
    }
  });
  return readonly(blockingModal);
}
