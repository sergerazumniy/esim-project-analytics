-- 03_revenue_drop_hypotheses.sql
--
-- Each block below tests one hypothesis about why revenue dropped from
-- January to February 2026. Blocks are grouped into two passes:
--   1) "Ruled out" - factors with a small or negligible effect on revenue.
--   2) "Confirmed drivers" - factors that explain most of the drop.
-- All blocks run against base_orders (see 01_base_view.sql).

-- === monthly_overview ===
-- Headline numbers: revenue, paid orders, AOV and active buyers per month.
SELECT
    order_month,
    COUNT(*) FILTER (WHERE order_status = 'paid') AS paid_orders,
    COUNT(DISTINCT user_id) FILTER (WHERE order_status = 'paid') AS paying_users,
    SUM(price_eur) FILTER (WHERE order_status = 'paid') AS revenue_eur,
    ROUND(AVG(price_eur) FILTER (WHERE order_status = 'paid'), 2) AS aov_eur
FROM base_orders
GROUP BY order_month
ORDER BY order_month;

-- === calendar_effect ===
-- Hypothesis (ruled out / minor): February simply has fewer days than January.
SELECT
    order_month,
    COUNT(*) FILTER (WHERE order_status = 'paid') AS paid_orders,
    COUNT(DISTINCT day_of_month) AS days_in_period,
    ROUND(COUNT(*) FILTER (WHERE order_status = 'paid') * 1.0
        / NULLIF(COUNT(DISTINCT day_of_month), 0), 2) AS orders_per_day
FROM base_orders
GROUP BY order_month
ORDER BY order_month;

-- === refund_rate ===
-- Hypothesis (ruled out): the share of refunded orders increased in February.
SELECT
    order_month,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE order_status = 'refunded') AS refunded_orders,
    ROUND(COUNT(*) FILTER (WHERE order_status = 'refunded') * 100.0
        / NULLIF(COUNT(*), 0), 2) AS refund_rate_pct,
    SUM(price_eur) FILTER (WHERE order_status = 'refunded') AS refunded_amount_eur,
    SUM(price_eur) FILTER (WHERE order_status = 'paid') AS revenue_eur
FROM base_orders
GROUP BY order_month
ORDER BY order_month;

-- === country_mix ===
-- Hypothesis (ruled out): regional demand shifted meaningfully.
WITH by_country AS (
    SELECT
        order_country,
        SUM(price_eur) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-01-01') AS jan_revenue,
        SUM(price_eur) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-02-01') AS feb_revenue
    FROM base_orders
    GROUP BY order_country
)
SELECT
    order_country,
    jan_revenue,
    feb_revenue,
    ROUND((feb_revenue - jan_revenue) * 100.0 / NULLIF(SUM(jan_revenue) OVER (), 0), 2) AS contribution_to_change_pp
FROM by_country
ORDER BY contribution_to_change_pp;

-- === platform_mix ===
-- Hypothesis (ruled out): a specific platform (iOS / Android / web) drove the drop.
WITH by_platform AS (
    SELECT
        order_platform,
        SUM(price_eur) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-01-01') AS jan_revenue,
        SUM(price_eur) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-02-01') AS feb_revenue
    FROM base_orders
    GROUP BY order_platform
)
SELECT
    order_platform,
    jan_revenue,
    feb_revenue,
    ROUND((feb_revenue - jan_revenue) * 100.0 / NULLIF(SUM(jan_revenue) OVER (), 0), 2) AS contribution_to_change_pp
FROM by_platform
ORDER BY contribution_to_change_pp;

-- === repeat_purchase_share ===
-- Hypothesis (ruled out): fewer customers came back for a second purchase.
WITH paid_ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_date, order_id) AS paid_order_number
    FROM base_orders
    WHERE order_status = 'paid'
)
SELECT
    order_month,
    CASE WHEN paid_order_number = 1 THEN 'first_purchase' ELSE 'repeat_purchase' END AS order_type,
    COUNT(*) AS paid_orders,
    COUNT(DISTINCT user_id) AS users,
    SUM(price_eur) AS revenue_eur
FROM paid_ranked
GROUP BY order_month, order_type
ORDER BY order_month, order_type;

-- === volume_aov_decomposition ===
-- Hypothesis (confirmed driver): revenue = paid_orders x AOV. Which factor moved more?
WITH monthly AS (
    SELECT
        order_month,
        COUNT(*) FILTER (WHERE order_status = 'paid') AS paid_orders,
        SUM(price_eur) FILTER (WHERE order_status = 'paid') AS revenue_eur,
        AVG(price_eur) FILTER (WHERE order_status = 'paid') AS aov_eur
    FROM base_orders
    GROUP BY order_month
),
wide AS (
    SELECT
        MAX(paid_orders) FILTER (WHERE order_month = DATE '2026-01-01') AS jan_orders,
        MAX(paid_orders) FILTER (WHERE order_month = DATE '2026-02-01') AS feb_orders,
        MAX(revenue_eur) FILTER (WHERE order_month = DATE '2026-01-01') AS jan_revenue,
        MAX(revenue_eur) FILTER (WHERE order_month = DATE '2026-02-01') AS feb_revenue,
        MAX(aov_eur) FILTER (WHERE order_month = DATE '2026-01-01') AS jan_aov,
        MAX(aov_eur) FILTER (WHERE order_month = DATE '2026-02-01') AS feb_aov
    FROM monthly
)
SELECT
    jan_revenue, feb_revenue, jan_orders, feb_orders, jan_aov, feb_aov,
    ROUND(feb_revenue - jan_revenue, 2) AS revenue_change_eur,
    ROUND((feb_orders - jan_orders) * jan_aov, 2) AS volume_effect_eur,
    ROUND(feb_orders * (feb_aov - jan_aov), 2) AS aov_effect_eur
