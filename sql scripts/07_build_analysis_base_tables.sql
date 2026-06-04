-- Cleaning review records and creating the main review analysis base
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.reviews_analysis_base`
PARTITION BY review_month
CLUSTER BY category_name, parent_asin, asin AS

WITH standardized_reviews AS (
    SELECT
        category_name,
        SAFE_CAST(asin AS STRING) AS asin,
        SAFE_CAST(parent_asin AS STRING) AS parent_asin,
        SAFE_CAST(user_id AS STRING) AS user_id,
        SAFE_CAST(rating AS INT64) AS rating,
        SAFE_CAST(helpful_vote AS INT64) AS helpful_vote_original,
        CASE
            WHEN helpful_vote < 0 THEN NULL
            ELSE SAFE_CAST(helpful_vote AS INT64)
        END AS helpful_vote_clean,
        SAFE_CAST(verified_purchase AS BOOL) AS verified_purchase,
        NULLIF(REGEXP_REPLACE(TRIM(COALESCE(review_title, "")), r"\s+", " "), "") AS review_title_clean,
        NULLIF(REGEXP_REPLACE(TRIM(COALESCE(review_text, "")), r"\s+", " "), "") AS review_text_clean,
        SAFE_CAST(review_timestamp_ms AS INT64) AS review_timestamp_ms,
        review_timestamp_utc,
        review_date,
        review_month
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_reviews`
    WHERE rating BETWEEN 1 AND 5
),
ranked_reviews AS (
    SELECT
        *,
        COUNT(*) OVER (
            PARTITION BY
                category_name,
                parent_asin,
                user_id,
                rating,
                review_timestamp_ms,
                COALESCE(review_title_clean, ""),
                COALESCE(review_text_clean, "")
        ) AS duplicate_group_size,
        ROW_NUMBER() OVER (
            PARTITION BY
                category_name,
                parent_asin,
                user_id,
                rating,
                review_timestamp_ms,
                COALESCE(review_title_clean, ""),
                COALESCE(review_text_clean, "")
            ORDER BY asin
        ) AS duplicate_record_rank
    FROM standardized_reviews
)

SELECT
    category_name,
    asin,
    parent_asin,
    user_id,
    rating,
    helpful_vote_original,
    helpful_vote_clean,
    helpful_vote_original < 0 AS had_negative_helpful_vote,
    verified_purchase,
    review_title_clean,
    review_text_clean,
    review_timestamp_ms,
    review_timestamp_utc,
    review_date,
    review_month,
    LENGTH(COALESCE(review_title_clean, "")) AS review_title_length,
    LENGTH(COALESCE(review_text_clean, "")) AS review_text_length,
    review_text_clean IS NOT NULL AS has_non_blank_review_text,
    LENGTH(COALESCE(review_text_clean, "")) >= 30 AS has_minimum_text_length_30,
    LENGTH(COALESCE(review_text_clean, "")) >= 50 AS has_minimum_text_length_50,
    LENGTH(COALESCE(review_text_clean, "")) >= 100 AS has_minimum_text_length_100,
    REGEXP_CONTAINS(COALESCE(review_text_clean, ""), r"[A-Za-z]{3,}") AS has_alphabetic_word_pattern,
    REGEXP_CONTAINS(COALESCE(review_text_clean, ""), r"https?://|www\.") AS contains_url,
    REGEXP_CONTAINS(COALESCE(review_text_clean, ""), r"^[^A-Za-z0-9]*$") AS is_symbol_only_text,
    duplicate_group_size,
    duplicate_record_rank,
    duplicate_group_size > 1 AS is_duplicate_candidate,
    duplicate_record_rank = 1 AS is_primary_duplicate_record,
    (
        review_text_clean IS NOT NULL
        AND LENGTH(COALESCE(review_text_clean, "")) >= 30
        AND REGEXP_CONTAINS(COALESCE(review_text_clean, ""), r"[A-Za-z]{3,}")
    ) AS is_text_analysis_ready
FROM ranked_reviews;


