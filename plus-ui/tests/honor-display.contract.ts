import { afterAll, describe, expect, it } from 'vitest';
import { createSSRApp, h, type Component } from 'vue';
import { renderToString } from 'vue/server-renderer';
import { compileStyle, parse } from '@vue/compiler-sfc';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import SportsProfileCard from '@/components/consumer/SportsProfileCard.vue';
import AvatarFrame from '@/components/consumer/AvatarFrame.vue';
import CertifiedHonorBadge from '@/components/consumer/CertifiedHonorBadge.vue';
import type { CertifiedHonor } from '@/api/sports/honorCertification';
import { certifiedFrameDisplay, worldHonorArtwork } from '@/utils/honorPresentation';

// All positive examples are synthetic display contracts. No approved business fact is created.
const fixture = (place = 1): CertifiedHonor => ({
  honorId: 'synthetic-' + place, title: '合成展示 · 世界' + ['','冠军','亚军','季军'][place],
  eventYear: 2025, eventName: '合成契约赛事', sportId: 'synthetic-badminton', sportName: '羽毛球',
  place, worn: true, publicVisible: false
});
const avatar = (rankOnly = false, rankName = '青铜') => h(AvatarFrame, { rankName, rankOnly }, {
  default: () => h('span', { class: 'sample-initial', 'aria-label': '合成昵称首字' }, '合'),
  markers: () => h('small', { class: 'sample-growth-marker' }, rankName)
});
const card = (honors: CertifiedHonor[], sportId = 'synthetic-badminton', rankOnly = false) => h(SportsProfileCard, { honors, sportId }, {
  default: () => [h('span', { class: 'sample-participation-title' }, '首次完赛'), avatar(rankOnly), h('b', '合成名片')]
});
const render = (node: ReturnType<typeof h>) => renderToString(createSSRApp({ render: () => node }));

describe('synthetic certified display contracts — never actual honors', () => {
  it.each([[1, 'champion'], [2, 'runner-up'], [3, 'third-place']] as const)('exact podium %s renders its own frame and badge and keeps real growth fields', async (place, artwork) => {
    const html = await render(card([fixture(place)]));
    expect(html).toContain(`/honors/world-${artwork}-frame.webp`);
    expect(html).toContain(`/honors/world-${artwork}-badge.webp`);
    expect(html).toContain('data-growth-rank="bronze"');
    expect(html).toContain('首次完赛');
    expect(html).toContain('sample-growth-marker');
    expect(html).toContain('draggable="false"');
    expect(html).not.toContain('/frames-v2/bronze.webp');
  });

  const invalid = [
    ['unworn', { worn: false }], ['different sport', { sportId: 'synthetic-football' }],
    ['missing year', { eventYear: 0 }], ['future year', { eventYear: new Date().getFullYear() + 1 }],
    ['non-integer year', { eventYear: 2025.5 }], ['unknown place', { place: 4 }],
    ['missing identity', { honorId: '' }], ['missing verified title', { title: ' ' }]
  ] as const;
  it.each(invalid)('%s cannot change a growth avatar into a certified avatar', async (_label, patch) => {
    const html = await render(card([{ ...fixture(), ...patch }]));
    expect(html).not.toContain('/honors/world-');
    expect(html).not.toContain('data-certified-honor');
    expect(html).toContain('/frames-v2/bronze.webp');
    expect(html).toContain('首次完赛');
  });

  it('a missing selected sport cannot borrow a certification from another sport', async () => {
    const html = await render(card([fixture()], ''));
    expect(html).not.toContain('/honors/world-');
    expect(html).toContain('data-growth-rank="bronze"');
  });
  it('conflicting worn projections cannot arbitrarily choose the champion frame', async () => {
    const honors = [fixture(1), fixture(2)];
    expect(certifiedFrameDisplay(honors, 'synthetic-badminton')).toBeUndefined();
    const html = await render(card(honors));
    expect(html).not.toContain('-frame.webp');
    expect(html).toContain('/frames-v2/bronze.webp');
  });
  it('a rank-only preview ignores its certified ancestor while preserving the independent badge', async () => {
    const html = await render(card([fixture()], 'synthetic-badminton', true));
    expect(html).toContain('/frames-v2/bronze.webp');
    expect(html).not.toContain('world-champion-frame');
    expect(html).toContain('world-champion-badge');
  });
  it('certification context cannot leak to a sibling avatar outside the person card', async () => {
    const html = await render(h('main', [card([fixture()]), h('aside', { id: 'ordinary-sibling' }, [avatar(false, '白银')])]));
    const sibling = html.slice(html.indexOf('<aside'));
    expect(sibling).toContain('/frames-v2/silver.webp');
    expect(sibling).not.toContain('/honors/world-');
  });
  it('frame projection is readonly and carries only display fields', () => {
    const display = certifiedFrameDisplay([fixture()], 'synthetic-badminton');
    expect(Object.isFrozen(display)).toBe(true);
    expect(Object.keys(display!).sort()).toEqual(['artwork','eventYear','honorId','source','sportId']);
    expect(display).not.toHaveProperty('proofFileIds');
    expect(display).not.toHaveProperty('reviewNotes');
  });
  it.each(['gold','champion','constructor','__proto__','01','4','-1','',NaN])('unknown placement %s cannot imply world champion', place => {
    expect(worldHonorArtwork(place)).toBeUndefined();
  });
  it.each([
    { verified: false, year: 2025, placement: '1' },
    { verified: true, year: 0, placement: '1' },
    { verified: true, year: 2025, placement: 'gold' }
  ])('invalid badge props cannot render a verified badge', async props => {
    const html = await render(h(CertifiedHonorBadge, { title: '合成显示', ...props }));
    expect(html).not.toContain('certified-honor-badge');
    expect(html).not.toContain('已认证');
  });
});

