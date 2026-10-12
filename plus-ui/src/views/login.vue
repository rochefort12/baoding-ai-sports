<template>
  <ConsumerAuthLayout title="工作账号登录" description="政府工作人员和平台管理员使用分配的账号登录。">
    <p v-if="bootstrapError" class="sport-inline-message" role="alert">
      {{ bootstrapError }} <button class="sport-text-retry" type="button" @click="bootstrap">重新加载</button>
    </p>
    <el-form
      ref="loginRef"
      :model="loginForm"
      :rules="loginRules"
      :validate-on-rule-change="false"
      class="sport-work-login"
      @submit.prevent="handleLogin"
    >
      <el-form-item prop="username"
        ><SportField
          v-model="loginForm.username"
          label="工作账号"
          name="username"
          placeholder="请输入工作账号"
          autocomplete="username"
          :disabled="loading"
          required
          @blur="validateField('username')"
      /></el-form-item>
      <el-form-item prop="password"
        ><SportField
          v-model="loginForm.password"
          label="密码"
          name="password"
          type="password"
          placeholder="请输入密码"
          autocomplete="current-password"
          :disabled="loading"
          required
          @blur="validateField('password')"
      /></el-form-item>
      <el-form-item v-if="captchaEnabled" prop="code">
        <div class="sport-auth-code">
          <SportField
            :model-value="loginForm.code || ''"
            label="图形验证码"
            name="captcha"
            placeholder="输入右侧字符"
            :maxlength="10"
            required
            @update:model-value="loginForm.code = $event"
            @blur="validateField('code')"
          />
          <button type="button" class="sport-auth-captcha" aria-label="更换图形验证码" :disabled="loading || captchaLoading" @click="getCode">
            <img v-if="codeUrl" :src="codeUrl" alt="图形验证码" draggable="false" /><span v-else>加载中</span>
          </button>
        </div>
      </el-form-item>
      <SportButton type="submit" block size="lg" :busy="loading" :disabled="captchaLoading || !!bootstrapError">登录工作台</SportButton>
    </el-form>
    <div class="consumer-links">
      <router-link :to="participantLoginTarget">手机号登录</router-link><router-link to="/portal/home">浏览赛事</router-link>
    </div>
    <WeChatLoginButton :disabled="loading" :authorize="authorizeWeChat" />
  </ConsumerAuthLayout>
</template>

<script setup lang="ts">
import ConsumerAuthLayout from '@/components/consumer/ConsumerAuthLayout.vue';
import SportField from '@/components/sport-ui/SportField.vue';
import SportButton from '@/components/sport-ui/SportButton.vue';
import WeChatLoginButton from '@/components/consumer/WeChatLoginButton.vue';
import { getCodeImg } from '@/api/login';
import { authorizeWorkWeChat } from '@/api/wechatLogin';
import { useUserStore } from '@/store/modules/user';
import { LoginData } from '@/api/types';
import { to } from 'await-to-js';
import { useI18n } from 'vue-i18n';
import { removePlatformToken } from '@/utils/auth';
import { sanitizeAdminTarget, sanitizeReturnTo, splitTarget } from '@/utils/returnTo';
const userStore = useUserStore();
const router = useRouter();
const { t } = useI18n();

const loginForm = ref<LoginData>({
  username: '',
  password: '',
  rememberMe: false,
  code: '',
  uuid: ''
} as LoginData);

const codeUrl = ref('');
const loading = ref(false);
const captchaLoading = ref(false),
  bootstrapError = ref('');
// 验证码开关。关闭后不保留必填校验，避免输入框隐藏后仍拦登录。
const captchaEnabled = ref(true);
const loginRules = computed<ElFormRules>(() => ({
  username: [{ required: true, trigger: 'blur', message: t('login.rule.username.required') }],
  password: [{ required: true, trigger: 'blur', message: t('login.rule.password.required') }],
  ...(captchaEnabled.value ? { code: [{ required: true, trigger: 'change', message: t('login.rule.code.required') }] } : {})
}));
const redirect = ref('/');
const loginRef = ref<ElFormInstance>();
const participantLoginTarget = computed(() => {
  const returnTo = router.currentRoute.value.query.returnTo;
  return { path: '/portal/login', query: returnTo ? { returnTo: sanitizeReturnTo(returnTo) } : {} };
});

watch(
  () => router.currentRoute.value,
  (newRoute: any) => {
    redirect.value = newRoute.query && newRoute.query.redirect;
  },
  { immediate: true }
);

const validateField = (name: string) => {
  loginRef.value?.validateField(name).catch(() => {});
};

const handleLogin = () => {
  if (loading.value || captchaLoading.value || bootstrapError.value) return;
  loginRef.value?.validate(async (valid: boolean) => {
    if (valid) {
      loading.value = true;
      localStorage.removeItem('username');
      localStorage.removeItem('password');
      localStorage.removeItem('rememberMe');
      const payload: LoginData = {
        ...loginForm.value,
        clientId: '',
        // 账号所属组织由服务端核对；表单和地址参数都不能指定租户。
        grantType: 'work-password'
      };
      const [err] = await to(userStore.login(payload));
      if (!err) {
        removePlatformToken();
        const target = splitTarget(sanitizeAdminTarget(redirect.value));
        await router.push({ path: target.path, query: target.query });
        loading.value = false;
      } else {
        loading.value = false;
        // 重新获取验证码
        if (captchaEnabled.value) {
          await getCode();
        }
      }
    } else {
      return;
    }
  });
};

/**
 * 获取验证码
 */
const getCode = async () => {
  if (captchaLoading.value) return;
  captchaLoading.value = true;
  try {
    const { data } = await getCodeImg();
    captchaEnabled.value = data.captchaEnabled === undefined ? true : data.captchaEnabled;
    if (captchaEnabled.value) {
      loginForm.value.code = '';
      codeUrl.value = 'data:image/gif;base64,' + data.img;
      loginForm.value.uuid = data.uuid;
    } else {
      loginForm.value.code = '';
      loginForm.value.uuid = '';
      codeUrl.value = '';
    }
  } catch {
    bootstrapError.value = '登录验证暂时无法加载，请重试。';
  } finally {
    captchaLoading.value = false;
  }
};

const clearStoredCredentials = () => {
  localStorage.removeItem('username');
  localStorage.removeItem('password');
  localStorage.removeItem('rememberMe');
};

const authorizeWeChat = () => authorizeWorkWeChat();

async function bootstrap() {
  if (captchaLoading.value) return;
  bootstrapError.value = '';
  await getCode();
}
onMounted(() => {
  clearStoredCredentials();
  bootstrap();
});
</script>
