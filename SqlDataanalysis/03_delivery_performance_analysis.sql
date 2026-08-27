-- ============================================================================
-- 3. DELIVERY PERFORMANCE ANALYSIS
-- ============================================================================
USE olist_brazilian_ecommerce;

-- 3.1 Actual versus estimated delivery and on-time percentage.
WITH delivery AS (
    SELECT
        order_id,
        order_status,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) AS days_from_estimate
    FROM olist_orders
    WHERE order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
SELECT
    COUNT(*) AS delivered_orders,
    SUM(days_from_estimate <= 0) AS on_time_orders,
    SUM(days_from_estimate > 0) AS late_orders,
    ROUND(100 * AVG(days_from_estimate <= 0), 2) AS on_time_percentage,
    ROUND(AVG(days_from_estimate), 2) AS average_days_from_estimate,
    ROUND(AVG(DATEDIFF(order_delivered_customer_date,
                       order_estimated_delivery_date)), 2) AS average_schedule_variance
FROM delivery;

-- 3.2 Average delivery time by customer state and region.
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(AVG(TIMESTAMPDIFF(DAY, o.order_purchase_timestamp,
                            o.order_delivered_customer_date)), 2) AS avg_delivery_days,
    ROUND(AVG(TIMESTAMPDIFF(DAY, o.order_delivered_carrier_date,
                            o.order_delivered_customer_date)), 2) AS avg_carrier_to_customer_days,
    ROUND(100 * AVG(o.order_delivered_customer_date <=
                    o.order_estimated_delivery_date), 2) AS on_time_percentage
FROM olist_customers c
JOIN olist_orders o ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delivery_days DESC;

-- 3.3 Delivery delay impact on review scores.
WITH order_reviews_average AS (
    SELECT order_id, AVG(review_score) AS average_review_score
    FROM olist_order_reviews
    GROUP BY order_id
), delivered_reviews AS (
    SELECT
        o.order_id,
        DATEDIFF(o.order_delivered_customer_date,
                 o.order_estimated_delivery_date) AS days_from_estimate,
        TIMESTAMPDIFF(DAY, o.order_purchase_timestamp,
                      o.order_delivered_customer_date) AS delivery_days,
        r.average_review_score
    FROM olist_orders o
    JOIN order_reviews_average r ON r.order_id = o.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT
    CASE WHEN days_from_estimate <= 0 THEN 'on time or early' ELSE 'late' END AS delivery_group,
    COUNT(*) AS order_count,
    ROUND(AVG(delivery_days), 2) AS average_delivery_days,
    ROUND(AVG(average_review_score), 2) AS average_review_score
FROM delivered_reviews
GROUP BY delivery_group;

-- 3.4 Carrier and logistics partner performance (seller proxy).
SELECT
    oi.seller_id,
    s.seller_state,
    s.seller_city,
    COUNT(DISTINCT o.order_id) AS order_count,
    ROUND(AVG(TIMESTAMPDIFF(DAY, o.order_purchase_timestamp,
                            o.order_delivered_customer_date)), 2) AS avg_delivery_days,
    ROUND(100 * AVG(o.order_delivered_customer_date <=
                    o.order_estimated_delivery_date), 2) AS on_time_percentage,
    ROUND(AVG(oi.freight_value), 2) AS average_freight_value
FROM olist_order_items oi
JOIN olist_orders o ON o.order_id = oi.order_id
JOIN olist_sellers s ON s.seller_id = oi.seller_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY oi.seller_id, s.seller_state, s.seller_city
HAVING COUNT(DISTINCT o.order_id) >= 10
ORDER BY on_time_percentage DESC, avg_delivery_days;

-- 3.5 Freight value versus product weight and estimated distance proxy.
SELECT
    CASE
        WHEN p.product_weight_g < 1000 THEN 'under 1 kg'
        WHEN p.product_weight_g < 5000 THEN '1-5 kg'
        WHEN p.product_weight_g < 10000 THEN '5-10 kg'
        ELSE '10 kg or more'
    END AS weight_band,
    ROUND(AVG(oi.freight_value), 2) AS average_freight_value,
    ROUND(AVG(p.product_weight_g), 0) AS average_weight_g,
    ROUND(AVG(oi.freight_value / NULLIF(p.product_weight_g, 0) * 1000), 2) AS freight_per_kg,
    COUNT(*) AS item_count
FROM olist_order_items oi
JOIN olist_products p ON p.product_id = oi.product_id
WHERE p.product_weight_g IS NOT NULL
GROUP BY weight_band
ORDER BY MIN(p.product_weight_g);