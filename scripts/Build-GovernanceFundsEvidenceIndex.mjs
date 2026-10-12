import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

// Index original immutable receipts; this does not turn successful defect
// observations, common preflight checks or older packages into acceptance.
const projectRoot = fs.realpathSync(process.cwd());
const requested = process.env.AISPORTS_REGRESSION_CONTEXT;
assert.ok(requested, 'A protected, existing regression context is required');
const contextPath = fs.realpathSync(requested);
const batchRoot = path.dirname(contextPath);
assert.ok(batchRoot.startsWith(path.join(projectRoot, '.local', 'business-regression-20261011') + path.sep));
assert.equal(path.basename(contextPath), 'context.private.json');
const context = JSON.parse(fs.readFileSync(contextPath, 'utf8'));
assert.equal(context.backend, 'http://127.0.0.1:8082');
assert.equal(context.frontend, 'http://127.0.0.1:5192');

const receiptPaths = [];
for (const entry of fs.readdirSync(batchRoot, { withFileTypes: true })) {
  if (!entry.isDirectory()) continue;
  if (entry.name === 'governance') {
    for (const child of fs.readdirSync(path.join(batchRoot, entry.name), { withFileTypes: true })) {
      if (child.isDirectory()) receiptPaths.push(path.join(entry.name, child.name, 'receipt.json'));
    }
  } else if (/^(?:payment-exception-(?:ui|resolution)|historical-funds|badminton-temporal-boundary|canonical-payment-proof|canonical-competition-results|badminton-aftercare)-/.test(entry.name)) {
    receiptPaths.push(path.join(entry.name, 'receipt.json'));
  }
}
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const records = receiptPaths.filter(relative => fs.existsSync(path.join(batchRoot, relative))).sort().map(relative => {
  const bytes = fs.readFileSync(path.join(batchRoot, relative));
  const receipt = JSON.parse(bytes);
  const checks = Array.isArray(receipt.checks) ? receipt.checks : [];
  return {
    path: relative.replaceAll('\\', '/'), sha256: hash(bytes),
    passed: receipt.passed === true,
    recordedMode: receipt.mode ?? null,
    jarSha256: receipt.jarSha256 ?? null,
    checkCount: checks.length,
    passedCheckCount: checks.filter(check => check.passed === true).length,
    failedCheckNames: checks.filter(check => check.passed === false).map(check => check.name),
    commonCheckNames: checks.filter(check => /preflight|identity is distinct|source stayed stable|no business write|no script error/i.test(check.name ?? '')).map(check => check.name)
  };
});
const index = {
  schema: 'aisports.governance-funds-evidence-index.v2',
  createdAt: new Date().toISOString(),
  scope: 'isolated-government-historical-funds-and-temporal-aftercare',
  kind: 'evidence-index-not-acceptance',
  boundaries: [
    'Only existing 8082/5192 synthetic business receipts are indexed; no request or mutation is executed.',
    'All original passed and failed receipt bytes are preserved.',
    'Check counts include common preflight and repeated stages; do not sum them as business use cases.',
    'A passed pre-fix-failure-observation receipt proves a reproduced defect, not working product behavior.',
    'An omitted historical JAR is recorded as null; no package binding is inferred.',
    'Pre-guard synthetic result receipts do not prove natural-time lifecycle correctness; use the new future-refusal and independent naturally started event evidence.',
    'These records do not verify real bank transfers, SMS delivery, field operations or real world awards.'
  ], records
};
const destination = path.join(batchRoot, `governance-funds-evidence-${Date.now()}-${crypto.randomUUID()}.json`);
const bytes = Buffer.from(JSON.stringify(index, null, 2) + '\n');
const descriptor = fs.openSync(destination, 'wx');
try { fs.writeFileSync(descriptor, bytes); fs.fsyncSync(descriptor); } finally { fs.closeSync(descriptor); }
console.log(JSON.stringify({ path: path.relative(projectRoot, destination).replaceAll('\\', '/'), sha256: hash(bytes), recordCount: records.length }));
