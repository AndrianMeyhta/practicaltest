import { test } from 'node:test';
import assert from 'node:assert/strict';
import { stockPayload, idempotencyKey } from '../src/stock-validation.js';

test('validasi transaksi menolak tipe, jumlah, duplikasi, gudang sama dan field asing', () => {
  const valid = { source_warehouse_id: 1, destination_warehouse_id: 2, items: [{ item_id: 2, quantity: 1 }, { item_id: 1, quantity: 3 }] };
  assert.equal(stockPayload(valid, 'transfers').items[0].item_id, 1);
  for (const body of [null, [], {}, { ...valid, source_warehouse_id: '1' }, { ...valid, destination_warehouse_id: 1 }, { ...valid, items: [] }, { ...valid, items: Array(51).fill({ item_id: 1, quantity: 1 }) }, { ...valid, items: [{ item_id: 1, quantity: 1.5 }] }, { ...valid, items: [{ item_id: 1, quantity: 0 }] }, { ...valid, items: [{ item_id: 1, quantity: 1 }, { item_id: 1, quantity: 2 }] }, { ...valid, extra: true }]) {
    assert.throws(() => stockPayload(body, 'transfers'), { code: 'VALIDATION_ERROR' });
  }
  assert.throws(() => stockPayload({ warehouse_id: 1, item_id: 1, quantity: 1, direction: 'IN', notes: ' ' }, 'adjustments'));
  assert.throws(() => idempotencyKey('invalid'));
});