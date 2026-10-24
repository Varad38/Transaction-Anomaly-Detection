-- ============================================================
-- PROJECT 1: Financial Transaction Anomaly Detection
-- Author : Varad Rajagire
-- Tool   : SQL (compatible with MySQL / PostgreSQL)
-- Purpose: Identify fraudulent or high-risk transactions
--          from 85,000+ synthetic transaction records
-- ============================================================

-- ============================================================
-- SECTION 1: DATABASE & TABLE SETUP
-- ============================================================

CREATE DATABASE IF NOT EXISTS fraud_detection;
USE fraud_detection;

CREATE TABLE IF NOT EXISTS transactions (
    transaction_id      VARCHAR(20)     PRIMARY KEY,
    account_id          VARCHAR(15)     NOT NULL,
    transaction_date    DATETIME        NOT NULL,
    amount              DECIMAL(10,2)   NOT NULL,
    merchant_category   VARCHAR(50),
    channel             VARCHAR(20),        -- online / in-store / mobile
    location_city       VARCHAR(50),
    account_city        VARCHAR(50),
    login_attempts      INT DEFAULT 1,      -- failed logins before this txn
    is_new_device       TINYINT(1),         -- 1 = unrecognised device
    is_first_order      TINYINT(1),         -- 1 = first purchase on account
    account_age_days    INT,
    flagged             TINYINT(1) DEFAULT 0
);

-- ============================================================
-- SECTION 2: BASIC EXPLORATION
-- ============================================================

-- 2a. Total record count
SELECT COUNT(*) AS total_transactions FROM transactions;

-- 2b. Date range of data
SELECT
    MIN(transaction_date) AS earliest,
    MAX(transaction_date) AS latest
FROM transactions;

-- 2c. Distribution by channel
SELECT
    channel,
    COUNT(*)                                AS txn_count,
    ROUND(AVG(amount), 2)                   AS avg_amount,
    ROUND(SUM(amount), 2)                   AS total_volume
FROM transactions
GROUP BY channel
ORDER BY txn_count DESC;

-- 2d. Top merchant categories by volume
SELECT
    merchant_category,
    COUNT(*)            AS txn_count,
    ROUND(SUM(amount),2) AS total_amount
FROM transactions
GROUP BY merchant_category
ORDER BY total_amount DESC
LIMIT 10;

-- ============================================================
-- SECTION 3: FRAUD DETECTION RULES
-- ============================================================

-- RULE 1: Velocity abuse — 5+ transactions from same account within 1 hour
SELECT
    t1.account_id,
    t1.transaction_date,
    COUNT(t2.transaction_id) AS txns_in_window,
    SUM(t2.amount)           AS total_in_window
FROM transactions t1
JOIN transactions t2
    ON  t1.account_id = t2.account_id
    AND t2.transaction_date BETWEEN t1.transaction_date
                                AND DATE_ADD(t1.transaction_date, INTERVAL 1 HOUR)
GROUP BY t1.account_id, t1.transaction_date
HAVING COUNT(t2.transaction_id) >= 5
ORDER BY txns_in_window DESC;

-- RULE 2: Geographic mismatch — transaction city differs from account city
SELECT
    transaction_id,
    account_id,
    transaction_date,
    amount,
    location_city,
    account_city
FROM transactions
WHERE location_city <> account_city
  AND amount > 5000
ORDER BY amount DESC;

-- RULE 3: Account takeover signals — multiple failed logins before purchase
SELECT
    transaction_id,
    account_id,
    transaction_date,
    amount,
    login_attempts,
    is_new_device
FROM transactions
WHERE login_attempts >= 3
  AND is_new_device = 1
ORDER BY login_attempts DESC, amount DESC;

-- RULE 4: First-time high-value orders (common in CNP fraud)
SELECT
    transaction_id,
    account_id,
    transaction_date,
    amount,
    channel,
    account_age_days
FROM transactions
WHERE is_first_order = 1
  AND amount > 10000
  AND channel = 'online'
ORDER BY amount DESC;

-- RULE 5: Abnormally large single transaction (> 3 standard deviations from mean)
SELECT
    transaction_id,
    account_id,
    transaction_date,
    amount,
    merchant_category,
    channel
FROM transactions
WHERE amount > (
    SELECT AVG(amount) + 3 * STDDEV(amount) FROM transactions
)
ORDER BY amount DESC;

