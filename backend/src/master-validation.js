import { ApiError } from './api-error.js';

const length = (value) => [...value].length;
export function validateId(value) {
  if (typeof value !== 'string' || !/^[1-9]\d*$/.test(value) || Number(value) > 4294967295) {
    throw new ApiError(400, 'INVALID_ID', 'ID harus berupa integer positif yang valid.');
  }
  return Number(value);
}

export function validateList(query, kind) {
  const allowed = ['page', 'limit', ...(kind !== 'warehouses' ? ['search'] : []), ...(kind === 'stocks' ? ['warehouse_id'] : ['active'])];
  const invalid = () => { throw new ApiError(400, 'INVALID_QUERY', 'Parameter daftar tidak valid.'); };
  if (Object.keys(query).some((key) => !allowed.includes(key)) || Object.values(query).some((v) => typeof v !== 'string')) invalid();
  const page = query.page ?? '1', limit = query.limit ?? '20';
  if (![page, limit].every((v) => /^[1-9]\d*$/.test(v)) || !Number.isSafeInteger(Number(page)) || Number(page) > 1000000 || Number(limit) > 100) invalid();
  if (query.active !== undefined && !['true', 'false'].includes(query.active)) invalid();
  const search = (query.search ?? '').trim();
  if (length(search) > 100) invalid();
  let warehouseId;
  if (kind === 'stocks') {
    try { warehouseId = validateId(query.warehouse_id); } catch { invalid(); }
  }
  return { page: Number(page), limit: Number(limit), search, warehouseId,
    active: query.active === undefined ? undefined : query.active === 'true' };
}

export function validateMaster(body, kind, patch = false) {
  const details = [];
  const fail = (field, message) => details.push({ field, message });
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw new ApiError(422, 'VALIDATION_ERROR', 'Isi request harus berupa objek JSON.', []);
  }
  const allowed = patch ? ['name', 'is_active'] : ['code', 'name', 'is_active', ...(kind === 'items' ? ['unit'] : [])];
  for (const key of Object.keys(body)) {
    if (!allowed.includes(key)) fail(key, patch && ['code', 'unit'].includes(key) ? 'Field ini tidak dapat diubah.' : 'Field tidak dikenal.');
  }
  if (patch && Object.keys(body).length === 0) fail('_form', 'Isi minimal nama atau status aktif.');
  const result = {};
  for (const [field, max] of [['code', 30], ['name', 100], ...(kind === 'items' ? [['unit', 20]] : [])]) {
    if (patch && (field !== 'name' || !Object.hasOwn(body, field))) continue;
    if (typeof body[field] !== 'string') { fail(field, 'Wajib berupa teks.'); continue; }
    let value = body[field].trim();
    if (length(value) < 1 || length(value) > max) fail(field, `Panjang harus 1–${max} karakter setelah trim.`);
    if (field === 'code') {
      if (!/^[A-Za-z0-9_-]+$/.test(value)) fail(field, 'Gunakan huruf ASCII, angka, tanda hubung, atau underscore.');
      value = value.toUpperCase();
    }
    result[field] = value;
  }
  if (Object.hasOwn(body, 'is_active')) {
    if (typeof body.is_active !== 'boolean') fail('is_active', 'Status aktif harus berupa boolean.');
    else result.is_active = body.is_active;
  } else if (!patch) result.is_active = true;
  if (details.length) throw new ApiError(422, 'VALIDATION_ERROR', 'Periksa kembali isian Anda.', details);
  return result;
}