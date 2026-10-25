import { createHash, randomUUID } from 'node:crypto';

// Pemanggil memiliki transaksi; seluruh jalur stok wajib lock gudang lalu barang.
export async function insertOpeningStock(connection, { warehouseId, itemId, quantity, notes = '' }) {
  if (!Number.isInteger(quantity) || quantity < 1 || quantity > 1000000) {
    throw new Error('Quantity stok awal tidak valid.');
  }
  const [[warehouse]] = await connection.execute('SELECT * FROM warehouses WHERE id=? FOR UPDATE', [warehouseId]);
  const [[item]] = await connection.execute('SELECT * FROM items WHERE id=? FOR UPDATE', [itemId]);
  if (!warehouse?.is_active || !item?.is_active) throw new Error('Master tidak aktif.');
  await connection.execute(`INSERT INTO warehouse_stocks(warehouse_id,item_id,quantity)
    VALUES (?,?,0) ON DUPLICATE KEY UPDATE quantity=quantity`, [warehouseId, itemId]);
  const [[stock]] = await connection.execute('SELECT quantity FROM warehouse_stocks WHERE warehouse_id=? AND item_id=? FOR UPDATE', [warehouseId, itemId]);
  const [history] = await connection.execute('SELECT id FROM stock_movements WHERE warehouse_id=? AND item_id=? LIMIT 1', [warehouseId, itemId]);
  const [openings] = await connection.execute('SELECT id FROM opening_stocks WHERE warehouse_id=? AND item_id=? LIMIT 1', [warehouseId, itemId]);
  if (stock.quantity !== 0 || history.length || openings.length) throw new Error('OPENING_NOT_ALLOWED');
  const key = randomUUID();
  const fingerprint = createHash('sha256').update(JSON.stringify({ warehouse_id: warehouseId, item_id: itemId, quantity, notes })).digest('hex');
  const [result] = await connection.execute(`INSERT INTO opening_stocks
    (opening_number,warehouse_id,item_id,quantity,warehouse_code,warehouse_name,item_code,item_name,item_unit,notes,idempotency_key,request_fingerprint)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`,
  [key, warehouseId, itemId, quantity, warehouse.code, warehouse.name, item.code, item.name, item.unit, notes, key, fingerprint]);
  await connection.execute("UPDATE opening_stocks SET opening_number=CONCAT('AWL-',DATE_FORMAT(created_at,'%Y%m%d'),'-',id) WHERE id=?", [result.insertId]);
  await connection.execute(`INSERT INTO stock_movements
    (warehouse_id,item_id,movement_type,quantity_in,quantity_out,balance_before,balance_after,opening_stock_id)
    VALUES (?,?,'OPENING',?,0,0,?,?)`, [warehouseId, itemId, quantity, quantity, result.insertId]);
  await connection.execute('UPDATE warehouse_stocks SET quantity=? WHERE warehouse_id=? AND item_id=?', [quantity, warehouseId, itemId]);
  return result.insertId;
}