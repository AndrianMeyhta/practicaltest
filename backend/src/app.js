import { randomUUID } from 'node:crypto';
import express from 'express';

export function createApp({ database } = {}) {
  const app = express();
  app.disable('x-powered-by');
  app.use((req, res, next) => {
    req.requestId = randomUUID();
    res.setHeader('X-Request-Id', req.requestId);
    next();
  });
  app.use(express.json({ limit: '64kb' }));

  // Liveness proses saja; belum memeriksa koneksi database.
  app.get('/api/v1/live', (req, res) => {
    res.json({ data: { status: 'ok' } });
  });
  app.get('/api/v1/health', async (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    try {
      if (!database) throw new Error('Database belum dikonfigurasi.');
      await database.check();
      res.json({ data: { status: 'ok', database: 'connected' } });
    } catch (error) {
      console.error({ requestId: req.requestId, code: error.code ?? 'DATABASE_UNAVAILABLE' });
      res.status(503).json({ error: {
        code: 'DATABASE_UNAVAILABLE',
        message: 'Database belum tersedia. Silakan coba lagi.',
        request_id: req.requestId,
      } });
    }
  });
  function pagination(req) {
    const page = req.query.page ?? '1';
    const limit = req.query.limit ?? '20';
    if (![page, limit].every((v) => typeof v === 'string' && /^[1-9]\d*$/.test(v)) ||
      !Number.isSafeInteger(Number(page)) || Number(page) > 1000000 || Number(limit) > 100) return null;
    return { page: Number(page), limit: Number(limit) };
  }
  app.get(['/api/v1/warehouses', '/api/v1/stocks'], async (req, res, next) => {
    const paging = pagination(req);
    const stocks = req.path.endsWith('/stocks');
    const warehouseId = Number(req.query.warehouse_id);
    if (!paging || (stocks && (!/^[1-9]\d*$/.test(req.query.warehouse_id ?? '') || !Number.isSafeInteger(warehouseId))) ||
      (req.query.search !== undefined && (typeof req.query.search !== 'string' || req.query.search.length > 100))) {
      return res.status(400).json({ error: { code: 'INVALID_QUERY', message: 'Parameter daftar tidak valid.', request_id: req.requestId } });
    }
    try {
      const result = stocks
        ? await database.listStocks({ ...paging, warehouseId, search: req.query.search ?? '' })
        : await database.listWarehouses(paging);
      if (!result) return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Gudang tidak ditemukan.', request_id: req.requestId } });
      res.json(result);
    } catch (error) { next(error); }
  });
  app.use((req, res) => {
    res.status(404).json({ error: {
      code: 'NOT_FOUND', message: 'Endpoint tidak ditemukan.', request_id: req.requestId,
    } });
  });
  app.use((error, req, res, next) => {
    if (res.headersSent) return next(error);
    const invalidJson = error.type === 'entity.parse.failed';
    const tooLarge = error.type === 'entity.too.large';
    const status = invalidJson ? 400 : tooLarge ? 413 : 500;
    if (status === 500) console.error({ requestId: req.requestId, error });
    res.status(status).json({ error: {
      code: invalidJson ? 'INVALID_JSON' : tooLarge ? 'PAYLOAD_TOO_LARGE' : 'INTERNAL_ERROR',
      message: invalidJson ? 'JSON tidak valid.' : tooLarge ? 'Payload terlalu besar.' : 'Terjadi kesalahan internal.',
      request_id: req.requestId,
    } });
  });
  return app;
}