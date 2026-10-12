<template>
  <ConsumerShell>
    <ConsumerPageHeader title="我的" description="运动名片、参赛资料与账号设置。"><router-link class="btn" to="/portal/growth">我的成长与荣誉</router-link></ConsumerPageHeader>
    <div v-if="route.query.returnTo" class="notice warn" style="margin-bottom: 22px">
      <ConsumerIcon name="file" />补齐必要资料后，回到刚才的操作继续办理。
    </div>
    <ConsumerState v-if="loading" loading title="正在读取本人档案" icon="user" />
    <ConsumerState v-else-if="loadError" error title="暂时无法读取档案" :description="loadError" icon="user">
      <button class="btn" @click="load">重新读取</button>
    </ConsumerState>
    <div v-else class="profile-layout">
      <aside class="profile-menu" :class="{ 'is-prerequisite': route.query.returnTo }">
        <div class="profile-person">
          <SportsProfileCard :honors="certifiedHonors" :sport-id="profileSport">
          <SportsAvatar v-if="display" :nickname="display.display.nickname" :account-id="display.accountId" :avatar-file-id="display.display.avatar_file_id" :tone="display.display.avatar_style" :rank-name="personalGrowth?.rank" :rank-level="personalGrowth?.rankIndex" :points="personalGrowth?.points" :title="personalTitle" :title-code="personalGrowth?.equipment?.title_code" />
          <span v-else class="account-avatar">{{ (home?.displayName || '我').slice(0, 1) }}</span>
          </SportsProfileCard>
          <p v-if="honorError" class="profile-honor-error">认证荣誉暂时无法读取</p>
          <p>{{ home?.self ? '参赛资料已登记' : '尚未登记参赛资料' }}</p>
        </div>
        <el-select v-if="profileSports.length>1" v-model="profileSport" aria-label="选择名片运动" style="width:150px;margin:10px auto" @change="profileSportChanged"><el-option v-for="sport in profileSports" :key="sport.id" :value="sport.id" :label="sport.name"/></el-select>
        <router-link class="profile-card-link" to="/portal/growth">编辑昵称、称号与公开范围<ConsumerIcon name="chevron"/></router-link>
        <router-link class="active" to="/portal/profile"><ConsumerIcon name="user" />完善资料<ConsumerIcon name="chevron" /></router-link
        ><router-link v-for="item in shortcuts" :key="item.to" :to="item.to"
          ><ConsumerIcon :name="item.icon" /><span class="shortcut-label">{{ item.label }}</span><span v-if="item.to === '/portal/notices' && unread" class="badge orange" :aria-label="unread+'条未读消息'">{{ unread }}</span
          ><ConsumerIcon name="chevron" /></router-link
        ><el-button link :loading="switchingWork" @click="switchWork">平台／政府管理<ConsumerIcon name="chevron" /></el-button>
        <el-button link @click="logout" style="margin-top: 12px">退出登录</el-button>
      </aside>
      <div>
        <section class="consumer-card profile-form">
          <div class="between">
            <h2>完善资料</h2>
            <span class="badge gray">仅本人维护</span>
          </div>
          <div v-if="display" class="profile-avatar-field" data-testid="profile-avatar-field">
            <div><h3>我的头像</h3><p>在名片和队伍中展示，公开范围可在运动名片中设置。</p></div>
            <SportsAvatarEditor :expected-version="display.display.version" @saved="avatarSaved" />
          </div>
          <p class="consumer-muted">姓名、出生日期和手机号用于参赛。证件资料由本人填写，不等于已通过实名核验。</p>
          <el-form label-position="top"
            ><div class="form-two-columns">
              <el-form-item label="真实姓名" required>
                <el-input v-model="selfForm.legalName" maxlength="100" />
              </el-form-item>
              <el-form-item label="出生日期" required>
                <el-date-picker v-model="selfForm.birthDate" value-format="YYYY-MM-DD" type="date" />
              </el-form-item>
              <el-form-item label="性别" required>
                <el-select v-model="selfForm.gender" placeholder="请选择">
                  <el-option label="男" value="male" />
                  <el-option label="女" value="female" />
                  <el-option label="其他" value="other" />
                </el-select>
              </el-form-item>
              <el-form-item label="手机号" required>
                <el-input v-model="selfForm.mobile" maxlength="11" disabled />
                <p class="field-hint">这是注册时验证过的手机号，不能改成其他号码。</p>
              </el-form-item>
            </div>
            <details class="optional-fields">
              <summary>补充资料 · 选填</summary>
              <div class="form-two-columns">
                <el-form-item label="证件类型">
                  <el-select v-model="selfForm.idDocType" clearable placeholder="可不填">
                    <el-option label="居民身份证" value="id_card" />
                    <el-option label="护照" value="passport" />
                    <el-option label="港澳台通行证" value="hmt_pass" />
                    <el-option label="其他" value="other" />
                  </el-select>
                </el-form-item>
                <el-form-item label="证件号码">
                  <el-input v-model="selfForm.idNumber" maxlength="40" />
                </el-form-item>
                <el-form-item label="所在城市">
                  <el-input v-model="selfForm.city" maxlength="100" />
                </el-form-item>
                <el-form-item label="详细地址">
                  <el-input v-model="selfForm.addressDetail" maxlength="200" />
                </el-form-item>
                <el-form-item label="血型">
                  <el-select v-model="selfForm.bloodType" clearable placeholder="可不填">
                    <el-option label="A" value="A" />
                    <el-option label="B" value="B" />
                    <el-option label="AB" value="AB" />
                    <el-option label="O" value="O" />
                    <el-option label="未知" value="unknown" />
                  </el-select>
                </el-form-item>
                <el-form-item label="衣服尺码">
                  <el-select v-model="selfForm.clothingSize" clearable placeholder="可不填">
                    <el-option v-for="size in clothingSizes" :key="size" :label="size" :value="size" />
                  </el-select>
                </el-form-item>
                <el-form-item label="紧急联系人">
                  <el-input v-model="selfForm.emergencyContactName" maxlength="100" />
                </el-form-item>
                <el-form-item label="紧急联系号码">
                  <el-input v-model="selfForm.emergencyContactPhone" maxlength="11" />
                </el-form-item>
              </div>
            </details>
            <p class="consumer-note">当前资料更新不会改变已经提交的报名快照。</p>
            <el-button type="primary" @click="submitSelf">{{ route.query.returnTo ? '保存并继续办理' : '保存本人档案' }}</el-button></el-form
          >
        </section>
        <section class="consumer-card profile-honors"><HonorCertification @changed="honorChanged" /></section>
        <details class="account-settings">
          <summary>账号设置与注销</summary>
          <section class="consumer-card">
            <h3>注销账号</h3>
            <p class="consumer-muted">注销前需要验证当前手机号。有效报名、未结资金或尚未移交的队长 / 管理职责会阻止注销，历史业务记录按规则保留。</p>
            <el-form label-position="top">
              <p v-if="debugCode" class="field-hint">本地模拟验证码：{{ debugCode }}。当前注销验证码为模拟通道，不代表真实短信已发送。</p>
              <el-form-item label="注销验证码">
                <el-input v-model="closeCode" maxlength="6" />
              </el-form-item>
              <el-button @click="sendClose">获取注销验证码</el-button>
              <el-button type="danger" @click="confirmClose">确认注销</el-button>
            </el-form>
          </section>
        </details>
      </div>
    </div>
  </ConsumerShell>
