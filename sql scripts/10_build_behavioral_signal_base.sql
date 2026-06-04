-- Classifying each category’s readiness for different business analysis use cases
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_category_use_case_readiness` AS
SELECT
    category_name,
    total_review_count,
    general_analysis_readiness_ratio,
    text_analysis_readiness_ratio,
    price_analysis_readiness_ratio,
    content_analysis_readiness_ratio,
    CASE
        WHEN general_analysis_readiness_ratio >= 0.98 THEN 'High'
        WHEN general_analysis_readiness_ratio >= 0.95 THEN 'Moderate'
        ELSE 'Low'
    END AS general_analysis_readiness_level,
    CASE
        WHEN text_analysis_readiness_ratio >= 0.80 THEN 'High'
        WHEN text_analysis_readiness_ratio >= 0.65 THEN 'Moderate'
        ELSE 'Low'
    END AS text_analysis_readiness_level,
    CASE
        WHEN price_analysis_readiness_ratio >= 0.70 THEN 'High'
        WHEN price_analysis_readiness_ratio >= 0.50 THEN 'Moderate'
        ELSE 'Low'
    END AS price_analysis_readiness_level,
    CASE
        WHEN content_analysis_readiness_ratio >= 0.80 THEN 'High'
        WHEN content_analysis_readiness_ratio >= 0.50 THEN 'Moderate'
        ELSE 'Low'
    END AS content_analysis_readiness_level
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_scope_data_readiness_summary`;


-- Calculating monthly category-level review behavior and dissatisfaction signals
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_monthly_category_signals` AS
SELECT
    category_name,
    review_month,
    COUNT(*) AS review_count,
    AVG(rating) AS average_rating,
    SAFE_DIVIDE(COUNTIF(rating IN (1, 2)), COUNT(*)) AS low_rating_ratio,
    SAFE_DIVIDE(COUNTIF(rating IN (4, 5)), COUNT(*)) AS high_rating_ratio,
    AVG(COALESCE(helpful_vote_clean, 0)) AS average_helpful_vote,
    SAFE_DIVIDE(COUNTIF(COALESCE(helpful_vote_clean, 0) > 0), COUNT(*)) AS helpful_vote_presence_ratio,
    SAFE_DIVIDE(COUNTIF(review_text_length >= 250), COUNT(*)) AS long_review_ratio,
    SAFE_DIVIDE(COUNTIF(verified_purchase IS TRUE), COUNT(*)) AS verified_purchase_ratio
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_general_analysis_scope`
GROUP BY category_name, review_month;


-- Calculating product-level risk signals from ratings, text, helpfulness and volume
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_product_risk_signals` AS
SELECT
    category_name,
    parent_asin,
    ANY_VALUE(product_title_clean) AS product_title,
    ANY_VALUE(store_clean) AS store_name,
    ANY_VALUE(price_amount) AS price_amount,
    COUNT(*) AS review_count,
    AVG(rating) AS average_rating,
    SAFE_DIVIDE(COUNTIF(rating IN (1, 2)), COUNT(*)) AS low_rating_ratio,
    SAFE_DIVIDE(COUNTIF(rating = 1), COUNT(*)) AS one_star_ratio,
    AVG(COALESCE(helpful_vote_clean, 0)) AS average_helpful_vote,
    SAFE_DIVIDE(COUNTIF(COALESCE(helpful_vote_clean, 0) > 0), COUNT(*)) AS helpful_vote_presence_ratio,
    AVG(review_text_length) AS average_review_text_length,
    SAFE_DIVIDE(COUNTIF(review_text_length >= 250), COUNT(*)) AS long_review_ratio,
    SAFE_DIVIDE(COUNTIF(verified_purchase IS TRUE), COUNT(*)) AS verified_purchase_ratio,
    COUNTIF(is_text_analysis_ready) AS text_analysis_ready_review_count
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_general_analysis_scope`
GROUP BY category_name, parent_asin
HAVING COUNT(*) >= 100;


-- Checking which monthly category periods are reliable enough for trend analysis
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_monthly_category_eligibility` AS
SELECT
    category_name,
    review_month,
    review_count,
    average_rating,
    low_rating_ratio,
    high_rating_ratio,
    average_helpful_vote,
    helpful_vote_presence_ratio,
    long_review_ratio,
    verified_purchase_ratio,
    CASE
        WHEN review_count >= 10000 THEN 'High'
        WHEN review_count >= 1000 THEN 'Moderate'
        WHEN review_count >= 250 THEN 'Low'
        ELSE 'Very low'
    END AS monthly_sample_size_band,
    review_count >= 1000 AS is_trend_analysis_eligible,
    review_count >= 10000 AS is_high_confidence_trend_period
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_monthly_category_signals`;


-- Checking which products have enough evidence for reliable product-level analysis
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_product_sample_eligibility` AS
SELECT
    category_name,
    parent_asin,
    product_title,
    store_name,
    price_amount,
    review_count,
    average_rating,
    low_rating_ratio,
    one_star_ratio,
    average_helpful_vote,
    helpful_vote_presence_ratio,
    average_review_text_length,
    long_review_ratio,
    verified_purchase_ratio,
    text_analysis_ready_review_count,
    SAFE_DIVIDE(text_analysis_ready_review_count, review_count) AS text_analysis_ready_ratio,
    CASE
        WHEN review_count >= 5000 THEN 'Very high'
        WHEN review_count >= 1000 THEN 'High'
        WHEN review_count >= 250 THEN 'Moderate'
        ELSE 'Low'
    END AS product_sample_size_band,
    review_count >= 250 AS is_product_analysis_eligible,
    review_count >= 1000 AS is_high_confidence_product_analysis_eligible
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_product_risk_signals`;


-- Summarizing trend coverage and monthly reliability for each category
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_category_month_coverage_summary` AS
SELECT
    category_name,
    COUNT(*) AS total_month_count,
    COUNTIF(review_count >= 1000) AS eligible_month_count,
    COUNTIF(review_count >= 10000) AS high_confidence_month_count,
    MIN(review_month) AS first_review_month,
    MAX(review_month) AS last_review_month
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_monthly_category_eligibility`
GROUP BY category_name;