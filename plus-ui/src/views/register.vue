<template>
  <div class="register">
    <el-form ref="registerRef" :model="registerForm" :rules="registerRules" class="register-form">
      <div class="title-box">
        <h3 class="title">参赛者注册</h3>
        <lang-select />
      </div>
      <p class="register-note">使用手机号注册。登录名就是这个手机号。姓名在登录后的身份档案里填写。</p>
      <el-form-item prop="phone">
        <el-input v-model="registerForm.phone" type="text" size="large" auto-complete="off" placeholder="手机号" maxlength="11">
          <template #prefix><svg-icon icon-class="user" class="el-input__icon input-icon" /></template>
        </el-input>
      </el-form-item>
      <el-form-item prop="password">
        <el-input
          v-model="registerForm.password"
          type="password"
          size="large"
          auto-complete="off"
          :placeholder="proxy.$t('register.password')"
          @keyup.enter="handleRegister"
        >
          <template #prefix><svg-icon icon-class="password" class="el-input__icon input-icon" /></template>
        </el-input>
      </el-form-item>
      <el-form-item prop="confirmPassword">
        <el-input
          v-model="registerForm.confirmPassword"
          type="password"
          size="large"
          auto-complete="off"
          :placeholder="proxy.$t('register.confirmPassword')"
          @keyup.enter="handleRegister"
        >
          <template #prefix><svg-icon icon-class="password" class="el-input__icon input-icon" /></template>
        </el-input>
      </el-form-item>
      <p v-if="captchaError" class="register-note">{{ captchaError }}</p>
      <div id="aliyun-captcha-element" class="aliyun-captcha-box"></div>
      <button id="aliyun-captcha-button" type="button" class="aliyun-captcha-trigger" tabindex="-1"></button>
      <el-form-item prop="smsCode">
        <el-input v-model="registerForm.smsCode" size="large" auto-complete="off" placeholder="短信验证码" style="width: 63%" maxlength="6">
          <template #prefix><svg-icon icon-class="validCode" class="el-input__icon input-icon" /></template>
        </el-input>
        <div class="register-code">
          <el-button class="sms-button" :disabled="smsWaiting" @click="sendSms">{{ smsWaiting ? smsSeconds + '秒后重试' : '获取验证码' }}</el-button>
        </div>
      </el-form-item>
      <p v-if="debugCode" class="register-note">短信验证码：{{ debugCode }}。阿里云短信尚未接入，所以这次显示在页面上。</p>
      <el-form-item style="width: 100%">
        <el-button :loading="loading" size="large" type="primary" style="width: 100%" @click.prevent="handleRegister">
          <span v-if="!loading">{{ proxy.$t('register.register') }}</span>
          <span v-else>{{ proxy.$t('register.registering') }}</span>
        </el-button>
        <div style="float: right">
          <router-link class="link-type" :to="'/login'">{{ proxy.$t('register.switchLoginPage') }}</router-link>
        </div>
      </el-form-item>
    </el-form>
    <!--  底部  -->
    <div class="el-register-footer">
      <span>Copyright © 2018-2026 疯狂的狮子Li All Rights Reserved.</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { getParticipantCaptchaConfig, registerParticipant, sendParticipantSms } from '@/api/login';
import { RegisterForm } from '@/api/types';
import { to } from 'await-to-js';
import { useI18n } from 'vue-i18n';

const { proxy } = getCurrentInstance() as ComponentInternalInstance;

const router = useRouter();

const { t } = useI18n();

const registerForm = ref<RegisterForm & { phone: string; smsCode: string }>({
  tenantId: '',
  username: '',
  phone: '',
  password: '',
  confirmPassword: '',
  code: '',
  smsCode: '',
  uuid: '',
  userType: 'sys_user'
});

const equalToPassword = (rule: any, value: string, callback: any) => {
  if (registerForm.value.password !== value) {
    callback(new Error(t('register.rule.confirmPassword.equalToPassword')));
  } else {
    callback();
  }
};

const registerRules: ElFormRules = {
  phone: [
    { required: true, trigger: 'blur', message: '请填写手机号' },
    { pattern: /^1[3-9]\d{9}$/, message: '请填写中国大陆11位手机号', trigger: 'blur' }
  ],
  smsCode: [
    { required: true, trigger: 'blur', message: '请填写短信验证码' },
    { pattern: /^\d{6}$/, message: '短信验证码为6位数字', trigger: 'blur' }
  ],
  password: [
    { required: true, trigger: 'blur', message: t('register.rule.password.required') },
    { min: 5, max: 20, message: t('register.rule.password.length', { min: 5, max: 20 }), trigger: 'blur' },
    { pattern: /^[^<>"'|\\]+$/, message: t('register.rule.password.pattern', { strings: '< > " \' \\ |' }), trigger: 'blur' }
  ],
  confirmPassword: [
    { required: true, trigger: 'blur', message: t('register.rule.confirmPassword.required') },
    { required: true, validator: equalToPassword, trigger: 'blur' }
  ]
};
const loading = ref(false);
const registerRef = ref<ElFormInstance>();
const debugCode = ref('');
const smsWaiting = ref(false);
const smsSeconds = ref(0);
const captchaError = ref('');
let smsTimer: number | undefined;
let captchaVerifyParam = '';

