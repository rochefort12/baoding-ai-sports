<template>
  <section class="b-promote" :aria-busy="working || loading">
    <header class="b-promotion-heading">
      <img class="promotion-studio-orb sport-assistant-mark sport-assistant-mark--card" src="/images/sports/assistant-orb-v2.webp" alt="" width="32" height="32" draggable="false" />
      <div><h3>宣传工作室</h3><p>{{ card?.eventName || '带入赛事信息，准备一套可分享的材料。' }}</p></div>
    </header>
    <p v-if="card?.stale" class="b-promotion-notice">赛事信息已更新，基础文案和预览已同步最新资料。可再次生成 AI 文案。</p>
    <p v-else-if="card && !card.published" class="b-promotion-notice">赛事还未公开，可以先准备宣传材料；发布后才会带上报名链接和二维码。</p>
    <el-alert v-if="error" :title="error" type="error" :closable="false" />
    <el-button v-if="!card && !loading && error" @click="load(props.eventId)">重新读取</el-button>
    <div class="b-promotion-workspace">
      <div class="b-promotion-results">
        <div class="b-promotion-tabs" role="tablist" aria-label="宣传材料预览">
          <button v-for="tab in materialTabs" :id="tabId(tab.id)" :key="tab.id" type="button" role="tab" :aria-selected="activeMaterial === tab.id" :aria-controls="panelId" :tabindex="activeMaterial === tab.id ? 0 : -1" @click="activeMaterial = tab.id" @keydown="switchTab($event, tab.id)">{{ tab.label }}</button>
        </div>
        <div :id="panelId" class="b-promotion-canvas" role="tabpanel" :aria-labelledby="tabId(activeMaterial)" tabindex="0">
          <div class="b-promotion-canvas-bar"><span>{{ previewLabel }}</span><span v-if="activeMaterial !== 'group'">{{ activeMaterial === 'poster' ? '高清长图' : '朋友圈配图' }}</span></div>
          <div v-if="loading" class="b-promotion-empty" role="status"><img class="sport-assistant-mark sport-assistant-mark--card" src="/images/sports/assistant-orb-v2.webp" alt="" width="32" height="32" draggable="false"/><p>正在读取赛事信息…</p></div>
          <div v-else-if="activeMaterial === 'group'" class="b-promotion-copy-preview">
            <template v-if="currentCopy"><h4>群消息 · 微信 / QQ</h4><p>{{ groupText }}</p></template>
            <div v-else class="b-promotion-empty"><span aria-hidden="true">✉</span><p>生成海报时，也会为你准备一段群消息。</p></div>
          </div>
          <template v-else>
            <div class="b-promotion-artwork"><img v-if="activeMaterial === 'poster' ? posterUrl : momentsUrl" :src="activeMaterial === 'poster' ? posterUrl : momentsUrl" :alt="activeMaterial === 'poster' ? '赛事海报' : '朋友圈宣传图'" /><p v-else class="b-muted">{{ error ? '预览暂不可用，请重新读取赛事信息。' : '正在准备预览…' }}</p></div>
            <p v-if="activeMaterial === 'moments' && currentCopy" class="b-promotion-caption">{{ card?.momentsCaption }}</p>
          </template>
        </div>
        <div class="b-promotion-export">
          <template v-if="activeMaterial === 'poster'">
            <el-button :disabled="!posterPng" @click="download(posterPng, '海报.png')">下载图片</el-button>
            <el-button :disabled="!posterPdf" @click="download(posterPdf, '海报.pdf')">下载 PDF</el-button>
            <el-button :disabled="!posterUrl" text @click="printPoster">打印</el-button>
          </template>
          <template v-else-if="activeMaterial === 'moments'">
            <el-button :disabled="!momentsPng" @click="download(momentsPng, '朋友圈.png')">下载图片</el-button>
            <el-button :disabled="!currentCopy" @click="copy(card?.momentsCaption || '')">复制短句</el-button>
          </template>
          <el-button v-else :disabled="!currentCopy" @click="copy(groupText)">复制群消息</el-button>
          <span>材料由你分享，不会自动发布</span>
        </div>
      </div>
      <aside class="b-promotion-copilot" aria-label="AI 海报创作">
        <div class="b-promotion-assistant"><img class="sport-assistant-mark sport-assistant-mark--card" src="/images/sports/assistant-orb-v2.webp" alt="" width="32" height="32" draggable="false"/><div><strong>{{ card?.copySource === 'basic' ? '基础文案已准备' : currentCopy ? '调整宣传材料' : '生成宣传材料' }}</strong><p>{{ card?.copySource === 'basic' ? '可复制当前文案，或生成海报背景与配套文案。' : currentCopy ? '填写新的效果要求，再生成材料。' : '可补充画面要求，生成时会带入当前赛事资料。' }}</p></div></div>
        <label :for="promptId" class="b-promotion-prompt-label">你想要什么样的海报？<span>选填</span></label>
        <el-input :id="promptId" v-model="note" aria-label="海报创作要求" type="textarea" :rows="3" maxlength="200" :disabled="working" placeholder="例如：清爽的蓝绿色，突出羽毛球，文案轻松一点" />
        <div class="b-promotion-ideas" aria-label="创作灵感">
          <button v-for="idea in ideas" :key="idea.label" type="button" :disabled="working" @click="useIdea(idea)">{{ idea.label }} <span aria-hidden="true">↗</span></button>
        </div>
        <p v-if="card?.imageEnabled === false" class="b-promotion-notice">AI 生图暂不可用。可以用现有图片生成文案。</p>
        <el-checkbox v-model="consent" :disabled="working" class="b-promotion-consent">允许 AI 使用必要赛事信息生成图片与文案</el-checkbox>
        <p v-if="!consent" class="b-promotion-hint">勾选同意后即可生成，每次点击可能产生模型费用。</p>
        <el-button class="b-ai-button b-promotion-generate" :disabled="!consent || !card || working || loading" :loading="working" @click="generate(card?.imageEnabled === false ? 'copy' : 'poster')"><img v-if="!working" class="sport-assistant-mark" src="/images/sports/assistant-orb-v2.webp" alt="" width="22" height="22" draggable="false"/>{{ working ? '正在生成…' : card?.imageEnabled === false ? '生成文案' : '生成海报' }}</el-button>
        <div v-if="working" class="b-promotion-progress" role="status" aria-live="polite">
          <p>{{ progressText }}</p><ol><li :class="{ active: stage === 'image', done: stage === 'copy' || stage === 'layout' }">{{ mode === 'copy' ? '保留画面' : '生成图片' }}</li><li :class="{ active: stage === 'copy', done: stage === 'layout' }">{{ mode === 'image' ? '保留文案' : '准备文案' }}</li><li :class="{ active: stage === 'layout' }">适配排版</li></ol>
        </div>
        <p v-else-if="resultNote" class="b-promotion-feedback" role="status" aria-live="polite">{{ resultNote }}</p>
        <p v-else class="b-promotion-hint">{{ card?.imageEnabled === false ? '保留现有画面，生成海报标题、群消息和朋友圈配文。' : '一次生成海报、朋友圈配图和群消息。' }}</p>
        <details class="b-promotion-more">
          <summary>更多调整<span>风格、素材与文案</span></summary>
          <div class="b-promotion-options">
            <label>画面风格<SportSelect v-model="posterStyle" aria-label="宣传视觉风格" :options="[{ value: 'auto', label: 'AI 自动匹配' }, { value: 'competitive', label: '动感竞技' }, { value: 'junior', label: '明亮活力' }, { value: 'community', label: '清新相聚' }]" :disabled="working" @change="redraw" /></label>
            <label>主要读者<SportSelect v-model="audience" aria-label="宣传受众" :options="['运动爱好者', '俱乐部与运动伙伴', '青少年与家长', '社区居民'].map(value => ({ value, label: value }))" :disabled="working" @change="redraw" /></label>
            <label>预览背景<SportSelect v-model="backgroundSource" aria-label="宣传背景来源" :options="[{ value: 'auto', label: '自动使用已有图片' }, { value: 'generated', label: '本赛事 AI 图片', disabled: !card?.visualFileId }, { value: 'event', label: '赛事宣传图片', disabled: !card?.bannerFileId }, { value: 'default', label: '默认体育插画' }]" :disabled="working" @change="redraw" /></label>
            <p class="b-promotion-hint">{{ backgroundLabel }}。以上选择只调整预览；点击生成才会调用 AI，新图会自动用于海报。</p>
            <p v-if="card?.visualStale || card?.visualFileId && card?.visualStyle !== effectiveStyle" class="b-promotion-notice">图片与当前赛事或风格可能不一致，可以重新生成。</p>
            <div class="b-promotion-secondary-actions"><el-button :disabled="!consent || !card || working" @click="generate('copy')">只生成文案</el-button><el-button :disabled="!consent || !card || working || card.imageEnabled === false" @click="generate('image')">只生成图片</el-button></div>
          </div>
        </details>
      </aside>
    </div>
  </section>
