-- Building price-band behavior metrics for comparing ratings, dissatisfaction helpfulness and review detail across category-specific price ranges
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_price_band_summary` AS
WITH eligible_reviews AS (
    SELECT
        category_name,
        parent_asin,
        price_amount,
        rating,
        helpful_vote_clean,
        review_text_length,
        verified_purchase
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_price_analysis_scope`
),
category_price_thresholds AS (
    SELECT
        category_name,
        APPROX_QUANTILES(price_amount, 100)[OFFSET(25)] AS price_p25,
        APPROX_QUANTILES(price_amount, 100)[OFFSET(50)] AS price_p50,
        APPROX_QUANTILES(price_amount, 100)[OFFSET(75)] AS price_p75,
        APPROX_QUANTILES(price_amount, 100)[OFFSET(95)] AS price_p95
    FROM eligible_reviews
    GROUP BY category_name
),
banded_reviews AS (
    SELECT
        reviews.category_name,
        reviews.parent_asin,
        reviews.price_amount,
        reviews.rating,
        reviews.helpful_vote_clean,
        reviews.review_text_length,
        reviews.verified_purchase,
        CASE
            WHEN reviews.price_amount <= thresholds.price_p25 THEN 'Budget'
            WHEN reviews.price_amount <= thresholds.price_p50 THEN 'Lower mid'
            WHEN reviews.price_amount <= thresholds.price_p75 THEN 'Upper mid'
            WHEN reviews.price_amount <= thresholds.price_p95 THEN 'Premium'
            ELSE 'Very premium'
        END AS price_band
    FROM eligible_reviews AS reviews
    INNER JOIN category_price_thresholds AS thresholds
        ON reviews.category_name = thresholds.category_name
)

SELECT
    category_name,
    price_band,
    COUNT(*) AS review_count,
    AVG(rating) AS average_rating,
    SAFE_DIVIDE(COUNTIF(rating IN (1, 2)), COUNT(*)) AS low_rating_ratio,
    SAFE_DIVIDE(COUNTIF(rating = 1), COUNT(*)) AS one_star_ratio,
    AVG(COALESCE(helpful_vote_clean, 0)) AS average_helpful_vote,
    SAFE_DIVIDE(COUNTIF(COALESCE(helpful_vote_clean, 0) > 0), COUNT(*)) AS helpful_vote_presence_ratio,
    AVG(review_text_length) AS average_review_text_length,
    SAFE_DIVIDE(COUNTIF(review_text_length >= 250), COUNT(*)) AS long_review_ratio,
    SAFE_DIVIDE(COUNTIF(verified_purchase IS TRUE), COUNT(*)) AS verified_purchase_ratio
FROM banded_reviews
GROUP BY category_name, price_band;


-- Measuring how verified and non-verified reviews are behaving across rating levels and review-quality signals
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_verified_rating_behavior` AS
SELECT
    category_name,
    verified_purchase,
    rating,
    COUNT(*) AS review_count,
    AVG(COALESCE(helpful_vote_clean, 0)) AS average_helpful_vote,
    SAFE_DIVIDE(COUNTIF(COALESCE(helpful_vote_clean, 0) > 0), COUNT(*)) AS helpful_vote_presence_ratio,
    AVG(review_text_length) AS average_review_text_length,
    SAFE_DIVIDE(COUNTIF(review_text_length >= 250), COUNT(*)) AS long_review_ratio
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_general_analysis_scope`
GROUP BY category_name, verified_purchase, rating;


-- Ranking products by customer dissatisfaction, review volume, helpfulness and text readiness to identify product-risk priorities
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_product_risk_ranking` AS
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
        text_analysis_ready_ratio
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_product_sample_eligibility`
    WHERE is_product_analysis_eligible = TRUE
),
scored_products AS (
    SELECT
        *,
        (
            (low_rating_ratio * 0.35) +
            (one_star_ratio * 0.20) +
            (helpful_vote_presence_ratio * 0.15) +
            (long_review_ratio * 0.15) +
            ((1 - SAFE_DIVIDE(average_rating, 5)) * 0.15)
        ) AS product_risk_score
    FROM eligible_products
)

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
    product_risk_score,
    DENSE_RANK() OVER (
        PARTITION BY category_name
        ORDER BY product_risk_score DESC, review_count DESC
    ) AS category_risk_rank
FROM scored_products;


-- Creating smoothed monthly trend metrics for tracking category feedback patterns over time
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_monthly_behavior_trends` AS
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
    AVG(average_rating) OVER (
        PARTITION BY category_name
        ORDER BY review_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS average_rating_3_month_moving_average,
    AVG(low_rating_ratio) OVER (
        PARTITION BY category_name
        ORDER BY review_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS low_rating_ratio_3_month_moving_average,
    AVG(helpful_vote_presence_ratio) OVER (
        PARTITION BY category_name
        ORDER BY review_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS helpful_vote_presence_ratio_3_month_moving_average,
    AVG(long_review_ratio) OVER (
        PARTITION BY category_name
        ORDER BY review_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS long_review_ratio_3_month_moving_average
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_monthly_category_eligibility`
WHERE is_trend_analysis_eligible = TRUE;


-- Summarizing category-level rating polarization and dissatisfaction signals
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.analysis_category_polarization_summary` AS
SELECT
    category_name,
    COUNT(*) AS review_count,
    SAFE_DIVIDE(COUNTIF(rating IN (1, 5)), COUNT(*)) AS extreme_rating_ratio,
    SAFE_DIVIDE(COUNTIF(rating = 5), COUNT(*)) AS five_star_ratio,
    SAFE_DIVIDE(COUNTIF(rating = 1), COUNT(*)) AS one_star_ratio,
    SAFE_DIVIDE(COUNTIF(rating IN (1, 2)), COUNT(*)) AS low_rating_ratio,
    SAFE_DIVIDE(COUNTIF(rating IN (4, 5)), COUNT(*)) AS high_rating_ratio,
    AVG(COALESCE(helpful_vote_clean, 0)) AS average_helpful_vote
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_general_analysis_scope`
GROUP BY category_name;