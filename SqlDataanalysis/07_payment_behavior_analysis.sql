-- ============================================================================
-- 7. PAYMENT BEHAVIOR ANALYSIS
-- ============================================================================
USE olist_brazilian_ecommerce;

-- 7.1 Payment type breakdown.
SELECT
    payment_type,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS orders_using_type,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value,
    ROUND(100 * SUM(payment_value) / SUM(SUM(payment_value)) OVER (), 2)
        AS payment_value_share_percentage
FROM olist_order_payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;

-- 7.2 Installment count distribution (Brazil-specific payment behavior).
SELECT
    payment_installments,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM olist_order_payments
WHERE payment_type = 'credit_card'
GROUP BY payment_installments
ORDER BY payment_installments;

-- 7.3 Installment count versus order value, one row per order.
WITH order_payment_summary AS (
    SELECT
        order_id,
        MAX(payment_installments) AS maximum_installments,
        SUM(payment_value) AS order_payment_value,
        COUNT(*) AS payment_record_count
    FROM olist_order_payments
    GROUP BY order_id
)
SELECT
    maximum_installments,
    COUNT(*) AS order_count,
    ROUND(AVG(order_payment_value), 2) AS average_order_value,
    ROUND(AVG(payment_record_count), 2) AS average_payment_records,
    ROUND(SUM(order_payment_value), 2) AS total_order_value
FROM order_payment_summary
GROUP BY maximum_installments
ORDER BY maximum_installments;

-- 7.4 Payment type versus delivery and review score.
WITH payment_type_by_order AS (
    SELECT order_id, GROUP_CONCAT(DISTINCT payment_type ORDER BY payment_type)
        AS payment_types
    FROM olist_order_payments
    GROUP BY order_id
), reviews_by_order AS (
    SELECT order_id, AVG(review_score) AS average_review_score
    FROM olist_order_reviews
    GROUP BY order_id
)
SELECT
    p.payment_types,
    COUNT(*) AS order_count,
    ROUND(AVG(TIMESTAMPDIFF(DAY, o.order_purchase_timestamp,
                            o.order_delivered_customer_date)), 2)
        AS average_delivery_days,
    ROUND(100 * AVG(o.order_delivered_customer_date <=
                    o.order_estimated_delivery_date), 2) AS on_time_percentage,
    ROUND(AVG(r.average_review_score), 2) AS average_review_score
FROM payment_type_by_order p
JOIN olist_orders o ON o.order_id = p.order_id
LEFT JOIN reviews_by_order r ON r.order_id = o.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY p.payment_types
ORDER BY order_count DESC;
