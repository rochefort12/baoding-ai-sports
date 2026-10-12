import { webcrypto } from 'node:crypto';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/utils/request', () => ({ default: requestMock }));
vi.mock('element-plus', () => ({ ElMessageBox: { confirm: vi.fn() } }));
import { performAction } from './phase1';
import { writeEventMaterial } from './organizerMaterials';

beforeEach(() => {
  requestMock.mockReset();
  const values = new Map<string, string>();
  vi.stubGlobal('sessionStorage', {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => values.set(key, value),
    removeItem: (key: string) => values.delete(key)
  });
  // Actual insecure LAN contexts still offer random bytes, but no subtle/UUID.
  vi.stubGlobal('crypto', { getRandomValues: webcrypto.getRandomValues.bind(webcrypto) });
});
afterEach(() => vi.unstubAllGlobals());

describe('LAN operations after a disconnected response', () => {
  it.each(['action', 'material'] as const)('%s retries the same payload with the same key, then clears it on success', async (kind) => {
    const call = (input: Record<string, string | number>) => kind === 'action' ? performAction('profile.display', input) : writeEventMaterial('save', input);
    requestMock.mockRejectedValueOnce(new Error('Disconnected')).mockResolvedValue({ data: { status: 'ok' } });
    await expect(call({ title: '联测🏸', version: 1 })).rejects.toThrow('Disconnected');
    await call({ version: 1, title: '联测🏸' });
    const first = requestMock.mock.calls[0][0].data;
    const retry = requestMock.mock.calls[1][0].data;
    expect(retry.requestKey).toBe(first.requestKey);
    expect(first.requestKey).toMatch(/^[0-9a-f-]{36}$/);
    await call({ title: '联测🏸', version: 1 });
    expect(requestMock.mock.calls[2][0].data.requestKey).not.toBe(first.requestKey);
  });

  it('does not reuse a failed key for different material content', async () => {
    requestMock.mockRejectedValueOnce(new Error('Disconnected')).mockResolvedValue({ data: {} });
    await expect(writeEventMaterial('save', { content: '旧文稿' })).rejects.toThrow('Disconnected');
    await writeEventMaterial('save', { content: '新文稿' });
    expect(requestMock.mock.calls[1][0].data.requestKey).not.toBe(requestMock.mock.calls[0][0].data.requestKey);
  });
});
