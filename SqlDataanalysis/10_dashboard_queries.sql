-- ============================================================================
-- 10. DASHBOARD QUERIES (POWER BI / TABLEAU)
-- Each result is shaped for a visual or KPI card.
-- ============================================================================
USE olist_brazilian_ecommerce;

-- 10.1 Executive KPI cards: revenue, orders, AOV, and on-time delivery.
WITH order_values AS (
    SELECT
        o.order_id,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM olist_orders o
    LEFT JOIN olist_order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY o.order_id, o.order_delivered_customer_date,
             o.order_estimated_delivery_date
)
SELECT
    COUNT(*) AS completed_order_count,
    ROUND(SUM(order_value), 2) AS gross_revenue,
    ROUND(AVG(order_value), 2) AS average_order_value,
    ROUND(AVG(order_delivered_customer_date IS NOT NULL), 4)
        AS delivery_completion_rate,
    ROUND(100 * AVG(
        CASE WHEN order_delivered_customer_date IS NOT NULL
             THEN order_delivered_customer_date <= order_estimated_delivery_date
        END), 2) AS on_time_delivery_percentage
FROM order_values;

-- 10.2 Monthly executive trend.
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01') AS month_start,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(oi.order_item_id) AS item_count,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS gross_revenue,
    ROUND(SUM(oi.price + oi.freight_value) /
          NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS average_order_value
FROM olist_orders o
JOIN olist_order_items oi ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY month_start
ORDER BY month_start;

-- 10.3 Regional map view.
SELECT
    c.customer_state,
    c.customer_city,
    COUNT(DISTINCT o.order_id) AS order_count,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS gross_revenue,
    ROUND(AVG(oi.price + oi.freight_value), 2) AS average_item_value
FROM olist_customers c
JOIN olist_orders o ON o.customer_id = c.customer_id
JOIN olist_order_items oi ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_state, c.customer_city
ORDER BY gross_revenue DESC;

-- 10.4 Seller performance dashboard dataset.
SELECT
    oi.seller_id,
    s.seller_state,
    s.seller_city,
    COUNT(DISTINCT oi.order_id) AS order_count,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS gross_revenue,
    ROUND(AVG(r.review_score), 2) AS average_review_score,
    ROUND(100 * AVG(o.order_delivered_customer_date <=
                    o.order_estimated_delivery_date), 2) AS on_time_percentage
FROM olist_order_items oi
JOIN olist_orders o ON o.order_id = oi.order_id
JOIN olist_sellers s ON s.seller_id = oi.seller_id
LEFT JOIN olist_order_reviews r ON r.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY oi.seller_id, s.seller_state, s.seller_city
ORDER BY gross_revenue DESC;

-- 10.5 Drill-down: category -> product -> order.
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name,
             'unknown') AS product_category,
    oi.product_id,
    o.order_id,
    o.order_purchase_timestamp,
    c.customer_state,
    oi.seller_id,
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value AS line_total,
    o.order_status
FROM olist_order_items oi
JOIN olist_orders o ON o.order_id = oi.order_id
JOIN olist_customers c ON c.customer_id = o.customer_id
JOIN olist_products p ON p.product_id = oi.product_id
LEFT JOIN product_category_translation t
    ON t.product_category_name = p.product_category_name
ORDER BY product_category, oi.product_id, o.order_purchase_timestamp;
