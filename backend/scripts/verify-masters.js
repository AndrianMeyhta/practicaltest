import assert from 'node:assert/strict';
import mysql from 'mysql2/promise';
import { insertOpeningStock } from '../src/opening-stock.js';

export async function verifyMasters({ url, connection, config, database }) {
  async function request(path, method = 'GET', body, status = 200) {
    const response = await fetch(`${url}/${path}`, { method,
      headers: { 'Content-Type': 'application/json' }, body: body === undefined ? undefined : JSON.stringify(body) });
    const data = response.status === 204 ? null : await response.json();
    assert.equal(response.status, status, JSON.stringify(data));
    if (status >= 400) { assert.ok(Array.isArray(data.error.details)); assert.ok(data.error.request_id); }
    return data;
  }
  for (const kind of ['items', 'warehouses']) {
    const body = { code: ` test_${kind} `, name: ' Test ', ...(kind === 'items' ? { unit: ' pcs ' } : {}) };
    const { data: created } = await request(kind, 'POST', body, 201);
    assert.equal(created.code, `TEST_${kind.toUpperCase()}`);
    assert.equal(created.name, 'Test');
    await request(kind, 'POST', { ...body, code: created.code.toLowerCase() }, 409);
    for (const invalid of [{}, { code: created.code }, { unit: 'pcs' }, { unknown: true }, { is_active: 0 }]) {
      await request(`${kind}/${created.id}`, 'PATCH', invalid, 422);
    }
    await request(`${kind}/0`, 'DELETE', undefined, 400);
    await request(`${kind}/4294967295`, 'PATCH', { name: 'Missing' }, 404);
    await request(`${kind}/${created.id}`, 'PATCH', { name: ' Renamed ', is_active: false });
    const filtered = await request(`${kind}?active=false&limit=1`);
    assert.ok(filtered.data.every((r) => r.is_active === false));
    await request(`${kind}?active=1`, 'GET', undefined, 400);
    await request(`${kind}?page=1&page=2`, 'GET', undefined, 400);
    if (kind === 'items') {
      const result = await request(`${kind}?search=test_items`);
      assert.equal(result.meta.total, 1);
    }
    await request(`${kind}/1`, 'PATCH', { is_active: false }, 409);
    const used = await request(`${kind}/1`, 'DELETE', undefined, 409);
    assert.equal(used.error.code, 'MASTER_IN_USE');
    if (kind === 'items') await connection.execute('INSERT INTO warehouse_stocks VALUES (3,?,0,DEFAULT)', [created.id]);
    else await connection.execute('INSERT INTO warehouse_stocks VALUES (?,1,0,DEFAULT)', [created.id]);
    // Fault injection hanya pada database terisolasi: gagal setelah saldo nol dihapus.
    await connection.query(`CREATE TRIGGER fail_delete_${kind} BEFORE DELETE ON ${kind} FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='test rollback'`);
    await request(`${kind}/${created.id}`, 'DELETE', undefined, 500);
    const [[{ total }]] = await connection.execute(`SELECT COUNT(*) total FROM warehouse_stocks WHERE ${kind === 'items' ? 'item_id' : 'warehouse_id'}=?`, [created.id]);
    assert.equal(total, 1);
    await connection.query(`DROP TRIGGER fail_delete_${kind}`);
    await request(`${kind}/${created.id}`, 'DELETE', undefined, 204);
    await request(`${kind}/${created.id}`, 'DELETE', undefined, 404);
  }
  const pair = await Promise.all([1, 2].map(() => fetch(`${url}/items`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ code: 'RACE-CODE', name: 'Race', unit: 'pcs' }) })));
  assert.deepEqual(pair.map((r) => r.status).sort(), [201, 409]);

  // Stok awal memegang lock terlebih dahulu, bukan service mutasi.
  for (const kind of ['items', 'warehouses']) {
    for (const operation of ['remove', 'update']) {
      const master = await database[kind].create({ code: `RACE-${kind}-${operation}`, name: 'Race', unit: 'pcs', is_active: true });
      const c = await mysql.createConnection(config);
      try {
        await c.beginTransaction();
        await insertOpeningStock(c, { warehouseId: kind === 'warehouses' ? master.id : 3, itemId: kind === 'items' ? master.id : 1, quantity: 1 });
        const pending = database[kind][operation](master.id, { is_active: false }).then(() => null, (e) => e);
        await c.commit();
        const error = await pending;
        assert.equal(error.code, operation === 'remove' ? 'MASTER_IN_USE' : 'MASTER_HAS_STOCK');
      } finally { await c.end(); }
      const inactive = await database[kind].create({ code: `FIRST-${kind}-${operation}`, name: 'Master first', unit: 'pcs', is_active: true });
      await database[kind][operation](inactive.id, { is_active: false });
      await connection.beginTransaction();
      await assert.rejects(insertOpeningStock(connection, {
        warehouseId: kind === 'warehouses' ? inactive.id : 3,
        itemId: kind === 'items' ? inactive.id : 1, quantity: 1,
      }), /Master tidak aktif/);
      await connection.rollback();
    }
  }
  // Histori tetap melarang penghapusan walaupun saldo nol.
  await connection.query('UPDATE warehouse_stocks SET quantity=0 WHERE item_id=1');
  assert.equal((await request('items/1', 'DELETE', undefined, 409)).error.code, 'MASTER_IN_USE');
  await request('items/1', 'PATCH', { is_active: false });
  console.log('CRUD master: HTTP, constraint, saldo nol, histori, rollback dan konkurensi helper stok awal lulus.');
}