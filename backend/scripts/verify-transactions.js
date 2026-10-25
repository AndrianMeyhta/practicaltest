import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

export async function verifyTransactions(url, connection) {
  async function send(kind, body, key = randomUUID(), expected = 201) {
    const response = await fetch(`${url}/${kind}`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Idempotency-Key': key }, body: JSON.stringify(body) });
    const json = await response.json();
    assert.equal(response.status, expected, JSON.stringify(json));
    return json.data;
  }
  const transfer = { source_warehouse_id: 1, destination_warehouse_id: 3, items: [{ item_id: 1, quantity: 2 }, { item_id: 2, quantity: 3 }] };
  const preview = await send('transfers/preview', transfer, randomUUID(), 200);
  assert.equal(preview.changes.length, 4);
  const key = randomUUID();
  const first = await send('transfers', transfer, key);
  assert.equal(first.items.length, 2);
  assert.equal((await send('transfers', transfer, key, 200)).id, first.id);
  await send('transfers', { ...transfer, notes: 'Berbeda' }, key, 409);
  await send('transfers', { ...transfer, items: [{ item_id: 1, quantity: 1000000 }] }, randomUUID(), 409);
  await send('adjustments', { warehouse_id: 3, item_id: 1, quantity: 1, direction: 'OUT', notes: 'Reject' });
  await send('adjustments', { warehouse_id: 3, item_id: 1, quantity: 2, direction: 'IN', notes: 'Selisih fisik' });
  await send('adjustments', { warehouse_id: 3, item_id: 1, quantity: 4, direction: 'OUT', notes: 'Reject' }, randomUUID(), 409);
  const opening = { warehouse_id: 3, item_id: 3, quantity: 7 };
  const openingKey = randomUUID();
  const doc = await send('opening-stocks', opening, openingKey);
  assert.equal((await send('opening-stocks', opening, openingKey, 200)).id, doc.id);
  await send('opening-stocks', opening, randomUUID(), 409);
  const snapshot = async () => {
    const [stocks] = await connection.query('SELECT warehouse_id,item_id,quantity FROM warehouse_stocks ORDER BY warehouse_id,item_id');
    const [[counts]] = await connection.query('SELECT (SELECT COUNT(*) FROM stock_transfers) transfers,(SELECT COUNT(*) FROM stock_transfer_items) details,(SELECT COUNT(*) FROM stock_movements) movements');
    return { stocks, counts };
  };
  const before = await snapshot();
  await connection.query("CREATE TRIGGER fail_transaction BEFORE INSERT ON stock_movements FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='transaction rollback test'");
  await send('transfers', transfer, randomUUID(), 500);
  await connection.query('DROP TRIGGER fail_transaction');
  assert.deepEqual(await snapshot(), before);
  const concurrentKey = randomUUID();
  const responses = await Promise.all([1, 2].map(() => fetch(`${url}/transfers`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Idempotency-Key': concurrentKey }, body: JSON.stringify(transfer) })));
  assert.deepEqual(responses.map((r) => r.status).sort(), [200, 201]);
  const documents = await Promise.all(responses.map((r) => r.json()));
  assert.equal(documents[0].data.id, documents[1].data.id);
  const stock = (await snapshot()).stocks.find((s) => s.warehouse_id === 3 && s.item_id === 1).quantity;
  const compete = await Promise.all([1, 2].map(() => fetch(`${url}/adjustments`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Idempotency-Key': randomUUID() }, body: JSON.stringify({ warehouse_id: 3, item_id: 1, direction: 'OUT', quantity: stock, notes: 'Uji konkurensi' }) })));
  assert.deepEqual(compete.map((r) => r.status).sort(), [201, 409]);
  const [mismatch] = await connection.query(`SELECT s.* FROM warehouse_stocks s JOIN stock_movements m ON m.id=(SELECT MAX(x.id) FROM stock_movements x WHERE x.warehouse_id=s.warehouse_id AND x.item_id=s.item_id) WHERE s.quantity<>m.balance_after`);
  assert.equal(mismatch.length, 0);
  const history = await (await fetch(`${url}/history?limit=2`)).json();
  assert.equal(history.data.length, 2);
  const ledger = await (await fetch(`${url}/stock-card?warehouse_id=3&item_id=1&limit=1`)).json();
  assert.equal(ledger.balance, 0);
  assert.equal(ledger.data[0].balance_after, 0);
  console.log('Transaksi: preview multi-item, transfer, balancing, stok awal, replay dan konflik lulus.');
}