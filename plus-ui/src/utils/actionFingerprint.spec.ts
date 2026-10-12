import { createHash, webcrypto } from 'node:crypto';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { sha256Hex } from './actionFingerprint';

afterEach(() => vi.unstubAllGlobals());

describe('payload SHA-256 across HTTPS and LAN HTTP', () => {
  it.each(['', 'abc', '联测：双打🏸\uD800', '不同项目和中文姓名'.repeat(80)])('preserves UTF-8 digest for %j', async (text) => {
    const bytes = new TextEncoder().encode(text);
    const expected = createHash('sha256').update(bytes).digest('hex');
    vi.stubGlobal('crypto', webcrypto);
    expect(await sha256Hex(bytes)).toBe(expected);
    vi.stubGlobal('crypto', { getRandomValues: webcrypto.getRandomValues.bind(webcrypto) });
    expect(await sha256Hex(bytes)).toBe(expected);
  });

  it('hashes only a view, rather than surrounding bytes in its buffer', async () => {
    const bytes = new Uint8Array([255, 0, 128, 17, 255]).subarray(1, 4);
    const expected = createHash('sha256').update(bytes).digest('hex');
    vi.stubGlobal('crypto', webcrypto);
    expect(await sha256Hex(bytes)).toBe(expected);
    vi.stubGlobal('crypto', undefined);
    expect(await sha256Hex(bytes)).toBe(expected);
  });
});
