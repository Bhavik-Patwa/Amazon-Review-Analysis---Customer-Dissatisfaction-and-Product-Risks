-- Summarizing how much data is usable for each type of analysis
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_scope_category_summary` AS
SELECT
    category_name,
    COUNT(*) AS total_review_count,
    COUNTIF(is_primary_duplicate_record) AS primary_duplicate_review_count,
    COUNTIF(is_text_analysis_ready AND is_primary_duplicate_record) AS text_analysis_ready_review_count,
    COUNTIF(has_usable_price AND is_primary_duplicate_record) AS price_analysis_ready_review_count,
    COUNTIF(has_usable_product_title AND is_primary_duplicate_record) AS title_analysis_ready_review_count,
    COUNTIF(has_usable_store AND is_primary_duplicate_record) AS store_analysis_ready_review_count,
    COUNTIF(has_usable_features AND is_primary_duplicate_record) AS features_analysis_ready_review_count,
    COUNTIF(has_usable_description AND is_primary_duplicate_record) AS description_analysis_ready_review_count,
    SAFE_DIVIDE(
        COUNTIF(is_primary_duplicate_record),
        COUNT(*)
    ) AS primary_duplicate_review_ratio,
    SAFE_DIVIDE(
        COUNTIF(is_text_analysis_ready AND is_primary_duplicate_record),
        COUNT(*)
    ) AS text_analysis_ready_ratio,
    SAFE_DIVIDE(
        COUNTIF(has_usable_price AND is_primary_duplicate_record),
        COUNT(*)
    ) AS price_analysis_ready_ratio,
    SAFE_DIVIDE(
        COUNTIF(has_usable_product_title AND is_primary_duplicate_record),
        COUNT(*)
    ) AS title_analysis_ready_ratio,
    SAFE_DIVIDE(
        COUNTIF(has_usable_store AND is_primary_duplicate_record),
        COUNT(*)
    ) AS store_analysis_ready_ratio,
    SAFE_DIVIDE(
        COUNTIF(has_usable_features AND is_primary_duplicate_record),
        COUNT(*)
    ) AS features_analysis_ready_ratio,
    SAFE_DIVIDE(
        COUNTIF(has_usable_description AND is_primary_duplicate_record),
        COUNT(*)
    ) AS description_analysis_ready_ratio
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_analysis_base`
GROUP BY category_name;


-- Creating the general analysis dataset after removing duplicate review records
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_general_analysis_scope`
PARTITION BY review_month
CLUSTER BY category_name, parent_asin, asin AS

SELECT *
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_analysis_base`
WHERE is_primary_duplicate_record = TRUE;


-- Creating the review-text analysis dataset using only text-ready reviews
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_text_analysis_scope`
PARTITION BY review_month
CLUSTER BY category_name, parent_asin, asin AS

SELECT *
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_analysis_base`
WHERE is_primary_duplicate_record = TRUE
  AND is_text_analysis_ready = TRUE;


-- Creating the price analysis dataset using only reviews with usable product prices
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_price_analysis_scope`
PARTITION BY review_month
CLUSTER BY category_name, parent_asin, asin AS

SELECT *
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_analysis_base`
WHERE is_primary_duplicate_record = TRUE
  AND has_usable_price = TRUE;


-- Creating the content analysis dataset using products with usable metadata
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_content_analysis_scope`
PARTITION BY review_month
CLUSTER BY category_name, parent_asin, asin AS

SELECT *
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_analysis_base`
WHERE is_primary_duplicate_record = TRUE
  AND has_usable_product_title = TRUE
  AND (
      has_usable_features = TRUE
      OR has_usable_description = TRUE
      OR has_usable_details = TRUE
  );