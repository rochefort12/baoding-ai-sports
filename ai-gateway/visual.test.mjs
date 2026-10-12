import test from 'node:test';
import assert from 'node:assert/strict';
import { visualPrompt, generateVisual } from './visual.mjs';
const env = { AI_IMAGE_API_KEY: 'fixture-only', AI_IMAGE_ENDPOINT: 'https://image.example.test/v1/images/generations', AI_IMAGE_MODEL: 'fixture-image' };
const png = Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), Buffer.alloc(100)]).toString('base64');
test('未配置不会复用聊天密钥或调用供应商', async () => {
  let calls = 0;
  assert.equal((await generateVisual({ env: { DASHSCOPE_API_KEY: 'fixture-chat' }, body: {}, fetchImpl: () => calls++ })).errorCode, 'IMAGE_NOT_CONFIGURED');
  assert.equal(calls, 0);
});
test('篮球、跑步、游泳和未知项目按明确项目生成，不能默认羽毛球', () => {
  for (const project of ['篮球', '马拉松', '游泳', '飞盘', '多项目运动会']) {
    const prompt = visualPrompt({ name: '阳光交流赛', project, style: 'community' });
    assert.ok(prompt.includes('"sport":"' + project + '"'));
    assert.ok(prompt.includes('Do not assume badminton'));
    assert.ok(prompt.includes('NO TEXT'));
    assert.ok(prompt.includes('sport-neutral'));
  }
});
test('独立图像请求只含视觉描述，事实文字不交给生图模型', async () => {
  let request;
  const result = await generateVisual({ env, body: { project: '篮球', name: '三人篮球赛', style: 'competitive', accountId: 'private', fees: 'private-fee', contact: 'private-contact' }, fetchImpl: async (_url, options) => { request = options; return new Response(JSON.stringify({ data: [{ b64_json: png }] })); } });
  assert.equal(result.ok, true);
  const payload = JSON.parse(request.body);
  assert.ok(payload.prompt.includes('篮球'));
  assert.ok(!payload.prompt.includes('private'));
  assert.equal(payload.n, 1);
  assert.equal(request.redirect, 'error');
  assert.ok(!('response_format' in payload));
});
test('兼容模型可明确要求base64，拒绝URL或HTML输出', async () => {
  let payload;
  const result = await generateVisual({ env: { ...env, AI_IMAGE_RESPONSE_FORMAT: 'b64_json' }, body: {}, fetchImpl: async (_url, options) => { payload = JSON.parse(options.body); return new Response(JSON.stringify({ data: [{ url: 'https://unknown.invalid/image.png' }] })); } });
  assert.equal(payload.response_format, 'b64_json');
  assert.equal(result.errorCode, 'IMAGE_INVALID');
});
test('无效风格、图片、过大响应和供应商错误不暴露原响应', async () => {
  assert.throws(() => visualPrompt({ style: 'not-a-style' }));
  for (const response of [new Response('secret error', { status: 500 }), new Response(JSON.stringify({ data: [{ b64_json: Buffer.alloc(100, 60).toString('base64') }] })), new Response('{}', { headers: { 'content-length': String(9 * 1024 * 1024) } })]) {
    const result = await generateVisual({ env, body: {}, fetchImpl: async () => response });
    assert.equal(result.ok, false); assert.ok(!JSON.stringify(result).includes('secret'));
  }
});
test('端点必须HTTPS且不跟随重定向', async () => {
  let calls = 0;
  const result = await generateVisual({ env: { ...env, AI_IMAGE_ENDPOINT: 'http://local.invalid' }, body: {}, fetchImpl: () => calls++ });
  assert.equal(result.errorCode, 'IMAGE_CONFIG_INVALID'); assert.equal(calls, 0);
});
test('Seedream Flash使用指定模型与单图契约，不传不支持的n或fast模式', async () => {
  let payload;
  const result = await generateVisual({ env: {...env, AI_IMAGE_PROVIDER:'volcengine', AI_IMAGE_ENDPOINT:'https://ark.cn-beijing.volces.com/api/v3/images/generations', AI_IMAGE_MODEL:'doubao-seedream-5-0-flash-260915'}, body:{project:'游泳'}, fetchImpl:async (_url,options)=>{payload=JSON.parse(options.body);return new Response(JSON.stringify({data:[{b64_json:png}]}));} });
  assert.equal(result.ok,true);assert.equal(payload.model,'doubao-seedream-5-0-flash-260915');assert.equal(payload.response_format,'b64_json');assert.equal(payload.output_format,'jpeg');assert.equal(payload.watermark,false);
  for(const field of ['n','stream','sequential_image_generation','optimize_prompt_options']) assert.ok(!(field in payload));
  assert.ok(payload.prompt.includes('Flat two-dimensional'));assert.ok(payload.prompt.includes('NO photography'));assert.ok(payload.prompt.includes('#F6F0E8'));assert.ok(payload.prompt.includes('"sport":"游泳"'));
});
test('供应商授权和限频失败只返回安全分类，不泄露错误正文', async()=>{
  for(const [status,code] of [[401,'IMAGE_AUTH_FAILED'],[403,'IMAGE_ACCESS_DENIED'],[429,'IMAGE_RATE_LIMITED']]){
    const result=await generateVisual({env,body:{},fetchImpl:async()=>new Response('credential-like fixture text',{status})});
    assert.equal(result.errorCode,code);assert.ok(!JSON.stringify(result).includes('credential'));
  }
});
