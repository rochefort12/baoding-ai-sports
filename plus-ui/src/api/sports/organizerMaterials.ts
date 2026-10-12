import request from '@/utils/request';
import { sha256Hex } from '@/utils/actionFingerprint';
import { newRequestKey } from '@/utils/requestKey';
export type MaterialKind = 'plan' | 'script' | 'announcement' | 'promotion';
export interface EventMaterial { kind: MaterialKind; title: string; content: string; version: number; source: 'manual' | 'ai'; factDigest: string; updatedAt: string; history: Omit<EventMaterial, 'history'>[]; }
export interface MaterialWorkspace { eventId: string; eventVersion: number; facts: Record<string, any>; factDigest: string; aiAvailable: boolean; materials: Partial<Record<MaterialKind, EventMaterial>>; }
export const getEventMaterials = (id: string) => request<MaterialWorkspace>({ url: `/sports/b/events/${id}/materials` });
/** Retry after a disconnected response reuses the same payload-bound request key. */
export async function writeEventMaterial(code: 'save' | 'generate', input: Record<string, string | number>) {
  const frozen = { ...input };
  const bytes = new TextEncoder().encode(JSON.stringify(Object.fromEntries(Object.entries(frozen).sort(([a], [b]) => a.localeCompare(b)))));
  const hash = await sha256Hex(bytes);
  const slot = `event-material:${code}:${hash}`, requestKey = sessionStorage.getItem(slot) || newRequestKey();
  sessionStorage.setItem(slot, requestKey);
  const res = await request<{ receiptId: string; result: EventMaterial }>({
    url: `/sports/platform/actions/event.material.${code}/execute`, method: 'post', timeout: 75000,
    data: { input: frozen, requestKey }, headers: { repeatSubmit: false }
  });
  sessionStorage.removeItem(slot); return res;
}
