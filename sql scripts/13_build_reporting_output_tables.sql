-- Creating the final category overview table for dashboard-level risk and readiness reporting
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.reporting_category_overview` AS
SELECT
    category_name,
    analysis_review_count,
    average_rating,
    low_rating_ratio,
    one_star_ratio,
    high_rating_ratio,
    extreme_rating_ratio,
    average_helpful_vote,
    helpful_vote_presence_ratio,
    average_review_text_length,
    long_review_ratio,
    verified_purchase_ratio,
    general_analysis_coverage_ratio,
    text_analysis_coverage_ratio,
    price_analysis_coverage_ratio,
    content_analysis_coverage_ratio,
    total_month_count,
    eligible_month_count,
    high_confidence_month_count,
    general_analysis_coverage_level,
    text_analysis_coverage_level,
    price_analysis_coverage_level,
    content_analysis_coverage_level
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_feedback_summary`;


-- Creating the final price behavior table for comparing category performance across price bands
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.reporting_category_price_behavior` AS
SELECT
    category_name,
    price_band,
    price_band_order,
    review_count,
    average_rating,
    low_rating_ratio,
    one_star_ratio,
    average_helpful_vote,
    helpful_vote_presence_ratio,
    average_review_text_length,
    long_review_ratio,
    verified_purchase_ratio,
    price_analysis_coverage_ratio,
    price_analysis_coverage_level,
    price_interpretation_strength
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_price_behavior_summary`
WHERE price_interpretation_strength IN ('Strong', 'Usable with caution');


-- Creating the final review trust table for comparing verified and non-verified review behavior
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.reporting_category_review_trust` AS
SELECT
    category_name,
    verified_purchase,
    CASE
        WHEN verified_purchase IS TRUE THEN 'Verified purchase'
        WHEN verified_purchase IS FALSE THEN 'Non-verified purchase'
        ELSE 'Unknown verification'
    END AS verified_purchase_label,
    rating_group,
    review_count,
    average_helpful_vote,
    helpful_vote_presence_ratio,
    average_review_text_length,
    long_review_ratio,
    segment_evidence_level
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_review_trust_summary`
WHERE segment_evidence_level IN ('High', 'Moderate');


-- Creating the final product risk action table for prioritizing products with strong dissatisfaction signals
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.reporting_product_issue_actions` AS
SELECT
    category_name,
    parent_asin,
    product_title,
    product_display_name,
    store_name,
    store_display_name,
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
    issue_priority_level,
    evidence_confidence_level,
    product_identification_quality,
    business_use_caution,
    business_basis,
    comparison_scope
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.product_issue_priority`
WHERE issue_priority_level IN ('Highest priority', 'Priority review');


-- Creating the final product content action table for identifying product pages with content improvement opportunities
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.reporting_product_content_actions` AS
SELECT
    category_name,
    parent_asin,
    product_title,
    product_display_name,
    store_name,
    store_display_name,
    price_amount,
    review_count,
    average_rating,
    low_rating_ratio,
    average_helpful_vote,
    helpful_vote_presence_ratio,
    text_analysis_ready_ratio,
    has_product_title,
    has_store,
    has_features,
    has_description,
    has_details,
    has_any_content_metadata,
    has_rich_content_metadata,
    has_minimum_content_support,
    has_rich_content_support,
    content_analysis_coverage_level,
    metadata_gap_type,
    metadata_improvement_priority,
    evidence_confidence_level,
    business_basis
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.product_content_gap_priority`
WHERE metadata_improvement_priority IN ('Highest priority', 'Priority review');


-- Creating the final category metadata table for dashboarding content and metadata readiness
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.reporting_category_metadata` AS
SELECT
    category_name,
    total_review_count,
    total_product_count,
    title_analysis_ready_review_ratio,
    store_analysis_ready_review_ratio,
    features_analysis_ready_review_ratio,
    description_analysis_ready_review_ratio,
    details_analysis_ready_review_ratio,
    minimum_content_support_review_ratio,
    rich_content_support_review_ratio,
    title_analysis_ready_product_ratio,
    store_analysis_ready_product_ratio,
    features_analysis_ready_product_ratio,
    description_analysis_ready_product_ratio,
    details_analysis_ready_product_ratio,
    minimum_content_support_product_ratio,
    rich_content_support_product_ratio,
    excluded_title_analysis_review_count,
    excluded_store_analysis_review_count,
    excluded_minimum_content_support_review_count,
    excluded_rich_content_support_review_count,
    excluded_title_analysis_product_count,
    excluded_store_analysis_product_count,
    excluded_minimum_content_support_product_count,
    excluded_rich_content_support_product_count,
    content_analysis_coverage_ratio,
    content_analysis_coverage_level
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_metadata_readiness_summary`;


-- Creating the final category trend table for tracking customer feedback changes over time
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.reporting_category_trends` AS
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
    monthly_sample_size_band,
    is_trend_analysis_eligible,
    is_high_confidence_trend_period,
    average_rating_3_month_moving_average,
    low_rating_ratio_3_month_moving_average,
    helpful_vote_presence_ratio_3_month_moving_average,
    long_review_ratio_3_month_moving_average,
    trend_evidence_level
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.category_feedback_trend_summary`
WHERE is_trend_analysis_eligible = TRUE;