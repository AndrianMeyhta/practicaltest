import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateMaster, validateList, validateId } from '../src/master-validation.js';
import { transaction } from '../src/master-store.js';

test('validasi master normalisasi, panjang, tipe, immutable dan PATCH kosong', () => {
  const valid = { code: ' abc_1-x ', name: ' Barang ', unit: ' pcs ' };
  assert.deepEqual(validateMaster(valid, 'items'), { code: 'ABC_1-X', name: 'Barang', unit: 'pcs', is_active: true });
  for (const body of [null, [], {}, { ...valid, code: 'ß' }, { ...valid, code: 'x'.repeat(31) },
    { ...valid, code: '' }, { ...valid, name: ' ' }, { ...valid, name: 'a'.repeat(101) },
    { ...valid, unit: 'a'.repeat(21) }, { ...valid, unit: 1 }, { ...valid, is_active: 1 }, { ...valid, extra: 1 }]) {
    assert.throws(() => validateMaster(body, 'items'), { code: 'VALIDATION_ERROR' });
  }
  for (const body of [{}, { code: 'ABC' }, { unit: 'pcs' }, { is_active: 'false' }]) {
    assert.throws(() => validateMaster(body, 'items', true));
  }
  assert.deepEqual(validateMaster({ name: ' Baru ', is_active: false }, 'items', true), { name: 'Baru', is_active: false });
  assert.equal(validateMaster({ code: 'A'.repeat(30), name: 'a'.repeat(100), unit: 'u'.repeat(20) }, 'items').code.length, 30);
});

test('query dan ID ketat', () => {
  for (const query of [{ page: '0' }, { limit: '101' }, { active: '1' }, { page: ['1', '2'] }, { unknown: 'x' }, { search: 'x'.repeat(101) }]) {
    assert.throws(() => validateList(query, 'items'), { code: 'INVALID_QUERY' });
  }
  assert.equal(validateList({ active: 'false', search: '  ' }, 'items').active, false);
  for (const id of ['0', '-1', '1.0', '4294967296', ['1'], undefined]) assert.throws(() => validateId(id));
});

test('transaksi rollback dan release ketika operasi atau commit gagal', async () => {
  for (const commitFails of [true, false]) {
    const events = [];
    const c = { beginTransaction: async () => events.push('begin'),
      commit: async () => { events.push('commit'); throw new Error('commit'); },
      rollback: async () => events.push('rollback'), release: () => events.push('release') };
    await assert.rejects(transaction({ getConnection: async () => c }, async () => {
      if (!commitFails) throw new Error('operation');
    }));
    assert.deepEqual(events.slice(-2), ['rollback', 'release']);
  }
});