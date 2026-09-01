-- =====================================================================
-- retention.sql
-- Tính retention curve D0-D7 và D1/D3/D7
-- =====================================================================

-- 1 Retention curve D0 -> D7
-- ---------------------------------------------------------------------
SELECT
    days_since_registration,
    COUNT(DISTINCT uid) AS active_users,
    ROUND(
        100.0 * COUNT(DISTINCT uid)
        / (SELECT COUNT(DISTINCT uid) FROM `project-1-506509.game_analytics.reg_complete`),
        2
    ) AS retention_pct -- tổng số users đã hoạt động trên từng ngày/tổng users đã đăng ký
FROM `project-1-506509.game_analytics.first_7d_activity`
GROUP BY days_since_registration
ORDER BY days_since_registration;


-- 2 Tính D1 / D3 / D7
-- ---------------------------------------------------------------------
WITH cohort AS (
    SELECT COUNT(DISTINCT uid) AS total_players
    FROM `project-1-506509.game_analytics.reg_complete`
)
SELECT
    c.total_players,
    ROUND(100 * SAFE_DIVIDE(
        COUNT(DISTINCT CASE WHEN f.days_since_registration = 1 THEN f.uid END),
        c.total_players), 2) AS d1_retention_pct, -- count():chỉ đếm những uid thoả điều kiện
    ROUND(100 * SAFE_DIVIDE(
        COUNT(DISTINCT CASE WHEN f.days_since_registration = 3 THEN f.uid END),
        c.total_players), 2) AS d3_retention_pct,
    ROUND(100 * SAFE_DIVIDE(
        COUNT(DISTINCT CASE WHEN f.days_since_registration = 7 THEN f.uid END),
        c.total_players), 2) AS d7_retention_pct -- safe_divide:tự ngắt nếu mẫu=0
FROM `project-1-506509.game_analytics.first_7d_activity` f
CROSS JOIN cohort c
GROUP BY c.total_players;


-- 3 Mức thay đổi retention giữa các ngày liên tiếp
-- Note: D0->D1 giảm ~-98pp; các ngày sau tăng nhẹ. Đây là đặc
-- tính của bộ dữ liệu synthetic, không phản ánh hành vi churn thật.
-- ---------------------------------------------------------------------
WITH curve AS (
    SELECT
        days_since_registration,
        100.0 * COUNT(DISTINCT uid)
        / (SELECT COUNT(DISTINCT uid) FROM `project-1-506509.game_analytics.reg_complete`)
            AS retention_pct
    FROM `project-1-506509.game_analytics.first_7d_activity`
    GROUP BY days_since_registration
)
SELECT
    CONCAT('D', CAST(days_since_registration - 1 AS STRING),
           '->D', CAST(days_since_registration AS STRING)) AS transition,
    ROUND(retention_pct
          - LAG(retention_pct) OVER (ORDER BY days_since_registration), 2) AS change_pp 
-- lag: lấy giá trị dòng trước đấy
FROM curve
WHERE days_since_registration > 0
ORDER BY days_since_registration;