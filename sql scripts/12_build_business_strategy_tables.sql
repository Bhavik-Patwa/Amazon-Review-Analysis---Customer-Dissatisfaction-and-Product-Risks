-- Summarizing category coverage and reliability across general, text, price and content analysis scopes
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_coverage_summary` AS
SELECT
    readiness.category_name,
    readiness.total_review_count,
    exclusions.included_general_analysis_review_count AS general_analysis_review_count,
    exclusions.included_text_analysis_review_count AS text_analysis_review_count,
    exclusions.included_price_analysis_review_count AS price_analysis_review_count,
    exclusions.included_content_analysis_review_count AS content_analysis_review_count,
    SAFE_DIVIDE(
        exclusions.included_general_analysis_review_count,
        readiness.total_review_count
    ) AS general_analysis_coverage_ratio,
    SAFE_DIVIDE(
        exclusions.included_text_analysis_review_count,
        readiness.total_review_count
    ) AS text_analysis_coverage_ratio,
    SAFE_DIVIDE(
        exclusions.included_price_analysis_review_count,
        readiness.total_review_count
    ) AS price_analysis_coverage_ratio,
    SAFE_DIVIDE(
        exclusions.included_content_analysis_review_count,
        readiness.total_review_count
    ) AS content_analysis_coverage_ratio,
    coverage.total_month_count,
    coverage.eligible_month_count,
    coverage.high_confidence_month_count,
    coverage.first_review_month,
    coverage.last_review_month,
    CASE
        WHEN SAFE_DIVIDE(exclusions.included_general_analysis_review_count, readiness.total_review_count) >= 0.98 THEN 'Strong'
        WHEN SAFE_DIVIDE(exclusions.included_general_analysis_review_count, readiness.total_review_count) >= 0.95 THEN 'Usable'
        ELSE 'Limited'
    END AS general_analysis_coverage_level,
    CASE
        WHEN SAFE_DIVIDE(exclusions.included_text_analysis_review_count, readiness.total_review_count) >= 0.80 THEN 'Strong'
        WHEN SAFE_DIVIDE(exclusions.included_text_analysis_review_count, readiness.total_review_count) >= 0.65 THEN 'Usable'
        ELSE 'Limited'
    END AS text_analysis_coverage_level,
    CASE
        WHEN SAFE_DIVIDE(exclusions.included_price_analysis_review_count, readiness.total_review_count) >= 0.70 THEN 'Strong'
        WHEN SAFE_DIVIDE(exclusions.included_price_analysis_review_count, readiness.total_review_count) >= 0.50 THEN 'Usable'
        ELSE 'Limited'
    END AS price_analysis_coverage_level,
    CASE
        WHEN SAFE_DIVIDE(exclusions.included_content_analysis_review_count, readiness.total_review_count) >= 0.80 THEN 'Strong'
        WHEN SAFE_DIVIDE(exclusions.included_content_analysis_review_count, readiness.total_review_count) >= 0.50 THEN 'Usable'
        ELSE 'Limited'
    END AS content_analysis_coverage_level
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_category_use_case_readiness` AS readiness
LEFT JOIN `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_scope_exclusion_summary` AS exclusions
    ON readiness.category_name = exclusions.category_name
LEFT JOIN `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_category_month_coverage_summary` AS coverage
    ON readiness.category_name = coverage.category_name;


-- Combining category feedback, dissatisfaction, review behavior and coverage metrics into a business-ready summary
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_feedback_summary` AS
WITH category_level_metrics AS (
    SELECT
        category_name,
        COUNT(*) AS analysis_review_count,
        AVG(rating) AS average_rating,
        AVG(COALESCE(helpful_vote_clean, 0)) AS average_helpful_vote,
        SAFE_DIVIDE(COUNTIF(COALESCE(helpful_vote_clean, 0) > 0), COUNT(*)) AS helpful_vote_presence_ratio,
        AVG(review_text_length) AS average_review_text_length,
        SAFE_DIVIDE(COUNTIF(review_text_length >= 250), COUNT(*)) AS long_review_ratio,
        SAFE_DIVIDE(COUNTIF(verified_purchase IS TRUE), COUNT(*)) AS verified_purchase_ratio
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_general_analysis_scope`
    GROUP BY category_name
)

