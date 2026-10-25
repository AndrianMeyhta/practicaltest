CREATE TABLE stock_adjustments (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 adjustment_number VARCHAR(40) NOT NULL UNIQUE,
 warehouse_id INT UNSIGNED NOT NULL,
 item_id INT UNSIGNED NOT NULL,
 direction VARCHAR(3) NOT NULL CHECK (direction IN ('IN','OUT')),
 quantity INT NOT NULL CHECK (quantity BETWEEN 1 AND 1000000),
 warehouse_code VARCHAR(30) NOT NULL,
 warehouse_name VARCHAR(100) NOT NULL,
 item_code VARCHAR(30) NOT NULL,
 item_name VARCHAR(100) NOT NULL,
 item_unit VARCHAR(20) NOT NULL,
 notes VARCHAR(500) NOT NULL CHECK (CHAR_LENGTH(TRIM(notes)) > 0),
 idempotency_key CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
 request_fingerprint CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE RESTRICT,
 FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE stock_movements
 ADD COLUMN adjustment_id INT UNSIGNED NULL UNIQUE,
 ADD FOREIGN KEY (adjustment_id) REFERENCES stock_adjustments(id) ON DELETE RESTRICT,
 DROP CHECK stock_movements_chk_6,
 ADD CONSTRAINT ck_movement_source CHECK (
  (movement_type='OPENING' AND opening_stock_id IS NOT NULL AND transfer_item_id IS NULL AND adjustment_id IS NULL AND quantity_in>0 AND quantity_out=0 AND balance_before=0)
  OR (movement_type='TRANSFER_IN' AND opening_stock_id IS NULL AND transfer_item_id IS NOT NULL AND adjustment_id IS NULL AND quantity_in>0 AND quantity_out=0)
  OR (movement_type='TRANSFER_OUT' AND opening_stock_id IS NULL AND transfer_item_id IS NOT NULL AND adjustment_id IS NULL AND quantity_out>0 AND quantity_in=0)
  OR (movement_type='ADJUSTMENT_IN' AND opening_stock_id IS NULL AND transfer_item_id IS NULL AND adjustment_id IS NOT NULL AND quantity_in>0 AND quantity_out=0)
  OR (movement_type='ADJUSTMENT_OUT' AND opening_stock_id IS NULL AND transfer_item_id IS NULL AND adjustment_id IS NOT NULL AND quantity_out>0 AND quantity_in=0)
 );