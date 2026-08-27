-- ============================================================================
-- 8. PREDICTIVE MODELING / ML USE CASES
-- These queries create labeled feature datasets for export to Python/R.
-- ============================================================================
USE olist_brazilian_ecommerce;

-- 8.1 Late-delivery prediction: one row per completed order.
-- Target = 1 when delivery was later than the estimated date.
SELECT
    o.order_id,
    c.customer_state,
    c.customer_city,
    COUNT(oi.order_item_id) AS item_count,
    SUM(oi.price) AS product_value,
    SUM(oi.freight_value) AS freight_value,
    SUM(oi.price + oi.freight_value) AS order_value,
    AVG(p.product_weight_g) AS average_product_weight_g,
    COUNT(DISTINCT oi.seller_id) AS seller_count,
    TIMESTAMPDIFF(HOUR, o.order_purchase_timestamp, o.order_approved_at)
        AS approval_delay_hours,
    DATEDIFF(o.order_estimated_delivery_date, DATE(o.order_purchase_timestamp))
        AS promised_delivery_window_days,
    TIMESTAMPDIFF(DAY, o.order_purchase_timestamp,
                  o.order_delivered_customer_date) AS actual_delivery_days,
    CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
         THEN 1 ELSE 0 END AS late_delivery_target
FROM olist_orders o
JOIN olist_customers c ON c.customer_id = o.customer_id
LEFT JOIN olist_order_items oi ON oi.order_id = o.order_id
LEFT JOIN olist_products p ON p.product_id = oi.product_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY o.order_id, c.customer_state, c.customer_city,
         o.order_purchase_timestamp, o.order_approved_at,
         o.order_estimated_delivery_date, o.order_delivered_customer_date;

-- 8.2 Review-score prediction features and target.
SELECT
    o.order_id,
    c.customer_state,
    COUNT(oi.order_item_id) AS item_count,
    SUM(oi.price + oi.freight_value) AS order_value,
    AVG(oi.price) AS average_item_price,
    AVG(oi.freight_value) AS average_freight_value,
    AVG(TIMESTAMPDIFF(DAY, o.order_purchase_timestamp,
                      o.order_delivered_customer_date)) AS delivery_days,
    AVG(DATEDIFF(o.order_delivered_customer_date,
                 o.order_estimated_delivery_date)) AS days_from_estimate,
    AVG(r.review_score) AS review_score_target
FROM olist_orders o
JOIN olist_customers c ON c.customer_id = o.customer_id
JOIN olist_order_items oi ON oi.order_id = o.order_id
LEFT JOIN olist_order_reviews r ON r.order_id = o.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY o.order_id, c.customer_state;

-- 8.3 Customer repeat-order/churn proxy.
-- The source has no future observation window; repeat_order_target is a
-- historical proxy that identifies customers with more than one order.
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        MIN(o.order_purchase_timestamp) AS first_order_date,
        MAX(o.order_purchase_timestamp) AS last_order_date,
        SUM(oi.price + oi.freight_value) AS total_spend
    FROM olist_customers c
    JOIN olist_orders o ON o.customer_id = c.customer_id
    LEFT JOIN olist_order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    order_count,
    DATEDIFF(last_order_date, first_order_date) AS customer_lifetime_days,
    ROUND(total_spend, 2) AS total_spend,
    CASE WHEN order_count > 1 THEN 1 ELSE 0 END AS repeat_order_target,
    CASE WHEN order_count = 1 THEN 1 ELSE 0 END AS one_time_customer_proxy
FROM customer_orders;

-- 8.4 Category demand time series for ARIMA/Prophet.
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01') AS month_start,
    COALESCE(t.product_category_name_english, p.product_category_name,
             'unknown') AS product_category,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(oi.order_item_id IS NOT NULL) AS units_sold,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS gross_revenue
FROM olist_orders o
JOIN olist_order_items oi ON oi.order_id = o.order_id
JOIN olist_products p ON p.product_id = oi.product_id
LEFT JOIN product_category_translation t
    ON t.product_category_name = p.product_category_name
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY month_start, product_category
ORDER BY month_start, product_category;
