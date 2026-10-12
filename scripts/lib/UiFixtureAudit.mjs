import assert from 'node:assert/strict';

/** 未登记接口必须显式失败，不能用成功空数据掩盖接口漂移。仅记录路径，避免保存凭据/请求正文。 */
export function createFixtureAudit() {
  const unmatched = [];
  return {
    unmatched,
    async reject(route) {
      const request = route.request();
      const call = `${request.method()} ${new URL(request.url()).pathname}`;
      unmatched.push(call);
      console.error('UNMATCHED FIXTURE ' + call);
      return route.fulfill({ status: 404, json: { code: 404, msg: '未登记测试接口', data: null } });
    },
    assertClean() { assert.deepEqual(unmatched, [], '所有业务请求必须有显式夹具'); }
  };
}
