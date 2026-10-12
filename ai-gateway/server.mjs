import { createServer } from 'node:http';
import { runTask, discussTurn, assistReadOnly, composePromotion, guideTurn } from './kernel.mjs';
import { generateVisual } from './visual.mjs';
import { runAgent } from './agent.mjs';
import { composeEventMaterial } from './materials.mjs';

const port = Number(process.env.AI_GATEWAY_PORT || 8091);

const server = createServer(async (request, response) => {
  if (request.method !== 'POST' || !['/internal/run','/internal/discuss','/internal/assist','/internal/promote','/internal/guide','/internal/visual','/internal/agent','/internal/material'].includes(request.url)) {
    response.writeHead(404, { 'Content-Type': 'application/json' });
    response.end(JSON.stringify({ ok: false, errorCode: 'NOT_FOUND' }));
    return;
  }
  const expected = process.env.AI_INTERNAL_TOKEN || '';
  const presented = request.headers['x-ai-internal-token'] || '';
  if (!expected || presented !== expected) {
    response.writeHead(401, { 'Content-Type': 'application/json' });
    response.end(JSON.stringify({ ok: false, errorCode: 'UNAUTHORIZED' }));
    return;
  }
  try {
    const body = JSON.parse(await readBody(request,request.url==='/internal/agent'?8*1024*1024:2*1024*1024));
    const result = request.url === '/internal/material'
      ? await composeEventMaterial({ env: process.env, fetchImpl: globalThis.fetch, body })
      : request.url === '/internal/agent'
      ? await runAgent({ env: process.env, fetchImpl: globalThis.fetch, body })
      : request.url === '/internal/visual'
      ? await generateVisual({ env: process.env, fetchImpl: globalThis.fetch, body })
      : request.url === '/internal/assist'
      ? await assistReadOnly({ env: process.env, fetchImpl: globalThis.fetch, body })
      : request.url === '/internal/discuss'
      ? await discussTurn({ env: process.env, fetchImpl: globalThis.fetch, body })
      : request.url === '/internal/promote'
      ? await composePromotion({ env: process.env, fetchImpl: globalThis.fetch, body })
      : request.url === '/internal/guide'
      ? await guideTurn({ env: process.env, fetchImpl: globalThis.fetch, body })
      : await runTask({ env: process.env, fetchImpl: globalThis.fetch, body });
    response.writeHead(result.ok ? 200 : 422, { 'Content-Type': 'application/json' });
    response.end(JSON.stringify(result));
  } catch(error) {
    const tooLarge=error?.message==='BODY_TOO_LARGE';
    response.writeHead(tooLarge?413:422, { 'Content-Type': 'application/json' });
    response.end(JSON.stringify({ ok: false, errorCode: tooLarge?'MATERIAL_LIMIT':'MODEL_FAILED' }));
  }
});

server.listen(port, '127.0.0.1');

function readBody(request,maxBytes) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let length=0,limited=false;
    request.on('data', (chunk) => {length+=chunk.length;if(length>maxBytes){if(!limited){limited=true;chunks.length=0;reject(new Error('BODY_TOO_LARGE'));}}else if(!limited)chunks.push(chunk);});
    request.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    request.on('error', reject);
  });
}
