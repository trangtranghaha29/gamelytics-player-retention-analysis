-- =====================================================================
-- registration_activity.sql
-- Chuẩn bị dữ liệu
-- =====================================================================

-- 1 reg_users
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `project-1-506509.game_analytics.reg_users` AS
SELECT
    uid,
    DATE(TIMESTAMP_SECONDS(reg_ts)) AS registration_date
FROM `project-1-506509.game_analytics.reg_data`;


-- 2 auth_events
-- dòng: mỗi ngày người chơi có hoạt động
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `project-1-506509.game_analytics.auth_events` AS
SELECT DISTINCT
    uid,
    DATE(TIMESTAMP_SECONDS(auth_ts)) AS activity_date
FROM `project-1-506509.game_analytics.auth_data`;


-- 3 reg_complete
-- cohort đăng ký từ 2020-01-01 và có đủ 7 ngày quan sát
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `project-1-506509.game_analytics.reg_complete` AS
SELECT
    uid,
    registration_date,
    FORMAT_DATE('%Y-%m', registration_date) AS cohort_month
FROM `project-1-506509.game_analytics.reg_users`
WHERE registration_date >= DATE '2020-01-01' -- loại timestamp quá cũ
  AND registration_date <= DATE_SUB(
        (SELECT MAX(activity_date) FROM `project-1-506509.game_analytics.auth_events`),
        INTERVAL 7 DAY -- có đủ 7 ngày tham gia
      );


-- 4 first_7d_activity
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `project-1-506509.game_analytics.first_7d_activity` AS
WITH bounds AS (
    SELECT MAX(activity_date) AS last_activity_date
    FROM `project-1-506509.game_analytics.auth_events`
)
SELECT
    rc.uid,
    rc.registration_date,
    rc.cohort_month,
    ae.activity_date,
    DATE_DIFF(ae.activity_date, rc.registration_date, DAY) AS days_since_registration
FROM `project-1-506509.game_analytics.reg_complete` rc
JOIN `project-1-506509.game_analytics.auth_events` ae
    ON rc.uid = ae.uid
CROSS JOIN bounds b
WHERE ae.activity_date >= rc.registration_date -- bỏ log lỗi (hoạt động trước khi đăng ký)
  AND ae.activity_date <= b.last_activity_date -- chặn mọi quan sát vượt bound
  AND DATE_DIFF(ae.activity_date, rc.registration_date, DAY) BETWEEN 0 AND 7;


-- 5 Kiểm tra
-- ---------------------------------------------------------------------
SELECT
    COUNT(DISTINCT uid)     AS cohort_players,
    MIN(registration_date)  AS first_cohort_date,
    MAX(registration_date)  AS last_cohort_date
FROM `project-1-506509.game_analytics.reg_complete`;


-- 6 Số lượng đăng ký mới theo ngày
-- dùng cho biểu đồ phân phối
-- ---------------------------------------------------------------------
SELECT
    registration_date,
    COUNT(DISTINCT uid) AS new_players
FROM `project-1-506509.game_analytics.reg_complete`
GROUP BY registration_date
ORDER BY registration_date;