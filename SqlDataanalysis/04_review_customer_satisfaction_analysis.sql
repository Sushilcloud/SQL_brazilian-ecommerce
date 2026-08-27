-- ============================================================================
-- 4. REVIEW AND CUSTOMER SATISFACTION ANALYSIS
-- Text sentiment requires an NLP library/model; the SQL below provides the
-- review text dataset and transparent Portuguese keyword indicators.
-- ============================================================================
USE olist_brazilian_ecommerce;

-- 4.1 Distribution of review scores.
SELECT
    review_score,
    COUNT(*) AS review_count,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage_of_reviews
FROM olist_order_reviews
GROUP BY review_score
ORDER BY review_score;

-- 4.2 Review score versus delivery time.
SELECT
    r.review_score,
    COUNT(*) AS review_count,
    ROUND(AVG(TIMESTAMPDIFF(DAY, o.order_purchase_timestamp,
                            o.order_delivered_customer_date)), 2) AS avg_delivery_days,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date,
                       o.order_estimated_delivery_date)), 2) AS avg_days_from_estimate
FROM olist_order_reviews r
JOIN olist_orders o ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY r.review_score
ORDER BY r.review_score;

-- 4.3 Review score versus item price and product category.
SELECT
    r.review_score,
    COALESCE(t.product_category_name_english, p.product_category_name,
             'unknown') AS product_category,
    COUNT(DISTINCT r.review_id, r.order_id) AS review_count,
    ROUND(AVG(oi.price), 2) AS average_item_price,
    ROUND(AVG(oi.price + oi.freight_value), 2) AS average_item_total
FROM olist_order_reviews r
JOIN olist_order_items oi ON oi.order_id = r.order_id
JOIN olist_products p ON p.product_id = oi.product_id
LEFT JOIN product_category_translation t
    ON t.product_category_name = p.product_category_name
GROUP BY r.review_score, product_category
HAVING COUNT(DISTINCT r.review_id, r.order_id) >= 10
ORDER BY product_category, r.review_score;

-- 4.4 Exportable review-text dataset for Portuguese NLP/sentiment analysis.
SELECT
    r.review_id,
    r.order_id,
    r.review_score,
    CASE
        WHEN r.review_score >= 4 THEN 'positive'
        WHEN r.review_score = 3 THEN 'neutral'
        ELSE 'negative'
    END AS score_sentiment_label,
    TRIM(CONCAT_WS(' ', r.review_comment_title, r.review_comment_message)) AS review_text,
    r.review_creation_date
FROM olist_order_reviews r
WHERE COALESCE(r.review_comment_title, r.review_comment_message) IS NOT NULL
  AND TRIM(CONCAT_WS(' ', r.review_comment_title, r.review_comment_message)) <> '';

-- 4.5 Transparent Portuguese keyword indicators for complaint/praise terms.
-- This is a screening query, not a replacement for spaCy/NLTK/transformers.
SELECT
    CASE
        WHEN LOWER(CONCAT_WS(' ', review_comment_title, review_comment_message))
             REGEXP 'bom|otimo|excelente|recomendo|rapido|satisfeito' THEN 'praise keyword'
        WHEN LOWER(CONCAT_WS(' ', review_comment_title, review_comment_message))
             REGEXP 'ruim|pessimo|atraso|atrasado|defeito|problema|reclama|demora' THEN 'complaint keyword'
        ELSE 'other or no keyword'
    END AS keyword_group,
    COUNT(*) AS review_count,
    ROUND(AVG(review_score), 2) AS average_review_score
FROM olist_order_reviews
WHERE COALESCE(review_comment_title, review_comment_message) IS NOT NULL
GROUP BY keyword_group
ORDER BY review_count DESC;

-- 4.6 Most common normalized Portuguese complaint/praise terms.
WITH terms AS (
    SELECT 'bom' AS term UNION ALL SELECT 'otimo' UNION ALL SELECT 'excelente'
    UNION ALL SELECT 'recomendo' UNION ALL SELECT 'rapido' UNION ALL SELECT 'satisfeito'
    UNION ALL SELECT 'ruim' UNION ALL SELECT 'pessimo' UNION ALL SELECT 'atraso'
    UNION ALL SELECT 'atrasado' UNION ALL SELECT 'defeito' UNION ALL SELECT 'problema'
    UNION ALL SELECT 'reclama' UNION ALL SELECT 'demora'
), review_text AS (
    SELECT review_score,
           LOWER(CONCAT_WS(' ', review_comment_title, review_comment_message)) AS text_value
    FROM olist_order_reviews
    WHERE COALESCE(review_comment_title, review_comment_message) IS NOT NULL
)
SELECT
    t.term,
    CASE
        WHEN t.term IN ('bom', 'otimo', 'excelente', 'recomendo', 'rapido', 'satisfeito')
            THEN 'praise'
        ELSE 'complaint'
    END AS term_type,
    COUNT(*) AS mention_count,
    ROUND(AVG(rt.review_score), 2) AS average_review_score
FROM terms t
JOIN review_text rt ON rt.text_value REGEXP CONCAT('(^|[^a-z])', t.term, '([^a-z]|$)')
GROUP BY t.term, term_type
ORDER BY mention_count DESC;