-- ============================================================================
-- 1. SALES AND REVENUE ANALYSIS
-- MySQL 8.x | Database created by sqlquery_schema/Sql Query for create table.sql.sql
-- ============================================================================
USE olist_brazilian_ecommerce;

-- 1.1 Total revenue trend by month, quarter, and year.
-- Revenue is calculated once per order to avoid duplicating payment totals when
-- an order has multiple items or review rows.
WITH order_revenue AS (
    SELECT
        o.order_id,
        o.order_purchase_timestamp,
        SUM(op.payment_value) AS revenue
    FROM olist_orders o
    JOIN olist_order_payments op ON op.order_id = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY o.order_id, o.order_purchase_timestamp
)
SELECT
    YEAR(order_purchase_timestamp) AS order_year,
    QUARTER(order_purchase_timestamp) AS order_quarter,
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,
    COUNT(*) AS order_count,
    ROUND(SUM(revenue), 2) AS total_revenue,
    ROUND(AVG(revenue), 2) AS average_order_value
FROM order_revenue
GROUP BY order_year, order_quarter, order_month
ORDER BY order_year, order_month;

-- 1.2 Revenue and order volume by product category.
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name,
             'unknown') AS product_category,
    COUNT(DISTINCT oi.order_id) AS order_count,
    SUM(oi.order_item_id IS NOT NULL) AS item_count,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS freight_revenue,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS gross_item_value
FROM olist_order_items oi
JOIN olist_orders o ON o.order_id = oi.order_id
JOIN olist_products p ON p.product_id = oi.product_id
LEFT JOIN product_category_translation t
    ON t.product_category_name = p.product_category_name
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY product_category
ORDER BY gross_item_value DESC;

-- 1.3 Revenue by customer state and city.
SELECT
    c.customer_state,
    c.customer_city,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS gross_revenue
FROM olist_customers c
JOIN olist_orders o ON o.customer_id = c.customer_id
JOIN olist_order_items oi ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_state, c.customer_city
ORDER BY gross_revenue DESC;

-- 1.4 Average order value and basket size, with one row per order.
WITH order_baskets AS (
    SELECT
        o.order_id,
        COUNT(oi.product_id) AS item_count,
        SUM(oi.price + oi.freight_value) AS basket_value
    FROM olist_orders o
    JOIN olist_order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY o.order_id
)
SELECT
    COUNT(*) AS orders_with_items,
    ROUND(AVG(basket_value), 2) AS average_order_value,
    ROUND(AVG(item_count), 2) AS average_basket_size,
    MIN(basket_value) AS minimum_order_value,
    MAX(basket_value) AS maximum_order_value,
    ROUND(SUM(basket_value), 2) AS total_item_value
FROM order_baskets;

-- 1.5 Top-selling products and categories.
SELECT
    oi.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name,
             'unknown') AS product_category,
    COUNT(*) AS units_sold,
    COUNT(DISTINCT oi.order_id) AS orders_containing_product,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(AVG(oi.price), 2) AS average_unit_price
FROM olist_order_items oi
JOIN olist_orders o ON o.order_id = oi.order_id
JOIN olist_products p ON p.product_id = oi.product_id
LEFT JOIN product_category_translation t
    ON t.product_category_name = p.product_category_name
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY oi.product_id, product_category
ORDER BY units_sold DESC, product_revenue DESC
LIMIT 50;

-- 1.6 Price distribution and outlier detection by category.
WITH item_prices AS (
    SELECT
        COALESCE(t.product_category_name_english, p.product_category_name,
                 'unknown') AS product_category,
        oi.price
    FROM olist_order_items oi
    JOIN olist_orders o ON o.order_id = oi.order_id
    JOIN olist_products p ON p.product_id = oi.product_id
    LEFT JOIN product_category_translation t
        ON t.product_category_name = p.product_category_name
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
), category_stats AS (
    SELECT
        product_category,
        COUNT(*) AS item_count,
        AVG(price) AS average_price,
        STDDEV_POP(price) AS price_stddev,
        MIN(price) AS minimum_price,
        MAX(price) AS maximum_price
    FROM item_prices
    GROUP BY product_category
)
SELECT
    product_category,
    item_count,
    ROUND(average_price, 2) AS average_price,
    ROUND(price_stddev, 2) AS price_stddev,
    ROUND(minimum_price, 2) AS minimum_price,
    ROUND(maximum_price, 2) AS maximum_price,
    ROUND(average_price - 2 * price_stddev, 2) AS lower_outlier_threshold,
    ROUND(average_price + 2 * price_stddev, 2) AS upper_outlier_threshold
FROM category_stats
ORDER BY price_stddev DESC;