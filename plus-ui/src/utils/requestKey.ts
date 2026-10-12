const mintRequestKey = () => {
  const bytes = new Uint8Array(16);
  const webCrypto = globalThis.crypto;
  if (typeof webCrypto?.getRandomValues === 'function') {
    webCrypto.getRandomValues(bytes);
  } else {
    for (let index = 0; index < bytes.length; index += 1) {
      bytes[index] = Math.floor(Math.random() * 256);
    }
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}` as ReturnType<Crypto['randomUUID']>;
};

/**
 * 局域网 http 不是安全上下文，部分页面和组件会直接调用 crypto.randomUUID。
 * 启动时补上这个方法，业务请求键也走同一实现。
 */
export const installRequestKey = () => {
  const webCrypto = globalThis.crypto;
  if (!webCrypto || typeof webCrypto.randomUUID === 'function') {
    return;
  }
  try {
    webCrypto.randomUUID = mintRequestKey;
  } catch {
    // 浏览器不允许改写时，newRequestKey 仍会自己生成。
  }
};

export const newRequestKey = () => {
  const webCrypto = globalThis.crypto;
  if (typeof webCrypto?.randomUUID === 'function') {
    return webCrypto.randomUUID();
  }
  return mintRequestKey();
};

installRequestKey();
