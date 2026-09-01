-- =====================================================================
-- engagement.sql
-- D7 Retention by Return Days (D1-D6)
-- =====================================================================

-- 1 player_features — mỗi người chơi 1 dòng
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `project-1-506509.game_analytics.player_features` AS
WITH return_days AS (
    SELECT
        uid,
        COUNT(DISTINCT activity_date) AS return_days_d1_d6
    FROM `project-1-506509.game_analytics.first_7d_activity`
    WHERE days_since_registration BETWEEN 1 AND 6
    GROUP BY uid
),
active_days AS (
    SELECT
        uid,
        COUNT(DISTINCT activity_date) AS active_days_d0_d6
    FROM `project-1-506509.game_analytics.first_7d_activity`
    WHERE days_since_registration BETWEEN 0 AND 6
    GROUP BY uid
),
d7_label AS (
    SELECT DISTINCT uid
    FROM `project-1-506509.game_analytics.first_7d_activity`
    WHERE days_since_registration = 7
)
SELECT
    rc.uid,
    rc.registration_date,
    rc.cohort_month,
    COALESCE(rd.return_days_d1_d6, 0) AS return_days_d1_d6,
    COALESCE(ad.active_days_d0_d6, 0) AS active_days_d0_d6,
    CASE WHEN l.uid IS NOT NULL THEN 1 ELSE 0 END AS retained_d7 --có hoạt động đúng ngày D7
FROM `project-1-506509.game_analytics.reg_complete` rc
LEFT JOIN return_days rd ON rc.uid = rd.uid
LEFT JOIN active_days ad ON rc.uid = ad.uid
LEFT JOIN d7_label   l  ON rc.uid = l.uid;


-- 2 D7 retention theo số ngày quay lại
-- ---------------------------------------------------------------------
SELECT
    return_days_d1_d6,
    COUNT(*) AS players,
    ROUND(100 * AVG(retained_d7), 2) AS d7_retention_pct
FROM `project-1-506509.game_analytics.player_features`
GROUP BY return_days_d1_d6
HAVING COUNT(*) >= 100          -- bỏ nhóm quá ít user (nhiễu)
ORDER BY return_days_d1_d6;


-- 3 Tính Avg Active Days và churn rate
-- ---------------------------------------------------------------------
SELECT
    ROUND(AVG(active_days_d0_d6), 2) AS avg_active_days,
    ROUND(100 * AVG(CASE WHEN return_days_d1_d6 = 0 THEN 1 ELSE 0 END), 2)
        AS no_return_pct
FROM `project-1-506509.game_analytics.player_features`;
