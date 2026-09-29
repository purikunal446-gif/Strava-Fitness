/*
  STRAVA FITNESS / BELLABEAT CASE STUDY
  MySQL analysis file

  Purpose:
  - Create a clean analytical layer from the Fitbit smart-device data.
  - Answer practical business questions around activity, sleep and weight.
  - Keep the analysis reproducible rather than hard-coding dashboard numbers.

  Main source tables:
    dailyActivity_merged.csv
    sleepDay_merged.csv
    weightLogInfo_merged.csv

  Note:
  The source files contain dates such as 4/12/2016 and 4/12/2016 12:00:00 AM.
  The staging tables therefore keep the raw date as VARCHAR and convert it
  into proper DATE/DATETIME columns in the clean layer.
*/

DROP DATABASE IF EXISTS strava_fitness;
CREATE DATABASE strava_fitness;
USE strava_fitness;

-- ------------------------------------------------------------
-- 1. Staging tables
-- ------------------------------------------------------------
CREATE TABLE stg_daily_activity (
    Id BIGINT,
    ActivityDate VARCHAR(40),
    TotalSteps INT,
    TotalDistance DECIMAL(10,2),
    TrackerDistance DECIMAL(10,2),
    LoggedActivitiesDistance DECIMAL(10,4),
    VeryActiveDistance DECIMAL(10,2),
    ModeratelyActiveDistance DECIMAL(10,2),
    LightActiveDistance DECIMAL(10,2),
    SedentaryActiveDistance DECIMAL(10,2),
    VeryActiveMinutes INT,
    FairlyActiveMinutes INT,
    LightlyActiveMinutes INT,
    SedentaryMinutes INT,
    Calories INT
);

CREATE TABLE stg_sleep (
    Id BIGINT,
    SleepDay VARCHAR(40),
    TotalSleepRecords INT,
    TotalMinutesAsleep INT,
    TotalTimeInBed INT
);

CREATE TABLE stg_weight (
    Id BIGINT,
    Date VARCHAR(40),
    WeightKg DECIMAL(10,2),
    WeightPounds DECIMAL(10,2),
    Fat DECIMAL(10,2),
    BMI DECIMAL(10,2),
    IsManualReport VARCHAR(10),
    LogId BIGINT
);

/*
  Import:
  Run these LOAD DATA statements only after changing the file paths to the
  location on your computer. In MySQL Workbench, LOCAL INFILE may need to be
  enabled depending on your installation.
*/
-- LOAD DATA LOCAL INFILE 'C:/path/dailyActivity_merged.csv'
-- INTO TABLE stg_daily_activity
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"'
-- IGNORE 1 ROWS;

-- LOAD DATA LOCAL INFILE 'C:/path/sleepDay_merged.csv'
-- INTO TABLE stg_sleep
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"'
-- IGNORE 1 ROWS;

-- LOAD DATA LOCAL INFILE 'C:/path/weightLogInfo_merged.csv'
-- INTO TABLE stg_weight
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"'
-- IGNORE 1 ROWS;


-- ------------------------------------------------------------
-- 2. Clean analytical tables
-- ------------------------------------------------------------
CREATE TABLE daily_activity AS
SELECT
    Id AS customer_id,
    STR_TO_DATE(ActivityDate, '%c/%e/%Y') AS activity_date,
    TotalSteps AS total_steps,
    TotalDistance AS total_distance,
    TrackerDistance AS tracker_distance,
    LoggedActivitiesDistance AS logged_activity_distance,
    VeryActiveDistance AS very_active_distance,
    ModeratelyActiveDistance AS moderately_active_distance,
    LightActiveDistance AS light_active_distance,
    SedentaryActiveDistance AS sedentary_active_distance,
    VeryActiveMinutes AS very_active_minutes,
    FairlyActiveMinutes AS fairly_active_minutes,
    LightlyActiveMinutes AS lightly_active_minutes,
    SedentaryMinutes AS sedentary_minutes,
    Calories AS calories
FROM stg_daily_activity
WHERE Id IS NOT NULL
  AND ActivityDate IS NOT NULL;

ALTER TABLE daily_activity
    ADD PRIMARY KEY (customer_id, activity_date),
    ADD INDEX idx_activity_date (activity_date);

CREATE TABLE sleep_daily AS
SELECT
    Id AS customer_id,
    DATE(STR_TO_DATE(SleepDay, '%c/%e/%Y %r')) AS sleep_date,
    TotalSleepRecords AS sleep_records,
    TotalMinutesAsleep AS minutes_asleep,
    TotalTimeInBed AS minutes_in_bed
FROM stg_sleep
WHERE Id IS NOT NULL
  AND SleepDay IS NOT NULL;

ALTER TABLE sleep_daily
    ADD INDEX idx_sleep_customer_date (customer_id, sleep_date);

