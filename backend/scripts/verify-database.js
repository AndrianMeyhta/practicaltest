import assert from 'node:assert/strict';
import { once } from 'node:events';
import mysql from 'mysql2/promise';
import { readDatabaseConfig } from '../src/config.js';
import { migrate } from '../src/migrate.js';
import { seedDemo } from '../src/seed.js';
import { insertOpeningStock } from '../src/opening-stock.js';
import { createDatabase } from '../src/database.js';
import { createApp } from '../src/app.js';

// Hanya database sementara yang dibuat oleh proses ini yang dihapus.
const config = readDatabaseConfig();
const name = `inventory_test_${process.pid}_${Date.now()}`;
const admin = await mysql.createConnection(config);
let connection, database, server;
let created = false;
try {
  await admin.query(`CREATE DATABASE \`${name}\` CHARACTER SET utf8mb4`);
  created = true;
  connection = await mysql.createConnection({ ...config, database: name });
  await migrate(connection);
  await migrate(connection);
  assert.equal(await seedDemo(connection), true);
  assert.equal(await seedDemo(connection), false);
  const [[counts]] = await connection.query(`SELECT
    (SELECT COUNT(*) FROM items) items,
    (SELECT COUNT(*) FROM warehouses) warehouses,
    (SELECT COUNT(*) FROM opening_stocks) openings,
    (SELECT COUNT(*) FROM stock_movements) movements,
    (SELECT COUNT(*) FROM stock_transfers) transfers`);
  assert.deepEqual(counts, { items: 3, warehouses: 3, openings: 5, movements: 5, transfers: 0 });
  const [mismatch] = await connection.query(`SELECT s.* FROM warehouse_stocks s
    JOIN stock_movements m ON m.warehouse_id=s.warehouse_id AND m.item_id=s.item_id
    WHERE s.quantity<>m.balance_after`);
  assert.equal(mismatch.length, 0);
  await assert.rejects(connection.query('UPDATE warehouse_stocks SET quantity=-1 LIMIT 1'));
  await assert.rejects(connection.query("INSERT INTO items(code,name,unit) VALUES ('upvc-ksn-pth-6m','duplicate','batang')"));
  await assert.rejects(connection.query('DELETE FROM items WHERE id=1'));
  await assert.rejects(connection.query('UPDATE stock_movements SET balance_after=999 WHERE id=1'));
  await assert.rejects(connection.query('UPDATE stock_movements SET opening_stock_id=NULL WHERE id=1'));
  await connection.beginTransaction();
  await assert.rejects(insertOpeningStock(connection, { warehouseId: 1, itemId: 1, quantity: 1 }), /OPENING_NOT_ALLOWED/);
  await connection.rollback();
  await connection.beginTransaction();
  await insertOpeningStock(connection, { warehouseId: 3, itemId: 1, quantity: 9 });
  // Simulasi kegagalan pemanggil sesudah dokumen, saldo, dan pergerakan ditulis.
  await connection.rollback();
  const [[rollback]] = await connection.query('SELECT COUNT(*) total FROM warehouse_stocks WHERE warehouse_id=3');
  assert.equal(rollback.total, 0);
  const [[openingCount]] = await connection.query('SELECT COUNT(*) total FROM opening_stocks');
  assert.equal(openingCount.total, 5);
  const [[movementCount]] = await connection.query('SELECT COUNT(*) total FROM stock_movements');
  assert.equal(movementCount.total, 5);

  database = createDatabase({ ...config, database: name });
  server = createApp({ database }).listen(0, '127.0.0.1');
  await once(server, 'listening');
  const url = `http://127.0.0.1:${server.address().port}/api/v1`;
  assert.equal((await fetch(`${url}/health`)).status, 200);
  const warehouses = await (await fetch(`${url}/warehouses?limit=2`)).json();
  assert.equal(warehouses.data.length, 2);
  assert.equal(warehouses.meta.total, 3);
  const empty = await (await fetch(`${url}/stocks?warehouse_id=3`)).json();
  assert.deepEqual(empty.data.map((row) => row.quantity), [0,0,0]);
  const main = await (await fetch(`${url}/stocks?warehouse_id=1`)).json();
  assert.deepEqual(main.data.map((row) => row.quantity), [25,40,12]);
  assert.equal((await fetch(`${url}/stocks?warehouse_id=999`)).status, 404);
  assert.equal((await fetch(`${url}/stocks?warehouse_id=1&limit=101`)).status, 400);
  console.log('MySQL: migration ulang, seed ulang, constraint, rollback, rekonsiliasi, dan HTTP API lulus.');
} finally {
  if (server) await new Promise((resolve) => server.close(resolve));
  if (database) await database.close();
  if (connection) await connection.end();
  if (created) await admin.query(`DROP DATABASE \`${name}\``);
  await admin.end();
}