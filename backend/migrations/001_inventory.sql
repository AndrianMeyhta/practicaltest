CREATE TABLE items (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 code VARCHAR(30) NOT NULL UNIQUE,
 name VARCHAR(100) NOT NULL,
 unit VARCHAR(20) NOT NULL,
 is_active BOOLEAN NOT NULL DEFAULT TRUE CHECK (is_active IN (0,1)),
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE warehouses (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 code VARCHAR(30) NOT NULL UNIQUE,
 name VARCHAR(100) NOT NULL,
 is_active BOOLEAN NOT NULL DEFAULT TRUE CHECK (is_active IN (0,1)),
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE warehouse_stocks (
 warehouse_id INT UNSIGNED NOT NULL,
 item_id INT UNSIGNED NOT NULL,
 quantity INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
 updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
 PRIMARY KEY (warehouse_id,item_id),
 FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE RESTRICT,
 FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE stock_transfers (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 transfer_number VARCHAR(40) NOT NULL UNIQUE,
 source_warehouse_id INT UNSIGNED NOT NULL,
 destination_warehouse_id INT UNSIGNED NOT NULL,
 source_warehouse_code VARCHAR(30) NOT NULL,
 source_warehouse_name VARCHAR(100) NOT NULL,
 destination_warehouse_code VARCHAR(30) NOT NULL,
 destination_warehouse_name VARCHAR(100) NOT NULL,
 status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED' CHECK (status = 'COMPLETED'),
 notes VARCHAR(500) NOT NULL DEFAULT '',
 idempotency_key CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
 request_fingerprint CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 CHECK (source_warehouse_id <> destination_warehouse_id),
 FOREIGN KEY (source_warehouse_id) REFERENCES warehouses(id) ON DELETE RESTRICT,
 FOREIGN KEY (destination_warehouse_id) REFERENCES warehouses(id) ON DELETE RESTRICT,
 INDEX ix_transfer_history (created_at,id),
 INDEX ix_transfer_source (source_warehouse_id,created_at,id),
 INDEX ix_transfer_destination (destination_warehouse_id,created_at,id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE stock_transfer_items (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 transfer_id INT UNSIGNED NOT NULL,
 item_id INT UNSIGNED NOT NULL,
 item_code VARCHAR(30) NOT NULL,
 item_name VARCHAR(100) NOT NULL,
 item_unit VARCHAR(20) NOT NULL,
 quantity INT NOT NULL CHECK (quantity BETWEEN 1 AND 1000000),
 source_stock_before INT NOT NULL CHECK (source_stock_before >= 0),
 source_stock_after INT NOT NULL CHECK (source_stock_after >= 0),
 destination_stock_before INT NOT NULL CHECK (destination_stock_before >= 0),
 destination_stock_after INT NOT NULL CHECK (destination_stock_after >= 0),
 CHECK (source_stock_after = source_stock_before - quantity),
 CHECK (destination_stock_after = destination_stock_before + quantity),
 UNIQUE (transfer_id,item_id),
 FOREIGN KEY (transfer_id) REFERENCES stock_transfers(id) ON DELETE RESTRICT,
 FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE opening_stocks (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 opening_number VARCHAR(40) NOT NULL UNIQUE,
 warehouse_id INT UNSIGNED NOT NULL,
 item_id INT UNSIGNED NOT NULL,
 quantity INT NOT NULL CHECK (quantity BETWEEN 1 AND 1000000),
 warehouse_code VARCHAR(30) NOT NULL,
 warehouse_name VARCHAR(100) NOT NULL,
 item_code VARCHAR(30) NOT NULL,
 item_name VARCHAR(100) NOT NULL,
 item_unit VARCHAR(20) NOT NULL,
 notes VARCHAR(500) NOT NULL DEFAULT '',
 idempotency_key CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
 request_fingerprint CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 UNIQUE (warehouse_id,item_id),
 FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE RESTRICT,
 FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE stock_movements (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 warehouse_id INT UNSIGNED NOT NULL,
 item_id INT UNSIGNED NOT NULL,
 movement_type VARCHAR(20) NOT NULL,
 quantity_in INT NOT NULL DEFAULT 0 CHECK (quantity_in BETWEEN 0 AND 1000000),
 quantity_out INT NOT NULL DEFAULT 0 CHECK (quantity_out BETWEEN 0 AND 1000000),
 balance_before INT NOT NULL CHECK (balance_before >= 0),
 balance_after INT NOT NULL CHECK (balance_after >= 0),
 opening_stock_id INT UNSIGNED NULL UNIQUE,
 transfer_item_id INT UNSIGNED NULL,
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 CHECK (balance_after = balance_before + quantity_in - quantity_out),
 CHECK (
   (movement_type = 'OPENING' AND opening_stock_id IS NOT NULL AND transfer_item_id IS NULL AND quantity_in > 0 AND quantity_out = 0 AND balance_before = 0)
   OR (movement_type = 'TRANSFER_IN' AND opening_stock_id IS NULL AND transfer_item_id IS NOT NULL AND quantity_in > 0 AND quantity_out = 0)
   OR (movement_type = 'TRANSFER_OUT' AND opening_stock_id IS NULL AND transfer_item_id IS NOT NULL AND quantity_out > 0 AND quantity_in = 0)
 ),
 UNIQUE (transfer_item_id,movement_type),
 INDEX ix_movement_pair (warehouse_id,item_id,id),
 FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE RESTRICT,
 FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE RESTRICT,
 FOREIGN KEY (opening_stock_id) REFERENCES opening_stocks(id) ON DELETE RESTRICT,
 FOREIGN KEY (transfer_item_id) REFERENCES stock_transfer_items(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;