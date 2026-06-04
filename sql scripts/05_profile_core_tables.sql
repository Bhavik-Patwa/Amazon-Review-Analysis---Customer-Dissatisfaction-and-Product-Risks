-- Profiling filtered reviews to check review coverage, missing values, ratings, helpful votes and text length
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.profile_reviews_overview` AS
SELECT
    category_name,
    COUNT(*) AS review_count,
    MIN(review_date) AS min_review_date,
    MAX(review_date) AS max_review_date,
    COUNTIF(parent_asin IS NULL) AS missing_parent_asin_count,
    COUNTIF(asin IS NULL) AS missing_asin_count,
    COUNTIF(user_id IS NULL) AS missing_user_id_count,
    COUNTIF(rating IS NULL) AS missing_rating_count,
    COUNTIF(review_text IS NULL) AS null_review_text_count,
    COUNTIF(TRIM(COALESCE(review_text, "")) = "") AS blank_review_text_count,
    COUNTIF(review_title IS NULL) AS null_review_title_count,
    COUNTIF(TRIM(COALESCE(review_title, "")) = "") AS blank_review_title_count,
    COUNTIF(review_timestamp_ms IS NULL) AS missing_review_timestamp_count,
    COUNTIF(review_date IS NULL) AS missing_review_date_count,
    COUNTIF(verified_purchase IS TRUE) AS verified_purchase_count,
    COUNTIF(verified_purchase IS FALSE) AS non_verified_purchase_count,
    COUNTIF(verified_purchase IS NULL) AS missing_verified_purchase_count,
    AVG(rating) AS average_rating,
    AVG(COALESCE(helpful_vote, 0)) AS average_helpful_vote,
    AVG(LENGTH(TRIM(COALESCE(review_text, "")))) AS average_review_text_length
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_reviews`
GROUP BY category_name;


-- Counting review volume by category and rating value
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.profile_rating_distribution` AS
SELECT
    category_name,
    rating,
    COUNT(*) AS review_count
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_reviews`
GROUP BY category_name, rating;


-- Checking review text quality, length, blank text, URLs and non-text content
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.profile_reviews_text_quality` AS
SELECT
    category_name,
    COUNT(*) AS review_count,
    COUNTIF(TRIM(COALESCE(review_text, "")) = "") AS blank_review_text_count,
    COUNTIF(LENGTH(TRIM(COALESCE(review_text, ""))) BETWEEN 1 AND 20) AS very_short_review_count,
    COUNTIF(LENGTH(TRIM(COALESCE(review_text, ""))) BETWEEN 21 AND 50) AS short_review_count,
    COUNTIF(LENGTH(TRIM(COALESCE(review_text, ""))) > 1000) AS long_review_count,
    COUNTIF(NOT REGEXP_CONTAINS(COALESCE(review_text, ""), "[A-Za-z]")) AS no_alphabetic_character_count,
    COUNTIF(REGEXP_CONTAINS(COALESCE(review_text, ""), r"https?://|www\\.")) AS url_present_count,
    AVG(LENGTH(TRIM(COALESCE(review_text, "")))) AS average_review_text_length,
    MAX(LENGTH(TRIM(COALESCE(review_text, "")))) AS max_review_text_length
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_reviews`
GROUP BY category_name;


-- Profiling filtered products for missing metadata, price issues, ratings and content fields
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.profile_products_quality` AS
SELECT
    category_name,
    COUNT(*) AS product_count,
    COUNTIF(parent_asin IS NULL) AS missing_parent_asin_count,
    COUNTIF(product_title IS NULL) AS null_product_title_count,
    COUNTIF(TRIM(COALESCE(product_title, "")) = "") AS blank_product_title_count,
    COUNTIF(main_category IS NULL) AS null_main_category_count,
    COUNTIF(TRIM(COALESCE(main_category, "")) = "") AS blank_main_category_count,
    COUNTIF(store IS NULL) AS null_store_count,
    COUNTIF(TRIM(COALESCE(store, "")) = "") AS blank_store_count,
    COUNTIF(price_amount IS NULL) AS missing_price_count,
    COUNTIF(price_amount <= 0) AS non_positive_price_count,
    COUNTIF(price_amount > 1000) AS high_price_count,
    COUNTIF(average_rating IS NULL) AS missing_average_rating_count,
    COUNTIF(rating_number IS NULL) AS missing_rating_number_count,
    COUNTIF(categories_json IS NULL OR categories_json = "null") AS missing_categories_json_count,
    COUNTIF(features_json IS NULL OR features_json = "null" OR features_json = "[]") AS missing_features_json_count,
    COUNTIF(description_json IS NULL OR description_json = "null" OR description_json = "[]") AS missing_description_json_count,
    COUNTIF(details_json IS NULL OR details_json = "null" OR details_json = "{}") AS missing_details_json_count,
    AVG(price_amount) AS average_price_amount,
    MAX(price_amount) AS max_price_amount
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_products`
GROUP BY category_name;


-- Checking whether filtered reviews still match valid filtered product records
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.profile_review_product_join_quality` AS
SELECT
    reviews.category_name,
    COUNT(*) AS review_count,
    COUNTIF(products.parent_asin IS NOT NULL) AS matched_product_count,
    COUNTIF(products.parent_asin IS NULL) AS unmatched_product_count,
    SAFE_DIVIDE(COUNTIF(products.parent_asin IS NOT NULL), COUNT(*)) AS matched_product_ratio,
    SAFE_DIVIDE(COUNTIF(products.parent_asin IS NULL), COUNT(*)) AS unmatched_product_ratio
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_reviews` AS reviews
LEFT JOIN `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_products` AS products
    ON reviews.category_name = products.category_name
   AND reviews.parent_asin = products.parent_asin
GROUP BY reviews.category_name;