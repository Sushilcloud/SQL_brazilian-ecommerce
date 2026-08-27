-- ============================================================================
-- 6. SELLER PERFORMANCE ANALYSIS
-- ============================================================================
USE olist_brazilian_ecommerce;

-- 6.1 Seller ranking by revenue, order count, units, and average review score.
WITH seller_reviews AS (
    SELECT order_id, AVG(review_score) AS average_review_score
    FROM olist_order_reviews
    GROUP BY order_id
), seller_metrics AS (
    SELECT
        oi.seller_id,
        s.seller_state,
        s.seller_city,
        COUNT(DISTINCT oi.order_id) AS order_count,
        COUNT(*) AS units_sold,
        SUM(oi.price) AS product_revenue,
        SUM(oi.price + oi.freight_value) AS gross_revenue,
        AVG(oi.freight_value) AS average_freight_value,
        AVG(sr.average_review_score) AS average_review_score
    FROM olist_order_items oi
    JOIN olist_orders o ON o.order_id = oi.order_id
    JOIN olist_sellers s ON s.seller_id = oi.seller_id
    LEFT JOIN seller_reviews sr ON sr.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY oi.seller_id, s.seller_state, s.seller_city
)
SELECT
    seller_id,
    seller_state,
    seller_city,
    order_count,
    units_sold,
    ROUND(product_revenue, 2) AS product_revenue,
    ROUND(gross_revenue, 2) AS gross_revenue,
    ROUND(average_review_score, 2) AS average_review_score,
    RANK() OVER (ORDER BY gross_revenue DESC) AS revenue_rank
FROM seller_metrics
ORDER BY revenue_rank
LIMIT 100;

-- 6.2 Seller response and processing time.
SELECT
    oi.seller_id,
    COUNT(DISTINCT oi.order_id) AS order_count,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, o.order_approved_at,
                            o.order_delivered_carrier_date)) / 24, 2)
        AS average_approval_to_carrier_days,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, o.order_purchase_timestamp,
                            o.order_delivered_carrier_date)) / 24, 2)
        AS average_purchase_to_carrier_days,
    ROUND(100 * AVG(o.order_delivered_carrier_date <= oi.shipping_limit_date), 2)
        AS shipped_by_limit_percentage
FROM olist_order_items oi
JOIN olist_orders o ON o.order_id = oi.order_id
WHERE o.order_approved_at IS NOT NULL
  AND o.order_delivered_carrier_date IS NOT NULL
GROUP BY oi.seller_id
HAVING COUNT(DISTINCT oi.order_id) >= 10
ORDER BY average_approval_to_carrier_days;

-- 6.3 Identify underperforming or high-risk sellers.
WITH seller_metrics AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT oi.order_id) AS order_count,
        SUM(oi.price + oi.freight_value) AS gross_revenue,
        AVG(r.review_score) AS average_review_score,
        AVG(o.order_delivered_customer_date > o.order_estimated_delivery_date)
            AS late_order_rate,
        MAX(o.order_purchase_timestamp) AS last_order_date
    FROM olist_order_items oi
    JOIN olist_orders o ON o.order_id = oi.order_id
    LEFT JOIN olist_order_reviews r ON r.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY oi.seller_id
)
SELECT
    seller_id,
    order_count,
    ROUND(gross_revenue, 2) AS gross_revenue,
    ROUND(average_review_score, 2) AS average_review_score,
    ROUND(100 * late_order_rate, 2) AS late_order_percentage,
    last_order_date,
    CASE
        WHEN average_review_score < 3 OR late_order_rate > 0.25 THEN 'underperforming'
        WHEN DATEDIFF((SELECT MAX(order_purchase_timestamp) FROM olist_orders),
                      last_order_date) > 180 THEN 'inactive or high-churn risk'
        ELSE 'normal'
    END AS seller_risk_flag
FROM seller_metrics
ORDER BY seller_risk_flag, gross_revenue DESC;

-- 6.4 Seller concentration: share of revenue and cumulative share.
WITH seller_revenue AS (
    SELECT
        oi.seller_id,
        SUM(oi.price + oi.freight_value) AS gross_revenue
    FROM olist_order_items oi
    JOIN olist_orders o ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY oi.seller_id
), ranked AS (
    SELECT
        seller_id,
        gross_revenue,
        SUM(gross_revenue) OVER () AS total_revenue,
        SUM(gross_revenue) OVER (ORDER BY gross_revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_revenue,
        ROW_NUMBER() OVER (ORDER BY gross_revenue DESC) AS seller_rank
    FROM seller_revenue
)
SELECT
    seller_rank,
    seller_id,
    ROUND(gross_revenue, 2) AS gross_revenue,
    ROUND(100 * gross_revenue / total_revenue, 2) AS revenue_share_percentage,
    ROUND(100 * cumulative_revenue / total_revenue, 2) AS cumulative_share_percentage
FROM ranked
ORDER BY seller_rank;
