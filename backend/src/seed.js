import { insertOpeningStock } from './opening-stock.js';

export async function seedDemo(connection) {
  const lockName = `seed:${connection.config.database}`;
  const [[lock]] = await connection.query('SELECT GET_LOCK(?,10) AS acquired', [lockName]);
  if (lock.acquired !== 1) throw new Error('Seed sedang berjalan.');
  try {
    await connection.query("SET time_zone = '+00:00'");
    await connection.beginTransaction();
    const [done] = await connection.query("SELECT name FROM seed_runs WHERE name='upvc-v1'");
    if (done.length) { await connection.rollback(); return false; }
    for (const table of ['items', 'warehouses', 'warehouse_stocks', 'opening_stocks', 'stock_transfers', 'stock_movements']) {
      const [[row]] = await connection.query(`SELECT COUNT(*) AS total FROM ${table}`);
      if (row.total) throw new Error('Seed hanya boleh dijalankan pada database aplikasi kosong.');
    }
    const warehouses = [];
    for (const [code, name] of [['GDG-UTAMA', 'Gudang Utama'], ['GDG-CABANG', 'Gudang Cabang'], ['GDG-BARU', 'Gudang Baru']]) {
      const [result] = await connection.execute('INSERT INTO warehouses(code,name) VALUES (?,?)', [code, name]);
      warehouses.push(result.insertId);
    }
    const items = [];
    for (const values of [
      ['UPVC-KSN-PTH-6M', 'Profil Kusen UPVC Putih 6 Meter', 'batang'],
      ['ACC-ENG-JDL', 'Engsel Jendela UPVC', 'pcs'],
      ['ACC-HDL-JDL-PTH', 'Handle Jendela UPVC Putih', 'pcs'],
    ]) {
      const [result] = await connection.execute('INSERT INTO items(code,name,unit) VALUES (?,?,?)', values);
      items.push(result.insertId);
    }
    for (const [w, i, quantity] of [[0,0,25], [0,1,40], [0,2,12], [1,0,3], [1,1,5]]) {
      await insertOpeningStock(connection, { warehouseId: warehouses[w], itemId: items[i], quantity, notes: 'Saldo awal demo UPVC' });
    }
    await connection.execute("INSERT INTO seed_runs(name) VALUES ('upvc-v1')");
    await connection.commit();
    return true;
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally { await connection.query('SELECT RELEASE_LOCK(?)', [lockName]); }
}