</template>
<script setup lang="ts" name="PortalIdentity">
import { computed, onMounted, reactive, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ElMessage } from 'element-plus';
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import ConsumerPageHeader from '@/components/consumer/ConsumerPageHeader.vue';
import ConsumerState from '@/components/consumer/ConsumerState.vue';
import { useUserStore } from '@/store/modules/user';
import ConsumerShell from '@/layout/consumer/ConsumerShell.vue';
import SportsAvatar from '@/components/consumer/SportsAvatar.vue';
import SportsAvatarEditor from '@/components/consumer/SportsAvatarEditor.vue';
import HonorCertification from '@/components/consumer/HonorCertification.vue';
import SportsProfileCard from '@/components/consumer/SportsProfileCard.vue';
import { myCertifiedHonors, type CertifiedHonor } from '@/api/sports/honorCertification';
import { getDisplay, getGrowthHome, type DisplayProfile } from '@/api/sports/phase1';
import { getGrowthRankCard, type GrowthRankCard } from '@/api/sports/growth';
import request from '@/utils/request';
import { bindSelf, getIdentity, IdentityHome } from '@/api/sports/identity';
import { closeParticipantAccount, sendCloseSms } from '@/api/login';
import { listNotices } from '@/api/sports/notice';
import { removePlatformToken, removeToken } from '@/utils/auth';
import { firstQuery, sanitizeReturnTo } from '@/utils/returnTo';
import { openWorkAccountLogin } from '@/utils/workAccountEntry';