-- Cleaning product metadata and creating the main product analysis base
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.products_analysis_base`
CLUSTER BY category_name, parent_asin AS

WITH price_reference AS (
    SELECT
        category_name,
        price_p95
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.profile_products_price_distribution`
),
standardized_products AS (
    SELECT
        category_name,
        SAFE_CAST(parent_asin AS STRING) AS parent_asin,
        NULLIF(REGEXP_REPLACE(TRIM(COALESCE(product_title, "")), r"\s+", " "), "") AS product_title_clean,
        NULLIF(REGEXP_REPLACE(TRIM(COALESCE(main_category, "")), r"\s+", " "), "") AS main_category_clean,
        NULLIF(REGEXP_REPLACE(TRIM(COALESCE(store, "")), r"\s+", " "), "") AS store_clean,
        SAFE_CAST(average_rating AS FLOAT64) AS average_rating,
        SAFE_CAST(rating_number AS INT64) AS rating_number,
        SAFE_CAST(price_amount AS FLOAT64) AS price_amount,
        categories_json,
        features_json,
        description_json,
        details_json
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.filtered_category_products`
)

SELECT
    products.category_name,
    products.parent_asin,
    products.product_title_clean,
    products.main_category_clean,
    products.store_clean,
    products.average_rating,
    products.rating_number,
    products.price_amount,
    products.categories_json,
    products.features_json,
    products.description_json,
    products.details_json,
    products.product_title_clean IS NOT NULL AS has_usable_product_title,
    products.main_category_clean IS NOT NULL AS has_usable_main_category,
    products.store_clean IS NOT NULL AS has_usable_store,
    products.price_amount IS NOT NULL AND products.price_amount > 0 AS has_usable_price,
    products.price_amount <= 0 AS has_non_positive_price,
    COALESCE(products.price_amount > price_reference.price_p95, FALSE) AS price_above_p95_flag,
    products.features_json IS NOT NULL AND products.features_json NOT IN ("null", "[]") AS has_usable_features,
    products.description_json IS NOT NULL AND products.description_json NOT IN ("null", "[]") AS has_usable_description,
    products.details_json IS NOT NULL AND products.details_json NOT IN ("null", "{}") AS has_usable_details
FROM standardized_products AS products
LEFT JOIN price_reference
    ON products.category_name = price_reference.category_name;


-- Combining cleaned reviews with product details for downstream analysis
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_analysis_base`
PARTITION BY review_month
CLUSTER BY category_name, parent_asin, asin AS

SELECT
    reviews.category_name,
    reviews.asin,
    reviews.parent_asin,
    reviews.user_id,
    reviews.rating,
    reviews.helpful_vote_original,
    reviews.helpful_vote_clean,
    reviews.had_negative_helpful_vote,
    reviews.verified_purchase,
    reviews.review_title_clean,
    reviews.review_text_clean,
    reviews.review_timestamp_ms,
    reviews.review_timestamp_utc,
    reviews.review_date,
    reviews.review_month,
    reviews.review_title_length,
    reviews.review_text_length,
    reviews.has_non_blank_review_text,
    reviews.has_minimum_text_length_30,
    reviews.has_minimum_text_length_50,
    reviews.has_minimum_text_length_100,
    reviews.has_alphabetic_word_pattern,
    reviews.contains_url,
    reviews.is_symbol_only_text,
    reviews.duplicate_group_size,
    reviews.duplicate_record_rank,
    reviews.is_duplicate_candidate,
    reviews.is_primary_duplicate_record,
    reviews.is_text_analysis_ready,
    products.product_title_clean,
    products.main_category_clean,
    products.store_clean,
    products.average_rating AS product_average_rating,
    products.rating_number AS product_rating_number,
    products.price_amount,
    products.has_usable_product_title,
    products.has_usable_main_category,
    products.has_usable_store,
    products.has_usable_price,
    products.has_non_positive_price,
    products.price_above_p95_flag,
    products.has_usable_features,
    products.has_usable_description,
    products.has_usable_details
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.reviews_analysis_base` AS reviews
LEFT JOIN `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.products_analysis_base` AS products
    ON reviews.category_name = products.category_name
   AND reviews.parent_asin = products.parent_asin;