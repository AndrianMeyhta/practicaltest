import { ApiError } from './api-error.js';

export const escapeSearch = (value) => value.replace(/[!%_]/g, '!$&');

export async function transaction(pool, operation) {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const result = await operation(connection);
    await connection.commit();
    return result;
  } catch (error) {
    try { await connection.rollback(); } catch { /* Pertahankan error penyebab. */ }
    throw error;
  } finally { connection.release(); }
}

export function masterStore(pool, kind) {
  if (!['items', 'warehouses'].includes(kind)) throw new Error('Jenis master tidak valid.');
  // Identifier hanya berasal dari allowlist internal, tidak dari input pengguna.
  const item = kind === 'items';
  const foreign = item ? 'item_id' : 'warehouse_id';
  const fields = `id,code,name,${item ? 'unit,' : ''}is_active`;
  const present = (row) => ({ ...row, is_active: Boolean(row.is_active) });
  const lock = async (c, id) => {
    const [[row]] = await c.execute(`SELECT ${fields} FROM ${kind} WHERE id=? FOR UPDATE`, [id]);
    if (!row) throw new ApiError(404, 'NOT_FOUND', `${item ? 'Barang' : 'Gudang'} tidak ditemukan.`);
    return row;
  };
  const ensureZero = async (c, id) => {
    const [stocks] = await c.execute(`SELECT warehouse_id,item_id,quantity FROM warehouse_stocks WHERE ${foreign}=? ORDER BY warehouse_id,item_id FOR UPDATE`, [id]);
    if (stocks.some((s) => s.quantity !== 0)) throw new ApiError(409, 'MASTER_HAS_STOCK', 'Master masih memiliki stok. Seluruh saldo harus nol.', [{ field: 'is_active', message: 'Master hanya dapat dinonaktifkan jika seluruh saldo nol.' }]);
  };
  return {
    list: ({ page, limit, search = '', active }) => transaction(pool, async (c) => {
      const clauses = [], params = [];
      if (active !== undefined) { clauses.push('is_active=?'); params.push(active); }
      if (item && search) {
        clauses.push("(code LIKE ? ESCAPE '!' OR name LIKE ? ESCAPE '!')");
        params.push(...Array(2).fill(`%${escapeSearch(search)}%`));
      }
      const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
      const [[{ total }]] = await c.query(`SELECT COUNT(*) total FROM ${kind} ${where}`, params);
      const [rows] = await c.query(`SELECT ${fields} FROM ${kind} ${where} ORDER BY id LIMIT ? OFFSET ?`, [...params, limit, (page - 1) * limit]);
      return { data: rows.map(present), meta: { page, limit, total } };
    }),
    create: (body) => transaction(pool, async (c) => {
      const columns = ['code', 'name', ...(item ? ['unit'] : []), 'is_active'];
      const [result] = await c.execute(`INSERT INTO ${kind} (${columns.join(',')}) VALUES (${columns.map(() => '?').join(',')})`, columns.map((key) => body[key]));
      return present(await lock(c, result.insertId));
    }),
    update: (id, body) => transaction(pool, async (c) => {
      // Lock hanya master target, lalu saldo. Jangan mengambil lock gudang setelah barang.
      await lock(c, id);
      if (body.is_active === false) await ensureZero(c, id);
      const columns = ['name', 'is_active'].filter((key) => Object.hasOwn(body, key));
      await c.execute(`UPDATE ${kind} SET ${columns.map((key) => `${key}=?`).join(',')} WHERE id=?`, [...columns.map((key) => body[key]), id]);
      return present(await lock(c, id));
    }),
    remove: (id) => transaction(pool, async (c) => {
      await lock(c, id);
      // Locking read melihat commit terbaru setelah menunggu master, bukan snapshot lama.
      const references = [
        ['stock_adjustments', `${foreign}=?`, [id]],
        ['opening_stocks', `${foreign}=?`, [id]],
        [item ? 'stock_transfer_items' : 'stock_transfers', item ? 'item_id=?' : 'source_warehouse_id=? OR destination_warehouse_id=?', item ? [id] : [id, id]],
        ['stock_movements', `${foreign}=?`, [id]],
      ];
      for (const [table, condition, params] of references) {
        const [rows] = await c.execute(`SELECT id FROM ${table} WHERE ${condition} LIMIT 1 FOR UPDATE`, params);
        if (rows.length) throw new ApiError(409, 'MASTER_IN_USE', 'Master sudah digunakan. Histori tidak boleh dihapus; gunakan penonaktifan setelah saldo nol.');
      }
      await ensureZero(c, id);
      await c.execute(`DELETE FROM warehouse_stocks WHERE ${foreign}=? AND quantity=0`, [id]);
      await c.execute(`DELETE FROM ${kind} WHERE id=?`, [id]);
    }),
  };
}