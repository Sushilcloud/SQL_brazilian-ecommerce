-- ============================================================================
-- 5. GEOSPATIAL ANALYSIS
-- MySQL 8.x | Uses ZIP-prefix coordinates from olist_geolocation.
-- ============================================================================
USE olist_brazilian_ecommerce;

-- 5.1 Orders by Brazilian customer state (Power BI choropleth source).
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS gross_revenue,
    ROUND(AVG(oi.price + oi.freight_value), 2) AS average_item_value
FROM olist_customers c
JOIN olist_orders o ON o.customer_id = c.customer_id
LEFT JOIN olist_order_items oi ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_state
ORDER BY order_count DESC;

-- 5.2 Seller state versus customer state: origin-to-destination lanes.
SELECT
    s.seller_state,
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS order_count,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS gross_revenue,
    ROUND(AVG(oi.freight_value), 2) AS average_freight_value
FROM olist_order_items oi
JOIN olist_orders o ON o.order_id = oi.order_id
JOIN olist_sellers s ON s.seller_id = oi.seller_id
JOIN olist_customers c ON c.customer_id = o.customer_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY s.seller_state, c.customer_state
ORDER BY order_count DESC;

-- 5.3 Regional demand hotspots by customer city.
SELECT
    c.customer_state,
    c.customer_city,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS gross_revenue
FROM olist_customers c
JOIN olist_orders o ON o.customer_id = c.customer_id
JOIN olist_order_items oi ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_state, c.customer_city
ORDER BY order_count DESC, gross_revenue DESC
LIMIT 100;

-- 5.4 ZIP-prefix distance proxy versus delivery time and freight.
-- Geolocation has no exact address, so this uses average coordinates per ZIP.
WITH geo_zip AS (
    SELECT
        geolocation_zip_code_prefix,
        AVG(geolocation_lat) AS latitude,
        AVG(geolocation_lng) AS longitude
    FROM olist_geolocation
    GROUP BY geolocation_zip_code_prefix
), shipment_distance AS (
    SELECT
        oi.order_id,
        oi.price,
        oi.freight_value,
        p.product_weight_g,
        6371 * 2 * ASIN(SQRT(
            POW(SIN(RADIANS(cg.latitude - sg.latitude) / 2), 2) +
            COS(RADIANS(sg.latitude)) * COS(RADIANS(cg.latitude)) *
            POW(SIN(RADIANS(cg.longitude - sg.longitude) / 2), 2)
        )) AS distance_km,
        TIMESTAMPDIFF(DAY, o.order_purchase_timestamp,
                      o.order_delivered_customer_date) AS delivery_days
    FROM olist_order_items oi
    JOIN olist_orders o ON o.order_id = oi.order_id
    JOIN olist_customers c ON c.customer_id = o.customer_id
    JOIN olist_sellers s ON s.seller_id = oi.seller_id
    JOIN olist_products p ON p.product_id = oi.product_id
    JOIN geo_zip cg ON cg.geolocation_zip_code_prefix = c.customer_zip_code_prefix
    JOIN geo_zip sg ON sg.geolocation_zip_code_prefix = s.seller_zip_code_prefix
    WHERE o.order_delivered_customer_date IS NOT NULL
), distance_bands AS (
    SELECT
        CASE
            WHEN distance_km < 100 THEN '0-100 km'
            WHEN distance_km < 500 THEN '100-500 km'
            WHEN distance_km < 1000 THEN '500-1000 km'
            WHEN distance_km < 2000 THEN '1000-2000 km'
            ELSE '2000+ km'
        END AS distance_band,
        distance_km,
        delivery_days,
        freight_value
    FROM shipment_distance
    WHERE distance_km IS NOT NULL
)
SELECT
    distance_band,
    COUNT(*) AS shipment_count,
    ROUND(AVG(distance_km), 1) AS average_distance_km,
    ROUND(AVG(delivery_days), 2) AS average_delivery_days,
    ROUND(AVG(freight_value), 2) AS average_freight_value
FROM distance_bands
GROUP BY distance_band
ORDER BY MIN(distance_km);
