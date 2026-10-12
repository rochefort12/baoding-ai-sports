/** Real configured models; isolated file/tools transport. Never creates database tasks or events. */
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname } from 'node:path';
import { runTask } from '../ai-gateway/kernel.mjs';

const [imagePath, output, selected = ''] = process.argv.slice(2);
const form = name => /单打|男单|女单/.test(name) ? 'individual' : 'pair';
const sexes = ['男单', '女单', '男双', '女双', '混双'];
const scenarios = [
  { id: 'geography', text: '秋日羽球交流赛安排在保定。为了让不同覆盖范围的球友分别竞争，持保定市参赛资格的可以报名本市单打和本市双打；河北省范围另外开放省内单打，不开双打；面向全国的公开赛道则只接受单打。各赛道独立排名，一人可以跨赛道报名。', expected: [['保定市', '单打'], ['保定市', '双打'], ['河北省', '单打'], ['全国', '单打']] },
  { id: 'location-only', text: '全国羽球邀请赛落地河北省保定市体育馆，来自全国各地的球友都可以参加，不按户籍分赛道。一个人上场的只安排男子单打，两人搭档的只安排男女混合双打。这两种分别计成绩。', expected: [['男单'], ['混双']], forbiddenName: /全国|河北|保定|户籍/ },
  { id: 'occupation', text: '周末羽球相聚赛希望兼顾不同经历。平时下班打球的业余选手分别打男子单打、女子双打；职业选手另行排名，男子单打保留，女子双打这次不办，改打混合双打。两边不能混报。', expected: [['业余', '男单'], ['业余', '女双'], ['职业', '男单'], ['职业', '混双']] },
  { id: 'relationship', text: '家庭羽球欢乐赛欢迎一家人来玩。孩子与家长搭档参加亲子双打，成年人两人搭档走成人双打，祖辈和孙辈搭档走隔代双打。三种搭档关系各自抽签和排名；孩子单独上场的比赛这次没有安排。', expected: [['亲子', '双打'], ['成人', '双打'], ['隔代', '双打']] },
  { id: 'custom', text: '夜航羽球挑战赛把积分不足800的选手放在启航层，只打男子单打；积分800至1199的进入巡航层，男子单打和男女混合双打都能报；1200及以上的归领航层，只打男女混合双打。层名是本次活动自定义叫法，低层不能报名高层。', expected: [['启航', '男单'], ['巡航', '男单'], ['巡航', '混双'], ['领航', '混双']] },
  { id: 'cross-dimensions', text: '晨光羽球挑战赛面向青少年。U12里刚学球的新人可以报男子单打或女子双打，有经历的进阶选手只打男子单打；U16这回只接收新人，安排女子双打，U16进阶暂不接收。年龄和水平同时决定独立排名，一人只按自己的条件报名。', expected: [['U12', '新人', '男单'], ['U12', '新人', '女双'], ['U12', '进阶', '男单'], ['U16', '新人', '女双']], forbiddenName: /U16.*进阶|进阶.*U16/ },
  { id: 'table-image', image: true, expected: ['A', 'B', 'C', 'D'].flatMap(group => (group === 'A' || group === 'B' ? sexes : sexes.slice(2)).map(sex => [group + '组', sex])) }
];
function normalize(name) {
  return String(name).replace(/男子单打/g, '男单').replace(/女子单打/g, '女单')
    .replace(/男子双打/g, '男双').replace(/女子双打/g, '女双')
    .replace(/男女混合双打|男女混双|混合双打/g, '混双')
    .replace(/本市/g, '保定市').replace(/省内/g, '河北省').replace(/\s/g, '');
}
function matches(name, tokens) {
  const n = normalize(name);
  return tokens.every(token => n.includes(token === '单打' ? '单' : token === '双打' ? '双' : token));
}
const results = [];
const endpoint = `${process.env.AI_COMPAT_BASE_URL?.replace(/\/$/, '')}/chat/completions`;
for (const scenario of scenarios.filter(item => !selected || selected.split(',').includes(item.id))) {
  console.log(JSON.stringify({ started: scenario.id }));
  const calls = [];
  const fetchImpl = async (input, options) => {
    const url = String(input);
    if (url === endpoint) {
      const payload = JSON.parse(options.body);
      const response = await fetch(input, options);
      if (!response.ok) return new Response('Provider request failed', { status: response.status });
      const completion = await response.json();
      calls.push({ model: payload.model, vision: Array.isArray(payload.messages[0]?.content), content: completion.choices?.[0]?.message?.content || '', finishReason: completion.choices?.[0]?.finish_reason, usage: completion.usage });
      return Response.json(completion);
    }
    if (url === 'http://127.0.0.1:1/sports/internal/ai/tasks/1/files/1' && scenario.image) return new Response(await readFile(imagePath));
    if (url === 'http://127.0.0.1:1/sports/internal/ai/tasks/1/tools') {
      const { name } = JSON.parse(options.body);
      const result = name === 'read_document_block' ? { text: scenario.text || '' } : name === 'describe_event_constraints' ? { entryTypes: ['individual', 'pair', 'team'], limitCount: '必须由办赛人确认正整数，不提供默认名额', allowedActions: ['ask', 'update'], note: '仅生成候选，不创建赛事' } : { valid: false, missing: ['报名名额等尚未提供'], note: '隔离校验，不代表真实业务预检' };
      return Response.json({ result: JSON.stringify(result) });
    }
    throw new Error('Evaluation refused unexpected endpoint');
  };
  const start = Date.now();
  const result = await runTask({ env: process.env, fetchImpl, body: { taskId: '1', javaBase: 'http://127.0.0.1:1', currentTime: '2026-10-10 12:00:00', extraction: { files: [{ fileId: '1', mediaKind: scenario.image ? 'png' : 'text', blocks: scenario.image ? [] : [{ label: '原文', text: scenario.text }] }] } } });
  const units = result.proposal?.units || [];
  const names = units.map(unit => unit?.name?.value || '');
  const missing = scenario.expected.filter(tokens => names.filter(name => matches(name, tokens)).length !== 1);
  const extra = names.filter(name => !scenario.expected.some(tokens => matches(name, tokens)));
  const wrongForms = units.filter(unit => unit.entryType?.value !== form(unit.name?.value || '')).map(unit => unit.name?.value);
  const forbiddenNames = names.filter(name => scenario.forbiddenName?.test(name));
  const birthAsEventTime = scenario.image && ['startsAt', 'endsAt', 'registrationOpensAt', 'registrationClosesAt'].some(key => result.proposal?.event?.[key]?.value);
  const record = { id: scenario.id, input: scenario.text || '用户所附四行分组表格图片', expected: scenario.expected, ok: result.ok, errorCode: result.errorCode, names, missing, extra, forbiddenNames, wrongForms, birthAsEventTime, pass: result.ok && names.length === scenario.expected.length && !missing.length && !extra.length && !forbiddenNames.length && !wrongForms.length && !birthAsEventTime, elapsedMs: Date.now() - start, proposal: result.proposal, calls };
  results.push(record);
  await mkdir(dirname(output), { recursive: true });
  await writeFile(output, JSON.stringify({ date: '2026-10-10', scope: 'Real models; isolated file/tools transport; no database writes', results }, null, 2));
  console.log(JSON.stringify({ id: record.id, pass: record.pass, names, missing, extra, wrongForms, birthAsEventTime, elapsedMs: record.elapsedMs, errorCode: record.errorCode }));
}
if (results.some(result => !result.pass)) process.exitCode = 1;
