import { createHash, randomUUID } from 'node:crypto';
import { ApiError } from './api-error.js';
import { transaction } from './master-store.js';

const kinds = { transfers: ['stock_transfers', 'transfer_number', 'MUT'], 'opening-stocks': ['opening_stocks', 'opening_number', 'AWL'], adjustments: ['stock_adjustments', 'adjustment_number', 'ADJ'] };
const conflict = (code, message) => { throw new ApiError(409, code, message); };

export function stockService(pool) {
  async function detail(c, kind, id) {
    const [table] = kinds[kind];
    const [[document]] = await c.execute(`SELECT * FROM ${table} WHERE id=?`, [id]);
    if (!document) throw new ApiError(404, 'NOT_FOUND', 'Dokumen tidak ditemukan.');
    delete document.request_fingerprint;
    delete document.idempotency_key;
    if (kind === 'transfers') {
      const [items] = await c.execute('SELECT * FROM stock_transfer_items WHERE transfer_id=? ORDER BY item_id', [id]);
      document.items = items;
    } else {
      const [[movement]] = await c.execute(`SELECT balance_before,balance_after FROM stock_movements WHERE ${kind === 'adjustments' ? 'adjustment_id' : 'opening_stock_id'}=?`, [id]);
      Object.assign(document, movement);
    }
    return { ...document, kind };
  }
  async function inspect(c, kind, body, lock) {
    const transfer = kind === 'transfers';
    const warehouseIds = transfer ? [body.source_warehouse_id, body.destination_warehouse_id].sort((a, b) => a - b) : [body.warehouse_id];
    const lines = transfer ? body.items : [{ item_id: body.item_id, quantity: body.quantity }];
    const warehouses = new Map(), items = new Map(), balances = new Map();
    const suffix = lock ? ' FOR UPDATE' : '';
    for (const id of warehouseIds) {
      const [[row]] = await c.execute(`SELECT id,code,name,is_active FROM warehouses WHERE id=?${suffix}`, [id]);
      if (!row?.is_active) conflict('MASTER_INACTIVE', 'Gudang tidak ditemukan atau tidak aktif.');
      warehouses.set(id, row);
    }
    for (const { item_id } of lines) {
      const [[row]] = await c.execute(`SELECT id,code,name,unit,is_active FROM items WHERE id=?${suffix}`, [item_id]);
      if (!row?.is_active) conflict('MASTER_INACTIVE', 'Barang tidak ditemukan atau tidak aktif.');
      items.set(item_id, row);
    }
    for (const warehouseId of warehouseIds) {
      for (const { item_id } of lines) {
        if (lock) await c.execute('INSERT INTO warehouse_stocks(warehouse_id,item_id,quantity) VALUES (?,?,0) ON DUPLICATE KEY UPDATE quantity=quantity', [warehouseId, item_id]);
        const [[row]] = await c.execute(`SELECT quantity FROM warehouse_stocks WHERE warehouse_id=? AND item_id=?${suffix}`, [warehouseId, item_id]);
        balances.set(`${warehouseId}:${item_id}`, row?.quantity ?? 0);
      }
    }
    if (kind === 'opening-stocks') {
      const [history] = await c.execute(`SELECT id FROM stock_movements WHERE warehouse_id=? AND item_id=? LIMIT 1${suffix}`, [body.warehouse_id, body.item_id]);
      const [opening] = await c.execute(`SELECT id FROM opening_stocks WHERE warehouse_id=? AND item_id=? LIMIT 1${suffix}`, [body.warehouse_id, body.item_id]);
      if (history.length || opening.length || balances.get(`${body.warehouse_id}:${body.item_id}`) !== 0) conflict('OPENING_NOT_ALLOWED', 'Pasangan barang dan gudang sudah memiliki stok atau histori.');
    }
    const changes = [];
    for (const line of lines) {
      for (const warehouseId of warehouseIds) {
        const before = balances.get(`${warehouseId}:${line.item_id}`);
        const out = transfer ? warehouseId === body.source_warehouse_id : body.direction === 'OUT';
        const after = before + (out ? -line.quantity : line.quantity);
        if (after < 0) conflict('INSUFFICIENT_STOCK', `Stok ${items.get(line.item_id).name} tidak mencukupi.`);
        if (after > 2147483647) conflict('STOCK_OVERFLOW', 'Saldo hasil melampaui batas penyimpanan.');
        changes.push({ warehouse_id: warehouseId, warehouse_name: warehouses.get(warehouseId).name,
          item_id: line.item_id, item_name: items.get(line.item_id).name, unit: items.get(line.item_id).unit,
          quantity_in: out ? 0 : line.quantity, quantity_out: out ? line.quantity : 0, balance_before: before, balance_after: after });
      }
    }
    return { warehouses, items, changes };
  }
  return {
    preview: (kind, body) => transaction(pool, async (c) => ({ changes: (await inspect(c, kind, body, false)).changes, reserved: false })),
    detail: (kind, id) => transaction(pool, (c) => detail(c, kind, id)),
    async create(kind, body, key) {
      const [table, number, prefix] = kinds[kind];
      const fingerprint = createHash('sha256').update(JSON.stringify(body)).digest('hex');
      const replay = async (c) => {
        const [[row]] = await c.execute(`SELECT id,request_fingerprint FROM ${table} WHERE idempotency_key=?`, [key]);
        if (!row) return null;
        if (row.request_fingerprint !== fingerprint) conflict('IDEMPOTENCY_CONFLICT', 'Key telah digunakan untuk isi transaksi berbeda.');
        return { data: await detail(c, kind, row.id), replay: true };
      };
      try {
        return await transaction(pool, async (c) => {
          const previous = await replay(c);
          if (previous) return previous;
          const { warehouses, items, changes } = await inspect(c, kind, body, true);
          const columns = [number, 'notes', 'idempotency_key', 'request_fingerprint'];
          const values = [randomUUID(), body.notes, key, fingerprint];
          if (kind === 'transfers') {
            for (const side of ['source', 'destination']) {
              const w = warehouses.get(body[`${side}_warehouse_id`]);
              columns.push(`${side}_warehouse_id`, `${side}_warehouse_code`, `${side}_warehouse_name`);
              values.push(w.id, w.code, w.name);
            }
          } else {
            const w = warehouses.get(body.warehouse_id), i = items.get(body.item_id);
            columns.push('warehouse_id', 'item_id', 'quantity', 'warehouse_code', 'warehouse_name', 'item_code', 'item_name', 'item_unit');
            values.push(w.id, i.id, body.quantity, w.code, w.name, i.code, i.name, i.unit);
            if (kind === 'adjustments') { columns.push('direction'); values.push(body.direction); }
          }
          const [result] = await c.execute(`INSERT INTO ${table} (${columns.join(',')}) VALUES (${columns.map(() => '?').join(',')})`, values);
          const id = result.insertId;
          await c.execute(`UPDATE ${table} SET ${number}=CONCAT(?,DATE_FORMAT(created_at,'%Y%m%d'),'-',id) WHERE id=?`, [`${prefix}-`, id]);
          const detailIds = new Map();
          if (kind === 'transfers') for (const line of body.items) {
            const i = items.get(line.item_id);
            const source = changes.find((s) => s.item_id === i.id && s.warehouse_id === body.source_warehouse_id);
            const destination = changes.find((s) => s.item_id === i.id && s.warehouse_id === body.destination_warehouse_id);
            const [r] = await c.execute(`INSERT INTO stock_transfer_items(transfer_id,item_id,item_code,item_name,item_unit,quantity,source_stock_before,source_stock_after,destination_stock_before,destination_stock_after) VALUES (?,?,?,?,?,?,?,?,?,?)`,
              [id, i.id, i.code, i.name, i.unit, line.quantity, source.balance_before, source.balance_after, destination.balance_before, destination.balance_after]);
            detailIds.set(i.id, r.insertId);
          }
          for (const change of changes) {
            const type = kind === 'opening-stocks' ? 'OPENING' : `${kind === 'transfers' ? 'TRANSFER' : 'ADJUSTMENT'}_${change.quantity_in ? 'IN' : 'OUT'}`;
            await c.execute(`INSERT INTO stock_movements(warehouse_id,item_id,movement_type,quantity_in,quantity_out,balance_before,balance_after,opening_stock_id,transfer_item_id,adjustment_id) VALUES (?,?,?,?,?,?,?,?,?,?)`,
              [change.warehouse_id, change.item_id, type, change.quantity_in, change.quantity_out, change.balance_before, change.balance_after,
                kind === 'opening-stocks' ? id : null, detailIds.get(change.item_id) ?? null, kind === 'adjustments' ? id : null]);
            await c.execute('UPDATE warehouse_stocks SET quantity=? WHERE warehouse_id=? AND item_id=?', [change.balance_after, change.warehouse_id, change.item_id]);
          }
          return { data: await detail(c, kind, id), replay: false };
        });
      } catch (error) {
        // Setelah rollback, baca baru menangkap hasil request identik yang menang.
        const previous = await transaction(pool, replay);
        if (previous) return previous;
        throw error;
      }
    },
  };
}