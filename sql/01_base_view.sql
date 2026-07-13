-- 01_base_view.sql
--
-- Joins the two raw tables (users, orders) into a single analytical view.
-- Every later query in this project is built on top of "base_orders" so the
-- join logic and derived date fields only have to be defined once.
--
-- Assumes "users" and "orders" tables already exist in the DuckDB connection
-- (they are loaded from the raw CSVs by src/db.py).

CREATE OR REPLACE VIEW base_orders AS
SELECT
    o.order_id,
    o.user_id,
    o.created_date,
    DATE_TRUNC('month', o.created_date) AS order_month,
    EXTRACT(DAY FROM o.created_date) AS day_of_month,
    o.country AS order_country,
    o.packet_size_name,
    o.price_eur,
    o.order_status,
    o.platform AS order_platform,
    u.registered_date,
    DATE_TRUNC('month', u.registered_date) AS registration_month,
    u.country AS user_country,
    u.platform AS user_platform,
    u.acquisition_channel
FROM orders o
JOIN users u ON o.user_id = u.user_id;
