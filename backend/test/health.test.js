import assert from 'node:assert/strict';
import { once } from 'node:events';
import { test } from 'node:test';
import { createApp } from '../src/app.js';
import { readDatabaseConfig } from '../src/config.js';

test('konfigurasi database wajib dan port valid', () => {
  assert.throws(() => readDatabaseConfig({}), /DB_HOST/);
  const env = { DB_HOST: 'localhost', DB_USER: 'app', DB_NAME: 'inventory' };
  assert.equal(readDatabaseConfig(env).port, 3306);
  assert.throws(() => readDatabaseConfig({ ...env, DB_PORT: 'invalid' }));
});

for (const available of [true, false]) {
  test(`health database ${available ? 'tersedia' : 'gagal'}`, async (t) => {
    let checks = 0;
    const database = { async check() {
      checks++;
      if (!available) throw new Error('secret password and SQL');
    } };
    const server = createApp({ database }).listen(0, '127.0.0.1');
    await once(server, 'listening');
    t.after(() => new Promise((resolve) => server.close(resolve)));
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/v1/health`);
    const body = await response.json();
    assert.equal(checks, 1);
    assert.equal(response.status, available ? 200 : 503);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    if (available) assert.deepEqual(body.data, { status: 'ok', database: 'connected' });
    else {
      assert.equal(body.error.code, 'DATABASE_UNAVAILABLE');
      assert.equal(body.error.request_id, response.headers.get('x-request-id'));
      assert.equal(JSON.stringify(body).includes('secret'), false);
    }
  });
}