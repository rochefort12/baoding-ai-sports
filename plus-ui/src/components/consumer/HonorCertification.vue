<template>
  <section class="honor-certification" data-testid="honor-certification" :aria-busy="busy || loading">
    <div class="honor-cert-heading"><div><h3>荣誉认证</h3><p>世界赛事的冠军、亚军和季军，经核验后展示年份、赛事及项目。</p></div><button class="honor-cert-button" :disabled="busy" @click="start">申请认证</button></div>
    <p class="honor-cert-note">证明仅本人和平台审核人可查看。认证不增加成长积分，获批后由你选择佩戴和公开。</p>
    <p v-if="error" role="alert" class="honor-cert-error">{{ error }} <button v-if="!dirty" class="honor-cert-link" @click="load">重新读取</button></p>
    <p v-if="success" role="status" class="honor-cert-success">{{ success }}</p>
    <div v-if="loading" class="honor-cert-empty">正在读取认证记录…</div>
    <div v-else class="honor-cert-records"><button v-for="item in applications" :key="item.honorId" class="honor-cert-record" :class="{ selected: current?.honorId === item.honorId, approved: item.status === 'approved' }" :disabled="busy" @click="select(item)"><span><strong>{{ item.status === 'approved' ? item.title : `${item.details.eventYear} · ${item.details.eventName}` }}</strong><small>{{ certificationLabels[item.status] }}{{ item.worn ? ' · 正在佩戴' : '' }}</small></span><span aria-hidden="true">›</span></button><p v-if="!applications.length && !editing" class="honor-cert-empty">还没有认证记录。准备好赛事结果和本人获奖证明后，可以提交申请。</p></div>
    <div v-if="editing" class="honor-cert-editor" data-testid="honor-certification-editor">
      <div class="honor-cert-heading"><h4>{{ current ? certificationLabels[current.status] : '新申请' }}</h4><button class="honor-cert-link" :disabled="busy" @click="close">收起</button></div>
      <p v-if="lastReason" class="honor-cert-decision"><b>平台说明</b>{{ lastReason }}</p>
      <p v-if="current" class="honor-cert-note">本人申请档案：{{ current.applicantIdentity.legalName }}{{ current.applicantIdentity.birthYear ? ' · '+current.applicantIdentity.birthYear+'年出生' : '' }}。认证只确认这份档案对应的世界赛事获奖事实。</p>
      <form class="honor-cert-form" @submit.prevent="save">
        <label>赛事年份<input v-model.number="form.eventYear" data-testid="honor-year" type="number" min="1900" :max="thisYear" required :disabled="!editable || busy" placeholder="实际举办年份" /></label>
        <label>运动项目<SportSelect :model-value="form.sportId" :options="sportOptions" data-testid="honor-sport" aria-label="运动项目" placeholder="选择运动项目" name="honor-sport" required :disabled="!editable || busy" @update:model-value="form.sportId = String($event)" /></label>
        <label class="wide">赛事完整名称<input v-model="form.eventName" data-testid="honor-event" maxlength="100" required :disabled="!editable || busy" placeholder="与正式结果公布中的赛事名称保持一致" /></label>
        <label>获奖名次<SportSelect :model-value="form.place" :options="placeOptions" data-testid="honor-place" aria-label="获奖名次" name="honor-place" required :disabled="!editable || busy" @update:model-value="setPlace" /></label>
        <label>公开结果链接（可补充）<input v-model="form.sourceUrl" type="url" maxlength="1000" :disabled="!editable || busy" placeholder="https://" /></label>
        <div class="wide honor-cert-proofs"><div class="honor-cert-heading"><strong>本人获奖证明</strong><button v-if="editable" type="button" class="honor-cert-button" :disabled="busy || !current || dirty || form.proofFileIds.length >= 8" @click="fileInput?.click()">上传证明</button></div><p>JPG、PNG、WebP 或 PDF，每份不超过5MB，最多8份。{{ !current || dirty ? '先保存资料，再上传证明。' : '请提供能核对赛事、本人及名次的资料。' }}</p><input ref="fileInput" class="honor-cert-file" type="file" accept="image/jpeg,image/png,image/webp,application/pdf" @change="upload" /><div class="honor-cert-proof-list"><div v-for="(fileId, index) in form.proofFileIds" :key="fileId"><button type="button" class="honor-cert-link" :disabled="busy" @click="previewProof(fileId)">查看证明 {{ index + 1 }}</button><button v-if="editable" type="button" class="honor-cert-link muted" :disabled="busy" @click="form.proofFileIds = form.proofFileIds.filter(id => id !== fileId)">移出本次申请</button></div></div></div>
        <div v-if="editable" class="wide honor-cert-actions"><button class="honor-cert-button" data-testid="honor-save" :disabled="busy">{{ busy ? '正在办理…' : '保存草稿' }}</button><button v-if="current" type="button" class="honor-cert-button primary" data-testid="honor-submit" :disabled="busy || dirty || !current.details.proofFileIds.length" @click="submit">提交核验</button><small>{{ dirty ? '修改尚未保存' : current ? '资料已保存' : '尚未保存' }}</small></div>
        <p v-else-if="current?.status === 'submitted'" class="wide honor-cert-note">材料已提交，平台核验后会通过站内信通知你。请保留原始证明。</p>
      </form>
      <div v-if="current?.status === 'approved'" class="honor-certified-result"><CertifiedHonorBadge :title="current.title" :placement="String(current.verified.place || '')" :verified="current.status === 'approved' && !!current.verified.eventYear" :year="current.verified.eventYear" /><div><p>已核验 · {{ current.verified.officialIssuer }}</p></div><div class="honor-cert-actions"><button class="honor-cert-button primary" data-testid="honor-wear" :disabled="busy" @click="wear">{{ current.worn ? '取消佩戴' : '佩戴认证称号' }}</button><button class="honor-cert-button" data-testid="honor-visibility" :disabled="busy" @click="visibility">{{ current.publicVisible ? '关闭公开' : '允许公开展示' }}</button></div><p class="honor-cert-note">公开展示还需要个人运动名片已公开；证明及审核说明不会公开。</p></div>
      <details v-if="current?.history.length" class="honor-cert-history"><summary>办理记录 · {{ current.history.length }}</summary><article v-for="(entry, index) in [...current.history].reverse()" :key="index"><strong>{{ historyLabel(entry.state) }}</strong><time>{{ formatTime(entry.at) }}</time><p v-if="entry.reason">{{ entry.reason }}</p></article></details>
    </div>
    <el-dialog v-model="proofOpen" title="私有证明" width="min(780px,94vw)" append-to-body @closed="clearProof"><img v-if="proofUrl && proofType.startsWith('image/')" class="honor-proof-preview" :src="proofUrl" alt="本人提交的认证证明" /><template v-else-if="proofUrl"><p>PDF证明仅供本次核验查看，请妥善保管。</p><a class="honor-cert-button" :href="proofUrl" download="荣誉认证证明.pdf">下载PDF查看</a></template></el-dialog>
  </section>
