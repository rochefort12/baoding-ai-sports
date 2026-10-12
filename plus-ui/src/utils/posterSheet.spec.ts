import { describe, expect, it } from 'vitest';
import { contrastRatio, posterColorsFromRgba, type Rgb } from './posterSheet';

function pixels(width: number, height: number, paint: (x: number, y: number) => Rgb) {
  const data = new Uint8ClampedArray(width * height * 4);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const color = paint(x, y);
      const index = (y * width + x) * 4;
      data[index] = color.r;
      data[index + 1] = color.g;
      data[index + 2] = color.b;
      data[index + 3] = 255;
    }
  }
  return data;
}

function parse(hex: string): Rgb {
  const value = Number.parseInt(hex.slice(1), 16);
  return { r: (value >> 16) & 255, g: (value >> 8) & 255, b: value & 255 };
}

describe('海报底色取色', () => {
  it('深色底用浅色字，浅色底用深色字，对比度至少4.5', () => {
    const dark = posterColorsFromRgba(pixels(20, 8, () => ({ r: 12, g: 36, b: 84 })));
    const light = posterColorsFromRgba(pixels(20, 8, () => ({ r: 246, g: 240, b: 232 })));
    expect(dark).toBeTruthy();
    expect(light).toBeTruthy();
    expect(contrastRatio(parse(dark!.paper), parse(dark!.ink))).toBeGreaterThanOrEqual(4.5);
    expect(contrastRatio(parse(light!.paper), parse(light!.ink))).toBeGreaterThanOrEqual(4.5);
    expect(contrastRatio(parse(dark!.paper), parse(dark!.accent))).toBeGreaterThanOrEqual(4.5);
    expect(contrastRatio(parse(light!.paper), parse(light!.accent))).toBeGreaterThanOrEqual(4.5);
    expect(parse(dark!.ink).r).toBeGreaterThan(200);
    expect(parse(light!.ink).r).toBeLessThan(80);
  });

  it('少量黑线和高饱和色不盖过大面积底色', () => {
    const mixed = posterColorsFromRgba(pixels(40, 10, (x, y) => {
      if (y === 0) return { r: 0, g: 0, b: 0 };
      if (x < 2) return { r: 230, g: 20, b: 20 };
      return { r: 244, g: 236, b: 220 };
    }));
    expect(mixed).toBeTruthy();
    const paper = parse(mixed!.paper);
    expect(paper.r).toBeGreaterThan(220);
    expect(paper.g).toBeGreaterThan(210);
    expect(paper.b).toBeGreaterThan(190);
  });

  it('没有有效像素时不产出颜色', () => {
    expect(posterColorsFromRgba(new Uint8ClampedArray(0))).toBeNull();
    expect(posterColorsFromRgba(null)).toBeNull();
  });
});