FROM wide;

-- === acquisition_channel ===
-- Hypothesis (confirmed driver): one acquisition channel underperformed.
WITH by_channel AS (
    SELECT
        acquisition_channel,
        SUM(price_eur) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-01-01') AS jan_revenue,
        SUM(price_eur) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-02-01') AS feb_revenue,
        COUNT(*) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-01-01') AS jan_orders,
        COUNT(*) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-02-01') AS feb_orders
    FROM base_orders
    GROUP BY acquisition_channel
)
SELECT
    acquisition_channel,
    jan_revenue, feb_revenue, jan_orders, feb_orders,
    ROUND((feb_revenue - jan_revenue) * 100.0 / NULLIF(jan_revenue, 0), 2) AS revenue_change_pct,
    ROUND((feb_revenue - jan_revenue) * 100.0 / NULLIF(SUM(jan_revenue) OVER (), 0), 2) AS contribution_to_change_pp
FROM by_channel
ORDER BY contribution_to_change_pp;

-- === tariff_mix ===
-- Hypothesis (confirmed driver): users shifted away from expensive packages.
WITH by_tariff AS (
    SELECT
        packet_size_name,
        SUM(price_eur) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-01-01') AS jan_revenue,
        SUM(price_eur) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-02-01') AS feb_revenue,
        COUNT(*) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-01-01') AS jan_orders,
        COUNT(*) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-02-01') AS feb_orders
    FROM base_orders
    GROUP BY packet_size_name
)
SELECT
    packet_size_name,
    jan_revenue, feb_revenue, jan_orders, feb_orders,
    ROUND((feb_orders - jan_orders) * 100.0 / NULLIF(jan_orders, 0), 2) AS orders_change_pct,
    ROUND((feb_revenue - jan_revenue) * 100.0 / NULLIF(SUM(jan_revenue) OVER (), 0), 2) AS contribution_to_change_pp
FROM by_tariff
ORDER BY contribution_to_change_pp;

-- === channel_tariff_interaction ===
-- Hypothesis (confirmed driver): the drop is concentrated in a specific
-- channel x tariff combination, not spread evenly.
-- NB: cells with few orders are noisy - read jan_orders/feb_orders before
-- trusting a percentage change (see the sample-size caveat in the notebook).
WITH by_segment AS (
    SELECT
        acquisition_channel,
        packet_size_name,
        SUM(price_eur) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-01-01') AS jan_revenue,
        SUM(price_eur) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-02-01') AS feb_revenue,
        COUNT(*) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-01-01') AS jan_orders,
        COUNT(*) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-02-01') AS feb_orders
    FROM base_orders
    GROUP BY acquisition_channel, packet_size_name
)
SELECT
    acquisition_channel,
    packet_size_name,
    jan_revenue, feb_revenue, jan_orders, feb_orders,
    ROUND((feb_revenue - jan_revenue) * 100.0 / NULLIF(SUM(jan_revenue) OVER (), 0), 2) AS contribution_to_change_pp
FROM by_segment
WHERE COALESCE(jan_revenue, 0) + COALESCE(feb_revenue, 0) > 0
ORDER BY contribution_to_change_pp
LIMIT 15;

-- === paid_social_isolation ===
-- Stress-test: is paid_social really an independent root cause, or is it
-- entangled with the tariff-mix story above? Split revenue/orders/AOV into
-- "paid_social" vs "every other channel combined" for both months.
SELECT
    CASE WHEN acquisition_channel = 'paid_social' THEN 'paid_social' ELSE 'all_other_channels' END AS channel_group,
    order_month,
    COUNT(*) FILTER (WHERE order_status = 'paid') AS paid_orders,
    SUM(price_eur) FILTER (WHERE order_status = 'paid') AS revenue_eur,
    ROUND(AVG(price_eur) FILTER (WHERE order_status = 'paid'), 2) AS aov_eur
FROM base_orders
GROUP BY channel_group, order_month
ORDER BY channel_group, order_month;

-- === tariff_mix_excluding_paid_social ===
-- Same tariff-mix cut as above, but with paid_social removed. If the
-- "expensive tariffs declined" story were a real market-wide shift, it
-- should still show up here. If it disappears, the tariff-mix signal was
-- just a side effect of paid_social's collapse (paid_social skewed heavily
-- towards expensive packages - see the notebook for the exact share).
WITH by_tariff AS (
    SELECT
        packet_size_name,
        SUM(price_eur) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-01-01') AS jan_revenue,
        SUM(price_eur) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-02-01') AS feb_revenue,
        COUNT(*) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-01-01') AS jan_orders,
        COUNT(*) FILTER (WHERE order_status = 'paid' AND order_month = DATE '2026-02-01') AS feb_orders
    FROM base_orders
    WHERE acquisition_channel != 'paid_social'
    GROUP BY packet_size_name
)
SELECT
    packet_size_name,
    jan_revenue, feb_revenue, jan_orders, feb_orders,
    ROUND((feb_orders - jan_orders) * 100.0 / NULLIF(jan_orders, 0), 2) AS orders_change_pct
FROM by_tariff
ORDER BY packet_size_name;
