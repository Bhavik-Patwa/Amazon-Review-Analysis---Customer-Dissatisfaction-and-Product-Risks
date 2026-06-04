-- Checking review value quality for ratings, helpful votes and suspicious dates
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.profile_reviews_value_quality` AS
SELECT
    category_name,
    COUNT(*) AS review_count,
    COUNTIF(rating NOT BETWEEN 1 AND 5 OR rating IS NULL) AS invalid_rating_count,
    COUNTIF(rating = 0) AS zero_rating_count,
    COUNTIF(helpful_vote IS NULL) AS missing_helpful_vote_count,
    COUNTIF(helpful_vote < 0) AS negative_helpful_vote_count,
    MAX(helpful_vote) AS max_helpful_vote,
    COUNTIF(review_date < DATE '1995-01-01') AS suspicious_early_review_date_count,
    COUNTIF(review_date > CURRENT_DATE()) AS future_review_date_count
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_reviews`
GROUP BY category_name;


-- Identifying possible duplicate review records across categories and products
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.profile_reviews_duplicate_signals` AS
WITH duplicate_groups AS (
    SELECT
        category_name,
        parent_asin,
        user_id,
        review_title,
        review_text,
        rating,
        review_timestamp_ms,
        COUNT(*) AS duplicate_count
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_reviews`
    GROUP BY
        category_name,
        parent_asin,
        user_id,
        review_title,
        review_text,
        rating,
        review_timestamp_ms
)
SELECT
    category_name,
    COUNT(*) AS unique_review_groups,
    COUNTIF(duplicate_count > 1) AS duplicated_review_groups,
    SUM(duplicate_count) AS total_rows_in_grouping,
    SUM(CASE WHEN duplicate_count > 1 THEN duplicate_count ELSE 0 END) AS duplicated_rows
FROM duplicate_groups
GROUP BY category_name;


-- Measuring whether review text is usable for text-based analysis
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.profile_reviews_text_readiness` AS
SELECT
    category_name,
    COUNT(*) AS review_count,
    COUNTIF(TRIM(COALESCE(review_text, "")) <> "") AS non_blank_review_text_count,
    COUNTIF(LENGTH(TRIM(COALESCE(review_text, ""))) >= 30) AS review_text_30_plus_count,
    COUNTIF(LENGTH(TRIM(COALESCE(review_text, ""))) >= 50) AS review_text_50_plus_count,
    COUNTIF(LENGTH(TRIM(COALESCE(review_text, ""))) >= 100) AS review_text_100_plus_count,
    COUNTIF(REGEXP_CONTAINS(COALESCE(review_text, ""), r"[A-Za-z]{3,}")) AS alphabetic_word_pattern_count,
    COUNTIF(REGEXP_CONTAINS(COALESCE(review_text, ""), r"^[^A-Za-z0-9]*$")) AS symbol_only_or_empty_count
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_reviews`
GROUP BY category_name;


-- Checking product metadata completeness for content-based analysis
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.profile_products_metadata_readiness` AS
SELECT
    category_name,
    COUNT(*) AS product_count,
    COUNTIF(TRIM(COALESCE(product_title, "")) <> "") AS usable_product_title_count,
    COUNTIF(TRIM(COALESCE(main_category, "")) <> "") AS usable_main_category_count,
    COUNTIF(TRIM(COALESCE(store, "")) <> "") AS usable_store_count,
    COUNTIF(price_amount IS NOT NULL AND price_amount > 0) AS usable_price_count,
    COUNTIF(features_json IS NOT NULL AND features_json NOT IN ("null", "[]")) AS usable_features_count,
    COUNTIF(description_json IS NOT NULL AND description_json NOT IN ("null", "[]")) AS usable_description_count,
    COUNTIF(details_json IS NOT NULL AND details_json NOT IN ("null", "{}")) AS usable_details_count
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_products`
GROUP BY category_name;


-- Profiling product price availability and price-band distribution
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.profile_products_price_distribution` AS
SELECT
    category_name,
    COUNT(*) AS product_count,
    COUNTIF(price_amount IS NULL) AS missing_price_count,
    COUNTIF(price_amount <= 0) AS non_positive_price_count,
    APPROX_QUANTILES(IF(price_amount > 0, price_amount, NULL), 100)[OFFSET(5)] AS price_p05,
    APPROX_QUANTILES(IF(price_amount > 0, price_amount, NULL), 100)[OFFSET(25)] AS price_p25,
    APPROX_QUANTILES(IF(price_amount > 0, price_amount, NULL), 100)[OFFSET(50)] AS price_p50,
    APPROX_QUANTILES(IF(price_amount > 0, price_amount, NULL), 100)[OFFSET(75)] AS price_p75,
    APPROX_QUANTILES(IF(price_amount > 0, price_amount, NULL), 100)[OFFSET(95)] AS price_p95,
    MAX(price_amount) AS max_price_amount
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_products`
GROUP BY category_name;