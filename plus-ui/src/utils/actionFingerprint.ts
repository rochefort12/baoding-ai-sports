import CryptoJS from 'crypto-js';

/** The payload digest binds retries to identical bytes, including on LAN HTTP. */
export async function sha256Hex(bytes: Uint8Array): Promise<string> {
  if (typeof globalThis.crypto?.subtle?.digest === 'function') {
    const digest = await globalThis.crypto.subtle.digest('SHA-256', new Uint8Array(bytes).buffer);
    return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
  }
  // CryptoJS is already pinned in this frontend. Use the original UTF-8 bytes so
  // browser secure-context availability cannot change the retry slot.
  const words: number[] = [];
  bytes.forEach((byte, index) => {
    words[index >>> 2] = (words[index >>> 2] || 0) | (byte << (24 - (index % 4) * 8));
  });
  return CryptoJS.SHA256(CryptoJS.lib.WordArray.create(words, bytes.length)).toString(CryptoJS.enc.Hex);
}
