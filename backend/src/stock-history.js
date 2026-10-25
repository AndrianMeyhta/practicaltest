import { transaction } from './master-store.js';
import { ApiError } from './api-error.js';

export function historyQuery(query, ledger = false) {
  const allowed = ledger ? ['page', 'limit', 'warehouse_id', 'item_id'] : ['page', 'limit', 'kind', 'search', 'from', 'until', 'source_warehouse_id', 'destination_warehouse_id'];
  if (Object.keys(query).some((key) => !allowed.includes(key)) || Object.values(query).some((v) => typeof v !== 'string')) throw new ApiError(400, 'INVALID_QUERY', 'Parameter riwayat tidak valid.');
  const page = query.page ?? '1', limit = query.limit ?? '20';
  if (!/^[1-9]\d*$/.test(page) || Number(page) > 1000000 || !/^[1-9]\d*$/.test(limit) || Number(limit) > 100) throw new ApiError(400, 'INVALID_QUERY', 'Pagination tidak valid.');
  if (query.kind && !['transfers', 'opening-stocks', 'adjustments'].includes(query.kind)) throw new ApiError(400, 'INVALID_QUERY', 'Jenis transaksi tidak valid.');
  if (ledger && ['warehouse_id', 'item_id'].some((key) => !/^[1-9]\d*$/.test(query[key] ?? '') || Number(query[key]) > 4294967295)) throw new ApiError(400, 'INVALID_QUERY', 'Pilih gudang dan barang.');
  if ((query.search ?? '').trim().length > 100) throw new ApiError(400, 'INVALID_QUERY', 'Pencarian maksimal 100 karakter.');
  for (const key of ['source_warehouse_id', 'destination_warehouse_id']) {
    if (query[key] !== undefined && (!/^[1-9]\d*$/.test(query[key]) || Number(query[key]) > 4294967295)) throw new ApiError(400, 'INVALID_QUERY', 'Filter gudang tidak valid.');
  }
  for (const key of ['from', 'until']) {
    if (query[key] !== undefined && (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(query[key]) || !Number.isFinite(Date.parse(query[key])) || new Date(query[key]).toISOString() !== query[key])) throw new ApiError(400, 'INVALID_QUERY', 'Rentang waktu harus timestamp UTC valid.');
  }
  if (query.from && query.until && query.from >= query.until) throw new ApiError(400, 'INVALID_QUERY', 'Akhir rentang harus setelah awal.');
  return { page: Number(page), limit: Number(limit), kind: query.kind, warehouseId: Number(query.warehouse_id), itemId: Number(query.item_id),
    search: (query.search ?? '').trim(), from: query.from, until: query.until,
    source: query.source_warehouse_id, destination: query.destination_warehouse_id };
}

export function stockHistory(pool) {
  const union = `SELECT id,'transfers' kind,transfer_number number,created_at,notes,CONCAT(source_warehouse_name,' → ',destination_warehouse_name) location,
    source_warehouse_id,destination_warehouse_id,(SELECT COUNT(*) FROM stock_transfer_items i WHERE i.transfer_id=stock_transfers.id) item_count FROM stock_transfers
    UNION ALL SELECT id,'opening-stocks',opening_number,created_at,notes,warehouse_name,NULL,warehouse_id,1 FROM opening_stocks
    UNION ALL SELECT id,'adjustments',adjustment_number,created_at,notes,warehouse_name,IF(direction='OUT',warehouse_id,NULL),IF(direction='IN',warehouse_id,NULL),1 FROM stock_adjustments`;
  return {
    list: ({ page, limit, kind, search, from, until, source, destination }) => transaction(pool, async (c) => {
      const clauses = [], params = [];
      for (const [column, value] of [['kind', kind], ['source_warehouse_id', source], ['destination_warehouse_id', destination]]) {
        if (value) { clauses.push(`${column}=?`); params.push(value); }
      }
      if (search) { clauses.push("number LIKE ? ESCAPE '!'"); params.push(`%${search.replace(/[!%_]/g, '!$&')}%`); }
      if (from) { clauses.push('created_at>=?'); params.push(new Date(from)); }
      if (until) { clauses.push('created_at<?'); params.push(new Date(until)); }
      const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
      const [[{ total }]] = await c.query(`SELECT COUNT(*) total FROM (${union}) d ${where}`, params);
      const [data] = await c.query(`SELECT * FROM (${union}) d ${where} ORDER BY created_at DESC,kind,id DESC LIMIT ? OFFSET ?`, [...params, limit, (page - 1) * limit]);
      return { data, meta: { page, limit, total } };
    }),
    ledger: ({ page, limit, warehouseId, itemId }) => transaction(pool, async (c) => {
      const params = [warehouseId, itemId];
      const [[{ total }]] = await c.execute('SELECT COUNT(*) total FROM stock_movements WHERE warehouse_id=? AND item_id=?', params);
      const [[balance]] = await c.execute('SELECT quantity FROM warehouse_stocks WHERE warehouse_id=? AND item_id=?', params);
      const [data] = await c.query(`SELECT m.*,t.transfer_id,COALESCE(d.transfer_number,o.opening_number,a.adjustment_number) document_number
        FROM stock_movements m LEFT JOIN stock_transfer_items t ON t.id=m.transfer_item_id
        LEFT JOIN stock_transfers d ON d.id=t.transfer_id LEFT JOIN opening_stocks o ON o.id=m.opening_stock_id
        LEFT JOIN stock_adjustments a ON a.id=m.adjustment_id
        WHERE m.warehouse_id=? AND m.item_id=? ORDER BY m.id DESC LIMIT ? OFFSET ?`, [...params, limit, (page - 1) * limit]);
      return { data, meta: { page, limit, total }, balance: balance?.quantity ?? 0 };
    }),
    dashboard: () => transaction(pool, async (c) => {
      const [[counts]] = await c.query('SELECT (SELECT COUNT(*) FROM items WHERE is_active=1) items,(SELECT COUNT(*) FROM warehouses WHERE is_active=1) warehouses');
      const [units] = await c.query('SELECT i.unit,SUM(s.quantity) quantity FROM warehouse_stocks s JOIN items i ON i.id=s.item_id GROUP BY i.unit ORDER BY i.unit');
      return { ...counts, units };
    }),
  };
}