-- ============================================================
-- SECTION 4: RISK SCORING
-- ============================================================

-- Composite risk score per transaction (0–5 scale)
-- Each rule contributes 1 point when triggered
SELECT
    transaction_id,
    account_id,
    transaction_date,
    amount,
    channel,
    merchant_category,
    (
        CASE WHEN login_attempts >= 3 AND is_new_device = 1 THEN 1 ELSE 0 END +
        CASE WHEN location_city <> account_city              THEN 1 ELSE 0 END +
        CASE WHEN is_first_order = 1 AND amount > 10000      THEN 1 ELSE 0 END +
        CASE WHEN amount > 15000                             THEN 1 ELSE 0 END +
        CASE WHEN channel = 'online' AND account_age_days < 30 THEN 1 ELSE 0 END
    ) AS risk_score
FROM transactions
ORDER BY risk_score DESC
LIMIT 50;

-- ============================================================
-- SECTION 5: RISK TIER SEGMENTATION
-- ============================================================

-- Segment into Low / Medium / High risk tiers
SELECT
    risk_score,
    CASE
        WHEN risk_score >= 4 THEN 'HIGH'
        WHEN risk_score >= 2 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS risk_tier,
    COUNT(*)               AS txn_count,
    ROUND(AVG(amount), 2)  AS avg_amount,
    ROUND(SUM(amount), 2)  AS total_exposure
FROM (
    SELECT
        transaction_id,
        amount,
        (
            CASE WHEN login_attempts >= 3 AND is_new_device = 1 THEN 1 ELSE 0 END +
            CASE WHEN location_city <> account_city              THEN 1 ELSE 0 END +
            CASE WHEN is_first_order = 1 AND amount > 10000      THEN 1 ELSE 0 END +
            CASE WHEN amount > 15000                             THEN 1 ELSE 0 END +
            CASE WHEN channel = 'online' AND account_age_days < 30 THEN 1 ELSE 0 END
        ) AS risk_score
    FROM transactions
) scored
GROUP BY risk_score, risk_tier
ORDER BY risk_score DESC;

-- ============================================================
-- SECTION 6: TIME-OF-DAY & DAY-OF-WEEK ANALYSIS
-- ============================================================

-- Fraud concentration by hour of day
SELECT
    HOUR(transaction_date)          AS hour_of_day,
    COUNT(*)                        AS total_txns,
    SUM(flagged)                    AS flagged_txns,
    ROUND(100.0 * SUM(flagged) / COUNT(*), 2) AS flag_rate_pct
FROM transactions
GROUP BY hour_of_day
ORDER BY flag_rate_pct DESC;

-- Fraud rate by day of week
SELECT
    DAYNAME(transaction_date)       AS day_of_week,
    COUNT(*)                        AS total_txns,
    SUM(flagged)                    AS flagged_txns,
    ROUND(100.0 * SUM(flagged) / COUNT(*), 2) AS flag_rate_pct
FROM transactions
GROUP BY day_of_week
ORDER BY flag_rate_pct DESC;

-- ============================================================
-- SECTION 7: EXECUTIVE SUMMARY VIEW
-- ============================================================

SELECT
    'Total Transactions'        AS metric, COUNT(*)            AS value FROM transactions
UNION ALL
SELECT 'Total Volume (INR)',    ROUND(SUM(amount), 2)          FROM transactions
UNION ALL
SELECT 'Avg Transaction Size',  ROUND(AVG(amount), 2)          FROM transactions
UNION ALL
SELECT 'Flagged Transactions',  SUM(flagged)                   FROM transactions
UNION ALL
SELECT 'Flag Rate (%)',         ROUND(100.0*SUM(flagged)/COUNT(*),2) FROM transactions
UNION ALL
SELECT 'High-Risk Count',       COUNT(*) FROM (
    SELECT (
        CASE WHEN login_attempts >= 3 AND is_new_device = 1 THEN 1 ELSE 0 END +
        CASE WHEN location_city <> account_city              THEN 1 ELSE 0 END +
        CASE WHEN is_first_order = 1 AND amount > 10000      THEN 1 ELSE 0 END +
        CASE WHEN amount > 15000                             THEN 1 ELSE 0 END +
        CASE WHEN channel = 'online' AND account_age_days < 30 THEN 1 ELSE 0 END
    ) AS score FROM transactions
) s WHERE score >= 4;
