import { ref } from 'vue';

// A presentation preference for this tab's login; no token, person or task is stored.
const storageKey = 'sports-assistant-greeting-muted';
function readPreference() { try { return sessionStorage.getItem(storageKey) === '1'; } catch { return false; } }
export const assistantGreetingMuted = ref(readPreference());
export function muteAssistantGreetingForLogin() {
  assistantGreetingMuted.value = true;
  try { sessionStorage.setItem(storageKey, '1'); } catch { /* Still mute the active page if browser storage is disabled. */ }
}
export function resetAssistantGreetingForLogin() {
  assistantGreetingMuted.value = false;
  try { sessionStorage.removeItem(storageKey); } catch { /* Login remains available without preference storage. */ }
}
