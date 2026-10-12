import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createFixtureAudit } from './UiFixtureAudit.mjs';

test('未知接口拒绝并使最终检查失败，不记录令牌或正文', async () => {
  const audit = createFixtureAudit(); let response;
  await audit.reject({ request: () => ({ method: () => 'POST', url: () => 'http://localhost/sports/changed?token=private' }),
    fulfill: async value => { response = value; } });
  assert.equal(response.status, 404);
  assert.equal(response.json.code, 404);
  assert.deepEqual(audit.unmatched, ['POST /sports/changed']);
  assert.throws(() => audit.assertClean(), /所有业务请求/);
});
test('没有未知请求才允许通过', () => createFixtureAudit().assertClean());
