-- ============================================================================
-- Brazilian E-Commerce (Olist) Dataset — Schema + CSV Import
-- Source folder: D:\SushilITProjects\SQL_Projects\brazilian-ecommerce\data\raw
-- Target: MySQL 8.x
-- ============================================================================
--
-- BEFORE RUNNING:
-- 1. This uses LOAD DATA LOCAL INFILE, which reads files from YOUR machine
--    (the mysql client), not the server. Two things must allow it:
--      a) Server:  SET GLOBAL local_infile = 1;
--      b) Client:  connect with --local-infile=1
--         mysql --local-infile=1 -u root -p < import_brazilian_ecommerce.sql
--    If you'd rather not enable local_infile, drop "LOCAL" from each LOAD DATA
--    statement below AND copy the CSVs into the MySQL server's secure_file_priv
--    directory (find it via: SHOW VARIABLES LIKE 'secure_file_priv';), updating
--    the paths accordingly.
--
-- 2. Paths below use forward slashes (MySQL requires this on Windows too):
--    D:/SushilITProjects/SQL_Projects/brazilian-ecommerce/data/raw/...
--
-- 3. review_comment_message / review_comment_title can rarely contain
--    embedded newlines inside quoted fields. Standard LOAD DATA INFILE does
--    not reliably parse newlines inside quoted fields. If the review import
--    row count looks short, re-import that one file via a tool that handles
--    quoted newlines (e.g. `mysqlimport` won't help either — use Python/
--    pandas `to_sql`, or LibreOffice/Excel to re-save the CSV with newlines
--    stripped from those two columns first).
-- ============================================================================

CREATE DATABASE IF NOT EXISTS brazilian_ecommerce
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE brazilian_ecommerce;

SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------------------------------------------------------
-- Drop tables if re-running (children first)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS order_reviews;
DROP TABLE IF EXISTS order_payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS product_category_name_translation;
DROP TABLE IF EXISTS sellers;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS geolocation;

-- ----------------------------------------------------------------------------
-- 1. customers
-- ----------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id             CHAR(32)     NOT NULL PRIMARY KEY,
    customer_unique_id      CHAR(32)     NOT NULL,
    customer_zip_code_prefix VARCHAR(5)  NOT NULL,
    customer_city           VARCHAR(100) NOT NULL,
    customer_state          CHAR(2)      NOT NULL,
    INDEX idx_customers_unique_id (customer_unique_id),
    INDEX idx_customers_zip (customer_zip_code_prefix)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 2. sellers
