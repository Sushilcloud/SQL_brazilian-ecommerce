-- ============================================================================
-- 2. CUSTOMER SEGMENTATION (RFM ANALYSIS)
-- R = recency, F = frequency, M = monetary value.
-- ============================================================================
USE olist_brazilian_ecommerce;

-- 2.1 RFM base table, one row per customer_unique_id.
-- The report date is the day after the latest purchase in the dataset, making
-- recency reproducible instead of dependent on the current system date.
WITH dataset_date AS (
    SELECT DATE_ADD(MAX(order_purchase_timestamp), INTERVAL 1 DAY) AS report_date
    FROM olist_orders
), customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM olist_customers c
    JOIN olist_orders o ON o.customer_id = c.customer_id
    LEFT JOIN olist_order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id, o.order_id, o.order_purchase_timestamp
)
SELECT
    co.customer_unique_id,
    DATEDIFF(dd.report_date, DATE(MAX(co.order_purchase_timestamp))) AS recency_days,
    COUNT(DISTINCT co.order_id) AS frequency_orders,
    ROUND(SUM(COALESCE(co.order_value, 0)), 2) AS monetary_value
FROM customer_orders co
CROSS JOIN dataset_date dd
GROUP BY co.customer_unique_id, dd.report_date
ORDER BY monetary_value DESC;

-- 2.2 Score customers into quintiles and assign practical segments.
WITH dataset_date AS (
    SELECT DATE_ADD(MAX(order_purchase_timestamp), INTERVAL 1 DAY) AS report_date
    FROM olist_orders
), rfm AS (
    SELECT
        c.customer_unique_id,
        DATEDIFF(dd.report_date, DATE(MAX(o.order_purchase_timestamp))) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency_orders,
        SUM(COALESCE(oi.price + oi.freight_value, 0)) AS monetary_value
    FROM olist_customers c
    JOIN olist_orders o ON o.customer_id = c.customer_id
    LEFT JOIN olist_order_items oi ON oi.order_id = o.order_id
    CROSS JOIN dataset_date dd
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id, dd.report_date
), scored AS (
    SELECT
        rfm.*,
        6 - NTILE(5) OVER (ORDER BY recency_days) AS recency_score,
        NTILE(5) OVER (ORDER BY frequency_orders) AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary_value) AS monetary_score
    FROM rfm
), segmented AS (
    SELECT
        scored.*,
        recency_score + frequency_score + monetary_score AS rfm_total_score,
        CASE
            WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'loyal'
            WHEN recency_score >= 4 AND frequency_score <= 2 THEN 'new or promising'
            WHEN recency_score <= 2 AND frequency_score >= 3 THEN 'at-risk'
            WHEN recency_score <= 2 AND monetary_score >= 4 THEN 'high-value at-risk'
            WHEN recency_score >= 3 AND frequency_score >= 3 THEN 'potential loyalist'
            ELSE 'one-time or low-value'
        END AS customer_segment
    FROM scored
)
SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(recency_days), 1) AS average_recency_days,
    ROUND(AVG(frequency_orders), 2) AS average_orders,
    ROUND(AVG(monetary_value), 2) AS average_customer_value,
    ROUND(SUM(monetary_value), 2) AS segment_revenue
FROM segmented
GROUP BY customer_segment
ORDER BY segment_revenue DESC;

-- 2.3 Customer Lifetime Value estimate.
-- Historical CLV proxy = average order value x orders per customer. The second
-- result adds an optional 12-month projection using observed purchase rate.
WITH customer_history AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(oi.price + oi.freight_value) AS total_spend,
        DATEDIFF(MAX(o.order_purchase_timestamp), MIN(o.order_purchase_timestamp)) AS active_days
    FROM olist_customers c
    JOIN olist_orders o ON o.customer_id = c.customer_id
    JOIN olist_order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    order_count,
    ROUND(total_spend / NULLIF(order_count, 0), 2) AS average_order_value,
    active_days,
    ROUND(total_spend, 2) AS historical_clv,
    ROUND(
        (total_spend / NULLIF(order_count, 0))
        * (order_count / GREATEST(active_days / 365, 1))
        * 1,
        2
    ) AS estimated_annual_clv
FROM customer_history
ORDER BY historical_clv DESC;