CREATE TABLE weight_log AS
SELECT
    Id AS customer_id,
    STR_TO_DATE(Date, '%c/%e/%Y %r') AS logged_at,
    WeightKg AS weight_kg,
    WeightPounds AS weight_pounds,
    Fat AS body_fat,
    BMI AS bmi,
    CASE
        WHEN LOWER(IsManualReport) = 'true' THEN 1
        WHEN LOWER(IsManualReport) = 'false' THEN 0
        ELSE NULL
    END AS is_manual_report,
    LogId AS log_id
FROM stg_weight
WHERE Id IS NOT NULL
  AND Date IS NOT NULL;

ALTER TABLE weight_log
    ADD INDEX idx_weight_customer_date (customer_id, logged_at);


-- ------------------------------------------------------------
-- 3. Data quality checks
-- ------------------------------------------------------------

-- Overall record counts
SELECT 'daily_activity' AS table_name, COUNT(*) AS records FROM daily_activity
UNION ALL
SELECT 'sleep_daily', COUNT(*) FROM sleep_daily
UNION ALL
SELECT 'weight_log', COUNT(*) FROM weight_log;

-- Unique users
SELECT
    COUNT(DISTINCT customer_id) AS active_users,
    COUNT(*) AS activity_rows,
    MIN(activity_date) AS first_activity_date,
    MAX(activity_date) AS last_activity_date
FROM daily_activity;

-- Missing-value check in the main activity table
SELECT
    SUM(total_steps IS NULL) AS missing_steps,
    SUM(total_distance IS NULL) AS missing_distance,
    SUM(total_calories IS NULL) AS missing_calories,
    SUM(total_active_minutes IS NULL) AS missing_active_minutes
FROM (
    SELECT
        total_steps,
        total_distance,
        calories AS total_calories,
        (very_active_minutes + fairly_active_minutes + lightly_active_minutes) AS total_active_minutes
    FROM daily_activity
) q;

-- Duplicate check
SELECT customer_id, activity_date, COUNT(*) AS duplicate_rows
FROM daily_activity
GROUP BY customer_id, activity_date
HAVING COUNT(*) > 1;


-- ------------------------------------------------------------
-- 4. Reusable analytical view
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_activity_summary AS
SELECT
    customer_id,
    activity_date,
    DAYNAME(activity_date) AS weekday,
    total_steps,
    total_distance,
    calories,
    (very_active_minutes + fairly_active_minutes + lightly_active_minutes) AS active_minutes,
    sedentary_minutes,
    very_active_minutes,
    fairly_active_minutes,
    lightly_active_minutes,
    CASE
        WHEN total_steps >= 10000 THEN '10K+ steps'
        WHEN total_steps >= 7500 THEN '7.5K-9.9K steps'
        WHEN total_steps >= 5000 THEN '5K-7.4K steps'
        ELSE 'Below 5K'
    END AS activity_band
FROM daily_activity;


-- ------------------------------------------------------------
-- 5. Business analysis
-- ------------------------------------------------------------

-- Q1. Overall activity profile
SELECT
    COUNT(DISTINCT customer_id) AS users,
    ROUND(AVG(total_steps), 0) AS avg_daily_steps,
    ROUND(AVG(total_distance), 2) AS avg_daily_distance,
    ROUND(AVG(calories), 0) AS avg_daily_calories,
    ROUND(AVG(active_minutes), 0) AS avg_active_minutes,
    ROUND(AVG(sedentary_minutes), 0) AS avg_sedentary_minutes
FROM v_activity_summary;

-- Q2. Activity performance by weekday
SELECT
    weekday,
    COUNT(*) AS activity_days,
    ROUND(AVG(total_steps), 0) AS avg_steps,
    ROUND(AVG(active_minutes), 0) AS avg_active_minutes,
    ROUND(AVG(calories), 0) AS avg_calories
FROM v_activity_summary
GROUP BY weekday
ORDER BY avg_steps DESC;

-- Q3. Monthly trend
SELECT
    DATE_FORMAT(activity_date, '%Y-%m') AS month,
    COUNT(DISTINCT customer_id) AS active_users,
    ROUND(AVG(total_steps), 0) AS avg_steps,
    ROUND(AVG(calories), 0) AS avg_calories,
    ROUND(AVG(active_minutes), 0) AS avg_active_minutes
FROM v_activity_summary
GROUP BY DATE_FORMAT(activity_date, '%Y-%m')
ORDER BY month;

-- Q4. User-level engagement
SELECT
    customer_id,
    COUNT(*) AS tracked_days,
    ROUND(AVG(total_steps), 0) AS avg_steps,
    ROUND(AVG(active_minutes), 0) AS avg_active_minutes,
    ROUND(AVG(sedentary_minutes), 0) AS avg_sedentary_minutes,
    ROUND(AVG(calories), 0) AS avg_calories
