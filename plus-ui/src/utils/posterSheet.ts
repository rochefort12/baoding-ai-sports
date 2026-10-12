import { qrMatrix } from '@/utils/qrMatrix';

export interface PosterInput {
  eventName?: string;
  headline: string;
  invitation: string;
  whenText: string;
  location: string;
  organizationName: string;
  fees: { name: string; amount: string; mode: string }[];
  published: boolean;
  cancelled: boolean;
  link: string;
  banner?: CanvasImageSource | null;
  compact?: boolean;
  style?: 'competitive' | 'junior' | 'community';
}

const WIDTH = 1080;

export interface Rgb { r: number; g: number; b: number }
export interface PosterColors { paper: string; accent: string; ink: string; sub: string }

/** 只统计占比最大的颜色组。少量黑线和小块高饱和色不参与，避免单像素或全图平均被带偏。 */
export function posterColorsFromRgba(pixels: Uint8ClampedArray | null | undefined): PosterColors | null {
  const dominant = dominantGroup(pixels);
  if (!dominant) return null;
  return readableColors(dominant);
}

export function contrastRatio(a: Rgb, b: Rgb) {
  const hi = Math.max(relativeLuminance(a), relativeLuminance(b));
  const lo = Math.min(relativeLuminance(a), relativeLuminance(b));
  return (hi + 0.05) / (lo + 0.05);
}

function dominantGroup(pixels: Uint8ClampedArray | null | undefined): Rgb | null {
  if (!pixels || pixels.length < 4) return null;
  const buckets = new Map<string, { n: number; r: number; g: number; b: number }>();
  let total = 0;
  for (let index = 0; index < pixels.length; index += 4) {
    if (pixels[index + 3] < 200) continue;
    const r = pixels[index];
    const g = pixels[index + 1];
    const b = pixels[index + 2];
    const key = `${r >> 4},${g >> 4},${b >> 4}`;
    const bucket = buckets.get(key) || { n: 0, r: 0, g: 0, b: 0 };
    bucket.n += 1;
    bucket.r += r;
    bucket.g += g;
    bucket.b += b;
    buckets.set(key, bucket);
    total += 1;
  }
  if (!total) return null;
  const ranked = [...buckets.values()].sort((left, right) => right.n - left.n || lightness(right) - lightness(left));
  const eligible = ranked.filter((bucket) => {
    if (bucket.n / total >= 0.18) return true;
    const { s, l } = rgbToHsl(bucket.r / bucket.n, bucket.g / bucket.n, bucket.b / bucket.n);
    return !(l < 0.14 || s > 0.68);
  });
  const winner = (eligible.length ? eligible : ranked)[0];
  return { r: Math.round(winner.r / winner.n), g: Math.round(winner.g / winner.n), b: Math.round(winner.b / winner.n) };
}

function lightness(bucket: { n: number; r: number; g: number; b: number }) {
  return rgbToHsl(bucket.r / bucket.n, bucket.g / bucket.n, bucket.b / bucket.n).l;
}

function readableColors(source: Rgb): PosterColors | null {
  const hsl = rgbToHsl(source.r, source.g, source.b);
  const hue = hsl.s < 0.08 ? 16 : hsl.h;
  const saturation = Math.min(hsl.s, 0.22);
  const lightPaper = hsl.l >= 0.45;
  let paperL = lightPaper ? Math.max(hsl.l, 0.9) : Math.min(hsl.l, 0.22);
  const dark: Rgb = { r: 32, g: 58, b: 51 };
  const light: Rgb = { r: 247, g: 244, b: 239 };
  let paper = hslToRgb(hue, saturation, paperL);
  let darkContrast = contrastRatio(paper, dark);
  let lightContrast = contrastRatio(paper, light);
  for (let step = 0; step < 6 && Math.max(darkContrast, lightContrast) < 4.5; step += 1) {
    paperL = lightPaper ? Math.min(0.97, paperL + 0.02) : Math.max(0.06, paperL - 0.03);
    paper = hslToRgb(hue, saturation, paperL);
    darkContrast = contrastRatio(paper, dark);
    lightContrast = contrastRatio(paper, light);
  }
  const ink = darkContrast >= lightContrast ? dark : light;
  if (Math.max(darkContrast, lightContrast) < 4.5) return null;
  const accent = accentColor(hue, paper, ink === light);
  const sub = softened(ink, paper);
  return { paper: hex(paper), accent: hex(accent), ink: hex(ink), sub: hex(sub) };
}

