<template>
  <section class="honor-certification" data-testid="honor-review" :aria-busy="loading || busy">
    <div class="honor-cert-heading"><div><h3>外部荣誉认证</h3><p>核对正式公布结果、申请人身份和获奖项目，再作出认证决定。</p></div><el-select v-model="status" class="honor-review-status" :disabled="busy" @change="load"><el-option v-for="value in states" :key="value" :label="certificationLabels[value]" :value="value" /></el-select><button class="honor-cert-button" :disabled="busy || loading" @click="load">刷新</button></div>
    <p class="honor-cert-note">仅平台负责人办理。认证只确认外部荣誉事实，不变更赛事结果、办赛资格或成长积分。</p>
    <p v-if="error" class="honor-cert-error" role="alert">{{ error }}</p><p v-if="success" class="honor-cert-success" role="status">{{ success }}</p>
    <div class="honor-review-list"><button v-for="item in applications" :key="item.honorId" class="honor-cert-record" :disabled="busy" @click="open(item)"><span><strong>{{ item.details.eventYear }} · {{ item.details.eventName }}</strong><small>{{ item.nickname }} · {{ certificationLabels[item.status] }}</small></span><span>核对 ›</span></button><p v-if="!loading && !applications.length" class="honor-cert-empty">这个状态下暂无认证申请。</p></div>
    <el-dialog v-model="dialog" title="核验荣誉资料" width="min(860px,96vw)" :close-on-click-modal="false" :close-on-press-escape="!busy" :show-close="!busy" append-to-body>
      <section v-if="current" class="honor-certification" data-testid="honor-review-detail">
        <div class="honor-cert-heading"><div><h3>{{ current.details.eventName }}</h3><p>{{ current.nickname }} · {{ current.details.eventYear }}年 · 申请{{ placeName(current.details.place) }}</p></div><span>{{ certificationLabels[current.status] }}</span></div>
        <div class="honor-cert-decision"><b>本人档案归属核对</b>{{ current.applicantIdentity.legalName }}{{ current.applicantIdentity.birthYear ? ' · '+current.applicantIdentity.birthYear+'年出生' : '' }}<br/>证件资料：{{ current.applicantIdentity.hasIdentityDocument ? '已填写证件，号码不在此展示' : '未填写证件，须依据材料另行核实归属' }}。档案核验状态：{{ identityStatus(current.applicantIdentity.profileVerificationStatus) }}。<br/>昵称不作为实名证明；确认卡绑定当前账号、档案和版本。</div>
        <p v-if="current.details.sourceUrl" class="honor-cert-note">申请人提供的结果页面：<a :href="current.details.sourceUrl" target="_blank" rel="noopener noreferrer">打开来源链接</a></p>
        <div class="honor-cert-proof-list"><button v-for="(file,index) in current.details.proofFileIds" :key="file" class="honor-cert-button" :disabled="busy" @click="previewProof(file)">查看私有证明 {{ index + 1 }}</button></div>
        <p class="honor-cert-note">请核实材料确属申请人，赛事为世界级赛事，名次与正式公布一致。申请人的填写仅作为待核对内容。</p>
        <section v-if="current.verified.eventName" class="honor-verified-facts" data-testid="honor-verified-snapshot">
          <h4>已核实的外部赛事事实</h4>
          <p v-if="current.status === 'revoked'" class="honor-cert-note">此认证已撤销，以下为既有审核记录，不再作为有效荣誉展示。</p>
          <dl><div><dt>真实年份</dt><dd>{{ current.verified.eventYear }}年</dd></div><div><dt>运动项目</dt><dd>{{ sports.find(sport => sport.id === current?.verified.sportId)?.name || '已核实项目' }}</dd></div><div class="wide"><dt>赛事完整名称</dt><dd>{{ current.verified.eventName }}</dd></div><div><dt>世界赛事名次</dt><dd>世界{{ placeName(current.verified.place || 0) }}</dd></div><div><dt>正式公布单位</dt><dd>{{ current.verified.officialIssuer }}</dd></div><div class="wide"><dt>正式结果依据</dt><dd><a :href="current.verified.officialResultsUrl" target="_blank" rel="noopener noreferrer">{{ current.verified.officialResultsUrl }}</a></dd></div></dl>
        </section>
        <form class="honor-cert-form" @submit.prevent="decide('approve')">
          <template v-if="current.status === 'submitted'">
            <label>核实后的年份<input v-model.number="facts.eventYear" data-testid="honor-confirm-year" type="number" min="1900" :max="thisYear" required :disabled="busy" /></label>
            <label>核实后的运动项目<SportSelect v-model="facts.sportId" data-testid="honor-confirm-sport" aria-label="核实后的运动项目" :options="sports.map(sport => ({ value: sport.id, label: sport.name }))" required :disabled="busy" /></label>
            <label class="wide">核实后的赛事完整名称<input v-model="facts.eventName" data-testid="honor-confirm-event" maxlength="100" required :disabled="busy" /></label>
            <label>核实后的名次<SportSelect v-model="facts.place" data-testid="honor-confirm-place" aria-label="核实后的名次" :options="[{ value: 1, label: '冠军' }, { value: 2, label: '亚军' }, { value: 3, label: '季军' }]" :disabled="busy" /></label>
            <label>正式公布单位<input v-model="facts.officialIssuer" data-testid="honor-confirm-issuer" maxlength="160" required :disabled="busy" placeholder="独立核对的赛事公布主体" /></label>
            <label class="wide">正式结果依据<input v-model="facts.officialResultsUrl" data-testid="honor-confirm-url" type="url" maxlength="1000" required :disabled="busy" placeholder="核实后的公开HTTPS结果地址" /></label>
          </template>
          <label class="wide">{{ current.status === 'approved' ? '撤销依据与给申请人的说明' : '核验结论或需要补正的内容' }}<textarea v-model="reason" data-testid="honor-review-reason" rows="4" maxlength="2000" required :disabled="busy" placeholder="请具体说明核实内容、缺少的材料或不予通过的理由" /></label>
          <label v-if="current.status === 'submitted'" class="wide honor-review-check"><input v-model="verified" type="checkbox" :disabled="busy" />我已独立核实本人归属、世界赛事范围、真实年份、赛事名称、项目、名次及公布依据。</label>
          <div class="wide honor-cert-actions"><template v-if="current.status === 'submitted'"><button class="honor-cert-button primary" data-testid="honor-review-approve" :disabled="busy || !verified || !reason.trim()">通过认证</button><button type="button" class="honor-cert-button" data-testid="honor-review-correction" :disabled="busy || !reason.trim()" @click="decide('correction')">要求补正</button><button type="button" class="honor-cert-button" data-testid="honor-review-reject" :disabled="busy || !reason.trim()" @click="decide('reject')">不予通过</button></template><button v-if="current.status === 'approved'" type="button" class="honor-cert-button" data-testid="honor-review-revoke" :disabled="busy || !reason.trim()" @click="decide('revoke')">撤销认证</button></div>
        </form>
        <p v-if="dialogError" class="honor-cert-error" role="alert">{{ dialogError }}</p>
        <details v-if="current.history.length" class="honor-cert-history"><summary>既有办理记录 · {{ current.history.length }}</summary><article v-for="(entry,index) in [...current.history].reverse()" :key="index"><b>{{ stateLabel(entry.state) }}</b><time>{{ new Date(entry.at).toLocaleString('zh-CN',{timeZone:'Asia/Shanghai'}) }}</time><p>{{ entry.reason || '申请资料已留存' }}</p></article></details>
      </section>
    </el-dialog>
    <el-dialog v-model="proofOpen" title="私有证明 · 仅供核验" width="min(780px,94vw)" append-to-body @closed="clearProof"><img v-if="proofUrl && proofType.startsWith('image/')" class="honor-proof-preview" :src="proofUrl" alt="申请人提交的认证证明" /><template v-else-if="proofUrl"><p>请妥善保管申请人的材料。</p><a class="honor-cert-button" :href="proofUrl" download="荣誉认证证明.pdf">下载PDF查看</a></template></el-dialog>
  </section>
