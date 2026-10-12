import { qrcodegen } from '@/utils/qrcodegen';

const qrApi = qrcodegen as unknown as {
  QrCode: {
    encodeText: (value: string, level: unknown) => { size: number; getModule: (x: number, y: number) => boolean };
    Ecc: { MEDIUM: unknown };
  };
};

export function qrMatrix(text: string): boolean[][] {
  const code = qrApi.QrCode.encodeText(text, qrApi.QrCode.Ecc.MEDIUM);
  const size = code.size;
  return Array.from({ length: size }, (_, y) => Array.from({ length: size }, (_, x) => code.getModule(x, y)));
}
