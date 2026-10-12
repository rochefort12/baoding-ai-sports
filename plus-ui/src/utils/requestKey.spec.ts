import { describe, expect, it } from 'vitest';
import { newRequestKey } from './requestKey';

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

describe('newRequestKey', () => {
  it('uses a uuid when the browser does not provide randomUUID', () => {
    const webCrypto = globalThis.crypto;
    const original = webCrypto.randomUUID;
    Object.defineProperty(webCrypto, 'randomUUID', { configurable: true, value: undefined });
    try {
      expect(newRequestKey()).toMatch(uuid);
    } finally {
      Object.defineProperty(webCrypto, 'randomUUID', { configurable: true, value: original });
    }
  });
});