const route = useRoute();
const router = useRouter();
const switchingWork = ref(false);
const switchWork = async () => {
  if (switchingWork.value) return;
  switchingWork.value = true;
  try { await openWorkAccountLogin(); } finally { switchingWork.value = false; }
};
const home = ref<IdentityHome>();
const display = ref<DisplayProfile>();
const personalGrowth=ref<GrowthRankCard>(),profileSports=ref<{id:string;name:string}[]>([]),profileSport=ref('');
const certifiedHonors=ref<CertifiedHonor[]>([]),honorError=ref(false);
let honorRevision=0;
const loadHonorBadge=async()=>{const stamp=++honorRevision;certifiedHonors.value=[];honorError.value=false;if(!profileSport.value)return;try{const response=await myCertifiedHonors(profileSport.value);if(stamp===honorRevision)certifiedHonors.value=response.data;}catch{if(stamp===honorRevision)honorError.value=true;}};
const personalTitle=computed(()=>personalGrowth.value?.titles.find(title=>title.title_code===personalGrowth.value?.equipment?.title_code)?.title);
let personalRevision=0;
const loadPersonalGrowth=async()=>{const revision=++personalRevision;personalGrowth.value=undefined;try{if(!home.value?.self)return;if(!profileSports.value.length){const rows=(await getGrowthHome()).data as {owner_type:string;sport_id:string;sport_name:string}[];profileSports.value=rows.filter(row=>row.owner_type==='person').map(row=>({id:row.sport_id,name:row.sport_name}));if(!profileSports.value.length){const types=await request({url:'/sports/types',headers:{isToken:false}});const sport=types.data.sports.find((item:{code:string})=>item.code==='badminton');if(sport)profileSports.value=[{id:sport.id,name:sport.name}];}profileSport.value=profileSport.value||profileSports.value[0]?.id||'';}if(profileSport.value){const response=await getGrowthRankCard(profileSport.value);if(revision===personalRevision)personalGrowth.value=response.data;}}catch{ /* Rank remains absent when the sport rule or growth is unavailable; identity editing stays usable. */ }};
const loadDisplay = async () => { try { display.value = (await getDisplay()).data; } catch { display.value = undefined; } };
const avatarSaved = async () => { await loadDisplay(); window.dispatchEvent(new CustomEvent('sports-display-changed')); };
const profileSportChanged=async()=>{await Promise.all([loadPersonalGrowth(),loadHonorBadge()]);};
// Honor display refresh must not discard an unsaved participant profile form.
const honorChanged = async () => { await Promise.all([loadDisplay(), loadPersonalGrowth(),loadHonorBadge()]); window.dispatchEvent(new CustomEvent('sports-display-changed')); };
const unread = ref(0);
const closeCode = ref('');
const debugCode = ref('');
const shortcuts = [
  { to: '/portal/growth', label: '成长与名片', icon: 'award' },
  { to: '/portal/rooms', label: '找队友', icon: 'team' },
  { to: '/portal/registration', label: '我的参赛', icon: 'events' },
  { to: '/portal/teams', label: '我的队伍', icon: 'team' },
  { to: '/portal/results', label: '我的赛果', icon: 'award' },
  { to: '/portal/proofs', label: '成绩证明', icon: 'file' },
  { to: '/portal/notices', label: '我的消息', icon: 'bell' },
  { to: '/portal/organization', label: '我要办赛', icon: 'venue' },
  { to: '/portal/feedback', label: '意见反馈', icon: 'file' }
];
const logout = async () => {
  await useUserStore().logout();
  await router.replace('/portal/home');
};
const clothingSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];