function accentColor(hue: number, paper: Rgb, inkIsLight: boolean): Rgb {
  let lightness = inkIsLight ? 0.72 : 0.36;
  let color = hslToRgb(hue, 0.5, lightness);
  for (let step = 0; step < 8 && contrastRatio(color, paper) < 4.5; step += 1) {
    lightness = inkIsLight ? Math.min(0.92, lightness + 0.04) : Math.max(0.12, lightness - 0.04);
    color = hslToRgb(hue, 0.5, lightness);
  }
  return contrastRatio(color, paper) >= 4.5 ? color : (relativeLuminance(paper) > 0.4 ? { r: 32, g: 58, b: 51 } : { r: 247, g: 244, b: 239 });
}

function softened(ink: Rgb, paper: Rgb): Rgb {
  const mixed = {
    r: Math.round(ink.r * 0.72 + paper.r * 0.28),
    g: Math.round(ink.g * 0.72 + paper.g * 0.28),
    b: Math.round(ink.b * 0.72 + paper.b * 0.28)
  };
  return contrastRatio(mixed, paper) >= 4.5 ? mixed : ink;
}

function colorsFromBanner(banner: CanvasImageSource): PosterColors | null {
  try {
    const width = 40;
    const height = 24;
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const pen = canvas.getContext('2d', { willReadFrequently: true });
    if (!pen) return null;
    const source = banner as { width?: number; height?: number; naturalWidth?: number; naturalHeight?: number };
    const sourceWidth = source.naturalWidth || source.width || width;
    const sourceHeight = source.naturalHeight || source.height || height;
    if (!sourceWidth || !sourceHeight) return null;
    const scale = Math.max(width / sourceWidth, height / sourceHeight);
    pen.drawImage(banner, (width - sourceWidth * scale) / 2, (height - sourceHeight * scale) / 2, sourceWidth * scale, sourceHeight * scale);
    const band = Math.max(1, Math.round(height * 0.15));
    return posterColorsFromRgba(pen.getImageData(0, height - band, width, band).data);
  } catch {
    return null;
  }
}

function fadeClear(paper: string) {
  const match = /^#([0-9a-f]{6})$/i.exec(paper);
  if (!match) return 'rgba(246,240,232,0)';
  const value = Number.parseInt(match[1], 16);
  return `rgba(${(value >> 16) & 255},${(value >> 8) & 255},${value & 255},0)`;
}

function hex(color: Rgb) {
  return `#${[color.r, color.g, color.b].map((channel) => channel.toString(16).padStart(2, '0')).join('')}`;
}