</template>
<script setup lang="ts">
import { onBeforeRouteLeave } from 'vue-router';
import { ElMessageBox } from 'element-plus';
import CertifiedHonorBadge from './CertifiedHonorBadge.vue';
import SportSelect from '@/components/sport-ui/SportSelect.vue';
import { certificationLabels, listHonorApplications, getHonorApplication, getHonorSports, saveHonorApplication, submitHonorApplication, wearCertifiedHonor, setCertifiedHonorVisible, uploadHonorProof, readHonorProof, type HonorApplication, type HonorClaim, type HonorSport } from '@/api/sports/honorCertification';
const emit = defineEmits<{ changed: [] }>();
const applications = ref<HonorApplication[]>([]), sports = ref<HonorSport[]>([]), current = ref<HonorApplication>(), editing = ref(false), busy = ref(false), loading = ref(false), error = ref(''), success = ref(''), fileInput = ref<HTMLInputElement>();
const thisYear = new Date().getFullYear();
const empty = () => ({ eventYear: undefined as number | undefined, eventName: '', sportId: '', place: 1, level: 'world' as const, sourceUrl: '', proofFileIds: [] as string[] });
const form = reactive(empty()), saved = ref(JSON.stringify(form));
const sportOptions = computed(() => sports.value.map(sport => ({ value: sport.id, label: sport.name })));
const placeOptions = [{ value: 1, label: '冠军' }, { value: 2, label: '亚军' }, { value: 3, label: '季军' }];
function setPlace(value: string | number) { const place = Number(value); if ([1, 2, 3].includes(place)) form.place = place; }
const editable = computed(() => !current.value || ['draft','correction','rejected'].includes(current.value.status));
const dirty = computed(() => editing.value && editable.value && JSON.stringify(form) !== saved.value);
const lastReason = computed(() => current.value?.history.filter(h => h.reason).at(-1)?.reason || '');
let mounted = true, generation = 0;
async function load() { const stamp = ++generation; loading.value = true; try { const [a,s] = await Promise.all([listHonorApplications(), getHonorSports()]); if (!mounted || stamp !== generation) return; applications.value = a.data; sports.value = s.data.sports; error.value = ''; } catch { if (mounted && stamp === generation) error.value = '认证记录暂时无法读取，请稍后重试。'; } finally { if (mounted && stamp === generation) loading.value = false; } }
async function discard() { if (!dirty.value) return true; try { await ElMessageBox.confirm('这次修改尚未保存，离开会丢失修改。', '保留修改', { confirmButtonText: '放弃修改', cancelButtonText: '继续编辑', type: 'warning' }); return true; } catch { return false; } }
function apply(item?: HonorApplication) { current.value = item; Object.assign(form, item ? JSON.parse(JSON.stringify(item.details)) : empty()); saved.value = JSON.stringify(form); editing.value = true; error.value = ''; success.value = ''; }
async function start() { if (!busy.value && await discard()) apply(); }
async function select(item: HonorApplication) { if (!busy.value && await discard()) apply(item); }
async function close() { if (await discard()) { editing.value = false; error.value = ''; } }
async function refreshCurrent(id: string) { const r = await getHonorApplication(id); apply(r.data); await load(); emit('changed'); }
async function save() { if (busy.value || !editable.value) return; if (!form.eventYear || !form.eventName.trim() || !form.sportId) { error.value = '请填写实际年份、赛事名称和运动项目。'; return; } busy.value = true; error.value = ''; try { const r = await saveHonorApplication({ ...form, eventYear: Number(form.eventYear) } as HonorClaim, current.value); await refreshCurrent(r.data.result.honorId); success.value = '草稿已保存。'; } catch { error.value = '草稿未保存，当前填写保留；请核对信息和办理权限。'; } finally { busy.value = false; } }
async function submit() { if (!current.value || busy.value || dirty.value) return; busy.value = true; error.value = ''; try { const r = await submitHonorApplication(current.value); await refreshCurrent(r.data.result.honorId); success.value = '已提交核验，办理结果会通过站内信通知。'; } catch(e) { if(e !== 'cancel' && e !== 'close') error.value = '本次未提交，材料保留；可刷新核对版本和证明。'; } finally { busy.value = false; } }
async function wear() { if (!current.value || busy.value) return; busy.value = true; try { const r = await wearCertifiedHonor(current.value, !current.value.worn); await refreshCurrent(r.data.result.honorId); success.value = '佩戴设置已保存。'; } catch { error.value = '佩戴设置未保存，请刷新核对认证状态。'; } finally { busy.value = false; } }
async function visibility() { if (!current.value || busy.value) return; busy.value = true; try { const r = await setCertifiedHonorVisible(current.value, !current.value.publicVisible); await refreshCurrent(r.data.result.honorId); success.value = '公开范围已保存。'; } catch { error.value = '公开范围未保存，请刷新核对认证状态。'; } finally { busy.value = false; } }
async function upload(event: Event) { const input = event.target as HTMLInputElement, file = input.files?.[0]; if (!file || !current.value || busy.value || dirty.value) return; if (file.size > 5*1024*1024 || !['image/jpeg','image/png','image/webp','application/pdf'].includes(file.type)) { error.value = '请选择5MB以内的 JPG、PNG、WebP 或 PDF。'; input.value = ''; return; } busy.value = true; error.value = ''; try { const id = current.value.honorId; await uploadHonorProof(current.value, file); await refreshCurrent(id); success.value = '证明已上传，可以继续补充或提交核验。'; } catch { error.value = '证明未上传完成，现有材料保留，请重试。'; } finally { busy.value = false; input.value = ''; } }
const proofOpen = ref(false), proofUrl = ref(''), proofType = ref('');
function clearProof() { if (proofUrl.value) URL.revokeObjectURL(proofUrl.value); proofUrl.value = ''; proofType.value = ''; }
async function previewProof(fileId: string) { if (!current.value || busy.value) return; busy.value = true; try { const b = await readHonorProof(current.value.honorId, fileId); if(!mounted)return; clearProof(); proofType.value = b.type; proofUrl.value = URL.createObjectURL(b); proofOpen.value = true; } catch { error.value = '证明暂时无法读取，请检查访问权限后重试。'; } finally { busy.value = false; } }
function historyLabel(state: string) { return ({ draft_saved:'草稿调整', submitted:'提交核验', correction:'要求补正', approved:'审核通过', rejected:'未通过', revoked:'认证撤销' } as Record<string,string>)[state] || state; }
function formatTime(value: string) { return new Date(value).toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' }); }
function beforeUnload(e: BeforeUnloadEvent) { if (dirty.value) { e.preventDefault(); e.returnValue = ''; } }
onBeforeRouteLeave(discard); onMounted(() => { load(); window.addEventListener('beforeunload', beforeUnload); }); onBeforeUnmount(() => { mounted = false; ++generation; clearProof(); window.removeEventListener('beforeunload', beforeUnload); });
</script>
<style lang="scss" src="@/assets/styles/honor-certification.scss"></style>