afterAll(async () => {
  const output = process.env.AISPORTS_HONOR_RENDER_DIR;
  if (!output) return;
  const components = { SportsProfileCard, AvatarFrame, CertifiedHonorBadge };
  let styles = '';
  for (const [name, component] of Object.entries(components)) {
    const filename = fileURLToPath(new URL(`../src/components/consumer/${name}.vue`, import.meta.url));
    const { descriptor } = parse(fs.readFileSync(filename, 'utf8'), { filename });
    const scope = (component as Component & { __scopeId?: string }).__scopeId || '';
    for (const style of descriptor.styles) {
      const result = compileStyle({ source: style.content, filename, id: scope, scoped: !!style.scoped });
      if (result.errors.length) throw new Error('Actual component styles did not compile');
      styles += result.code + '\n';
    }
  }
  const html = await render(h('main', [
    h('header', [h('h1', '世界荣誉 · 合成视觉检查'), h('p', '以下三张名片为独立合成契约样本，仅检查界面与资源，不代表真实认证。')]),
    h('div', { class: 'samples' }, [1,2,3].map(place => h('section', { class: 'sample', 'data-podium': place }, [card([fixture(place)])])))
  ]));
  fs.mkdirSync(output, { recursive: true });
  const fixtureStyles = `*{box-sizing:border-box}body{margin:0;background:#f5f5f3;color:#202321;font:15px -apple-system,BlinkMacSystemFont,"Microsoft YaHei",sans-serif}main{max-width:1000px;margin:auto;padding:40px 24px}header{margin-bottom:34px}h1{font-size:24px}header p{font-size:13px;color:#737a75;line-height:1.8}.samples{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:24px}.sample{min-height:340px;background:white;border:1px solid #e6e8e4;border-radius:24px;padding:28px 18px}.sample-participation-title{margin:10px 0 18px;color:#79674d;font-size:12px}.sample-initial{display:grid;place-items:center;width:100%;height:100%;font-size:34px}.sample-growth-marker{position:absolute;bottom:-5px;left:50%;transform:translateX(-50%);background:#fff;padding:4px 10px;border-radius:12px;z-index:4;white-space:nowrap}.sports-profile-card>b{margin-top:20px;font-size:14px}@media(max-width:620px){main{padding:24px 16px}.samples{grid-template-columns:1fr}.sample{padding:25px;min-height:340px}}`;
  fs.writeFileSync(path.join(output, 'synthetic-world-honor-components.html'), `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><base href="http://127.0.0.1:5192/"><title>合成认证视觉检查</title><style>${styles}${fixtureStyles}</style>${html}</html>`, { flag: 'wx' });
});