</template>
<script setup lang="ts">
import SportSelect from '@/components/sport-ui/SportSelect.vue';
import { computed, nextTick, onUnmounted, ref, useId, watch } from 'vue';
import { ElMessage } from 'element-plus';
import request from '@/utils/request';
import { generatePromotion, generatePromotionVisual, getPromotion, type PromotionCard } from '@/api/sports/promotion';
import { renderPoster } from '@/utils/posterSheet';
import { promotionStyle, type PromotionStyle } from '@/utils/promotionStyle';

const props = defineProps<{ eventId: string }>();
const instanceId = useId();
const panelId = `promotion-panel-${instanceId}`, promptId = `promotion-prompt-${instanceId}`;
type Material = 'poster' | 'moments' | 'group';
type GenerateMode = 'poster' | 'copy' | 'image';
const materialTabs: { id: Material; label: string }[] = [{ id: 'poster', label: '海报' }, { id: 'moments', label: '朋友圈' }, { id: 'group', label: '群消息' }];
const tabId = (id: Material) => `promotion-tab-${instanceId}-${id}`;
const activeMaterial = ref<Material>('poster');
async function switchTab(event: KeyboardEvent, id: Material) {
  if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
  event.preventDefault();
  const index = materialTabs.findIndex(tab => tab.id === id);
  const target = event.key === 'Home' ? 0 : event.key === 'End' ? 2 : (index + (event.key === 'ArrowRight' ? 1 : 2)) % 3;
  activeMaterial.value = materialTabs[target].id;
  await nextTick(); document.getElementById(tabId(activeMaterial.value))?.focus();
}
const ideas: { label: string; note: string; style: PromotionStyle }[] = [
  { label: '热血竞技', note: '画面有速度和力量感，突出这场赛事的运动项目，文案简洁有号召力。', style: 'competitive' },
  { label: '清新相聚', note: '清爽柔和的配色，强调运动伙伴相聚，文案轻松自然。', style: 'community' },
  { label: '明亮活力', note: '明亮有活力的配色，画面友好有趣，文案亲切。', style: 'junior' }
];
function useIdea(idea: typeof ideas[number]) { note.value = idea.note; posterStyle.value = idea.style; redraw(); }
const card = ref<PromotionCard>();
const note = ref('');
const posterStyle = ref<PromotionStyle | 'auto'>('auto');
const audience = ref('运动爱好者');
const backgroundSource = ref<'auto' | 'generated' | 'event' | 'default'>('auto');
const backgroundLabel = ref('当前使用默认体育插画');
const effectiveStyle = computed(() => posterStyle.value === 'auto' ? promotionStyle(card.value?.eventName, card.value?.projectName, audience.value, note.value) : posterStyle.value);
const currentCopy = computed(() => Boolean(card.value?.copySource === 'basic' || (card.value?.saved && !card.value.stale)));
const previewLabel = computed(() => !card.value ? '准备预览' : backgroundLabel.value === '当前使用默认体育插画' ? '版式预览 · 默认插画' : currentCopy.value ? '宣传材料预览' : '图片已就绪 · 文案待生成');
const consent = ref(false), loading = ref(false), working = ref(false);
const stage = ref<'' | 'image' | 'copy' | 'layout'>('');
const mode = ref<GenerateMode>('poster');
const progressText = computed(() => stage.value === 'image' ? '正在为这场赛事生成图片…' : stage.value === 'copy' ? '正在准备标题、群消息和朋友圈配文…' : '正在适配配色和海报排版…');
const resultNote = ref(''), error = ref('');
const momentsUrl = ref(''), posterUrl = ref('');
const momentsPng = ref<Blob>(), posterPng = ref<Blob>(), posterPdf = ref<Blob>();
let drawVersion = 0, eventVersion = 0, disposed = false;
const absolute = (path: string) => (path ? window.location.origin + path : '');
const groupText = computed(() => !card.value?.groupBody ? '' : card.value.cancelled ? card.value.groupBody : card.value.published && card.value.groupPath
  ? card.value.groupBody + '\n' + absolute(card.value.groupPath)
  : card.value.groupBody + '\n这场还没公开，发布后才会有赛事链接。');