FROM v_activity_summary
GROUP BY customer_id
ORDER BY avg_steps DESC;

-- Q5. Highly engaged users
SELECT
    customer_id,
    COUNT(*) AS tracked_days,
    ROUND(AVG(total_steps), 0) AS avg_steps,
    ROUND(AVG(active_minutes), 0) AS avg_active_minutes
FROM v_activity_summary
GROUP BY customer_id
HAVING AVG(total_steps) >= 10000
ORDER BY avg_steps DESC;

-- Q6. Users below a 5K daily-step threshold
SELECT
    customer_id,
    COUNT(*) AS tracked_days,
    ROUND(AVG(total_steps), 0) AS avg_steps,
    ROUND(AVG(sedentary_minutes), 0) AS avg_sedentary_minutes
FROM v_activity_summary
GROUP BY customer_id
HAVING AVG(total_steps) < 5000
ORDER BY avg_steps;

-- Q7. Activity bands
SELECT
    activity_band,
    COUNT(*) AS activity_days,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_of_days_pct
FROM v_activity_summary
GROUP BY activity_band
ORDER BY activity_days DESC;

-- Q8. Sleep profile
SELECT
    COUNT(DISTINCT customer_id) AS users_with_sleep_data,
    ROUND(AVG(minutes_asleep) / 60, 2) AS avg_sleep_hours,
    ROUND(AVG(minutes_in_bed) / 60, 2) AS avg_time_in_bed_hours,
    ROUND(AVG(minutes_in_bed - minutes_asleep), 0) AS avg_awake_minutes_in_bed
FROM sleep_daily;

-- Q9. Sleep and activity relationship
SELECT
    CASE
        WHEN s.minutes_asleep < 360 THEN 'Under 6 hours'
        WHEN s.minutes_asleep < 420 THEN '6-7 hours'
        WHEN s.minutes_asleep < 480 THEN '7-8 hours'
        ELSE '8+ hours'
    END AS sleep_band,
    COUNT(*) AS records,
    ROUND(AVG(a.total_steps), 0) AS avg_steps,
    ROUND(AVG(a.active_minutes), 0) AS avg_active_minutes,
    ROUND(AVG(a.calories), 0) AS avg_calories
FROM sleep_daily s
JOIN daily_activity a
  ON s.customer_id = a.customer_id
 AND s.sleep_date = a.activity_date
GROUP BY sleep_band
ORDER BY avg_steps DESC;

-- Q10. Weight/BMI coverage
SELECT
    COUNT(DISTINCT customer_id) AS users_with_weight_data,
    ROUND(AVG(weight_kg), 2) AS avg_weight_kg,
    ROUND(AVG(bmi), 2) AS avg_bmi,
    MIN(logged_at) AS first_weight_log,
    MAX(logged_at) AS last_weight_log
FROM weight_log;

-- Q11. Most active day for each weekday
WITH ranked_days AS (
    SELECT
        customer_id,
        activity_date,
        total_steps,
        ROW_NUMBER() OVER (
            PARTITION BY DAYNAME(activity_date)
            ORDER BY total_steps DESC
        ) AS rn
    FROM daily_activity
)
SELECT *
FROM ranked_days
WHERE rn = 1
ORDER BY activity_date;

-- Q12. Step-calorie relationship at daily level
SELECT
    ROUND(CORR(total_steps, calories), 3) AS step_calorie_correlation
FROM daily_activity;

-- ------------------------------------------------------------
-- 6. Dashboard-ready extracts
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW dashboard_daily AS
SELECT
    activity_date,
    COUNT(DISTINCT customer_id) AS active_users,
    ROUND(AVG(total_steps), 0) AS avg_steps,
    ROUND(AVG(total_distance), 2) AS avg_distance,
    ROUND(AVG(calories), 0) AS avg_calories,
    ROUND(AVG(very_active_minutes + fairly_active_minutes + lightly_active_minutes), 0) AS avg_active_minutes,
    ROUND(AVG(sedentary_minutes), 0) AS avg_sedentary_minutes
FROM daily_activity
GROUP BY activity_date;

CREATE OR REPLACE VIEW dashboard_user AS
SELECT
    customer_id,
    COUNT(*) AS tracked_days,
    ROUND(AVG(total_steps), 0) AS avg_steps,
    ROUND(AVG(total_distance), 2) AS avg_distance,
    ROUND(AVG(calories), 0) AS avg_calories,
    ROUND(AVG(very_active_minutes + fairly_active_minutes + lightly_active_minutes), 0) AS avg_active_minutes,
    ROUND(AVG(sedentary_minutes), 0) AS avg_sedentary_minutes
FROM daily_activity
GROUP BY customer_id;

-- End of analysis file.
