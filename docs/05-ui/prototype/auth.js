/* C03/C04 的本地演示会话；不保存手机号、密码、验证码或真实 token。 */
const Auth = (() => {
  const key='aisports-ui-auth-demo-v1';
  const load=()=>{try{const s=JSON.parse(sessionStorage.getItem(key));return {loggedIn:s?.loggedIn===true,profile:s?.profile===true,newAccount:s?.newAccount===true}}catch{return {loggedIn:false,profile:false,newAccount:false}}};
  let state=load();
  const save=()=>sessionStorage.setItem(key,JSON.stringify(state));
  const parts=()=>{const [path,...rest]=(location.hash.slice(1)||'home').split('?');return {path,params:new URLSearchParams(rest.join('?'))}};
  // 白名单任务标识，不接受任意 URL；事件与项目只采用本原型的固定枚举。
  function safeTarget(value){
    if(typeof value!=='string'||value.length>250||/[\\\s:#]/.test(value))return 'home';
    const [path,...rest]=value.split('?'),params=new URLSearchParams(rest.join('?'));
    if(!['home','events','detail','register','orders','teams','me','messages','identity','future/venues','future/life','organization/apply','organization/status'].includes(path)&&!/^order\/DEMO-\d+$/.test(path))return 'home';
    if(['register','detail'].includes(path)){const result=new URLSearchParams();result.set('event','demo-autumn');const unit=params.get('unit');if(['single','double','female'].includes(unit))result.set('unit',unit);return path+'?'+result}
    return path;
  }
  const target=()=>safeTarget(parts().params.get('returnTo')||'home');
  const link=(page,t=target())=>'#'+page+'?returnTo='+encodeURIComponent(safeTarget(t));
  function resume(t){const dest=safeTarget(t);if(dest.startsWith('organization/'))location.assign('organizer.html#'+dest.split('/')[1]);else location.hash=dest}
  function requireLogin(t){if(state.loggedIn)return true;location.hash=link('login',t).slice(1);return false}
  function demoLogin(profile=true){state={loggedIn:true,profile:Boolean(profile),newAccount:false};save()}
  function logout(){state.loggedIn=false;save();location.hash='home';window.dispatchEvent(new Event('hashchange'))}
  function header(){return state.loggedIn?`<a href="#messages" aria-label="消息">${UI.icon('bell')}</a><a class="avatar" href="#me" aria-label="示例账号林一">林</a>`:`<a class="btn slim auth-header-login" href="${link('login',parts().path)}">登录</a><a class="auth-header-signup" href="${link('signup',parts().path)}">注册</a>`}
  function render(shell){
    const page=parts().path;
    if(!['login','signup','forgot','identity','admin-entry'].includes(page))return false;
    const E=UI.esc,t=target(),isLogin=page==='login',isSignup=page==='signup';
    if(page==='admin-entry'){
      shell(`<div class="auth-layout"><section class="auth-card card"><span class="eyebrow">平台管理</span><h1>管理员登录入口</h1><p class="muted mt">正式产品沿用若依 /login，以管理员用户名登录。平台手机号账号通过独立的运动者入口登录。</p><div class="notice neutral mt">本地原型没有连接管理系统，不在此模拟管理员认证或授予管理权限。</div><a class="btn primary mt" href="${link('login')}">返回平台账号登录</a><a class="btn mt" href="#home">返回首页</a></section></div>`,'');return true;
    }
    if(page==='identity'){
      if(!requireLogin('identity'))return true;
      shell(`<div class="auth-layout"><aside class="auth-intro"><span class="eyebrow">本人档案 · C05 前置片段</span><h1>${state.profile?'本人资料概览':'继续报名前，完善本人档案'}</h1><p>浏览赛事、管理账号和申请办赛无需先建参赛档案；报名与入队时再检查必要信息。</p>${Platform.cityMark()}</aside><section class="card auth-card"><h2>本人基础信息</h2><p class="small muted mt">以下是固定虚构资料，不采集真实身份。完整档案编辑另行设计。</p><dl class="kv mt"><dt>姓名</dt><dd>林一（虚构）</dd><dt>出生日期</dt><dd>2000-06-18（虚构）</dd><dt>性别</dt><dd>男（虚构）</dd><dt>手机号</dt><dd>已验证手机号 · 正式产品只读</dd></dl><div class="notice neutral mt">手机号来自已验证账号；证件、地址等选填字段不能成为普通登录后的统一阻断。</div><button class="btn primary big mt" data-auth="profile">${state.profile?'返回原任务':'使用虚构档案继续（模拟）'}</button><a class="btn mt" href="#home">稍后完善，返回首页</a></section></div>`,'me');return true;
    }
    if(state.loggedIn){resume(t);return true}
    const title=isLogin?'登录':isSignup?'注册':'找回密码';
    const hint=t.startsWith('register')?'登录后继续「秋季羽毛球交流赛」报名；不会自动提交。':t.startsWith('organization/')?'登录后返回办赛申请 / 进度；无需先建参赛档案。':t!=='home'?'登录后返回刚才的任务。':'登录后回到 AI运动首页。';
    shell(`<div class="auth-layout"><aside class="auth-intro"><span class="eyebrow">保定 · 身边的运动生活</span><h1>每一份热爱，<br>都有上场的机会。</h1><p>发现赛事，与伙伴一起运动。参赛、队伍与办赛使用同一个平台账号。</p><div class="auth-city-art">${Platform.scene()}</div><a class="btn" href="#home">${UI.icon('back')} 返回首页</a></aside><section class="card auth-card"><div class="between"><h2>${title}</h2><span class="badge gray">平台账号</span></div><p class="muted small mt">${E(hint)}</p><form id="auth-form" novalidate class="stack mt"><label class="label"><span>手机号</span><input id="auth-phone" name="phone" type="tel" inputmode="numeric" maxlength="11" autocomplete="off" placeholder="请输入手机号" aria-required="true"></label><label class="label"><span>${page==='forgot'?'新密码':'密码'}</span><div class="password-control"><input id="auth-password" name="password" type="password" maxlength="20" autocomplete="off" placeholder="${page==='forgot'?'设置新密码':'请输入密码'}" aria-required="true"><button class="btn text slim" type="button" data-auth="show-password" aria-label="显示密码" aria-pressed="false">显示</button></div></label>${isLogin?'':`<label class="label"><span>确认密码</span><input id="auth-confirm" type="password" maxlength="20" autocomplete="off" placeholder="请再次输入密码" aria-required="true"></label>`}<div class="auth-verify"><span>安全验证</span><button class="btn slim" type="button" data-auth="captcha">完成安全验证（模拟）</button><span id="captcha-status" class="small muted" role="status">等待验证</span></div>${isLogin?'':`<label class="label"><span>短信验证码</span><div class="sms-control"><input id="auth-sms" inputmode="numeric" maxlength="6" autocomplete="off" placeholder="请输入 6 位验证码" aria-required="true"><button id="send-code" class="btn slim" type="button" data-auth="send-code">获取验证码</button></div><span id="sms-status" class="small muted" role="status">${page==='forgot'?'验证当前绑定的手机号':'验证手机号后注册平台账号'}</span></label>`}<p id="auth-error" class="field-error" role="alert"></p><button class="btn primary big" type="submit">${title}（模拟） ${UI.icon('arrow')}</button></form><div class="auth-links">${isLogin?`<a href="${link('signup')}">注册账号</a><a href="${link('forgot')}">忘记密码？</a>`:`<a href="${link('login')}">已有账号，返回登录</a>`}</div><div class="auth-demo"><p class="small muted">界面演示，请勿填写真实密码。不会发送短信；验证码仅用于此页模拟。</p>${isLogin?`<label class="label"><span>原型场景</span><select id="auth-profile"><option value="complete" ${state.newAccount?'':'selected'}>已有本人档案</option><option value="missing" ${state.newAccount?'selected':''}>尚无本人档案</option><option value="failure">登录失败</option><option value="expired">验证码已过期</option><option value="limited">操作过于频繁</option></select></label>`:''}<a class="small muted" href="#admin-entry">平台管理登录</a></div></section></div>`,'');
    let verified=false,sent=false,busy=false;
    const error=m=>{document.getElementById('auth-error').textContent=m};
    document.querySelectorAll('[data-auth]').forEach(button=>button.addEventListener('click',()=>{
      if(button.dataset.auth==='show-password'){const input=document.getElementById('auth-password'),show=input.type==='password';input.type=show?'text':'password';button.textContent=show?'隐藏':'显示';button.setAttribute('aria-label',show?'隐藏密码':'显示密码');button.setAttribute('aria-pressed',String(show))}
      if(button.dataset.auth==='captcha'){verified=true;button.textContent='重新验证（模拟）';document.getElementById('captcha-status').textContent='模拟验证完成；正式产品使用已启用的验证码服务';error('')}
      if(button.dataset.auth==='send-code'){
        if(!/^1[3-9]\d{9}$/.test(document.getElementById('auth-phone').value)){error('请填写中国大陆 11 位手机号。');return}
        if(!verified){error('请先完成安全验证。');return}
        sent=true;button.disabled=true;button.textContent='60 秒后可重试';document.getElementById('sms-status').textContent='如号码可办理，将收到验证码。本页模拟码 123456；未发送真实短信。';error('');
        const originalPhone=document.getElementById('auth-phone').value,until=Date.now()+60000;
        const timer=setInterval(()=>{if(!button.isConnected){clearInterval(timer);return}const seconds=Math.ceil((until-Date.now())/1000);button.textContent=seconds>0?seconds+' 秒后可重试':'获取验证码';if(seconds<=0){button.disabled=false;clearInterval(timer)}},1000);
        document.getElementById('auth-phone').addEventListener('input',()=>{if(document.getElementById('auth-phone').value!==originalPhone){sent=false;verified=false;button.disabled=false;button.textContent='获取验证码';document.getElementById('sms-status').textContent='手机号已变化，请重新验证并获取验证码。';document.getElementById('captcha-status').textContent='等待验证';clearInterval(timer)}},{once:true});
      }
    }));
    document.getElementById('auth-form').onsubmit=event=>{
      event.preventDefault();if(busy)return;error('');const phone=document.getElementById('auth-phone').value,password=document.getElementById('auth-password').value;
      if(!/^1[3-9]\d{9}$/.test(phone)){error('请填写中国大陆 11 位手机号。');return}
      if(password.length<5||password.length>20||/[<>"'|\\]/.test(password)){error('密码为 5—20 位，不含 < > " \' | 或反斜线。');return}
      if(!verified){error('请先完成安全验证。');return}
      if(!isLogin){if(password!==document.getElementById('auth-confirm').value){error('两次密码输入不一致。');return}if(!sent||document.getElementById('auth-sms').value!=='123456'){error('验证码错误、已过期或尚未获取，请重新验证。');return}}
      const scenario=document.getElementById('auth-profile')?.value;
      if(scenario==='failure'){error('手机号或密码不正确，请重试或找回密码。');return}
      if(scenario==='expired'){verified=false;error('安全验证已过期，请重新验证。');return}
      if(scenario==='limited'){error('操作过于频繁，请稍后重试。');return}
      busy=true;event.submitter.disabled=true;event.target.reset();
      if(isLogin){demoLogin(scenario!=='missing');resume(t);UI.toast('模拟登录成功，已返回原任务。')}
      else {state={loggedIn:false,profile:false,newAccount:isSignup||state.newAccount};save();location.hash=link('login',t).slice(1);UI.toast(isSignup?'模拟注册成功，请登录后继续。':'模拟密码重置成功；正式产品撤销平台及关联组织会话，请重新登录。')}
    };
    return true;
  }
  document.addEventListener('click',event=>{
    const action=event.target.closest('[data-auth]')?.dataset.auth;
    if(action==='logout'){logout();return}
    if(action==='profile'){state.profile=true;save();resume(target());return}
    const organizer=event.target.closest('a[href="organizer.html#apply"],a[href="organizer.html#status"]');
    if(organizer&&!state.loggedIn){event.preventDefault();requireLogin('organization/'+(organizer.hash.slice(1)||'apply'))}
  });
  return {get loggedIn(){return state.loggedIn},get profile(){return state.profile},parts,target,safeTarget,link,render,header,requireLogin,demoLogin,logout};
})();