function relativeLuminance(color: Rgb) {
  const channel = (value: number) => {
    const scaled = value / 255;
    return scaled <= 0.03928 ? scaled / 12.92 : ((scaled + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

function rgbToHsl(r: number, g: number, b: number) {
  const red = r / 255;
  const green = g / 255;
  const blue = b / 255;
  const max = Math.max(red, green, blue);
  const min = Math.min(red, green, blue);
  const l = (max + min) / 2;
  if (max === min) return { h: 0, s: 0, l };
  const delta = max - min;
  const s = l > 0.5 ? delta / (2 - max - min) : delta / (max + min);
  let h = 0;
  if (max === red) h = (green - blue) / delta + (green < blue ? 6 : 0);
  else if (max === green) h = (blue - red) / delta + 2;
  else h = (red - green) / delta + 4;
  return { h: h * 60, s, l };
}

function hslToRgb(h: number, s: number, l: number): Rgb {
  const hue = ((h % 360) + 360) % 360;
  if (s <= 0) {
    const value = Math.round(l * 255);
    return { r: value, g: value, b: value };
  }
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;
  const convert = (t: number) => {
    let value = t;
    if (value < 0) value += 1;
    if (value > 1) value -= 1;
    if (value < 1 / 6) return p + (q - p) * 6 * value;
    if (value < 1 / 2) return q;
    if (value < 2 / 3) return p + (q - p) * (2 / 3 - value) * 6;
    return p;
  };
  const hk = hue / 360;
  return {
    r: Math.round(convert(hk + 1 / 3) * 255),
    g: Math.round(convert(hk) * 255),
    b: Math.round(convert(hk - 1 / 3) * 255)
  };
}

export async function renderPoster(input: PosterInput): Promise<{ png: Blob; pdf: Blob }> {
  const baseHeight = input.compact ? 1440 : 1680;
  const measuring = document.createElement("canvas").getContext("2d");
  if (!measuring) throw new Error("画布不可用");
  const height = Math.max(baseHeight, posterHeight(measuring, input));
  const canvas = document.createElement('canvas');
  canvas.width = WIDTH;
  canvas.height = height;
  const pen = canvas.getContext('2d');
  if (!pen) throw new Error('画布不可用');
  paint(pen, input, height);
  const png = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/png'));
  if (!png) throw new Error('图片没有生成');
  const pixels = pen.getImageData(0, 0, WIDTH, height).data;
  const rgb = new Uint8Array(WIDTH * height * 3);
  for (let source = 0, target = 0; source < pixels.length; source += 4, target += 3) {
    const alpha = pixels[source + 3] / 255;
    rgb[target] = Math.round(pixels[source] * alpha + 255 * (1 - alpha));
    rgb[target + 1] = Math.round(pixels[source + 1] * alpha + 255 * (1 - alpha));
    rgb[target + 2] = Math.round(pixels[source + 2] * alpha + 255 * (1 - alpha));
  }
  return { png, pdf: pdfFromRgb(rgb, WIDTH, height) };
}

function lines(pen: CanvasRenderingContext2D, text: string, width: number): string[] {
  const result: string[] = []; let line = '';
  for (const char of text) {
    if (char === '\n') { result.push(line); line = ''; continue; }
    if (line && pen.measureText(line + char).width > width) { result.push(line); line = char; }
    else line += char;
  }
  if (line) result.push(line);
  return result;
}
function posterHeight(pen: CanvasRenderingContext2D, input: PosterInput) {
  pen.font = 'bold 70px Microsoft YaHei, sans-serif';
  const title = lines(pen, input.headline || '赛事报名', 936).length * 88;
  pen.font = '32px Microsoft YaHei, sans-serif';
  const invitation = lines(pen, input.invitation || '', 936).length * 48;
  pen.font = '30px Microsoft YaHei, sans-serif';
  const rows = facts(input).reduce((height, text) => height + lines(pen, text, 896).length * 46 + 20, 0);
  return 700 + title + 78 + invitation + 45 + 100 + rows + 290;
}
function paint(pen: CanvasRenderingContext2D, input: PosterInput, height: number) {
  const themes = {
    competitive: { paper: '#f6f0e8', accent: '#bd4828', ink: '#203a33', sub: '#4e625a', hero: '#e6c7ab', label: '赛事详情' },
    junior: { paper: '#f6f0e8', accent: '#be4b27', ink: '#183e35', sub: '#476257', hero: '#e9d8a1', label: '参赛信息' },
    community: { paper: '#f6f0e8', accent: '#9c5035', ink: '#163b2a', sub: '#4f6455', hero: '#b6cebb', label: '报名指引' }
  };
  const fallback = themes[input.style || 'competitive'];
  const sampled = input.banner ? colorsFromBanner(input.banner) : null;
  const theme = sampled ? { ...fallback, ...sampled } : fallback;
  pen.fillStyle = theme.paper; pen.fillRect(0, 0, WIDTH, height);
  const heroHeight = 640;
  if (input.banner) {
    pen.save(); pen.beginPath(); pen.rect(0, 0, WIDTH, heroHeight); pen.clip();
    const b = input.banner as { width?: number; height?: number; naturalWidth?: number; naturalHeight?: number };
    const w = b.naturalWidth || b.width || WIDTH, h = b.naturalHeight || b.height || heroHeight;
    const scale = Math.max(WIDTH / w, heroHeight / h);
    pen.drawImage(input.banner, (WIDTH - w * scale) / 2, (heroHeight - h * scale) / 2, w * scale, h * scale);
    pen.restore();
  } else {
    // 图片不可用时保留平面色块氛围，不回到场馆摄影或猜测运动器材。
    const backdrop = pen.createLinearGradient(0, 0, WIDTH, heroHeight);
    backdrop.addColorStop(0, theme.hero); backdrop.addColorStop(1, theme.paper);
    pen.fillStyle = backdrop; pen.fillRect(0, 0, WIDTH, heroHeight);
  }
  // 渐变只盖住主视觉下沿；下方信息区用同一纯色铺满，图片不能透到文字上。
  const fade = pen.createLinearGradient(0, 440, 0, heroHeight);
  fade.addColorStop(0, fadeClear(theme.paper)); fade.addColorStop(1, theme.paper);
  pen.fillStyle = fade; pen.fillRect(0, 440, WIDTH, heroHeight - 440);
  pen.fillStyle = theme.paper; pen.fillRect(0, heroHeight, WIDTH, height - heroHeight);
  pen.fillStyle = theme.accent; pen.font = 'bold 25px Microsoft YaHei, sans-serif'; pen.fillText(theme.label, 72, 698);
  let y = 790;
  pen.fillStyle = theme.ink; pen.font = 'bold 70px Microsoft YaHei, sans-serif';
  y = wrap(pen, input.headline || '赛事报名', 72, y, 936, 88);
  pen.fillStyle = theme.accent; pen.fillRect(72, y + 6, 110, 6);
  pen.fillStyle = theme.sub; pen.font = '32px Microsoft YaHei, sans-serif';
  y = wrap(pen, input.invitation || '', 72, y + 70, 936, 48) + 45;
  pen.strokeStyle = theme.accent; pen.lineWidth = 2; pen.beginPath(); pen.moveTo(72, y); pen.lineTo(1008, y); pen.stroke();
  pen.fillStyle = theme.ink; pen.font = '30px Microsoft YaHei, sans-serif';
  let line = y + 62;
  for (const fact of facts(input)) line = wrap(pen, fact, 72, line, 896, 46) + 20;
  pen.fillStyle = theme.ink; pen.font = 'bold 34px Microsoft YaHei, sans-serif';
  // 给二维码独立保留区，长CTA换行，不与二维码相撞。
  wrap(pen, input.cancelled ? '赛事已取消' : input.published ? '扫码了解规程\n选择项目报名' : '赛事筹备中', 72, height - 195, 700, 46);
  pen.fillStyle = theme.sub; pen.font = '24px Microsoft YaHei, sans-serif';
  wrap(pen, input.published ? '费用与资格以正式项目配置和规程为准' : '尚未公开，发布后才能报名', 72, height - 78, 720, 32);
  if (input.published && !input.cancelled && input.link) paintQr(pen, qrMatrix(input.link), 835, height - 235, 170);
}
function facts(input: PosterInput): string[] {
  const lines = [`比赛时间  ${input.whenText || '待定'}`, `比赛地点  ${input.location || '待定'}`, `承办组织  ${input.organizationName || '待定'}`];
  if (input.eventName) lines.unshift('赛事名称  ' + input.eventName);
  if (!input.fees.length) lines.push('项目费用  待配置');
  for (const fee of input.fees) lines.push(`${fee.name}  ${fee.amount === '' || fee.amount == null ? '费用待配置' : ['free', '免费'].includes(fee.mode) ? '免费' : fee.amount + '元'}`);
  return lines;
}

function wrap(pen: CanvasRenderingContext2D, text: string, x: number, y: number, width: number, lineHeight: number): number {
  let cursor = y;
  for (const line of lines(pen, text, width)) { pen.fillText(line, x, cursor); cursor += lineHeight; }
  return cursor;
}
function roundRect(pen: CanvasRenderingContext2D, x: number, y: number, width: number, height: number, radius: number) {
  pen.beginPath();
  pen.moveTo(x + radius, y);
  pen.arcTo(x + width, y, x + width, y + height, radius);
  pen.arcTo(x + width, y + height, x, y + height, radius);
  pen.arcTo(x, y + height, x, y, radius);
  pen.arcTo(x, y, x + width, y, radius);
  pen.closePath();
}

function paintQr(pen: CanvasRenderingContext2D, matrix: boolean[][], x: number, y: number, size: number) {
  const cell = size / matrix.length;
  pen.fillStyle = '#ffffff';
  pen.fillRect(x - 8, y - 8, size + 16, size + 16);
  pen.fillStyle = '#14324a';
  matrix.forEach((row, rowIndex) => row.forEach((dark, column) => dark && pen.fillRect(x + column * cell, y + rowIndex * cell, cell, cell)));
}

function pdfFromRgb(rgb: Uint8Array, pixelWidth: number, pixelHeight: number): Blob {
  const pageWidth = 595;
  const pageHeight = Math.round((pageWidth * pixelHeight) / pixelWidth);
  const raw = deflateStore(rgbRows(rgb, pixelWidth));
  const content = `q\n${pageWidth} 0 0 ${pageHeight} 0 0 cm\n/Im1 Do\nQ\n`;
  const chunks: Uint8Array[] = [];
  const push = (text: string) => chunks.push(new TextEncoder().encode(text));
  const mark = () => chunks.reduce((sum, item) => sum + item.length, 0);
  const offsets = [0];
  push('%PDF-1.4\n');
  const obj = (text: string) => {
    offsets.push(mark());
    push(text);
  };
  obj('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');
  obj('2 0 obj\n<< /Type /Pages /Count 1 /Kids [3 0 R] >>\nendobj\n');
  obj(
    `3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pageWidth} ${pageHeight}] /Resources << /XObject << /Im1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n`
  );
  offsets.push(mark());
  push(
    `4 0 obj\n<< /Type /XObject /Subtype /Image /Width ${pixelWidth} /Height ${pixelHeight} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length ${raw.length} >>\nstream\n`
  );
  chunks.push(raw);
  push('\nendstream\nendobj\n');
  offsets.push(mark());
  push(`5 0 obj\n<< /Length ${content.length} >>\nstream\n${content}endstream\nendobj\n`);
  const xref = mark();
  push('xref\n0 6\n0000000000 65535 f \n');
  for (let index = 1; index <= 5; index++) push(`${String(offsets[index]).padStart(10, '0')} 00000 n \n`);
  push(`trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`);
  return new Blob(chunks as BlobPart[], { type: 'application/pdf' });
}

function rgbRows(rgb: Uint8Array, width: number): Uint8Array {
  const stride = width * 3;
  const height = rgb.length / stride;
  const raw = new Uint8Array(height * (stride + 1));
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0;
    raw.set(rgb.subarray(y * stride, (y + 1) * stride), y * (stride + 1) + 1);
  }
  return raw;
}

function deflateStore(data: Uint8Array): Uint8Array {
  const chunks: Uint8Array[] = [new Uint8Array([0x78, 0x01])];
  let offset = 0;
  while (offset < data.length) {
    const take = Math.min(65535, data.length - offset);
    const header = new Uint8Array(5);
    header[0] = offset + take >= data.length ? 1 : 0;
    header[1] = take & 255;
    header[2] = take >> 8;
    header[3] = ~take & 255;
    header[4] = (~take >> 8) & 255;
    chunks.push(header, data.subarray(offset, offset + take));
    offset += take;
  }
  const tail = new Uint8Array(4);
  new DataView(tail.buffer).setUint32(0, adler32(data));
  chunks.push(tail);
  const total = chunks.reduce((sum, part) => sum + part.length, 0);
  const out = new Uint8Array(total);
  let cursor = 0;
  for (const part of chunks) {
    out.set(part, cursor);
    cursor += part.length;
  }
  return out;
}

function adler32(data: Uint8Array): number {
  let a = 1;
  let b = 0;
  for (const value of data) {
    a = (a + value) % 65521;
    b = (b + a) % 65521;
  }
  return (b << 16) | a;
}
