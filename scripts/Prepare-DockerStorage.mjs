// Read credentials from stdin, never from arguments or log output. No legacy objects are removed.
import { createHash, createHmac } from 'node:crypto';
let input = ''; for await (const part of process.stdin) input += part;
const c = JSON.parse(input); input = '';
if (c.bucket !== 'aisports-docker-fresh') throw new Error('Unexpected Docker bucket');
const sha = s => createHash('sha256').update(s).digest('hex');
const hmac = (key, text) => createHmac('sha256', key).update(text).digest();
async function request(method, query = '') {
  const stamp = new Date().toISOString().replace(/[-:]|\.\d{3}/g, '');
  const date = stamp.slice(0, 8), uri = '/' + c.bucket;
  const payload = sha(''), host = 'minio:9000';
  const headers = `host:${host}\nx-amz-content-sha256:${payload}\nx-amz-date:${stamp}\n`;
  const signed = 'host;x-amz-content-sha256;x-amz-date';
  const canonical = [method, uri, query, headers, signed, payload].join('\n');
  const scope = `${date}/us-east-1/s3/aws4_request`;
  const key = hmac(hmac(hmac(hmac('AWS4'+c.secretKey,date),'us-east-1'),'s3'),'aws4_request');
  const signature = createHmac('sha256',key).update(`AWS4-HMAC-SHA256\n${stamp}\n${scope}\n${sha(canonical)}`).digest('hex');
  return fetch(`http://${host}${uri}${query?'?'+query:''}`, {method, headers: {
    'x-amz-date':stamp, 'x-amz-content-sha256':payload,
    Authorization:`AWS4-HMAC-SHA256 Credential=${c.accessKey}/${scope}, SignedHeaders=${signed}, Signature=${signature}`
  }});
}
const created = await request('PUT');
if (!created.ok && created.status !== 409) throw new Error('Private bucket creation failed: '+created.status);
const listed = await request('GET','list-type=2');
if (!listed.ok) throw new Error('Private bucket access failed: '+listed.status);
const body = await listed.text();
console.log(JSON.stringify({bucket:c.bucket,accessible:true,empty:!body.includes('<Contents>')}));
