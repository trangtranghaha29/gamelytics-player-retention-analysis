-- =====================================================================
-- cohort_analysis.sql
-- Phân tích retention theo cohort tháng để tạo heatmap
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1 Cohort heatmap — long version
-- ---------------------------------------------------------------------
WITH cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT uid) AS cohort_players
    FROM `project-1-506509.game_analytics.reg_complete`
    GROUP BY cohort_month
)
SELECT
    f.cohort_month,
    f.days_since_registration,
    CONCAT('D', CAST(f.days_since_registration AS STRING)) AS day_label,
    COUNT(DISTINCT f.uid) AS active_users,
    cs.cohort_players,
    ROUND(100 * SAFE_DIVIDE(COUNT(DISTINCT f.uid), cs.cohort_players), 2)
        AS retention_pct -- tổng users active tháng đấy/tổng users đăng kí tháng đấy
FROM `project-1-506509.game_analytics.first_7d_activity` f
JOIN cohort_size cs
    ON f.cohort_month = cs.cohort_month
WHERE f.days_since_registration BETWEEN 1 AND 7
GROUP BY f.cohort_month, f.days_since_registration, cs.cohort_players
ORDER BY f.cohort_month, f.days_since_registration;


-- 2 Cohort heatmap — wide version
-- PIVOT heatmap long version thành wide version
-- ---------------------------------------------------------------------
WITH cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT uid) AS cohort_players
    FROM `project-1-506509.game_analytics.reg_complete`
    GROUP BY cohort_month
),
daily AS (
    SELECT
        f.cohort_month,
        f.days_since_registration AS d,
        ROUND(100 * SAFE_DIVIDE(COUNT(DISTINCT f.uid), cs.cohort_players), 2) AS ret
    FROM `project-1-506509.game_analytics.first_7d_activity` f
    JOIN cohort_size cs ON f.cohort_month = cs.cohort_month
    WHERE f.days_since_registration BETWEEN 1 AND 7
    GROUP BY f.cohort_month, f.days_since_registration, cs.cohort_players
)
SELECT *
FROM daily
PIVOT (MAX(ret) FOR d IN (1 AS D1, 2 AS D2, 3 AS D3, 4 AS D4, 5 AS D5, 6 AS D6, 7 AS D7))
ORDER BY cohort_month;


-- 3 Lượng người chơi mới vs D7 retention theo tháng
-- ---------------------------------------------------------------------
WITH cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT uid) AS new_users
    FROM `project-1-506509.game_analytics.reg_complete`
    GROUP BY cohort_month
),
d7 AS (
    SELECT cohort_month, COUNT(DISTINCT uid) AS d7_users
    FROM `project-1-506509.game_analytics.first_7d_activity`
    WHERE days_since_registration = 7
    GROUP BY cohort_month
)
SELECT
    cs.cohort_month,
    cs.new_users,
    ROUND(100 * SAFE_DIVIDE(d7.d7_users, cs.new_users), 2) AS d7_retention_pct
FROM cohort_size cs
LEFT JOIN d7 ON cs.cohort_month = d7.cohort_month
ORDER BY cs.cohort_month;