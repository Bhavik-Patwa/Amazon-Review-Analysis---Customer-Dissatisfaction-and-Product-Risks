-- Combining raw review tables from all selected categories into one standardized reviews table
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.reviews`
PARTITION BY review_month
CLUSTER BY category_name, parent_asin, asin AS

-- Adding reviews from 'Home_and_Kitchen' into the shared core review table
SELECT
    'Home_and_Kitchen' AS category_name,
    SAFE_CAST(asin AS STRING) AS asin,
    SAFE_CAST(parent_asin AS STRING) AS parent_asin,
    SAFE_CAST(user_id AS STRING) AS user_id,
    SAFE_CAST(rating AS FLOAT64) AS rating,
    SAFE_CAST(helpful_vote AS INT64) AS helpful_vote,
    SAFE_CAST(verified_purchase AS BOOL) AS verified_purchase,
    SAFE_CAST(title AS STRING) AS review_title,
    SAFE_CAST(text AS STRING) AS review_text,
    SAFE_CAST(timestamp AS INT64) AS review_timestamp_ms,
    TIMESTAMP_MILLIS(SAFE_CAST(timestamp AS INT64)) AS review_timestamp_utc,
    DATE(TIMESTAMP_MILLIS(SAFE_CAST(timestamp AS INT64))) AS review_date,
    DATE_TRUNC(DATE(TIMESTAMP_MILLIS(SAFE_CAST(timestamp AS INT64))), MONTH) AS review_month
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_RAW_DATASET_ID}}.review_home_and_kitchen_raw`

-- Adding reviews from 'Beauty_and_Personal_Care' into the shared core review table
UNION ALL

SELECT
    'Beauty_and_Personal_Care' AS category_name,
    SAFE_CAST(asin AS STRING) AS asin,
    SAFE_CAST(parent_asin AS STRING) AS parent_asin,
    SAFE_CAST(user_id AS STRING) AS user_id,
    SAFE_CAST(rating AS FLOAT64) AS rating,
    SAFE_CAST(helpful_vote AS INT64) AS helpful_vote,
    SAFE_CAST(verified_purchase AS BOOL) AS verified_purchase,
    SAFE_CAST(title AS STRING) AS review_title,
    SAFE_CAST(text AS STRING) AS review_text,
    SAFE_CAST(timestamp AS INT64) AS review_timestamp_ms,
    TIMESTAMP_MILLIS(SAFE_CAST(timestamp AS INT64)) AS review_timestamp_utc,
    DATE(TIMESTAMP_MILLIS(SAFE_CAST(timestamp AS INT64))) AS review_date,
    DATE_TRUNC(DATE(TIMESTAMP_MILLIS(SAFE_CAST(timestamp AS INT64))), MONTH) AS review_month
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_RAW_DATASET_ID}}.review_beauty_and_personal_care_raw`

-- Adding reviews from 'Electronics' into the shared core review table
UNION ALL

SELECT
    'Electronics' AS category_name,
    SAFE_CAST(asin AS STRING) AS asin,
    SAFE_CAST(parent_asin AS STRING) AS parent_asin,
    SAFE_CAST(user_id AS STRING) AS user_id,
    SAFE_CAST(rating AS FLOAT64) AS rating,
    SAFE_CAST(helpful_vote AS INT64) AS helpful_vote,
    SAFE_CAST(verified_purchase AS BOOL) AS verified_purchase,
    SAFE_CAST(title AS STRING) AS review_title,
    SAFE_CAST(text AS STRING) AS review_text,
    SAFE_CAST(timestamp AS INT64) AS review_timestamp_ms,
    TIMESTAMP_MILLIS(SAFE_CAST(timestamp AS INT64)) AS review_timestamp_utc,
    DATE(TIMESTAMP_MILLIS(SAFE_CAST(timestamp AS INT64))) AS review_date,
    DATE_TRUNC(DATE(TIMESTAMP_MILLIS(SAFE_CAST(timestamp AS INT64))), MONTH) AS review_month
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_RAW_DATASET_ID}}.review_electronics_raw`

-- Adding reviews from 'Books' into the shared core review table
UNION ALL

SELECT
    'Books' AS category_name,
    SAFE_CAST(asin AS STRING) AS asin,
    SAFE_CAST(parent_asin AS STRING) AS parent_asin,
    SAFE_CAST(user_id AS STRING) AS user_id,
    SAFE_CAST(rating AS FLOAT64) AS rating,
    SAFE_CAST(helpful_vote AS INT64) AS helpful_vote,
    SAFE_CAST(verified_purchase AS BOOL) AS verified_purchase,
    SAFE_CAST(title AS STRING) AS review_title,
    SAFE_CAST(text AS STRING) AS review_text,
    SAFE_CAST(timestamp AS INT64) AS review_timestamp_ms,
    TIMESTAMP_MILLIS(SAFE_CAST(timestamp AS INT64)) AS review_timestamp_utc,
    DATE(TIMESTAMP_MILLIS(SAFE_CAST(timestamp AS INT64))) AS review_date,
    DATE_TRUNC(DATE(TIMESTAMP_MILLIS(SAFE_CAST(timestamp AS INT64))), MONTH) AS review_month
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_RAW_DATASET_ID}}.review_books_raw`

-- Adding reviews from 'Movies_and_TV' into the shared core review table
UNION ALL

SELECT
    'Movies_and_TV' AS category_name,
    SAFE_CAST(asin AS STRING) AS asin,
    SAFE_CAST(parent_asin AS STRING) AS parent_asin,
    SAFE_CAST(user_id AS STRING) AS user_id,
    SAFE_CAST(rating AS FLOAT64) AS rating,
    SAFE_CAST(helpful_vote AS INT64) AS helpful_vote,
    SAFE_CAST(verified_purchase AS BOOL) AS verified_purchase,
    SAFE_CAST(title AS STRING) AS review_title,
    SAFE_CAST(text AS STRING) AS review_text,
    SAFE_CAST(timestamp AS INT64) AS review_timestamp_ms,
    TIMESTAMP_MILLIS(SAFE_CAST(timestamp AS INT64)) AS review_timestamp_utc,
    DATE(TIMESTAMP_MILLIS(SAFE_CAST(timestamp AS INT64))) AS review_date,
    DATE_TRUNC(DATE(TIMESTAMP_MILLIS(SAFE_CAST(timestamp AS INT64))), MONTH) AS review_month
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_RAW_DATASET_ID}}.review_movies_and_tv_raw`;