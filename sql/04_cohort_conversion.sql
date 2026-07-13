-- 04_cohort_conversion.sql
--
-- Hypothesis (continued from 03): did onboarding quality drop, i.e. did fewer
-- newly registered users convert to a paid order within 14 days?
--
-- Users registered after 2026-02-15 are excluded: the raw orders data only
-- runs through 2026-02-28, so a user registered on 2026-02-15 is the last
-- one for whom a full 14-day observation window (day 0 .. day 13) is fully
-- covered by the available data. Including later cohorts would silently
-- understate their conversion rate just because we haven't observed them
-- for 14 days yet.

-- === weekly_cohort_conversion ===
WITH users_with_orders AS (
    SELECT
        u.user_id,
        u.registered_date,
        DATE_TRUNC('week', u.registered_date) AS cohort_week,
        MAX(CASE WHEN o.order_id IS NOT NULL THEN 1 ELSE 0 END) AS has_paid_order_14d
    FROM users u
    LEFT JOIN orders o
        ON o.user_id = u.user_id
        AND o.order_status = 'paid'
        AND o.created_date >= u.registered_date
        AND o.created_date < u.registered_date + INTERVAL 14 DAY
    WHERE u.registered_date <= DATE '2026-02-15'
    GROUP BY u.user_id, u.registered_date, cohort_week
)
SELECT
    cohort_week,
    COUNT(*) AS cohort_users,
    SUM(has_paid_order_14d) AS users_with_paid_order_14d,
    ROUND(SUM(has_paid_order_14d) * 100.0 / NULLIF(COUNT(*), 0), 2) AS conversion_14d_pct
FROM users_with_orders
GROUP BY cohort_week
ORDER BY cohort_week;

-- === weekly_cohort_conversion_by_channel ===
WITH users_with_orders AS (
    SELECT
        u.user_id,
        u.registered_date,
        DATE_TRUNC('week', u.registered_date) AS cohort_week,
        u.acquisition_channel,
        MAX(CASE WHEN o.order_id IS NOT NULL THEN 1 ELSE 0 END) AS has_paid_order_14d
    FROM users u
    LEFT JOIN orders o
        ON o.user_id = u.user_id
        AND o.order_status = 'paid'
        AND o.created_date >= u.registered_date
        AND o.created_date < u.registered_date + INTERVAL 14 DAY
    WHERE u.registered_date <= DATE '2026-02-15'
    GROUP BY u.user_id, u.registered_date, cohort_week, u.acquisition_channel
)
SELECT
    cohort_week,
    acquisition_channel,
    COUNT(*) AS cohort_users,
    SUM(has_paid_order_14d) AS users_with_paid_order_14d,
    ROUND(SUM(has_paid_order_14d) * 100.0 / NULLIF(COUNT(*), 0), 2) AS conversion_14d_pct
FROM users_with_orders
GROUP BY cohort_week, acquisition_channel
ORDER BY cohort_week, acquisition_channel;

-- === monthly_conversion_by_channel ===
-- Same 14-day conversion metric as above, aggregated by calendar month
-- (rather than week) and split by acquisition_channel. Lets us separate two
-- very different problems that both look like "a channel got worse":
--   - fewer people registering through the channel (an acquisition/spend problem), vs
--   - people registering but converting to a paid order less often (a quality/onboarding problem).
WITH users_with_orders AS (
    SELECT
        u.user_id,
        u.registered_date,
        DATE_TRUNC('month', u.registered_date) AS registration_month,
        u.acquisition_channel,
        MAX(CASE WHEN o.order_id IS NOT NULL THEN 1 ELSE 0 END) AS has_paid_order_14d
    FROM users u
    LEFT JOIN orders o
        ON o.user_id = u.user_id
        AND o.order_status = 'paid'
        AND o.created_date >= u.registered_date
        AND o.created_date < u.registered_date + INTERVAL 14 DAY
    WHERE u.registered_date <= DATE '2026-02-15'
    GROUP BY u.user_id, u.registered_date, registration_month, u.acquisition_channel
)
SELECT
    registration_month,
    acquisition_channel,
    COUNT(*) AS cohort_users,
    SUM(has_paid_order_14d) AS users_with_paid_order_14d,
    ROUND(SUM(has_paid_order_14d) * 100.0 / NULLIF(COUNT(*), 0), 2) AS conversion_14d_pct
FROM users_with_orders
GROUP BY registration_month, acquisition_channel
ORDER BY acquisition_channel, registration_month;

-- === monthly_registrations_by_channel ===
-- Raw registration volume per channel per month (full months, no 14-day
-- window restriction) - the "top of funnel" half of the story.
SELECT
    DATE_TRUNC('month', registered_date) AS registration_month,
    acquisition_channel,
    COUNT(*) AS registrations
FROM users
GROUP BY registration_month, acquisition_channel
ORDER BY acquisition_channel, registration_month;

-- === monthly_conversion_comparison ===
-- Compares Jan vs Feb using only the first two full weekly cohorts of each
-- month, so the same number of cohort-weeks is compared on both sides.
WITH users_with_orders AS (
    SELECT
        u.user_id,
        u.registered_date,
        DATE_TRUNC('month', u.registered_date) AS registration_month,
        MAX(CASE WHEN o.order_id IS NOT NULL THEN 1 ELSE 0 END) AS has_paid_order_14d
    FROM users u
    LEFT JOIN orders o
        ON o.user_id = u.user_id
        AND o.order_status = 'paid'
        AND o.created_date >= u.registered_date
        AND o.created_date < u.registered_date + INTERVAL 14 DAY
    WHERE u.registered_date <= DATE '2026-02-15'
    GROUP BY u.user_id, u.registered_date, registration_month
)
SELECT
    registration_month,
    COUNT(*) AS cohort_users,
    SUM(has_paid_order_14d) AS users_with_paid_order_14d,
    ROUND(SUM(has_paid_order_14d) * 100.0 / NULLIF(COUNT(*), 0), 2) AS conversion_14d_pct
FROM users_with_orders
GROUP BY registration_month
ORDER BY registration_month;