const idCardWarning = (idDocType: string, idNumber: string, birthDate: string, gender: string) => {
  if (idDocType !== 'id_card' || !idNumber.trim()) {
    return '';
  }
  const id = idNumber.trim().toUpperCase();
  if (!/^\d{17}[\dX]$/.test(id)) {
    return '居民身份证应为18位';
  }
  const weights = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2];
  const codes = '10X98765432';
  const sum = weights.reduce((total, weight, index) => total + Number(id[index]) * weight, 0);
  if (codes[sum % 11] !== id[17]) {
    return '居民身份证校验位不正确';
  }
  const birth = `${id.slice(6, 10)}-${id.slice(10, 12)}-${id.slice(12, 14)}`;
  if (birthDate && birth !== birthDate) {
    return '身份证中的出生日期与填写的出生日期不一致';
  }
  const idGender = Number(id[16]) % 2 === 1 ? 'male' : 'female';
  if (gender && gender !== 'other' && gender !== idGender) {
    return '身份证中的性别与填写的性别不一致';
  }
  return '';
};
const selfForm = reactive({
  legalName: '',
  birthDate: '',
  gender: '',
  mobile: '',
  idDocType: '',
  idNumber: '',
  city: '',
  addressDetail: '',
  bloodType: '',
  clothingSize: '',
  emergencyContactName: '',
  emergencyContactPhone: ''
});

const loading = ref(true);
const loadError = ref('');
const load = async () => {
  loading.value = true;
  loadError.value = '';
  try {
    await loadData();
  } catch {
    loadError.value = '档案读取失败，请稍后重试。';
  } finally {
    loading.value = false;
  }
};
const loadData = async () => {
  const res = await getIdentity();
  home.value = res.data;
  await loadDisplay();
  await loadPersonalGrowth();
  await loadHonorBadge();
  try {
    const notices = await listNotices();
    unread.value = (notices.data || []).filter((item: { read: boolean }) => !item.read).length;
  } catch {
    unread.value = 0;
  }
  const self = res.data?.self;
  if (res.data?.loginPhone) {
    selfForm.mobile = res.data.loginPhone;
  }
  if (!self) {
    return;
  }
  selfForm.legalName = self.legalName || '';
  selfForm.birthDate = self.birthDate || '';
  selfForm.gender = self.gender || '';
  if (res.data?.loginPhone) {
    selfForm.mobile = res.data.loginPhone;
  } else {
    selfForm.mobile = self.mobile || '';
  }
  selfForm.idDocType = self.idDocType || '';
  selfForm.idNumber = self.idNumber || '';
  selfForm.city = self.city || '';
  selfForm.addressDetail = self.addressDetail || '';
  selfForm.bloodType = self.bloodType || '';
  selfForm.clothingSize = self.clothingSize || '';
  selfForm.emergencyContactName = self.emergencyContactName || '';
  selfForm.emergencyContactPhone = self.emergencyContactPhone || '';
};

const submitSelf = async () => {
  if (!selfForm.legalName.trim()) {
    ElMessage.error('请填写真实姓名');
    return;
  }
  if (!selfForm.birthDate) {
    ElMessage.error('请填写出生日期');
    return;
  }
  if (!selfForm.gender) {
    ElMessage.error('请选择性别');
    return;
  }
  if (!/^1[3-9]\d{9}$/.test(selfForm.mobile)) {
    ElMessage.error('请填写中国大陆11位手机号');
    return;
  }
  const warning = idCardWarning(selfForm.idDocType, selfForm.idNumber, selfForm.birthDate, selfForm.gender);
  if (warning) {
    ElMessage.warning(warning + '。可继续保存，请核对填写的信息。');
  }
  const payload = { ...selfForm };
  if (payload.idDocType === 'id_card' && payload.idNumber) {
    payload.idNumber = payload.idNumber.trim().toUpperCase();
  }
  await bindSelf(payload);
  ElMessage.success('本人档案已保存');
  const back = firstQuery(route.query.returnTo);
  if (back) {
    await router.push(sanitizeReturnTo(back));
    return;
  }
  await load();
};

