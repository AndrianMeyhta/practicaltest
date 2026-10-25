import { randomUUID } from 'node:crypto';
import express from 'express';
import { ApiError, publicError } from './api-error.js';
import { validateId, validateList, validateMaster } from './master-validation.js';
import { stockPayload, idempotencyKey } from './stock-validation.js';
import { historyQuery } from './stock-history.js';

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
        details: [],
        request_id: req.requestId,
      } });
    }
  });
  for (const kind of ['items', 'warehouses']) {
    const path = `/api/v1/${kind}`;
    app.get(path, async (req, res) => {
      res.json(await database[kind].list(validateList(req.query, kind)));
    });
    app.post(path, async (req, res) => {
      const body = validateMaster(req.body, kind);
      res.status(201).json({ data: await database[kind].create(body) });
    });
    app.patch(`${path}/:id`, async (req, res) => {
      const id = validateId(req.params.id);
      const body = validateMaster(req.body, kind, true);
      res.json({ data: await database[kind].update(id, body) });
    });
    app.delete(`${path}/:id`, async (req, res) => {
      const id = validateId(req.params.id);
      await database[kind].remove(id);
      res.status(204).end();
    });
  }
  app.get('/api/v1/stocks', async (req, res) => {
    const result = await database.listStocks(validateList(req.query, 'stocks'));
    if (!result) throw new ApiError(404, 'NOT_FOUND', 'Gudang tidak ditemukan.');
    res.json(result);
  });
  for (const kind of ['opening-stocks', 'transfers', 'adjustments']) {
    app.post(`/api/v1/${kind}/preview`, async (req, res) => {
      res.json({ data: await database.transactions.preview(kind, stockPayload(req.body, kind)) });
    });
    app.post(`/api/v1/${kind}`, async (req, res) => {
      const body = stockPayload(req.body, kind);
      const result = await database.transactions.create(kind, body, idempotencyKey(req.get('Idempotency-Key')));
      res.status(result.replay ? 200 : 201).json({ data: result.data });
    });
    app.get(`/api/v1/${kind}/:id`, async (req, res) => {
      res.json({ data: await database.transactions.detail(kind, validateId(req.params.id)) });
    });
  }
  app.get('/api/v1/history', async (req, res) => res.json(await database.history.list(historyQuery(req.query))));
  app.get('/api/v1/stock-card', async (req, res) => res.json(await database.history.ledger(historyQuery(req.query, true))));
  app.get('/api/v1/dashboard', async (req, res) => res.json({ data: await database.history.dashboard() }));
  app.use((req, res) => {
    res.status(404).json({ error: {
      code: 'NOT_FOUND', message: 'Endpoint tidak ditemukan.', details: [], request_id: req.requestId,
    } });
  });
  app.use((error, req, res, next) => {
    if (res.headersSent) return next(error);
    const invalidJson = error.type === 'entity.parse.failed';
    const tooLarge = error.type === 'entity.too.large';
    const safe = invalidJson ? new ApiError(400, 'INVALID_JSON', 'JSON tidak valid.')
      : tooLarge ? new ApiError(413, 'PAYLOAD_TOO_LARGE', 'Payload terlalu besar.') : publicError(error);
    if (safe.status >= 500) console.error({ requestId: req.requestId, code: error.code ?? safe.code });
    res.status(safe.status).json({ error: {
      code: safe.code,
      message: safe.message,
      details: safe.details,
      request_id: req.requestId,
    } });
  });
  return app;
}