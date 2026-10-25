export class ApiError extends Error {
  constructor(status, code, message, details = []) {
    super(message);
    Object.assign(this, { status, code, details });
  }
}

export function publicError(error) {
  if (error instanceof ApiError) return error;
  if (error.code === 'ER_DUP_ENTRY') return new ApiError(409, 'DUPLICATE_CODE', 'Kode sudah digunakan.', [{ field: 'code', message: 'Gunakan kode lain.' }]);
  if (error.code === 'ER_ROW_IS_REFERENCED_2') return new ApiError(409, 'MASTER_IN_USE', 'Master sudah digunakan dan tidak dapat dihapus.');
  if (['ER_LOCK_DEADLOCK', 'ER_LOCK_WAIT_TIMEOUT'].includes(error.code)) {
    return new ApiError(503, 'TRANSACTION_RETRY_REQUIRED', 'Data sedang diproses oleh operasi lain. Silakan coba lagi.');
  }
  if (['ECONNREFUSED', 'ECONNRESET', 'ETIMEDOUT', 'EPIPE', 'PROTOCOL_CONNECTION_LOST', 'ER_CON_COUNT_ERROR', 'ER_SERVER_SHUTDOWN', 'ER_ACCESS_DENIED_ERROR', 'ER_BAD_DB_ERROR'].includes(error.code) || error.message === 'No connections available.') {
    return new ApiError(503, 'DATABASE_UNAVAILABLE', 'Database belum tersedia. Hasil operasi tulis mungkin belum diketahui; periksa data terbaru sebelum mencoba lagi.');
  }
  return new ApiError(500, 'INTERNAL_ERROR', 'Terjadi kesalahan internal.');
}