</template>
<script setup lang="ts">
import { certificationLabels, reviewHonorApplications, getHonorApplication, getHonorSports, reviewHonorApplication, readHonorProof, type HonorApplication, type HonorSport, type CertificationStatus, type VerifiedHonorFacts } from '@/api/sports/honorCertification';
import SportSelect from '@/components/sport-ui/SportSelect.vue';
const states:CertificationStatus[] = ['submitted','approved','correction','rejected','revoked'];
const status=ref<CertificationStatus>('submitted'),applications=ref<HonorApplication[]>([]),sports=ref<HonorSport[]>([]),current=ref<HonorApplication>(),busy=ref(false),loading=ref(false),error=ref(''),dialogError=ref(''),success=ref(''),dialog=ref(false),reason=ref(''),verified=ref(false);
const thisYear=new Date().getFullYear(),facts=reactive<VerifiedHonorFacts>({eventYear:thisYear,eventName:'',sportId:'',place:1,level:'world',officialIssuer:'',officialResultsUrl:''});let mounted=true,generation=0;
async function load(){const stamp=++generation;loading.value=true;try{const[a,s]=await Promise.all([reviewHonorApplications(status.value),getHonorSports()]);if(!mounted||stamp!==generation)return;applications.value=a.data;sports.value=s.data.sports;error.value='';}catch{if(mounted&&stamp===generation)error.value='无法读取认证申请，请核对平台负责人权限。';}finally{if(mounted&&stamp===generation)loading.value=false;}}
async function open(item:HonorApplication){if(busy.value)return;busy.value=true;dialogError.value='';try{const r=await getHonorApplication(item.honorId);current.value=r.data;Object.assign(facts,{eventYear:r.data.details.eventYear,eventName:r.data.details.eventName,sportId:r.data.details.sportId,place:r.data.details.place,officialIssuer:'',officialResultsUrl:''},r.data.verified);reason.value='';verified.value=false;dialog.value=true;}catch{error.value='申请详情暂时无法读取，请重试。';}finally{busy.value=false;}}
function placeName(place:number){return ['','冠军','亚军','季军'][place]||'未知名次';}
function identityStatus(value:string){return ({unverified:'未核验',pending:'待核验',verified:'已核验',disputed:'存在争议'} as Record<string,string>)[value]||'待核对';}
function stateLabel(state:string){return state==='draft_saved'?'草稿调整':(certificationLabels as Record<string,string>)[state]||state;}
async function decide(decision:'approve'|'correction'|'reject'|'revoke'){if(!current.value||busy.value||!reason.value.trim()||(decision==='approve'&&!verified.value))return;busy.value=true;dialogError.value='';try{await reviewHonorApplication(current.value,decision,reason.value,decision==='approve'?{...facts}:undefined);dialog.value=false;await load();success.value='审核决定已保存，已通知申请人。';}catch(e){if(e!=='cancel'&&e!=='close')dialogError.value='此次审核未保存。请核对资料、版本和权限后重试。';}finally{busy.value=false;}}
const proofOpen=ref(false),proofUrl=ref(''),proofType=ref('');
function clearProof(){if(proofUrl.value)URL.revokeObjectURL(proofUrl.value);proofUrl.value='';proofType.value='';}
async function previewProof(file:string){if(!current.value||busy.value)return;busy.value=true;try{const blob=await readHonorProof(current.value.honorId,file);if(!mounted)return;clearProof();proofType.value=blob.type;proofUrl.value=URL.createObjectURL(blob);proofOpen.value=true;}catch{dialogError.value='证明暂时无法读取，请核对材料归属与访问权限。';}finally{busy.value=false;}}
onMounted(load);onBeforeUnmount(()=>{mounted=false;++generation;clearProof();});
</script>
<style lang="scss" src="@/assets/styles/honor-certification.scss"></style>
<style scoped lang="scss">
.honor-verified-facts{padding:16px;margin:14px 0;border:1px solid var(--s-line);border-radius:16px;background:var(--s-paper);h4{margin:0 0 12px;font-size:14px;}dl{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px;margin:0;}dt{font-size:11px;color:var(--s-muted);margin-bottom:5px;}dd{margin:0;font-size:13px;overflow-wrap:anywhere;}a{color:var(--s-ink);text-decoration:underline;}.wide{grid-column:1/-1;}}
@media(max-width:560px){.honor-verified-facts dl{grid-template-columns:minmax(0,1fr);}}
</style>
