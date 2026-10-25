import test from 'node:test';
import assert from 'node:assert/strict';
import { historyQuery } from '../src/stock-history.js';

test('filter riwayat memvalidasi tanggal UTC, gudang, pencarian dan rentang', () => {
  const result = historyQuery({ search: ' MUT- ', from: '2026-10-01T00:00:00.000Z', until: '2026-11-01T00:00:00.000Z', source_warehouse_id: '1' });
  assert.equal(result.search, 'MUT-');
  assert.equal(result.source, '1');
  for (const query of [{ from: '2026-02-30T00:00:00.000Z' }, { source_warehouse_id: '0' }, { search: 'x'.repeat(101) }, { from: '2026-11-01T00:00:00.000Z', until: '2026-10-01T00:00:00.000Z' }]) {
    assert.throws(() => historyQuery(query));
  }
});