const sendClose = async () => {
  const res = await sendCloseSms({ captchaVerifyParam: 'local' });
  debugCode.value = res.data?.debugCode || '';
  ElMessage.success('如果短信已接通，验证码会发到当前绑定手机号。当前是本地模拟。');
};

const confirmClose = async () => {
  if (!closeCode.value.trim()) {
    ElMessage.error('请填写注销验证码');
    return;
  }
  await closeParticipantAccount(closeCode.value.trim());
  removeToken();
  removePlatformToken();
  ElMessage.success('账号已注销');
  window.location.href = '/portal/home';
};

onMounted(load);
</script>
<style scoped>
.profile-honors{margin-top:24px}.profile-avatar-field{padding:20px;border:1px solid var(--s-line);border-radius:18px;background:#f9f9f7;margin:23px 0}.profile-avatar-field h3{font-size:14px;margin:0 0 7px}.profile-avatar-field p{font-size:11px;color:var(--s-muted);line-height:1.8;margin:0 0 16px}.profile-avatar-field :deep(.avatar-edit-trigger){min-height:42px}.profile-avatar-field :deep(.avatar-edit-hint){line-height:1.8;overflow-wrap:anywhere}
.profile-layout{gap:26px;grid-template-columns:265px minmax(0,1fr)}.profile-menu{background:var(--s-surface,#fff);border-radius:24px;padding:26px;align-self:start}.profile-person{display:flex;align-items:center;flex-direction:column;padding:10px 0 20px;gap:11px;text-align:center;border-bottom:1px solid var(--s-line);margin-bottom:20px}.profile-menu :deep(.sports-avatar-editor),.profile-menu>.profile-card-link,.profile-menu>:deep(.el-select){grid-column:1/-1}.shortcut-label{min-width:0;white-space:nowrap}.profile-menu .badge{flex-shrink:0;padding:3px 6px;font-size:10px}.profile-person>p{color:var(--s-muted);font-size:11px;margin:4px 0}.profile-menu :deep(.avatar-edit-trigger){width:100%;justify-content:center;font-size:12px;padding:10px}.profile-menu :deep(.avatar-edit-hint){font-size:10px;line-height:1.8}.profile-card-link{font-size:11px!important;padding:12px 0!important;color:var(--s-muted)!important;border-bottom:1px solid var(--s-line);margin-bottom:13px}.profile-menu>a:not(.profile-card-link){font-size:12px;padding:13px 9px;border-radius:10px}.profile-menu>a.active{background:#f1e8e0;color:var(--s-primary)}.profile-form :deep(.el-form-item__label){font-size:12px;color:var(--s-muted)}.profile-form :deep(.el-input__wrapper),.profile-form :deep(.el-select__wrapper){min-height:43px;border-radius:10px}.profile-form .between>h2{font-size:22px;letter-spacing:-.04em}.profile-form>.consumer-muted{font-size:12px;line-height:1.9;margin:15px 0 25px}.optional-fields{border-top:1px solid var(--s-line);padding-top:17px;margin:13px 0 25px}.optional-fields summary{font-size:12px;color:var(--s-muted);cursor:pointer;margin-bottom:17px}.account-settings{margin-top:24px}.account-settings>summary{font-size:12px;color:var(--s-muted);padding:15px 0;cursor:pointer}@media(max-width:800px){.profile-layout{display:flex;flex-direction:column}.profile-menu{width:100%;padding:23px}.profile-menu :deep(.sports-avatar){padding-top:0}.profile-person{padding-top:0}.profile-form>.consumer-muted{font-size:11px}.profile-menu>a:not(.profile-card-link){padding:12px 7px;gap:5px}.profile-card-link{margin-bottom:9px}.profile-menu :deep(.avatar-edit-hint){font-size:11px}}
</style>
