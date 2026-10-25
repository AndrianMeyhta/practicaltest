import { randomUUID } from 'node:crypto';
import express from 'express';

export function createApp() {
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