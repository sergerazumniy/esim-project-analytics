-- 02_data_quality_checks.sql
--
-- Basic data quality checks used in notebooks/00_data_quality_and_overview.ipynb.
-- Each block is self-contained and can be run on its own.

-- === unique_keys ===
-- Confirms that user_id and order_id are unique primary keys (no duplicate rows).
SELECT
    'users' AS table_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT user_id) AS unique_ids,
    COUNT(*) - COUNT(DISTINCT user_id) AS duplicate_rows
FROM users
UNION ALL
SELECT
    'orders' AS table_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT order_id) AS unique_ids,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_rows
FROM orders;

-- === null_check_users ===
-- Counts NULLs in every column of the users table.
SELECT
    COUNT(*) FILTER (WHERE user_id IS NULL) AS null_user_id,
    COUNT(*) FILTER (WHERE registered_date IS NULL) AS null_registered_date,
    COUNT(*) FILTER (WHERE country IS NULL) AS null_country,
    COUNT(*) FILTER (WHERE platform IS NULL) AS null_platform,
    COUNT(*) FILTER (WHERE acquisition_channel IS NULL) AS null_acquisition_channel
FROM users;

-- === null_check_orders ===
-- Counts NULLs in every column of the orders table.
SELECT
    COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE user_id IS NULL) AS null_user_id,
    COUNT(*) FILTER (WHERE created_date IS NULL) AS null_created_date,
    COUNT(*) FILTER (WHERE country IS NULL) AS null_country,
    COUNT(*) FILTER (WHERE packet_size_name IS NULL) AS null_packet_size_name,
    COUNT(*) FILTER (WHERE price_eur IS NULL) AS null_price_eur,
    COUNT(*) FILTER (WHERE order_status IS NULL) AS null_order_status,
    COUNT(*) FILTER (WHERE platform IS NULL) AS null_platform
FROM orders;

-- === date_range ===
-- Confirms both tables fall inside the expected Jan-Feb 2026 window.
SELECT 'users' AS table_name, MIN(registered_date) AS min_date, MAX(registered_date) AS max_date FROM users
UNION ALL
SELECT 'orders' AS table_name, MIN(created_date) AS min_date, MAX(created_date) AS max_date FROM orders;

-- === referential_integrity ===
-- Every order should reference an existing user, and no order should be
-- created before that user registered.
SELECT
    COUNT(*) AS orders_cnt,
    COUNT(*) FILTER (WHERE u.user_id IS NULL) AS orders_without_user,
    COUNT(*) FILTER (WHERE o.created_date < u.registered_date) AS orders_before_registration
FROM orders o
LEFT JOIN users u ON o.user_id = u.user_id;

-- === category_values ===
-- Cardinality / distribution of the categorical columns used throughout the analysis.
SELECT 'user_platform' AS dimension, platform AS value, COUNT(*) AS row_count FROM users GROUP BY platform
UNION ALL
SELECT 'acquisition_channel', acquisition_channel, COUNT(*) FROM users GROUP BY acquisition_channel
UNION ALL
SELECT 'order_status', order_status, COUNT(*) FROM orders GROUP BY order_status
UNION ALL
SELECT 'order_platform', platform, COUNT(*) FROM orders GROUP BY platform
ORDER BY dimension, row_count DESC;

-- === price_distribution ===
-- Sanity check on price_eur: no non-positive or extreme outlier values expected.
SELECT
    COUNT(*) AS orders_cnt,
    COUNT(*) FILTER (WHERE price_eur <= 0) AS non_positive_prices,
    MIN(price_eur) AS min_price,
    MAX(price_eur) AS max_price,
    ROUND(AVG(price_eur), 2) AS avg_price,
    MEDIAN(price_eur) AS median_price
FROM orders;
