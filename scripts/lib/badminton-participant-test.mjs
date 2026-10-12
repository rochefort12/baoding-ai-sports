// Real isolated participant/organizer HTTP only. Secrets stay in the protected context.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import os from 'node:os';

export const hashFile = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
export function atomicJson(file, value) {
  const next = file + '.next', fd = fs.openSync(next, 'w');
  try { fs.writeFileSync(fd, JSON.stringify(value, null, 2)); fs.fsyncSync(fd); }
  finally { fs.closeSync(fd); }
  fs.renameSync(next, file);
}
export function testHarness(kind, options = {}) {
  const contextPath = process.argv[2] || process.env.AISPORTS_BUSINESS_CONTEXT;
  assert.ok(contextPath, 'Supply the root-protected business context path');
  const context = JSON.parse(fs.readFileSync(contextPath, 'utf8'));
  assert.match(context.database, /^aisports_verify_phase1_[a-f0-9]{32}$/);
  assert.equal(new URL(context.backend).origin, 'http://127.0.0.1:8082');
  assert.equal(new URL(context.frontend).origin, 'http://127.0.0.1:5192');
  assert.equal(context.people.length, 6);
  assert.ok(context.prefix && context.runId && context.organizer?.token);
  const root = path.dirname(path.resolve(contextPath));
  const runtimePath=path.resolve('.local/phase1-implementation/verification-runtime.json');
  const runtime=JSON.parse(fs.readFileSync(runtimePath,'utf8'));
  assert.equal(runtime.port,8082);assert.equal(runtime.database,context.database);
  const progressName = options.progressName || 'participant-progress.private.json';
  assert.ok(['participant-progress.private.json', 'participant-scheduled-progress.private.json'].includes(progressName), 'Known isolated progress scope');
  const progressPath = path.join(root, progressName);
  const progress = fs.existsSync(progressPath) ? JSON.parse(fs.readFileSync(progressPath, 'utf8')) : {
    runId: context.runId, objects: {}, operations: {}, checks: [], keys: {}, createdAt: new Date().toISOString()
  };
  assert.equal(progress.runId, context.runId);
  const out = path.join(root, kind + '-' + Date.now()); fs.mkdirSync(out, {recursive: false});
  const report = {
    time: new Date().toISOString(), host: os.hostname(), runId: context.runId,
    backend: context.backend, frontend: context.frontend, database: context.database,
    contextSHA256: hashFile(contextPath), jarSHA256: runtime.jarSHA256, runtimeSHA256: hashFile(runtimePath),
    scope: 'Real local HTTP/UI and synthetic people/events. Ordinary members and organizer; no direct SQL, business response stubs or real bank/onsite facts.',
    passed: false, checks: [], failures: [], requests: [], objects: {}, screenshots: []
  };
  let definitions = context.definitions;
  const save = () => { progress.updatedAt = new Date().toISOString(); atomicJson(progressPath, progress); };
  const check = (id, text, actual) => {
    assert.ok(actual, id + ': ' + text); report.checks.push({id, text, observedAt: new Date().toISOString()});
    if (!progress.checks.some(row => row.id === id)) progress.checks.push({id, text}); save();
  };
  const people = context.people.map((actor, index) => ({...actor, label: String.fromCharCode(65 + index)}));
  const organizer = {...context.organizer, label: 'ordinary-organizer'};
  function key(slot) { progress.keys[slot] ||= crypto.randomUUID(); save(); return progress.keys[slot]; }
  function safeRoute(route) { return route.replace(/(\/invites\/)[^/]+/, '$1{private-invite}'); }
  async function call(actor, route, method = 'GET', input) {
    assert.ok(route.startsWith('/sports/') || route === '/auth/organization/enter');
    const start = Date.now();
    const response = await fetch(context.backend + route, {method, headers: {
      clientid: actor.clientId || context.clientId,
      Authorization: 'Bearer ' + actor.token,
      ...(input !== undefined ? {'Content-Type': 'application/json'} : {})
    }, ...(input === undefined ? {} : {body: JSON.stringify(input)})});
    let body; try { body = await response.json(); } catch { throw new Error('Expected JSON at ' + safeRoute(route)); }
    report.requests.push({actor: actor.label, method, route: safeRoute(route), status: response.status, code: body.code, elapsedMs: Date.now() - start,
      ...(body.code!==200?{message:String(body.msg||'').replace(/\b\d{11}\b/g,'{private-phone}').replace(/(?:Bearer\s+|sk-)[A-Za-z0-9._-]+/g,'{credential}').slice(0,300)}:{})});
    if (body.code === 401) throw new Error('Protected session expired; root must recover auth only');
    return body;
  }
  async function api(actor, route, method = 'GET', input) {
    const body = await call(actor, route, method, input);
    assert.equal(body.code, 200, safeRoute(route) + ' must succeed (code ' + body.code + '; '+String(body.msg||'').replace(/\b\d{11}\b/g,'{private-phone}').slice(0,150)+')'); return body.data;
  }
  async function once(slot, work) {
    if (progress.operations[slot]?.completed) return progress.operations[slot].result;
    progress.operations[slot] ||= {startedAt: new Date().toISOString()}; save();
    const result = await work();
    progress.operations[slot] = {...progress.operations[slot], completed: true, result, completedAt: new Date().toISOString()}; save(); return result;
  }
  async function prepareAction(actor, code, input, slot) {
    const row = (definitions || []).find(row => (row.definition || row).code === code);
    assert.ok(row, 'Current registered capability exists: ' + code);
    let confirmationId;
    if ((row.definition || row).confirmation) {
      await api(actor, '/sports/platform/actions/' + code + '/preview', 'POST', input);
      confirmationId = await api(actor, '/sports/platform/actions/' + code + '/confirm', 'POST', input);
    }
    return {input, requestKey: key(slot), ...(confirmationId ? {confirmationId} : {})};
  }
  async function action(actor, code, input, slot) {
    return once(slot, async () => {
      const body = await prepareAction(actor, code, input, slot);
      const receipt = await api(actor, '/sports/platform/actions/' + code + '/execute', 'POST', body);
      assert.ok(receipt.receiptId, 'Successful business action has a real receipt');
      return receipt;
    });
  }
  async function denied(actor, code, input, caseId, text) {
    const prepared = await prepareAction(actor, code, input, caseId + '.negative');
    const body = await call(actor, '/sports/platform/actions/' + code + '/execute', 'POST', prepared);
    check(caseId, text, body.code !== 200); return body;
  }
  /** Negative checks still bind a real confirmation if the current caller can
   * preview the action. Permission denial during preview is evidence itself. */
  async function rejectedAction(actor, code, input, caseId, text, expectedReason) {
    const row=(definitions||[]).find(row=>(row.definition||row).code===code);assert.ok(row);
    let result,confirmationId;
    if((row.definition||row).confirmation){
      const preview=await call(actor,'/sports/platform/actions/'+code+'/preview','POST',input);
      if(preview.code!==200)result=preview;
      else {const confirmed=await call(actor,'/sports/platform/actions/'+code+'/confirm','POST',input);if(confirmed.code!==200)result=confirmed;else confirmationId=confirmed.data;}
    }
    result ||= await call(actor,'/sports/platform/actions/'+code+'/execute','POST',{input,requestKey:key(caseId+'.rejected'),...(confirmationId?{confirmationId}:{})});
    check(caseId,text,result.code!==200&&(!expectedReason||expectedReason.test(result.msg||'')));
    return result;
  }
  async function preflight() {
    // Admin is used solely for the current capability metadata; all business acts use ordinary actors.
    const catalog = await api({...context.admin, label: 'metadata-only-platform'}, '/sports/platform/management');
    definitions = catalog.definitions;
    check('P01', 'Current capabilities read without release/initialization', definitions.length > 0);
    for (const actor of people) {
      const self = await api(actor, '/sports/c/identity');
      check('P02.' + actor.label, 'Ordinary participant session and personal profile available', Boolean(self.self));
    }
    check('P03', 'Existing organizer session reads its own events', Array.isArray(await api(organizer, '/sports/b/events')));
  }
  function reference(name, value) { progress.objects[name] = value; report.objects[name] = value; save(); return value; }
  async function entry(actor, id) { const rows = await api(actor, '/sports/c/registrations'); const row = rows.find(row => row.id === id); assert.ok(row, 'Member sees their own new-round entry'); return row; }
  async function registrationVersion(actor, id) { return (await api(actor, '/sports/entry-management/'+id)).registration.version; }
  async function room(actor, id) { return api(actor, '/sports/rooms/' + id); }
  function final(extra = {}) {
    Object.assign(report, extra); report.objects = {...progress.objects};
    const file = path.join(out, 'receipt.json'); atomicJson(file, report);
    console.log(JSON.stringify({passed:report.passed, checks:report.checks.length, failureIds:report.failures.map(row=>row.id), receipt:path.relative(process.cwd(),file).replaceAll('\\','/'), sha256:hashFile(file)}));
  }
  return {context, people, organizer, progress, root, out, report, save, check, key, call, api, action, once, prepareAction, denied, rejectedAction, preflight, reference, entry, registrationVersion, room, final};
}
