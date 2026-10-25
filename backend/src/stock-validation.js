import { ApiError } from './api-error.js';

export function stockPayload(body, kind) {
  const details = [];
  const fail = (field, message) => details.push({ field, message });
  const object = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
  const integer = (value, max = 4294967295) => Number.isInteger(value) && value > 0 && value <= max;
  if (!object(body)) throw new ApiError(422, 'VALIDATION_ERROR', 'Objek JSON wajib diisi.');
  const transfer = kind === 'transfers';
  const allowed = transfer ? ['source_warehouse_id', 'destination_warehouse_id', 'items', 'notes']
    : ['warehouse_id', 'item_id', 'quantity', 'notes', ...(kind === 'adjustments' ? ['direction'] : [])];
  for (const field of Object.keys(body)) if (!allowed.includes(field)) fail(field, 'Field tidak dikenal.');
  for (const field of transfer ? ['source_warehouse_id', 'destination_warehouse_id'] : ['warehouse_id', 'item_id']) {
    if (!integer(body[field])) fail(field, 'Pilih ID integer positif yang valid.');
  }
  if (transfer && body.source_warehouse_id === body.destination_warehouse_id) fail('destination_warehouse_id', 'Gudang asal dan tujuan harus berbeda.');
  const notes = typeof body.notes === 'string' ? body.notes.trim() : '';
  if (body.notes !== undefined && typeof body.notes !== 'string') fail('notes', 'Keterangan harus berupa teks.');
  if ([...notes].length > 500 || (kind === 'adjustments' && !notes)) fail('notes', 'Keterangan balancing wajib 1–500 karakter.');
  if (kind === 'adjustments' && !['IN', 'OUT'].includes(body.direction)) fail('direction', 'Pilih IN atau OUT.');
  const items = transfer ? body.items : [{ item_id: body.item_id, quantity: body.quantity }];
  if (!Array.isArray(items) || items.length < 1 || items.length > 50) fail('items', 'Isi 1–50 barang.');
  else {
    const ids = new Set();
    items.forEach((line, index) => {
      if (!object(line)) { fail(`items.${index}`, 'Baris barang harus berupa objek.'); return; }
      if (Object.keys(line).some((k) => !['item_id', 'quantity'].includes(k))) fail(`items.${index}`, 'Field tidak dikenal.');
      if (!integer(line.item_id) || ids.has(line.item_id)) fail(`items.${index}.item_id`, 'Barang harus valid dan tidak duplikat.');
      ids.add(line.item_id);
      if (!integer(line.quantity, 1000000)) fail(`items.${index}.quantity`, 'Jumlah harus integer 1–1.000.000.');
    });
  }
  if (details.length) throw new ApiError(422, 'VALIDATION_ERROR', 'Periksa isian transaksi.', details);
  return transfer ? { source_warehouse_id: body.source_warehouse_id, destination_warehouse_id: body.destination_warehouse_id,
    notes, items: items.map(({ item_id, quantity }) => ({ item_id, quantity })).sort((a, b) => a.item_id - b.item_id) }
    : { warehouse_id: body.warehouse_id, item_id: body.item_id, quantity: body.quantity, notes,
      ...(kind === 'adjustments' ? { direction: body.direction } : {}) };
}

export function idempotencyKey(value) {
  if (typeof value !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) {
    throw new ApiError(400, 'INVALID_IDEMPOTENCY_KEY', 'Header Idempotency-Key harus berupa UUID.');
  }
  return value.toLowerCase();
}