SELECT
    metrics.category_name,
    metrics.analysis_review_count,
    metrics.average_rating,
    feedback.extreme_rating_ratio,
    feedback.five_star_ratio,
    feedback.one_star_ratio,
    feedback.low_rating_ratio,
    feedback.high_rating_ratio,
    metrics.average_helpful_vote,
    metrics.helpful_vote_presence_ratio,
    metrics.average_review_text_length,
    metrics.long_review_ratio,
    metrics.verified_purchase_ratio,
    coverage.general_analysis_coverage_ratio,
    coverage.text_analysis_coverage_ratio,
    coverage.price_analysis_coverage_ratio,
    coverage.content_analysis_coverage_ratio,
    coverage.total_month_count,
    coverage.eligible_month_count,
    coverage.high_confidence_month_count,
    coverage.general_analysis_coverage_level,
    coverage.text_analysis_coverage_level,
    coverage.price_analysis_coverage_level,
    coverage.content_analysis_coverage_level
FROM category_level_metrics AS metrics
LEFT JOIN `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_category_polarization_summary` AS feedback
    ON metrics.category_name = feedback.category_name
LEFT JOIN `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_coverage_summary` AS coverage
    ON metrics.category_name = coverage.category_name;


-- Assigning product priority levels using risk scores, sample strength, metadata quality and business interpretation rules
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.product_issue_priority` AS
WITH eligible_products AS (
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
        text_analysis_ready_ratio,
        product_sample_size_band,
        is_product_analysis_eligible,
        is_high_confidence_product_analysis_eligible
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_product_sample_eligibility`
    WHERE is_product_analysis_eligible = TRUE
),
category_peer_thresholds AS (
    SELECT
        category_name,
        APPROX_QUANTILES(review_count, 100)[OFFSET(75)] AS review_count_p75,
        APPROX_QUANTILES(low_rating_ratio, 100)[OFFSET(75)] AS low_rating_ratio_p75,
        APPROX_QUANTILES(low_rating_ratio, 100)[OFFSET(90)] AS low_rating_ratio_p90,
        APPROX_QUANTILES(one_star_ratio, 100)[OFFSET(75)] AS one_star_ratio_p75,
        APPROX_QUANTILES(helpful_vote_presence_ratio, 100)[OFFSET(75)] AS helpful_vote_presence_ratio_p75,
        APPROX_QUANTILES(average_rating, 100)[OFFSET(10)] AS average_rating_p10,
        APPROX_QUANTILES(average_rating, 100)[OFFSET(25)] AS average_rating_p25
    FROM eligible_products
    GROUP BY category_name
),
category_coverage AS (
    SELECT
        category_name,
        content_analysis_coverage_level
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_coverage_summary`
)

SELECT
    products.category_name,
    products.parent_asin,
    products.product_title,
    COALESCE(products.product_title, CONCAT('ASIN ', products.parent_asin)) AS product_display_name,
    products.store_name,
    COALESCE(products.store_name, 'Unknown store') AS store_display_name,
    products.price_amount,
    products.review_count,
    products.average_rating,
    products.low_rating_ratio,
    products.one_star_ratio,
    products.average_helpful_vote,
    products.helpful_vote_presence_ratio,
    products.average_review_text_length,
    products.long_review_ratio,
    products.verified_purchase_ratio,
    products.text_analysis_ready_review_count,
    products.text_analysis_ready_ratio,
    products.product_sample_size_band,
    products.is_product_analysis_eligible,
    products.is_high_confidence_product_analysis_eligible,
    CASE
        WHEN products.is_high_confidence_product_analysis_eligible = TRUE
         AND products.review_count >= thresholds.review_count_p75
         AND products.low_rating_ratio >= thresholds.low_rating_ratio_p90
         AND (
             products.one_star_ratio >= thresholds.one_star_ratio_p75
             OR products.average_rating <= thresholds.average_rating_p10
         )
         AND products.helpful_vote_presence_ratio >= thresholds.helpful_vote_presence_ratio_p75
        THEN 'Highest priority'
        WHEN products.is_product_analysis_eligible = TRUE
         AND products.low_rating_ratio >= thresholds.low_rating_ratio_p75
         AND products.average_rating <= thresholds.average_rating_p25
        THEN 'Priority review'
        ELSE 'Monitor'
    END AS issue_priority_level,
    CASE
        WHEN products.is_high_confidence_product_analysis_eligible = TRUE
         AND products.text_analysis_ready_ratio >= 0.80
         AND products.product_title IS NOT NULL
        THEN 'High'
        WHEN products.is_product_analysis_eligible = TRUE
        THEN 'Moderate'
        ELSE 'Low'
    END AS evidence_confidence_level,
    CASE
        WHEN products.product_title IS NOT NULL
         AND coverage.content_analysis_coverage_level IN ('Strong', 'Usable')
        THEN 'High'
        WHEN products.product_title IS NOT NULL
        THEN 'Moderate'
        ELSE 'Low'
    END AS product_identification_quality,
    CASE
        WHEN coverage.content_analysis_coverage_level = 'Limited'
        THEN 'Category metadata support is limited, so product-level interpretation should be used cautiously'
        WHEN products.product_title IS NULL
        THEN 'Product identifier is incomplete, so business interpretation should be used cautiously'
        ELSE 'No major product identification limitation'
    END AS business_use_caution,
    CASE
        WHEN products.is_high_confidence_product_analysis_eligible = TRUE
         AND products.review_count >= thresholds.review_count_p75
         AND products.low_rating_ratio >= thresholds.low_rating_ratio_p90
         AND products.helpful_vote_presence_ratio >= thresholds.helpful_vote_presence_ratio_p75
        THEN 'High-volume product with unusually high dissatisfaction and engaged feedback relative to category peers'
        WHEN products.is_product_analysis_eligible = TRUE
         AND products.low_rating_ratio >= thresholds.low_rating_ratio_p75
         AND products.average_rating <= thresholds.average_rating_p25
        THEN 'Product underperforming against category peers on dissatisfaction and average rating'
        ELSE 'Monitor only'
    END AS business_basis,
    'Compared only against products in the same category' AS comparison_scope
FROM eligible_products AS products
INNER JOIN category_peer_thresholds AS thresholds
    ON products.category_name = thresholds.category_name
LEFT JOIN category_coverage AS coverage
    ON products.category_name = coverage.category_name;


-- Preparing price-band behavior summaries with ordered bands and interpretation strength labels
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_price_behavior_summary` AS
SELECT
    pricing.category_name,
    pricing.price_band,
    CASE
        WHEN pricing.price_band = 'Budget' THEN 1
        WHEN pricing.price_band = 'Lower mid' THEN 2
        WHEN pricing.price_band = 'Upper mid' THEN 3
        WHEN pricing.price_band = 'Premium' THEN 4
        WHEN pricing.price_band = 'Very premium' THEN 5
        ELSE 99
    END AS price_band_order,
    pricing.review_count,
    pricing.average_rating,
    pricing.low_rating_ratio,
    pricing.one_star_ratio,
    pricing.average_helpful_vote,
    pricing.helpful_vote_presence_ratio,
    pricing.average_review_text_length,
    pricing.long_review_ratio,
    pricing.verified_purchase_ratio,
    coverage.price_analysis_coverage_ratio,
    coverage.price_analysis_coverage_level,
    CASE
        WHEN coverage.price_analysis_coverage_ratio >= 0.70 THEN 'Strong'
        WHEN coverage.price_analysis_coverage_ratio >= 0.50 THEN 'Usable with caution'
        ELSE 'Limited'
    END AS price_interpretation_strength
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_price_band_summary` AS pricing
LEFT JOIN `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_coverage_summary` AS coverage
    ON pricing.category_name = coverage.category_name;


-- Summarizing review trust behavior by verification status and rating segment
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_review_trust_summary` AS
WITH grouped_reviews AS (
    SELECT
        category_name,
        verified_purchase,
        CASE
            WHEN rating IN (1, 2) THEN 'Low rating'
            WHEN rating = 3 THEN 'Mid rating'
            WHEN rating IN (4, 5) THEN 'High rating'
            ELSE 'Other'
        END AS rating_group,
        SUM(review_count) AS review_count,
        SAFE_DIVIDE(SUM(review_count * average_helpful_vote), SUM(review_count)) AS average_helpful_vote,
        SAFE_DIVIDE(SUM(review_count * helpful_vote_presence_ratio), SUM(review_count)) AS helpful_vote_presence_ratio,
        SAFE_DIVIDE(SUM(review_count * average_review_text_length), SUM(review_count)) AS average_review_text_length,
        SAFE_DIVIDE(SUM(review_count * long_review_ratio), SUM(review_count)) AS long_review_ratio
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_verified_rating_behavior`
    GROUP BY
        category_name,
        verified_purchase,
        rating_group
)

SELECT
    category_name,
    verified_purchase,
    rating_group,
    review_count,
    average_helpful_vote,
    helpful_vote_presence_ratio,
    average_review_text_length,
    long_review_ratio,
    CASE
        WHEN review_count >= 100000 THEN 'High'
        WHEN review_count >= 10000 THEN 'Moderate'
        ELSE 'Limited'
    END AS segment_evidence_level
FROM grouped_reviews;


-- Measuring category metadata readiness across titles, stores, features, descriptions and detailed product information
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_metadata_readiness_summary` AS
WITH review_weighted_summary AS (
    SELECT
        base.category_name,
        COUNT(*) AS total_review_count,
        COUNTIF(base.has_usable_product_title) AS title_analysis_ready_review_count,
        COUNTIF(base.has_usable_store) AS store_analysis_ready_review_count,
        COUNTIF(base.has_usable_features) AS features_analysis_ready_review_count,
        COUNTIF(base.has_usable_description) AS description_analysis_ready_review_count,
        COUNTIF(base.has_usable_details) AS details_analysis_ready_review_count,
        COUNTIF(
            base.has_usable_product_title
            AND (
                base.has_usable_features
                OR base.has_usable_description
                OR base.has_usable_details
            )
        ) AS minimum_content_support_review_count,
        COUNTIF(
            base.has_usable_product_title
            AND (
                base.has_usable_features
                OR base.has_usable_description
            )
        ) AS rich_content_support_review_count
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_general_analysis_scope` AS base
    GROUP BY base.category_name
),
product_weighted_summary AS (
    SELECT
        products.category_name,
        COUNT(*) AS total_product_count,
        COUNTIF(products.has_usable_product_title) AS title_analysis_ready_product_count,
        COUNTIF(products.has_usable_store) AS store_analysis_ready_product_count,
        COUNTIF(products.has_usable_features) AS features_analysis_ready_product_count,
        COUNTIF(products.has_usable_description) AS description_analysis_ready_product_count,
        COUNTIF(products.has_usable_details) AS details_analysis_ready_product_count,
        COUNTIF(
            products.has_usable_product_title
            AND (
                products.has_usable_features
                OR products.has_usable_description
                OR products.has_usable_details
            )
        ) AS minimum_content_support_product_count,
        COUNTIF(
            products.has_usable_product_title
            AND (
                products.has_usable_features
                OR products.has_usable_description
            )
        ) AS rich_content_support_product_count
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.products_analysis_base` AS products
    GROUP BY products.category_name
),
coverage AS (
    SELECT
        category_name,
        content_analysis_coverage_ratio,
        content_analysis_coverage_level
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_coverage_summary`
)

SELECT
    reviews.category_name,
    reviews.total_review_count,
    products.total_product_count,

    reviews.title_analysis_ready_review_count,
    reviews.store_analysis_ready_review_count,
    reviews.features_analysis_ready_review_count,
    reviews.description_analysis_ready_review_count,
    reviews.details_analysis_ready_review_count,
    reviews.minimum_content_support_review_count,
    reviews.rich_content_support_review_count,

    products.title_analysis_ready_product_count,
    products.store_analysis_ready_product_count,
    products.features_analysis_ready_product_count,
    products.description_analysis_ready_product_count,
    products.details_analysis_ready_product_count,
    products.minimum_content_support_product_count,
    products.rich_content_support_product_count,

    SAFE_DIVIDE(reviews.title_analysis_ready_review_count, reviews.total_review_count) AS title_analysis_ready_review_ratio,
    SAFE_DIVIDE(reviews.store_analysis_ready_review_count, reviews.total_review_count) AS store_analysis_ready_review_ratio,
    SAFE_DIVIDE(reviews.features_analysis_ready_review_count, reviews.total_review_count) AS features_analysis_ready_review_ratio,
    SAFE_DIVIDE(reviews.description_analysis_ready_review_count, reviews.total_review_count) AS description_analysis_ready_review_ratio,
    SAFE_DIVIDE(reviews.details_analysis_ready_review_count, reviews.total_review_count) AS details_analysis_ready_review_ratio,
    SAFE_DIVIDE(reviews.minimum_content_support_review_count, reviews.total_review_count) AS minimum_content_support_review_ratio,
    SAFE_DIVIDE(reviews.rich_content_support_review_count, reviews.total_review_count) AS rich_content_support_review_ratio,

    SAFE_DIVIDE(products.title_analysis_ready_product_count, products.total_product_count) AS title_analysis_ready_product_ratio,
    SAFE_DIVIDE(products.store_analysis_ready_product_count, products.total_product_count) AS store_analysis_ready_product_ratio,
    SAFE_DIVIDE(products.features_analysis_ready_product_count, products.total_product_count) AS features_analysis_ready_product_ratio,
    SAFE_DIVIDE(products.description_analysis_ready_product_count, products.total_product_count) AS description_analysis_ready_product_ratio,
    SAFE_DIVIDE(products.details_analysis_ready_product_count, products.total_product_count) AS details_analysis_ready_product_ratio,
    SAFE_DIVIDE(products.minimum_content_support_product_count, products.total_product_count) AS minimum_content_support_product_ratio,
    SAFE_DIVIDE(products.rich_content_support_product_count, products.total_product_count) AS rich_content_support_product_ratio,

    reviews.total_review_count - reviews.title_analysis_ready_review_count AS excluded_title_analysis_review_count,
    reviews.total_review_count - reviews.store_analysis_ready_review_count AS excluded_store_analysis_review_count,
    reviews.total_review_count - reviews.minimum_content_support_review_count AS excluded_minimum_content_support_review_count,
    reviews.total_review_count - reviews.rich_content_support_review_count AS excluded_rich_content_support_review_count,

    products.total_product_count - products.title_analysis_ready_product_count AS excluded_title_analysis_product_count,
    products.total_product_count - products.store_analysis_ready_product_count AS excluded_store_analysis_product_count,
    products.total_product_count - products.minimum_content_support_product_count AS excluded_minimum_content_support_product_count,
    products.total_product_count - products.rich_content_support_product_count AS excluded_rich_content_support_product_count,

    coverage.content_analysis_coverage_ratio,
    coverage.content_analysis_coverage_level
FROM review_weighted_summary AS reviews
LEFT JOIN product_weighted_summary AS products
    ON reviews.category_name = products.category_name
LEFT JOIN coverage
    ON reviews.category_name = coverage.category_name;


-- Identifying products where customer dissatisfaction and weak content support may require product-page improvement
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.product_content_gap_priority` AS
WITH aggregated_products AS (
    SELECT
        base.category_name,
        base.parent_asin,
        ANY_VALUE(base.product_title_clean) AS product_title,
        ANY_VALUE(base.store_clean) AS store_name,
        ANY_VALUE(base.price_amount) AS price_amount,
        COUNT(*) AS review_count,
        AVG(base.rating) AS average_rating,
        SAFE_DIVIDE(COUNTIF(base.rating IN (1, 2)), COUNT(*)) AS low_rating_ratio,
        AVG(COALESCE(base.helpful_vote_clean, 0)) AS average_helpful_vote,
        SAFE_DIVIDE(COUNTIF(COALESCE(base.helpful_vote_clean, 0) > 0), COUNT(*)) AS helpful_vote_presence_ratio,
        SAFE_DIVIDE(COUNTIF(base.is_text_analysis_ready), COUNT(*)) AS text_analysis_ready_ratio,
        LOGICAL_OR(base.has_usable_product_title) AS has_product_title,
        LOGICAL_OR(base.has_usable_store) AS has_store,
        LOGICAL_OR(base.has_usable_features) AS has_features,
        LOGICAL_OR(base.has_usable_description) AS has_description,
        LOGICAL_OR(base.has_usable_details) AS has_details
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_general_analysis_scope` AS base
    GROUP BY
        base.category_name,
        base.parent_asin
),
category_coverage AS (
    SELECT
        category_name,
        content_analysis_coverage_level
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_coverage_summary`
),
category_metadata_baselines AS (
    SELECT
        category_name,
        rich_content_support_product_ratio,
        minimum_content_support_product_ratio,
        title_analysis_ready_product_ratio
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_metadata_readiness_summary`
),
eligible_products AS (
    SELECT
        products.*,
        coverage.content_analysis_coverage_level,
        baselines.rich_content_support_product_ratio,
        baselines.minimum_content_support_product_ratio,
        baselines.title_analysis_ready_product_ratio,
        (
            products.has_features
            OR products.has_description
            OR products.has_details
        ) AS has_any_content_metadata,
        (
            products.has_features
            OR products.has_description
        ) AS has_rich_content_metadata,
        (
            products.has_product_title
            AND (
                products.has_features
                OR products.has_description
                OR products.has_details
            )
        ) AS has_minimum_content_support,
        (
            products.has_product_title
            AND (
                products.has_features
                OR products.has_description
            )
        ) AS has_rich_content_support
    FROM aggregated_products AS products
LEFT JOIN category_coverage AS coverage
    ON products.category_name = coverage.category_name
LEFT JOIN category_metadata_baselines AS baselines
    ON products.category_name = baselines.category_name
),
category_peer_thresholds AS (
    SELECT
        category_name,
        APPROX_QUANTILES(review_count, 100)[OFFSET(75)] AS review_count_p75,
        APPROX_QUANTILES(low_rating_ratio, 100)[OFFSET(75)] AS low_rating_ratio_p75,
        APPROX_QUANTILES(low_rating_ratio, 100)[OFFSET(90)] AS low_rating_ratio_p90,
        APPROX_QUANTILES(helpful_vote_presence_ratio, 100)[OFFSET(75)] AS helpful_vote_presence_ratio_p75,
        APPROX_QUANTILES(average_rating, 100)[OFFSET(25)] AS average_rating_p25
    FROM eligible_products
    WHERE content_analysis_coverage_level IN ('Strong', 'Usable')
    GROUP BY category_name
)

SELECT
    products.category_name,
    products.parent_asin,
    products.product_title,
    COALESCE(products.product_title, CONCAT('ASIN ', products.parent_asin)) AS product_display_name,
    products.store_name,
    COALESCE(products.store_name, 'Unknown store') AS store_display_name,
    products.price_amount,
    products.review_count,
    products.average_rating,
    products.low_rating_ratio,
    products.average_helpful_vote,
    products.helpful_vote_presence_ratio,
    products.text_analysis_ready_ratio,
    products.has_product_title,
    products.has_store,
    products.has_features,
    products.has_description,
    products.has_details,
    products.has_any_content_metadata,
    products.has_rich_content_metadata,
    products.has_minimum_content_support,
    products.has_rich_content_support,
    products.content_analysis_coverage_level,
    products.title_analysis_ready_product_ratio AS category_title_support_product_ratio,
    products.minimum_content_support_product_ratio AS category_minimum_content_support_product_ratio,
    products.rich_content_support_product_ratio AS category_rich_content_support_product_ratio,
    CASE
        WHEN products.has_product_title = FALSE THEN 'Missing product title'
        WHEN products.has_minimum_content_support = FALSE THEN 'Missing minimum content support'
        WHEN products.has_rich_content_support = FALSE THEN 'Missing rich content support'
        ELSE 'No major metadata gap'
    END AS metadata_gap_type,
    CASE
        WHEN products.content_analysis_coverage_level = 'Limited' THEN 'Use with caution'
        WHEN products.has_product_title = FALSE THEN 'Use with caution'
        WHEN products.review_count >= 250
         AND products.review_count >= thresholds.review_count_p75
         AND products.low_rating_ratio >= thresholds.low_rating_ratio_p90
         AND products.helpful_vote_presence_ratio >= thresholds.helpful_vote_presence_ratio_p75
         AND products.text_analysis_ready_ratio >= 0.80
         AND products.has_rich_content_support = FALSE
         AND products.rich_content_support_product_ratio >= 0.70
        THEN 'Highest priority'
        WHEN products.review_count >= 100
         AND products.low_rating_ratio >= thresholds.low_rating_ratio_p75
         AND products.average_rating <= thresholds.average_rating_p25
         AND (
             products.has_minimum_content_support = FALSE
             OR (
                 products.has_rich_content_support = FALSE
                 AND products.rich_content_support_product_ratio >= 0.70
             )
         )
        THEN 'Priority review'
        ELSE 'Monitor'
    END AS metadata_improvement_priority,
    CASE
        WHEN products.content_analysis_coverage_level = 'Limited' THEN 'Low'
        WHEN products.review_count >= 250
         AND products.helpful_vote_presence_ratio >= thresholds.helpful_vote_presence_ratio_p75
         AND products.text_analysis_ready_ratio >= 0.80
        THEN 'High'
        WHEN products.review_count >= 100
        THEN 'Moderate'
        ELSE 'Low'
    END AS evidence_confidence_level,
    CASE
        WHEN products.content_analysis_coverage_level = 'Limited'
        THEN 'Category-level metadata support is weak, so product-level metadata findings should be interpreted cautiously'
        WHEN products.has_product_title = FALSE
        THEN 'Product identifier is incomplete, so metadata improvement cannot be actioned cleanly'
        WHEN products.review_count >= 250
         AND products.review_count >= thresholds.review_count_p75
         AND products.low_rating_ratio >= thresholds.low_rating_ratio_p90
         AND products.helpful_vote_presence_ratio >= thresholds.helpful_vote_presence_ratio_p75
         AND products.text_analysis_ready_ratio >= 0.80
         AND products.has_rich_content_support = FALSE
         AND products.rich_content_support_product_ratio >= 0.70
        THEN 'High-review product with elevated dissatisfaction and weak rich-content support in a category where richer metadata is commonly available'
        WHEN products.review_count >= 100
         AND products.low_rating_ratio >= thresholds.low_rating_ratio_p75
         AND products.average_rating <= thresholds.average_rating_p25
         AND products.has_minimum_content_support = FALSE
        THEN 'Meaningful customer feedback is present, dissatisfaction is elevated, and minimum product content support is incomplete'
        WHEN products.review_count >= 100
         AND products.low_rating_ratio >= thresholds.low_rating_ratio_p75
         AND products.average_rating <= thresholds.average_rating_p25
         AND products.has_rich_content_support = FALSE
         AND products.rich_content_support_product_ratio >= 0.70
        THEN "Meaningful customer feedback is present, dissatisfaction is elevated, and this product falls below the category's common rich-content support standard"
        ELSE 'Monitor only'
    END AS business_basis
FROM eligible_products AS products
LEFT JOIN category_peer_thresholds AS thresholds
    ON products.category_name = thresholds.category_name;


-- Preparing category feedback trend summaries with smoothed monthly signals and confidence labels
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_feedback_trend_summary` AS
SELECT
    base.category_name,
    base.review_month,
    base.review_count,
    base.average_rating,
    base.low_rating_ratio,
    base.high_rating_ratio,
    base.average_helpful_vote,
    base.helpful_vote_presence_ratio,
    base.long_review_ratio,
    base.verified_purchase_ratio,
    base.monthly_sample_size_band,
    base.is_trend_analysis_eligible,
    base.is_high_confidence_trend_period,
    trends.average_rating_3_month_moving_average,
    trends.low_rating_ratio_3_month_moving_average,
    trends.helpful_vote_presence_ratio_3_month_moving_average,
    trends.long_review_ratio_3_month_moving_average,
    CASE
        WHEN base.is_high_confidence_trend_period = TRUE THEN 'High'
        WHEN base.is_trend_analysis_eligible = TRUE THEN 'Moderate'
        ELSE 'Low'
    END AS trend_evidence_level
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_monthly_category_eligibility` AS base
LEFT JOIN `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_monthly_behavior_trends` AS trends
    ON base.category_name = trends.category_name
   AND base.review_month = trends.review_month;