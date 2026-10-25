import mysql from 'mysql2/promise';

export function createDatabase(config) {
  const pool = mysql.createPool(config);
  return {
    async listWarehouses({ page, limit }) {
      const [[{ total }]] = await pool.query('SELECT COUNT(*) AS total FROM warehouses');
      const [rows] = await pool.query('SELECT id,code,name,is_active FROM warehouses ORDER BY id LIMIT ? OFFSET ?', [limit, (page - 1) * limit]);
      return { data: rows, meta: { page, limit, total } };
    },
    async listStocks({ warehouseId, page, limit, search }) {
      const connection = await pool.getConnection();
      try {
        await connection.query('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
        await connection.beginTransaction();
        const [[warehouse]] = await connection.execute('SELECT id FROM warehouses WHERE id=?', [warehouseId]);
        if (!warehouse) { await connection.rollback(); return null; }
        const where = `FROM items i LEFT JOIN warehouse_stocks s ON s.item_id=i.id AND s.warehouse_id=?
          WHERE (i.is_active=1 OR COALESCE(s.quantity,0)>0) AND (i.code LIKE ? OR i.name LIKE ?)`;
        const params = [warehouseId, `%${search}%`, `%${search}%`];
        const [[{ total }]] = await connection.query(`SELECT COUNT(*) AS total ${where}`, params);
        const [rows] = await connection.query(`SELECT i.id AS item_id,i.code,i.name,i.unit,COALESCE(s.quantity,0) AS quantity ${where} ORDER BY i.id LIMIT ? OFFSET ?`, [...params, limit, (page-1)*limit]);
        await connection.commit();
        return { data: rows, meta: { page, limit, total } };
      } catch (error) { await connection.rollback(); throw error; }
      finally { connection.release(); }
    },
    async check() {
      const connection = await pool.getConnection();
      try {
        await connection.query({ sql: 'SELECT 1 AS healthy', timeout: 3000 });
      } finally {
        connection.release();
      }
    },
    close: () => pool.end(),
  };
}