async function redraw() {
  if (!card.value) return;
  try { await draw(card.value); }
  catch { error.value = '所选背景读取失败，原预览保留；请重试或选择其他背景。'; }
}
async function load(id: string) {
  const version = eventVersion;
  loading.value = true; error.value = '';
  try {
    const { data } = await getPromotion(id);
    if (disposed || version !== eventVersion) return;
    card.value = data; await draw(data);
  } catch {
    if (version === eventVersion) error.value = card.value ? '预览暂时没有画出来，可以重选背景。' : '宣传材料读取失败，请重试。';
  } finally { if (version === eventVersion) loading.value = false; }
}
async function generate(requestedMode: GenerateMode = 'poster') {
  if (!consent.value || !card.value || working.value || loading.value) return;
  const version = eventVersion, id = props.eventId;
  // 一次创作固定输入，中途切换赛事不能混入另一请求或覆盖新赛事。
  const input = { consent: true, style: effectiveStyle.value, audience: audience.value, keywords: note.value.trim() };
  mode.value = requestedMode; working.value = true; error.value = ''; resultNote.value = '';
  let imageReady = false;
  try {
    if (requestedMode !== 'copy') {
      if (card.value.imageEnabled === false) throw new Error('AI 生图暂不可用，可以使用“只生成文案”。');
      stage.value = 'image';
      const { data } = await generatePromotionVisual(id, input);
      if (disposed || version !== eventVersion) return;
      if (!data.visualFileId) throw new Error('没有收到生成图片，请重试；原材料保留。');
      card.value = data; backgroundSource.value = 'generated'; await draw(data); imageReady = true;
    }
    if (requestedMode !== 'image') {
      stage.value = 'copy';
      const { data } = await generatePromotion(id, true, ('宣传受众：' + input.audience + '。' + input.keywords).slice(0, 200));
      if (disposed || version !== eventVersion) return;
      card.value = data; stage.value = 'layout'; await draw(data);
    }
    if (disposed || version !== eventVersion) return;
    resultNote.value = requestedMode === 'image' ? '图片已生成并用于海报。需要时可以再补文案。' : requestedMode === 'copy' ? '文案已生成，已有画面保留。可以切换查看朋友圈和群消息。' : '海报已生成。朋友圈配图和群消息也准备好了。';
  } catch (reason) {
    if (version === eventVersion && !disposed) error.value = (imageReady ? '图片已生成，AI 文案未完成，现有文案仍可使用。可在更多调整中只生成文案。' : '') + (reason instanceof Error ? reason.message : '这次没有生成成功，已有材料仍可使用。');
  } finally {
    if (version === eventVersion && !disposed) { working.value = false; stage.value = ''; }
  }
}
async function draw(data: PromotionCard) {
  if (disposed) return;
  const version = ++drawVersion, id = props.eventId;
  const hasCopy = data.copySource === 'basic' || (data.saved && !data.stale), source = backgroundSource.value;
  let banner: ImageBitmap | null = null, label = '';
  if (source === 'generated' || source === 'auto' && data.visualFileId) {
    banner = await loadBanner(data.visualFileId || null);
    if (banner) label = '当前使用本赛事生成图片'; else throw new Error('生成图片读取失败，请重试或选择其他背景。');
  }
  if (!banner && (source === 'event' || source === 'auto' && data.bannerFileId)) {
    banner = await loadBanner(data.bannerFileId);
    if (banner) label = '当前使用赛事宣传图片'; else throw new Error('赛事宣传图片读取失败，请重试或选择其他背景。');
  }
  if (!banner) { banner = await loadNeutral(); label = '当前使用默认体育插画'; }
  if (disposed || version !== drawVersion || id !== props.eventId) { banner?.close(); return; }
  const shared = { style: effectiveStyle.value, eventName: data.eventName, headline: hasCopy ? data.headline : (data.eventName || data.headline), invitation: hasCopy ? data.invitation : '', whenText: data.whenText, location: data.location, organizationName: data.organizationName, fees: data.fees || [], published: hasCopy && data.published, cancelled: data.cancelled, banner };
  let moments, poster;
  try { moments = await renderPoster({ ...shared, compact: true, link: absolute(data.momentsPath) }); poster = await renderPoster({ ...shared, link: absolute(data.posterPath) }); }
  finally { banner?.close(); }
  if (disposed || version !== drawVersion || id !== props.eventId) return;
  revoke(); backgroundLabel.value = label;
  momentsPng.value = moments.png; posterPng.value = poster.png; posterPdf.value = poster.pdf;
  momentsUrl.value = URL.createObjectURL(moments.png); posterUrl.value = URL.createObjectURL(poster.png);
}
async function loadNeutral() {
  try { const response = await fetch(import.meta.env.BASE_URL + 'images/promotion/sport-flat-seedream.jpg'); if (!response.ok) return null; return await createImageBitmap(await response.blob()); }
  catch { return null; }
}
async function loadBanner(fileId: string | null) {
  if (!fileId) return null;
  try { const blob = (await request({ url: '/sports/b/media/' + fileId, method: 'get', responseType: 'blob' })) as unknown as Blob; return await createImageBitmap(blob); }
  catch { return null; }
}
async function copy(text: string) {
  try { await navigator.clipboard.writeText(text); ElMessage.success('已复制，还没有发到外部渠道'); }
  catch { ElMessage.info('请选中文字手动复制'); }
}
function download(blob: Blob | undefined, name: string) {
  if (!blob) return;
  const url = URL.createObjectURL(blob), link = document.createElement('a');
  link.href = url; link.download = name; document.body.appendChild(link); link.click(); link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
function printPoster() {
  if (!posterUrl.value) return;
  const page = window.open('', '_blank');
  if (!page) { ElMessage.info('浏览器拦住了打印窗口，请改用下载 PDF'); return; }
  page.opener = null; page.document.write(`<img src="${posterUrl.value}" style="width:100%" onload="print()">`); page.document.close();
}
function revoke() {
  if (momentsUrl.value) URL.revokeObjectURL(momentsUrl.value);
  if (posterUrl.value) URL.revokeObjectURL(posterUrl.value);
  momentsUrl.value = ''; posterUrl.value = ''; momentsPng.value = undefined; posterPng.value = undefined; posterPdf.value = undefined;
}
watch(() => props.eventId, (id) => {
  eventVersion++; drawVersion++; card.value = undefined; working.value = false; stage.value = ''; resultNote.value = ''; consent.value = false;
  note.value = ''; audience.value = '运动爱好者'; backgroundSource.value = 'auto'; posterStyle.value = 'auto'; activeMaterial.value = 'poster';
  revoke(); load(id);
}, { immediate: true });
onUnmounted(() => { disposed = true; eventVersion++; drawVersion++; revoke(); });
</script>
<style scoped lang="scss">
.b-promote{color:var(--s-ink);}.b-promotion-heading{gap:14px!important;h3{font-size:25px!important;letter-spacing:-.8px;}p{font-size:12px;color:var(--s-muted);}}.promotion-studio-orb{width:62px;height:62px;object-fit:contain;}.b-promotion-tabs{background:var(--s-paper)!important;border-radius:16px!important;padding:5px!important;button{border-radius:12px!important;color:var(--s-muted)!important;&[aria-selected=true]{background:var(--s-surface)!important;color:var(--s-ink)!important;box-shadow:0 3px 12px #20232108;}}}.b-promotion-canvas{border-radius:22px!important;border:1px solid var(--s-line)!important;background:var(--s-paper)!important;}.b-promotion-canvas-bar{background:var(--s-surface)!important;}.b-promotion-copilot{background:var(--s-surface)!important;border-radius:24px!important;border:1px solid var(--s-line)!important;}.b-promotion-generate{border-radius:13px!important;background:var(--s-primary)!important;border-color:var(--s-primary)!important;color:white!important;}.b-promotion-ideas button{border-radius:12px!important;background:var(--s-paper)!important;border-color:var(--s-line)!important;color:var(--s-ink)!important;}.b-promotion-notice{background:#fff7ed!important;color:#936137!important;border-radius:12px!important;font-size:12px!important;}.b-promotion-options select{border-radius:11px!important;border-color:var(--s-line)!important;background:var(--s-paper)!important;}.b-promotion-export{flex-wrap:wrap;gap:10px;}.b-promotion-more{border-color:var(--s-line)!important;}
</style>
