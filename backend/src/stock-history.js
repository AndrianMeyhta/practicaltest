import { transaction } from './master-store.js';
import { ApiError } from './api-error.js';

export function historyQuery(query, ledger = false) {
  const allowed = ledger ? ['page', 'limit', 'warehouse_id', 'item_id'] : ['page', 'limit', 'kind'];
  if (Object.keys(query).some((key) => !allowed.includes(key)) || Object.values(query).some((v) => typeof v !== 'string')) throw new ApiError(400, 'INVALID_QUERY', 'Parameter riwayat tidak valid.');
  const page = query.page ?? '1', limit = query.limit ?? '20';
  if (!/^[1-9]\d*$/.test(page) || Number(page) > 1000000 || !/^[1-9]\d*$/.test(limit) || Number(limit) > 100) throw new ApiError(400, 'INVALID_QUERY', 'Pagination tidak valid.');
  if (query.kind && !['transfers', 'opening-stocks', 'adjustments'].includes(query.kind)) throw new ApiError(400, 'INVALID_QUERY', 'Jenis transaksi tidak valid.');
  if (ledger && ['warehouse_id', 'item_id'].some((key) => !/^[1-9]\d*$/.test(query[key] ?? '') || Number(query[key]) > 4294967295)) throw new ApiError(400, 'INVALID_QUERY', 'Pilih gudang dan barang.');
  return { page: Number(page), limit: Number(limit), kind: query.kind, warehouseId: Number(query.warehouse_id), itemId: Number(query.item_id) };
}

export function stockHistory(pool) {
  const union = `SELECT id,'transfers' kind,transfer_number number,created_at,notes,CONCAT(source_warehouse_name,' → ',destination_warehouse_name) location FROM stock_transfers
    UNION ALL SELECT id,'opening-stocks',opening_number,created_at,notes,warehouse_name FROM opening_stocks
    UNION ALL SELECT id,'adjustments',adjustment_number,created_at,notes,warehouse_name FROM stock_adjustments`;
  return {
    list: ({ page, limit, kind }) => transaction(pool, async (c) => {
      const where = kind ? 'WHERE kind=?' : '', params = kind ? [kind] : [];
      const [[{ total }]] = await c.query(`SELECT COUNT(*) total FROM (${union}) d ${where}`, params);
      const [data] = await c.query(`SELECT * FROM (${union}) d ${where} ORDER BY created_at DESC,kind,id DESC LIMIT ? OFFSET ?`, [...params, limit, (page - 1) * limit]);
      return { data, meta: { page, limit, total } };
    }),
    ledger: ({ page, limit, warehouseId, itemId }) => transaction(pool, async (c) => {
      const params = [warehouseId, itemId];
      const [[{ total }]] = await c.execute('SELECT COUNT(*) total FROM stock_movements WHERE warehouse_id=? AND item_id=?', params);
      const [[balance]] = await c.execute('SELECT quantity FROM warehouse_stocks WHERE warehouse_id=? AND item_id=?', params);
      const [data] = await c.query(`SELECT m.*,t.transfer_id FROM stock_movements m LEFT JOIN stock_transfer_items t ON t.id=m.transfer_item_id WHERE m.warehouse_id=? AND m.item_id=? ORDER BY m.id DESC LIMIT ? OFFSET ?`, [...params, limit, (page - 1) * limit]);
      return { data, meta: { page, limit, total }, balance: balance?.quantity ?? 0 };
    }),
    dashboard: () => transaction(pool, async (c) => {
      const [[counts]] = await c.query('SELECT (SELECT COUNT(*) FROM items WHERE is_active=1) items,(SELECT COUNT(*) FROM warehouses WHERE is_active=1) warehouses');
      const [units] = await c.query('SELECT i.unit,SUM(s.quantity) quantity FROM warehouse_stocks s JOIN items i ON i.id=s.item_id GROUP BY i.unit ORDER BY i.unit');
      return { ...counts, units };
    }),
  };
}