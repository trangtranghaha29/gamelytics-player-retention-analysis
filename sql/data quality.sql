-- =====================================================================
-- data_quality.sql
-- Kiểm tra dữ liệu trước khi phân tích retention.
-- Chạy trên BigQuery.
-- =====================================================================

-- 1 Số lượng bản ghi
-- ---------------------------------------------------------------------
SELECT 'reg_data' AS table_name, COUNT(*) AS total_rows
FROM `project-1-506509.game_analytics.reg_data`
UNION ALL
SELECT 'auth_data', COUNT(*)
FROM `project-1-506509.game_analytics.auth_data`;


-- 2 Kiểm tra NULL
-- ---------------------------------------------------------------------
SELECT
    COUNTIF(uid IS NULL)    AS null_uid,
    COUNTIF(reg_ts IS NULL) AS null_reg_ts
FROM `project-1-506509.game_analytics.reg_data`;

SELECT
    COUNTIF(uid IS NULL)     AS null_uid,
    COUNTIF(auth_ts IS NULL) AS null_auth_ts
FROM `project-1-506509.game_analytics.auth_data`;


-- 3 Kiểm tra reg_data: mỗi người chơi chỉ 1 dòng đăng ký
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)            AS total_rows,
    COUNT(DISTINCT uid) AS unique_users
FROM `project-1-506509.game_analytics.reg_data`;


-- 4 Khoảng thời gian của dữ liệu
-- Kiểm tra phạm vi thời gian để xác định phạm vi thời gian cần phân tích
-- ---------------------------------------------------------------------
SELECT
    DATE(TIMESTAMP_SECONDS(MIN(reg_ts))) AS first_registration,
    DATE(TIMESTAMP_SECONDS(MAX(reg_ts))) AS last_registration
FROM `project-1-506509.game_analytics.reg_data`;

SELECT
    DATE(TIMESTAMP_SECONDS(MIN(auth_ts))) AS first_activity,
    DATE(TIMESTAMP_SECONDS(MAX(auth_ts))) AS last_activity
FROM `project-1-506509.game_analytics.auth_data`;


-- 5 Phân bố đăng ký theo năm (xác định ngoại lai)
-- ---------------------------------------------------------------------
SELECT
    EXTRACT(YEAR FROM TIMESTAMP_SECONDS(reg_ts)) AS reg_year,
    COUNT(*) AS players
FROM `project-1-506509.game_analytics.reg_data`
GROUP BY reg_year
ORDER BY reg_year;


-- 6 Kiểm tra xem uid trong auth có tồn tại trong reg không?
-- ---------------------------------------------------------------------
SELECT COUNT(DISTINCT a.uid) AS orphan_uids
FROM `project-1-506509.game_analytics.auth_data` a
LEFT JOIN `project-1-506509.game_analytics.reg_data` r
    ON a.uid = r.uid
WHERE r.uid IS NULL;