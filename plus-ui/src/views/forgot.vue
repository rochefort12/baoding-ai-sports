<template>
  <div class="forgot">
    <el-form ref="formRef" :model="form" :rules="rules" class="forgot-form">
      <h3 class="title">重置平台密码</h3>
      <p class="note">只重置这个手机号对应的平台登录密码。不新建账号，也不修改档案。</p>
      <el-form-item prop="phone">
        <el-input v-model="form.phone" size="large" maxlength="11" placeholder="已注册手机号" />
      </el-form-item>
      <p v-if="captchaError" class="note">{{ captchaError }}</p>
      <div id="aliyun-captcha-element" class="aliyun-captcha-box"></div>
      <button id="aliyun-captcha-button" type="button" class="aliyun-captcha-trigger" tabindex="-1"></button>
      <el-form-item prop="smsCode">
        <el-input v-model="form.smsCode" size="large" maxlength="6" placeholder="重置验证码" style="width: 63%" />
        <el-button class="sms-button" :disabled="smsWaiting" @click="sendSms">{{ smsWaiting ? smsSeconds + '秒' : '获取验证码' }}</el-button>
      </el-form-item>
      <p v-if="debugCode" class="note">本地模拟验证码：{{ debugCode }}。阿里云短信尚未接入，所以这次显示在页面上。</p>
      <el-form-item prop="password">
        <el-input v-model="form.password" type="password" size="large" placeholder="新密码" />
      </el-form-item>
      <el-form-item prop="confirmPassword">
        <el-input v-model="form.confirmPassword" type="password" size="large" placeholder="确认新密码" @keyup.enter="submit" />
      </el-form-item>
      <el-button :loading="loading" type="primary" style="width: 100%" @click="submit">重置密码</el-button>
      <div class="links">
        <router-link to="/login">返回登录</router-link>
      </div>
    </el-form>
  </div>
</template>

<script setup lang="ts">
import { to } from 'await-to-js';
import { ElMessage, ElMessageBox } from 'element-plus';
import { getParticipantCaptchaConfig, resetParticipantPassword, sendResetSms } from '@/api/login';

const router = useRouter();
const formRef = ref<ElFormInstance>();
const form = reactive({ phone: '', smsCode: '', password: '', confirmPassword: '' });
const loading = ref(false);
const captchaError = ref('');
const debugCode = ref('');
const smsWaiting = ref(false);
const smsSeconds = ref(60);
let captchaVerifyParam = '';
let smsTimer = 0;

const rules: ElFormRules = {
  phone: [{ required: true, message: '请填写手机号', trigger: 'blur' }],
  smsCode: [{ required: true, message: '请填写验证码', trigger: 'blur' }],
  password: [
    { required: true, message: '请填写新密码', trigger: 'blur' },
    { min: 5, max: 20, message: '密码长度为 5 到 20 位', trigger: 'blur' },
    { pattern: /^[^<>"'|\\]+$/, message: '密码不能包含 < > " \' \\ |', trigger: 'blur' }
  ],
  confirmPassword: [
    { required: true, message: '请再次填写新密码', trigger: 'blur' },
    {
      validator: (_rule, value, callback) => {
        if (value !== form.password) {
          callback(new Error('两次密码不一致'));
          return;
        }
        callback();
      },
      trigger: 'blur'
    }
  ]
};

const sendSms = async () => {
  if (!/^1[3-9]\d{9}$/.test(form.phone)) {
    ElMessage.error('请先填写中国大陆11位手机号');
    return;
  }
  if (!captchaVerifyParam) {
    ElMessage.error('请先完成验证码');
    return;
  }
  const passed = captchaVerifyParam;
  captchaVerifyParam = '';
  const [err, res] = await to(sendResetSms({ phone: form.phone, captchaVerifyParam: passed }));
  if (err) {
    return;
  }
  debugCode.value = res.data?.debugCode || '';
  ElMessage.success(res.msg || '如果手机号已注册，验证码已发送');
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

const submit = () => {
  formRef.value?.validate(async (valid) => {
    if (!valid) {
      return;
    }
    loading.value = true;
    const [err] = await to(resetParticipantPassword({ phone: form.phone, password: form.password, smsCode: form.smsCode }));
    loading.value = false;
    if (err) {
      return;
    }
    await ElMessageBox.alert('密码已重置，请用新密码重新登录。', '系统提示', { type: 'success' });
    await router.push('/login');
  });
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

<style scoped>
.forgot {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100%;
  background: #f5f7fa;
}
.forgot-form {
  width: 420px;
  padding: 28px;
  background: #fff;
  border-radius: 8px;
}
.title {
  margin: 0 0 8px;
}
.note {
  color: #909399;
  font-size: 13px;
  line-height: 1.5;
}
.sms-button {
  width: 35%;
  margin-left: 2%;
}
.links {
  margin-top: 12px;
  text-align: right;
}
.aliyun-captcha-trigger {
  position: absolute;
  width: 0;
  height: 0;
  opacity: 0;
}
</style>
