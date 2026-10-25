import assert from 'node:assert/strict';
import { once } from 'node:events';
import { test } from 'node:test';
import { createApp } from '../src/app.js';
import { readConfig } from '../src/config.js';

test('konfigurasi port memiliki default dan menolak nilai tidak valid', () => {
  assert.deepEqual(readConfig({}), { host: '127.0.0.1', port: 3000 });
  assert.equal(readConfig({ PORT: '4000' }).port, 4000);
  for (const PORT of ['', '0', '-1', '1.5', '65536', 'abc']) {
    assert.throws(() => readConfig({ PORT }));
  }
});

test('HTTP liveness, route tidak ditemukan, dan validasi JSON', async (t) => {
  const server = createApp().listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;
  const live = await fetch(`${base}/api/v1/live`);
  assert.equal(live.status, 200);
  assert.deepEqual(await live.json(), { data: { status: 'ok' } });
  assert.equal(live.headers.get('x-powered-by'), null);
  const missing = await fetch(`${base}/missing`);
  assert.equal(missing.status, 404);
  const body = await missing.json();
  assert.equal(body.error.code, 'NOT_FOUND');
  assert.equal(body.error.request_id, missing.headers.get('x-request-id'));
  const invalid = await fetch(`${base}/api/v1/live`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{',
  });
  assert.equal(invalid.status, 400);
  assert.equal((await invalid.json()).error.code, 'INVALID_JSON');
  const oversized = await fetch(`${base}/api/v1/live`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text: 'x'.repeat(66000) }),
  });
  assert.equal(oversized.status, 413);
  assert.equal((await oversized.json()).error.code, 'PAYLOAD_TOO_LARGE');
});