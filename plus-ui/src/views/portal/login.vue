<template>
  <ConsumerAuthLayout title="欢迎回来" description="登录后，继续组队、报名与查看战绩。">
    <p v-if="captchaError" class="sport-inline-message" role="alert">
      {{ captchaError }} <button type="button" class="sport-text-retry" @click="loadCaptcha">重新加载</button>
    </p>
    <form class="sport-auth-native" novalidate @submit.prevent="submit">
      <SportField
        v-model="form.phone"
        label="手机号"
        name="phone"
        :maxlength="11"
        placeholder="请输入手机号"
        autocomplete="username"
        inputmode="tel"
        required
        :disabled="loading"
        :error="errors.phone"
        @blur="validateField('phone')"
      />
      <SportField
        v-model="form.password"
        label="密码"
        name="password"
        type="password"
        placeholder="请输入密码"
        autocomplete="current-password"
        required
        :disabled="loading"
        :error="errors.password"
        @blur="validateField('password')"
      />
      <div v-if="captchaEnabled" class="sport-auth-code">
        <SportField
          v-model="form.code"
          label="图形验证码"
          name="captcha"
          :maxlength="10"
          placeholder="输入右侧字符"
          required
          :disabled="loading"
          :error="errors.code"
          @blur="validateField('code')"
        />
        <button type="button" class="sport-auth-captcha" aria-label="更换图形验证码" :disabled="loading" @click="loadCaptcha">
          <img v-if="codeUrl" :src="codeUrl" alt="图形验证码" draggable="false" /><span v-else>加载中</span>
        </button>
      </div>
      <SportButton type="submit" block size="lg" :busy="loading" :disabled="!!captchaError || captchaLoading"
        >登录<template #trailing><ConsumerIcon name="arrow" /></template
      ></SportButton>
    </form>
    <div class="consumer-links">
      <router-link :to="{ path: '/portal/register', query: returnQuery }">注册账号</router-link
      ><router-link :to="{ path: '/portal/forgot', query: returnQuery }">忘记密码</router-link>
    </div>
  </ConsumerAuthLayout>
</template>

<script setup lang="ts" name="PortalLogin">
import { computed, onMounted, reactive, ref, nextTick } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { to } from 'await-to-js';
import SportField from '@/components/sport-ui/SportField.vue';
import SportButton from '@/components/sport-ui/SportButton.vue';
import ConsumerIcon from '@/components/consumer/ConsumerIcon.vue';
import { useAuthFields } from '@/components/sport-ui/useAuthFields';
import ConsumerAuthLayout from '@/components/consumer/ConsumerAuthLayout.vue';
import { getCodeImg } from '@/api/login';
import { LoginData } from '@/api/types';
import { useUserStore } from '@/store/modules/user';
import { getToken, setPlatformToken } from '@/utils/auth';
import { firstQuery, sanitizeReturnTo } from '@/utils/returnTo';
import { useCleanReturnTo } from '@/utils/useCleanReturnTo';

const route = useRoute();
const router = useRouter();
const userStore = useUserStore();
const loading = ref(false);
const captchaEnabled = ref(true);
const captchaError = ref('');
const captchaLoading = ref(false);
const codeUrl = ref('');
const form = reactive({ phone: '', password: '', code: '', uuid: '' });
const { errors, validateField, validate } = useAuthFields(form, { captcha: () => captchaEnabled.value });
useCleanReturnTo();
const returnQuery = computed(() => {
  const value = firstQuery(route.query.returnTo);
  return value ? { returnTo: sanitizeReturnTo(value) } : {};
});

const loadCaptcha = async () => {
  if (captchaLoading.value) return;
  captchaLoading.value = true;
  captchaError.value = '';
  try {
    const res = await getCodeImg();
    captchaEnabled.value = res.data.captchaEnabled !== false;
    if (captchaEnabled.value) {
      form.code = '';
      codeUrl.value = 'data:image/gif;base64,' + res.data.img;
      form.uuid = res.data.uuid || '';
    }
  } catch {
    captchaError.value = '登录验证暂时无法加载，请重试。';
  } finally {
    captchaLoading.value = false;
  }
};

const submit = async () => {
  if (loading.value || captchaLoading.value || captchaError.value) return;
  if (!validate()) {
    await nextTick();
    document.querySelector<HTMLInputElement>('.sport-field.has-error input')?.focus();
    return;
  }
  loading.value = true;
  const payload: LoginData = {
    username: form.phone,
    password: form.password,
    code: form.code,
    uuid: form.uuid,
    tenantId: '900001',
    clientId: '',
    grantType: 'platform'
  };
  const [err] = await to(userStore.login(payload));
  if (err) {
    loading.value = false;
    form.password = '';
    if (captchaEnabled.value) {
      await loadCaptcha();
    }
    return;
  }
  const token = getToken();
  if (token) {
    setPlatformToken(token);
  }
  await router.replace(sanitizeReturnTo(route.query.returnTo));
};

onMounted(loadCaptcha);
</script>