-- ----------------------------------------------------------------------------
CREATE TABLE sellers (
    seller_id             CHAR(32)     NOT NULL PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(5)  NOT NULL,
    seller_city           VARCHAR(100) NOT NULL,
    seller_state          CHAR(2)      NOT NULL,
    INDEX idx_sellers_zip (seller_zip_code_prefix)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 3. product_category_name_translation
-- ----------------------------------------------------------------------------
CREATE TABLE product_category_name_translation (
    product_category_name         VARCHAR(60) NOT NULL PRIMARY KEY,
    product_category_name_english VARCHAR(60) NOT NULL
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 4. products
-- ----------------------------------------------------------------------------
CREATE TABLE products (
    product_id                 CHAR(32)    NOT NULL PRIMARY KEY,
    product_category_name      VARCHAR(60) NULL,
    product_name_lenght        INT         NULL,
    product_description_lenght INT         NULL,
    product_photos_qty         INT         NULL,
    product_weight_g           INT         NULL,
    product_length_cm          INT         NULL,
    product_height_cm          INT         NULL,
    product_width_cm           INT         NULL,
    INDEX idx_products_category (product_category_name),
    CONSTRAINT fk_products_category
        FOREIGN KEY (product_category_name)
        REFERENCES product_category_name_translation (product_category_name)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 5. orders
-- ----------------------------------------------------------------------------
CREATE TABLE orders (
    order_id                      CHAR(32)    NOT NULL PRIMARY KEY,
    customer_id                   CHAR(32)    NOT NULL,
    order_status                  VARCHAR(20) NOT NULL,
    order_purchase_timestamp      DATETIME    NOT NULL,
    order_approved_at             DATETIME    NULL,
    order_delivered_carrier_date  DATETIME    NULL,
    order_delivered_customer_date DATETIME    NULL,
    order_estimated_delivery_date DATETIME    NULL,
    INDEX idx_orders_customer (customer_id),
    INDEX idx_orders_status (order_status),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 6. order_items
-- ----------------------------------------------------------------------------
CREATE TABLE order_items (
    order_id            CHAR(32)     NOT NULL,
    order_item_id        INT         NOT NULL,
    product_id           CHAR(32)    NOT NULL,
    seller_id            CHAR(32)    NOT NULL,
    shipping_limit_date  DATETIME    NOT NULL,
    price                 DECIMAL(10,2) NOT NULL,
    freight_value         DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    INDEX idx_order_items_product (product_id),
    INDEX idx_order_items_seller (seller_id),
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES products (product_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_order_items_seller
        FOREIGN KEY (seller_id)
        REFERENCES sellers (seller_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 7. order_payments
-- ----------------------------------------------------------------------------
CREATE TABLE order_payments (
    order_id             CHAR(32)    NOT NULL,
    payment_sequential   INT         NOT NULL,
    payment_type         VARCHAR(20) NOT NULL,
    payment_installments INT         NOT NULL,
    payment_value        DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_order_payments_order
        FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 8. order_reviews
-- ----------------------------------------------------------------------------
CREATE TABLE order_reviews (
    review_id               CHAR(32)  NOT NULL,
    order_id                CHAR(32)  NOT NULL,
    review_score             TINYINT  NOT NULL,
    review_comment_title     VARCHAR(255) NULL,
    review_comment_message   TEXT     NULL,
    review_creation_date     DATETIME NOT NULL,
    review_answer_timestamp  DATETIME NOT NULL,
    PRIMARY KEY (review_id, order_id),
    INDEX idx_order_reviews_order (order_id),
    CONSTRAINT fk_order_reviews_order
        FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 9. geolocation (standalone — no PK, zip prefixes repeat many times)
-- ----------------------------------------------------------------------------
CREATE TABLE geolocation (
    geolocation_zip_code_prefix VARCHAR(5)   NOT NULL,
    geolocation_lat              DOUBLE      NOT NULL,
    geolocation_lng              DOUBLE      NOT NULL,
    geolocation_city             VARCHAR(100) NOT NULL,
    geolocation_state            CHAR(2)      NOT NULL,
    INDEX idx_geolocation_zip (geolocation_zip_code_prefix)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- LOAD DATA — order matches FK dependency order (parents before children)
-- ============================================================================

-- 1. customers -----------------------------------------------------------
LOAD DATA LOCAL INFILE 'D:/SushilITProjects/SQL_Projects/brazilian-ecommerce/data/raw/olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state);

-- 2. sellers ---------------------------------------------------------------
LOAD DATA LOCAL INFILE 'D:/SushilITProjects/SQL_Projects/brazilian-ecommerce/data/raw/olist_sellers_dataset.csv'
INTO TABLE sellers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(seller_id, seller_zip_code_prefix, seller_city, seller_state);

-- 3. product_category_name_translation --------------------------------------
LOAD DATA LOCAL INFILE 'D:/SushilITProjects/SQL_Projects/brazilian-ecommerce/data/raw/product_category_name_translation.csv'
INTO TABLE product_category_name_translation
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_category_name, product_category_name_english);

-- 4. products (several columns may be empty -> NULL) -------------------------
LOAD DATA LOCAL INFILE 'D:/SushilITProjects/SQL_Projects/brazilian-ecommerce/data/raw/olist_products_dataset.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_id, @product_category_name, @product_name_lenght, @product_description_lenght,
 @product_photos_qty, @product_weight_g, @product_length_cm, @product_height_cm, @product_width_cm)
SET
    product_category_name      = NULLIF(@product_category_name, ''),
    product_name_lenght        = NULLIF(@product_name_lenght, ''),
    product_description_lenght = NULLIF(@product_description_lenght, ''),
    product_photos_qty         = NULLIF(@product_photos_qty, ''),
    product_weight_g           = NULLIF(@product_weight_g, ''),
    product_length_cm          = NULLIF(@product_length_cm, ''),
    product_height_cm          = NULLIF(@product_height_cm, ''),
    product_width_cm           = NULLIF(@product_width_cm, '');

-- 5. orders (delivery-related timestamps may be empty -> NULL) ---------------
LOAD DATA LOCAL INFILE 'D:/SushilITProjects/SQL_Projects/brazilian-ecommerce/data/raw/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, customer_id, order_status, order_purchase_timestamp,
 @order_approved_at, @order_delivered_carrier_date, @order_delivered_customer_date,
 @order_estimated_delivery_date)
SET
    order_approved_at             = NULLIF(@order_approved_at, ''),
    order_delivered_carrier_date  = NULLIF(@order_delivered_carrier_date, ''),
    order_delivered_customer_date = NULLIF(@order_delivered_customer_date, ''),
    order_estimated_delivery_date = NULLIF(@order_estimated_delivery_date, '');

-- 6. order_items -------------------------------------------------------------
LOAD DATA LOCAL INFILE 'D:/SushilITProjects/SQL_Projects/brazilian-ecommerce/data/raw/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value);

-- 7. order_payments -----------------------------------------------------------
LOAD DATA LOCAL INFILE 'D:/SushilITProjects/SQL_Projects/brazilian-ecommerce/data/raw/olist_order_payments_dataset.csv'
INTO TABLE order_payments
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, payment_sequential, payment_type, payment_installments, payment_value);

-- 8. order_reviews (title/message often empty -> NULL) -------------------------
LOAD DATA LOCAL INFILE 'D:/SushilITProjects/SQL_Projects/brazilian-ecommerce/data/raw/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(review_id, order_id, review_score, @review_comment_title, @review_comment_message,
 review_creation_date, review_answer_timestamp)
SET
    review_comment_title   = NULLIF(@review_comment_title, ''),
    review_comment_message = NULLIF(@review_comment_message, '');

-- 9. geolocation ----------------------------------------------------------------
LOAD DATA LOCAL INFILE 'D:/SushilITProjects/SQL_Projects/brazilian-ecommerce/data/raw/olist_geolocation_dataset.csv'
INTO TABLE geolocation
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state);

-- ============================================================================
-- Quick sanity check — row counts per table
-- ============================================================================
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation;
