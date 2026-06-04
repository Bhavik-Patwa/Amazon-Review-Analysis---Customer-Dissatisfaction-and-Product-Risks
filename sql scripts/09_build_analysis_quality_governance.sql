-- Summarizing why reviews are being included or excluded from analysis
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_scope_exclusion_summary` AS
SELECT
    category_name,
    COUNT(*) AS total_review_count,
    COUNTIF(is_primary_duplicate_record = FALSE) AS excluded_duplicate_review_count,
    COUNTIF(has_non_blank_review_text = FALSE) AS excluded_blank_text_review_count,
    COUNTIF(is_text_analysis_ready = FALSE) AS excluded_text_analysis_review_count,
    COUNTIF(has_usable_price = FALSE) AS excluded_price_analysis_review_count,
    COUNTIF(has_usable_product_title = FALSE) AS excluded_title_analysis_review_count,
    COUNTIF(has_usable_store = FALSE) AS excluded_store_analysis_review_count,
    COUNTIF(
        has_usable_features = FALSE
        AND has_usable_description = FALSE
        AND has_usable_details = FALSE
    ) AS excluded_content_analysis_review_count,
    COUNTIF(is_primary_duplicate_record = TRUE) AS included_general_analysis_review_count,
    COUNTIF(
        is_primary_duplicate_record = TRUE
        AND is_text_analysis_ready = TRUE
    ) AS included_text_analysis_review_count,
    COUNTIF(
        is_primary_duplicate_record = TRUE
        AND has_usable_price = TRUE
    ) AS included_price_analysis_review_count,
    COUNTIF(
        is_primary_duplicate_record = TRUE
        AND has_usable_product_title = TRUE
        AND (
            has_usable_features = TRUE
            OR has_usable_description = TRUE
            OR has_usable_details = TRUE
        )
    ) AS included_content_analysis_review_count
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_analysis_base`
GROUP BY category_name;


-- Listing detailed exclusion reasons for transparency and auditability
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_scope_exclusion_details` AS
SELECT
    category_name,
    exclusion_reason,
    COUNT(*) AS review_count
FROM (
    SELECT
        category_name,
        'Duplicate review record' AS exclusion_reason
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_analysis_base`
    WHERE is_primary_duplicate_record = FALSE

    UNION ALL

    SELECT
        category_name,
        'Blank review text'
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_analysis_base`
    WHERE has_non_blank_review_text = FALSE

    UNION ALL

    SELECT
        category_name,
        'Not ready for text analysis'
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_analysis_base`
    WHERE is_text_analysis_ready = FALSE

    UNION ALL

    SELECT
        category_name,
        'Missing usable price'
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_analysis_base`
    WHERE has_usable_price = FALSE

    UNION ALL

    SELECT
        category_name,
        'Missing usable product title'
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_analysis_base`
    WHERE has_usable_product_title = FALSE

    UNION ALL

    SELECT
        category_name,
        'Missing usable store'
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_analysis_base`
    WHERE has_usable_store = FALSE

    UNION ALL

    SELECT
        category_name,
        'Missing usable content metadata'
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_analysis_base`
    WHERE has_usable_features = FALSE
      AND has_usable_description = FALSE
      AND has_usable_details = FALSE
)
GROUP BY category_name, exclusion_reason;


-- Calculating category-level readiness for general, text, price and content analysis
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_scope_data_readiness_summary` AS
SELECT
    category_name,
    COUNT(*) AS total_review_count,
    SAFE_DIVIDE(
        COUNTIF(is_primary_duplicate_record = TRUE),
        COUNT(*)
    ) AS general_analysis_readiness_ratio,
    SAFE_DIVIDE(
        COUNTIF(
            is_primary_duplicate_record = TRUE
            AND is_text_analysis_ready = TRUE
        ),
        COUNT(*)
    ) AS text_analysis_readiness_ratio,
    SAFE_DIVIDE(
        COUNTIF(
            is_primary_duplicate_record = TRUE
            AND has_usable_price = TRUE
        ),
        COUNT(*)
    ) AS price_analysis_readiness_ratio,
    SAFE_DIVIDE(
        COUNTIF(
            is_primary_duplicate_record = TRUE
            AND has_usable_product_title = TRUE
            AND (
                has_usable_features = TRUE
                OR has_usable_description = TRUE
                OR has_usable_details = TRUE
            )
        ),
        COUNT(*)
    ) AS content_analysis_readiness_ratio
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_analysis_base`
GROUP BY category_name;