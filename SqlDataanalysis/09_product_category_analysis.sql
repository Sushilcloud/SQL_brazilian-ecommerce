-- ============================================================================
-- 9. PRODUCT CATEGORY ANALYSIS
-- ============================================================================
USE olist_brazilian_ecommerce;

-- 9.1 Category sales, canceled/unavailable order proxy, and review scores.
WITH category_orders AS (
    SELECT
        COALESCE(t.product_category_name_english, p.product_category_name,
                 'unknown') AS product_category,
        o.order_id,
        o.order_status,
        oi.price,
        oi.freight_value
    FROM olist_order_items oi
    JOIN olist_orders o ON o.order_id = oi.order_id
    JOIN olist_products p ON p.product_id = oi.product_id
    LEFT JOIN product_category_translation t
        ON t.product_category_name = p.product_category_name
), category_reviews AS (
    SELECT
        co.product_category,
        AVG(r.review_score) AS average_review_score
    FROM category_orders co
    JOIN olist_order_reviews r ON r.order_id = co.order_id
    GROUP BY co.product_category
)
SELECT
    co.product_category,
    COUNT(DISTINCT CASE WHEN co.order_status NOT IN ('canceled', 'unavailable')
                        THEN co.order_id END) AS completed_orders,
    COUNT(DISTINCT CASE WHEN co.order_status IN ('canceled', 'unavailable')
                        THEN co.order_id END) AS canceled_or_unavailable_orders,
    ROUND(SUM(CASE WHEN co.order_status NOT IN ('canceled', 'unavailable')
                   THEN co.price ELSE 0 END), 2) AS product_revenue,
    ROUND(SUM(CASE WHEN co.order_status NOT IN ('canceled', 'unavailable')
                   THEN co.freight_value ELSE 0 END), 2) AS freight_revenue,
    ROUND(cr.average_review_score, 2) AS average_review_score
FROM category_orders co
LEFT JOIN category_reviews cr ON cr.product_category = co.product_category
GROUP BY co.product_category, cr.average_review_score
ORDER BY product_revenue DESC;

-- 9.2 Cross-category purchase patterns (market basket pairs).
WITH order_categories AS (
    SELECT DISTINCT
        oi.order_id,
        COALESCE(t.product_category_name_english, p.product_category_name,
                 'unknown') AS product_category
    FROM olist_order_items oi
    JOIN olist_orders o ON o.order_id = oi.order_id
    JOIN olist_products p ON p.product_id = oi.product_id
    LEFT JOIN product_category_translation t
        ON t.product_category_name = p.product_category_name
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
), category_counts AS (
    SELECT product_category, COUNT(DISTINCT order_id) AS category_orders
    FROM order_categories
    GROUP BY product_category
), pairs AS (
    SELECT
        a.product_category AS category_a,
        b.product_category AS category_b,
        COUNT(DISTINCT a.order_id) AS pair_orders
    FROM order_categories a
    JOIN order_categories b
        ON b.order_id = a.order_id
       AND a.product_category < b.product_category
    GROUP BY a.product_category, b.product_category
)
SELECT
    p.category_a,
    p.category_b,
    p.pair_orders,
    ROUND(p.pair_orders / NULLIF(ca.category_orders, 0), 4) AS confidence_a_to_b,
    ROUND(p.pair_orders / NULLIF(cb.category_orders, 0), 4) AS confidence_b_to_a
FROM pairs p
JOIN category_counts ca ON ca.product_category = p.category_a
JOIN category_counts cb ON cb.product_category = p.category_b
ORDER BY p.pair_orders DESC
LIMIT 100;

-- 9.3 Category profitability proxy: product price versus freight cost.
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name,
             'unknown') AS product_category,
    COUNT(*) AS item_count,
    ROUND(AVG(oi.price), 2) AS average_product_price,
    ROUND(AVG(oi.freight_value), 2) AS average_freight_cost,
    ROUND(AVG(oi.price - oi.freight_value), 2) AS average_price_less_freight,
    ROUND(100 * AVG(oi.freight_value / NULLIF(oi.price, 0)), 2)
        AS freight_as_percent_of_price,
    ROUND(SUM(oi.price - oi.freight_value), 2) AS price_less_freight_total
FROM olist_order_items oi
JOIN olist_orders o ON o.order_id = oi.order_id
JOIN olist_products p ON p.product_id = oi.product_id
LEFT JOIN product_category_translation t
    ON t.product_category_name = p.product_category_name
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY product_category
ORDER BY price_less_freight_total DESC;