const handleRegister = () => {
  registerRef.value?.validate(async (valid: boolean) => {
    if (valid) {
      loading.value = true;
      const [err] = await to(
        registerParticipant({
          phone: registerForm.value.phone,
          password: registerForm.value.password,
          smsCode: registerForm.value.smsCode
        })
      );
      if (!err) {
        const phone = registerForm.value.phone;
        await ElMessageBox.alert('手机号 ' + phone + ' 已注册。请在登录页的用户名处填写该手机号。', '系统提示', {
          type: 'success'
        });
        await router.push('/login');
      } else {
        loading.value = false;
      }
    }
  });
};

const sendSms = async () => {
  const phone = registerForm.value.phone;
  if (!/^1[3-9]\d{9}$/.test(phone)) {
    ElMessage.error('请先填写中国大陆11位手机号');
    return;
  }
  if (!captchaVerifyParam) {
    ElMessage.error('请先完成验证码');
    return;
  }
  const passed = captchaVerifyParam;
  captchaVerifyParam = '';
  await requestSms(passed);
};

const requestSms = async (verifyParam: string) => {
  const [err, res] = await to(
    sendParticipantSms({
      phone: registerForm.value.phone,
      captchaVerifyParam: verifyParam
    })
  );
  if (err) {
    return;
  }
  debugCode.value = res.data?.debugCode || '';
  smsWaiting.value = true;
  smsSeconds.value = 60;
  window.clearInterval(smsTimer);
  smsTimer = window.setInterval(() => {
    smsSeconds.value -= 1;
    if (smsSeconds.value <= 0) {
      smsWaiting.value = false;
      window.clearInterval(smsTimer);
    }
  }, 1000);
};

const loadAliyunCaptcha = (region: string, prefix: string, sceneId: string) => {
  const win = window as Window & {
    AliyunCaptchaConfig?: { region: string; prefix: string };
    initAliyunCaptcha?: (options: Record<string, unknown>) => void;
  };
  win.AliyunCaptchaConfig = { region, prefix };
  const start = () => {
    win.initAliyunCaptcha?.({
      SceneId: sceneId,
      mode: 'embed',
      element: '#aliyun-captcha-element',
      button: '#aliyun-captcha-button',
      success: (param: string) => {
        captchaVerifyParam = param;
      },
      fail: () => {
        captchaVerifyParam = '';
        ElMessage.error('验证未通过，请重试');
      },
      getInstance: () => undefined,
      slideStyle: { width: 320, height: 40 },
      language: 'cn',
      onError: () => {
        captchaError.value = '阿里云验证码加载失败';
      }
    });
  };
  if (win.initAliyunCaptcha) {
    start();
    return;
  }
  const script = document.createElement('script');
  script.src = 'https://o.alicdn.com/captcha-frontend/aliyunCaptcha/AliyunCaptcha.js';
  script.onload = () => start();
  script.onerror = () => {
    captchaError.value = '阿里云验证码脚本加载失败';
  };
  document.head.appendChild(script);
};

onMounted(async () => {
  const [err, res] = await to(getParticipantCaptchaConfig());
  const config = err ? undefined : res.data;
  if (config?.aliyun && config.prefix && config.sceneId) {
    loadAliyunCaptcha(config.region || 'cn', config.prefix, config.sceneId);
    return;
  }
  captchaError.value = '阿里云验证码未配置';
});
</script>

<style lang="scss" scoped>
.register {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100%;
  background-image: url('../assets/images/login-background.jpg');
  background-size: cover;
}

.register-note {
  margin: 0 0 16px;
  color: #707070;
  font-size: 13px;
  line-height: 1.5;
}

.title-box {
  display: flex;

  .title {
    margin: 0px auto 30px auto;
    text-align: center;
    color: #707070;
  }

  :deep(.lang-select--style) {
    line-height: 0;
    color: #7483a3;
  }
}

.register-form {
  border-radius: 6px;
  background: #ffffff;
  width: 400px;
  padding: 25px 25px 5px 25px;

  .el-input {
    height: 40px;

    input {
      height: 40px;
    }
  }

  .input-icon {
    height: 39px;
    width: 14px;
    margin-left: 0;
  }
}

.register-tip {
  font-size: 13px;
  text-align: center;
  color: #bfbfbf;
}

.register-code {
  width: 33%;
  height: 40px;
  float: right;

  img {
    cursor: pointer;
    vertical-align: middle;
  }
}

.el-register-footer {
  height: 40px;
  line-height: 40px;
  position: fixed;
  bottom: 0;
  width: 100%;
  text-align: center;
  color: #fff;
  font-family: Arial, serif;
  font-size: 12px;
  letter-spacing: 1px;
}

.register-code-img {
  height: 40px;
  padding-left: 12px;
}

.sms-button {
  width: 100%;
  height: 40px;
  margin-left: 12px;
}

.aliyun-captcha-box {
  min-height: 40px;
  margin: 0 0 16px;
}

.aliyun-captcha-trigger {
  display: none;
}
</style>
