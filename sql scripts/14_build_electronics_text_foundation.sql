-- Building the Electronics text foundation with cleaned review text, product context, price bands and priority labels
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.electronics_text_foundation` AS
WITH electronics_reviews AS (
    SELECT
        base.category_name,
        base.parent_asin,
        base.asin,
        base.user_id,
        base.rating,
        base.helpful_vote_clean,
        base.verified_purchase,
        base.review_date,
        base.review_month,
        base.review_text_clean,
        base.review_text_length,
        base.has_non_blank_review_text,
        base.has_alphabetic_word_pattern,
        base.contains_url,
        base.is_symbol_only_text,
        base.is_text_analysis_ready,
        base.product_title_clean,
        base.store_clean,
        base.price_amount,
        base.has_usable_price
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.review_product_general_analysis_scope` AS base
    WHERE base.category_name = 'Electronics'
),
electronics_price_thresholds AS (
    SELECT
        APPROX_QUANTILES(price_amount, 100)[OFFSET(25)] AS price_p25,
        APPROX_QUANTILES(price_amount, 100)[OFFSET(50)] AS price_p50,
        APPROX_QUANTILES(price_amount, 100)[OFFSET(75)] AS price_p75,
        APPROX_QUANTILES(price_amount, 100)[OFFSET(95)] AS price_p95
    FROM electronics_reviews
    WHERE has_usable_price = TRUE
),
electronics_priority AS (
    SELECT
        category_name,
        parent_asin,
        issue_priority_level,
        evidence_confidence_level,
        product_identification_quality
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.product_issue_priority`
    WHERE category_name = 'Electronics'
),
normalized_reviews AS (
    SELECT
        reviews.category_name,
        reviews.parent_asin,
        reviews.asin,
        reviews.user_id,
        reviews.rating,
        reviews.helpful_vote_clean,
        reviews.verified_purchase,
        reviews.review_date,
        reviews.review_month,
        reviews.review_text_clean,
        reviews.review_text_length,
        reviews.has_non_blank_review_text,
        reviews.has_alphabetic_word_pattern,
        reviews.contains_url,
        reviews.is_symbol_only_text,
        reviews.is_text_analysis_ready,
        reviews.product_title_clean,
        reviews.store_clean,
        reviews.price_amount,
        reviews.has_usable_price,
        LOWER(
            NULLIF(
                TRIM(
                    REGEXP_REPLACE(
                        REGEXP_REPLACE(
                            REGEXP_REPLACE(
                                COALESCE(reviews.review_text_clean, ''),
                                'https?://[^ ]+|www\\.[^ ]+',
                                ' '
                            ),
                            '[\\r\\n\\t]+',
                            ' '
                        ),
                        '\\s+',
                        ' '
                    )
                ),
                ''
            )
        ) AS review_text_normalized
    FROM electronics_reviews AS reviews
),
tokenized_reviews AS (
    SELECT
        reviews.*,
        REGEXP_EXTRACT_ALL(COALESCE(reviews.review_text_normalized, ''), '[a-z0-9]+') AS all_tokens,
        REGEXP_EXTRACT_ALL(COALESCE(reviews.review_text_normalized, ''), '[a-z][a-z]+') AS alphabetic_tokens
    FROM normalized_reviews AS reviews
)

SELECT
    reviews.category_name,
    reviews.parent_asin,
    reviews.asin,
    reviews.user_id,
    reviews.rating,
    CASE
        WHEN reviews.rating IN (1, 2) THEN 'Low rating'
        WHEN reviews.rating = 3 THEN 'Mid rating'
        WHEN reviews.rating IN (4, 5) THEN 'High rating'
        ELSE 'Other'
    END AS rating_group,
    CASE
        WHEN reviews.rating IN (1, 2) THEN 'Dissatisfaction'
        WHEN reviews.rating IN (4, 5) THEN 'Satisfaction'
        ELSE 'Neutral'
    END AS sentiment_cohort,
    reviews.helpful_vote_clean,
    reviews.verified_purchase,
    reviews.review_date,
    reviews.review_month,
    reviews.review_text_clean,
    reviews.review_text_normalized,
    ARRAY_TO_STRING(reviews.all_tokens, ' ') AS review_text_for_modeling,
    reviews.review_text_length,
    ARRAY_LENGTH(reviews.all_tokens) AS token_count_approx,
    ARRAY_LENGTH(reviews.alphabetic_tokens) AS alphabetic_token_count,
    BYTE_LENGTH(COALESCE(reviews.review_text_clean, '')) > LENGTH(COALESCE(reviews.review_text_clean, '')) AS contains_non_ascii_characters,
    REGEXP_CONTAINS(COALESCE(reviews.review_text_normalized, ''), '[0-9]') AS contains_digits,
    reviews.has_non_blank_review_text,
    reviews.has_alphabetic_word_pattern,
    reviews.contains_url,
    reviews.is_symbol_only_text,
    reviews.is_text_analysis_ready,
    (
        reviews.review_text_normalized IS NOT NULL
        AND reviews.review_text_length >= 30
        AND ARRAY_LENGTH(reviews.all_tokens) >= 5
        AND ARRAY_LENGTH(reviews.alphabetic_tokens) >= 3
        AND reviews.is_symbol_only_text = FALSE
        AND ARRAY_TO_STRING(reviews.all_tokens, ' ') != ''
    ) AS is_text_modeling_candidate,
    reviews.product_title_clean,
    reviews.store_clean,
    reviews.price_amount,
    reviews.has_usable_price,
    CASE
        WHEN reviews.has_usable_price = FALSE THEN NULL
        WHEN reviews.price_amount <= thresholds.price_p25 THEN 'Budget'
        WHEN reviews.price_amount <= thresholds.price_p50 THEN 'Lower mid'
        WHEN reviews.price_amount <= thresholds.price_p75 THEN 'Upper mid'
        WHEN reviews.price_amount <= thresholds.price_p95 THEN 'Premium'
        ELSE 'Very premium'
    END AS price_band,
    CASE
        WHEN priority.parent_asin IS NULL THEN 'Below product evidence threshold'
        ELSE priority.issue_priority_level
    END AS issue_priority_level,
    CASE
        WHEN priority.parent_asin IS NULL THEN 'Low'
        ELSE priority.evidence_confidence_level
    END AS issue_evidence_confidence_level,
    CASE
        WHEN priority.parent_asin IS NULL THEN 'Low'
        ELSE priority.product_identification_quality
    END AS product_identification_quality,
    CASE
        WHEN priority.parent_asin IS NULL THEN 'Below product evidence threshold'
        ELSE 'Evidence-backed product'
    END AS product_evidence_segment,
    reviews.has_usable_price AS is_price_available,
    priority.parent_asin IS NOT NULL AS is_issue_priority_comparison_eligible,
    (
        reviews.rating IN (1, 2, 4, 5)
        AND reviews.has_usable_price = TRUE
        AND priority.parent_asin IS NOT NULL
        AND reviews.review_text_normalized IS NOT NULL
        AND reviews.review_text_length >= 30
        AND ARRAY_LENGTH(reviews.all_tokens) >= 5
        AND ARRAY_LENGTH(reviews.alphabetic_tokens) >= 3
        AND reviews.is_symbol_only_text = FALSE
        AND ARRAY_TO_STRING(reviews.all_tokens, ' ') != ''
    ) AS is_comparison_eligible,
    CASE
        WHEN reviews.rating NOT IN (1, 2, 4, 5) THEN 'Not target sentiment cohort'
        WHEN reviews.has_usable_price = FALSE THEN 'Price unavailable'
        WHEN priority.parent_asin IS NULL THEN 'Below product evidence threshold'
        WHEN (
            reviews.review_text_normalized IS NULL
            OR reviews.review_text_length < 30
            OR ARRAY_LENGTH(reviews.all_tokens) < 5
            OR ARRAY_LENGTH(reviews.alphabetic_tokens) < 3
            OR reviews.is_symbol_only_text = TRUE
            OR ARRAY_TO_STRING(reviews.all_tokens, ' ') = ''
        ) THEN 'Not text-modeling eligible'
        ELSE NULL
    END AS comparison_exclusion_reason
FROM tokenized_reviews AS reviews
CROSS JOIN electronics_price_thresholds AS thresholds
LEFT JOIN electronics_priority AS priority
    ON reviews.category_name = priority.category_name
   AND reviews.parent_asin = priority.parent_asin;


-- Filtering Electronics reviews into the text-ready modeling scope for dissatisfaction and satisfaction comparison
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.electronics_text_modeling_scope` AS
SELECT
    category_name,
    parent_asin,
    asin,
    user_id,
    rating,
    rating_group,
    sentiment_cohort,
    helpful_vote_clean,
    verified_purchase,
    review_date,
    review_month,
    review_text_clean,
    review_text_normalized,
    review_text_for_modeling,
    review_text_length,
    token_count_approx,
    alphabetic_token_count,
    contains_non_ascii_characters,
    contains_digits,
    product_title_clean,
    store_clean,
    price_amount,
    has_usable_price,
    price_band,
    issue_priority_level,
    issue_evidence_confidence_level,
    product_identification_quality,
    product_evidence_segment
FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.electronics_text_foundation`
WHERE is_comparison_eligible = TRUE;


-- Summarizing available Electronics review groups for balanced text analysis across cohorts, price bands and priority levels
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.electronics_text_modeling_strata_summary` AS
WITH eligible_product_groups AS (
    SELECT
        sentiment_cohort,
        verified_purchase,
        price_band,
        issue_priority_level,
        parent_asin,
        COUNT(*) AS review_count
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.electronics_text_modeling_scope`
    GROUP BY
        sentiment_cohort,
        verified_purchase,
        price_band,
        issue_priority_level,
        parent_asin
    HAVING COUNT(*) >= 25
),
strata_capacity AS (
    SELECT
        sentiment_cohort,
        verified_purchase,
        price_band,
        issue_priority_level,
        COUNT(*) AS product_group_count,
        SUM(review_count) AS total_review_capacity
    FROM eligible_product_groups
    GROUP BY
        sentiment_cohort,
        verified_purchase,
        price_band,
        issue_priority_level
),
paired_strata AS (
    SELECT
        COALESCE(diss.verified_purchase, sat.verified_purchase) AS verified_purchase,
        COALESCE(diss.price_band, sat.price_band) AS price_band,
        COALESCE(diss.issue_priority_level, sat.issue_priority_level) AS issue_priority_level,
        diss.product_group_count AS dissatisfaction_product_group_count,
        diss.total_review_capacity AS dissatisfaction_review_capacity,
        sat.product_group_count AS satisfaction_product_group_count,
        sat.total_review_capacity AS satisfaction_review_capacity,
        LEAST(
            COALESCE(diss.total_review_capacity, 0),
            COALESCE(sat.total_review_capacity, 0)
        ) AS balanced_review_capacity
    FROM (
        SELECT *
        FROM strata_capacity
        WHERE sentiment_cohort = 'Dissatisfaction'
    ) AS diss
    FULL OUTER JOIN (
        SELECT *
        FROM strata_capacity
        WHERE sentiment_cohort = 'Satisfaction'
    ) AS sat
        ON diss.verified_purchase = sat.verified_purchase
       AND diss.price_band = sat.price_band
       AND diss.issue_priority_level = sat.issue_priority_level
),
selected_strata AS (
    SELECT
        *,
        CASE
            WHEN COALESCE(dissatisfaction_product_group_count, 0) < 25
              OR COALESCE(satisfaction_product_group_count, 0) < 25
            THEN 'Limited'
            WHEN balanced_review_capacity < 50000
            THEN 'Comparison thin'
            ELSE 'Usable'
        END AS stratum_evidence_level
    FROM paired_strata
),
selected_capacity AS (
    SELECT
        SUM(balanced_review_capacity) AS selected_total_balanced_review_capacity
    FROM selected_strata
    WHERE stratum_evidence_level = 'Usable'
)

SELECT
    strata.verified_purchase,
    strata.price_band,
    strata.issue_priority_level,
    strata.dissatisfaction_product_group_count,
    strata.dissatisfaction_review_capacity,
    strata.satisfaction_product_group_count,
    strata.satisfaction_review_capacity,
    strata.balanced_review_capacity,
    CAST(
        ROUND(
            2000000 * SAFE_DIVIDE(
                strata.balanced_review_capacity,
                selected_capacity.selected_total_balanced_review_capacity
            )
        ) AS INT64
    ) AS target_review_count_per_sentiment,
    strata.stratum_evidence_level,
    strata.stratum_evidence_level = 'Usable' AS is_selected_for_modeling
FROM selected_strata AS strata
CROSS JOIN selected_capacity
WHERE strata.balanced_review_capacity > 0;


-- Aggregating Electronics reviews into product-level text documents for deeper NLP analysis
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.electronics_text_documents` AS
WITH eligible_product_groups AS (
    SELECT
        sentiment_cohort,
        verified_purchase,
        price_band,
        issue_priority_level,
        parent_asin,
        ANY_VALUE(product_title_clean) AS product_title_clean,
        ANY_VALUE(store_clean) AS store_clean,
        ANY_VALUE(product_identification_quality) AS product_identification_quality,
        COUNT(*) AS review_count,
        AVG(rating) AS average_rating,
        AVG(COALESCE(helpful_vote_clean, 0)) AS average_helpful_vote,
        AVG(review_text_length) AS average_review_text_length
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.electronics_text_modeling_scope`
    GROUP BY
        sentiment_cohort,
        verified_purchase,
        price_band,
        issue_priority_level,
        parent_asin
    HAVING COUNT(*) >= 25
),
selected_strata AS (
    SELECT
        verified_purchase,
        price_band,
        issue_priority_level,
        target_review_count_per_sentiment
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.electronics_text_modeling_strata_summary`
    WHERE is_selected_for_modeling = TRUE
      AND target_review_count_per_sentiment > 0
),
group_allocations AS (
    SELECT
        product_groups.sentiment_cohort,
        product_groups.verified_purchase,
        product_groups.price_band,
        product_groups.issue_priority_level,
        product_groups.parent_asin,
        product_groups.product_title_clean,
        product_groups.store_clean,
        product_groups.product_identification_quality,
        product_groups.review_count,
        product_groups.average_rating,
        product_groups.average_helpful_vote,
        product_groups.average_review_text_length,
        strata.target_review_count_per_sentiment,
        SUM(product_groups.review_count) OVER (
            PARTITION BY
                product_groups.sentiment_cohort,
                product_groups.verified_purchase,
                product_groups.price_band,
                product_groups.issue_priority_level
        ) AS stratum_review_count
    FROM eligible_product_groups AS product_groups
    INNER JOIN selected_strata AS strata
        ON product_groups.verified_purchase = strata.verified_purchase
       AND product_groups.price_band = strata.price_band
       AND product_groups.issue_priority_level = strata.issue_priority_level
),
product_level_targets AS (
    SELECT
        sentiment_cohort,
        verified_purchase,
        price_band,
        issue_priority_level,
        parent_asin,
        product_title_clean,
        store_clean,
        product_identification_quality,
        review_count,
        average_rating,
        average_helpful_vote,
        average_review_text_length,
        target_review_count_per_sentiment,
        stratum_review_count,
        CAST(
            LEAST(
                review_count,
                CEIL(
                    target_review_count_per_sentiment * SAFE_DIVIDE(review_count, stratum_review_count)
                )
            ) AS INT64
        ) AS target_review_count_for_product
    FROM group_allocations
),
ranked_reviews AS (
    SELECT
        scope.sentiment_cohort,
        scope.verified_purchase,
        scope.price_band,
        scope.issue_priority_level,
        scope.parent_asin,
        scope.review_text_for_modeling,
        targets.target_review_count_per_sentiment,
        targets.target_review_count_for_product,
        ROW_NUMBER() OVER (
            PARTITION BY
                scope.sentiment_cohort,
                scope.verified_purchase,
                scope.price_band,
                scope.issue_priority_level,
                scope.parent_asin
            ORDER BY FARM_FINGERPRINT(
                CONCAT(
                    COALESCE(scope.parent_asin, ''),
                    '|',
                    COALESCE(scope.asin, ''),
                    '|',
                    COALESCE(scope.user_id, ''),
                    '|',
                    COALESCE(CAST(scope.review_date AS STRING), ''),
                    '|',
                    COALESCE(scope.review_text_for_modeling, '')
                )
            )
        ) AS review_rank_in_product_stratum
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.electronics_text_modeling_scope` AS scope
    INNER JOIN product_level_targets AS targets
        ON scope.sentiment_cohort = targets.sentiment_cohort
       AND scope.verified_purchase = targets.verified_purchase
       AND scope.price_band = targets.price_band
       AND scope.issue_priority_level = targets.issue_priority_level
       AND scope.parent_asin = targets.parent_asin
),
capped_reviews AS (
    SELECT
        sentiment_cohort,
        verified_purchase,
        price_band,
        issue_priority_level,
        parent_asin,
        review_text_for_modeling,
        target_review_count_per_sentiment,
        review_rank_in_product_stratum
    FROM ranked_reviews
    WHERE review_rank_in_product_stratum <= target_review_count_for_product
),
chunked_reviews AS (
    SELECT
        sentiment_cohort,
        verified_purchase,
        price_band,
        issue_priority_level,
        parent_asin,
        target_review_count_per_sentiment,
        CAST(CEIL(SAFE_DIVIDE(review_rank_in_product_stratum, 250.0)) AS INT64) AS document_chunk_number,
        review_rank_in_product_stratum,
        review_text_for_modeling
    FROM capped_reviews
),
chunked_documents AS (
    SELECT
        targets.sentiment_cohort,
        targets.verified_purchase,
        targets.price_band,
        targets.issue_priority_level,
        targets.parent_asin,
        targets.product_title_clean,
        COALESCE(targets.product_title_clean, CONCAT('ASIN ', targets.parent_asin)) AS product_display_name,
        targets.store_clean,
        COALESCE(targets.store_clean, 'Unknown store') AS store_display_name,
        targets.product_identification_quality,
        targets.review_count,
        targets.target_review_count_per_sentiment,
        targets.target_review_count_for_product,
        targets.average_rating,
        targets.average_helpful_vote,
        targets.average_review_text_length,
        chunked.document_chunk_number,
        COUNT(*) AS sampled_review_count,
        SAFE_DIVIDE(COUNT(*), targets.review_count) AS sampled_review_ratio,
        CONCAT(
            targets.sentiment_cohort, '|',
            CAST(targets.verified_purchase AS STRING), '|',
            targets.price_band, '|',
            targets.issue_priority_level, '|',
            targets.parent_asin, '|chunk_', CAST(chunked.document_chunk_number AS STRING)
        ) AS document_id,
        STRING_AGG(
            chunked.review_text_for_modeling,
            ' review_boundary ' ORDER BY chunked.review_rank_in_product_stratum
        ) AS aggregated_text
    FROM chunked_reviews AS chunked
    INNER JOIN product_level_targets AS targets
        ON chunked.sentiment_cohort = targets.sentiment_cohort
       AND chunked.verified_purchase = targets.verified_purchase
       AND chunked.price_band = targets.price_band
       AND chunked.issue_priority_level = targets.issue_priority_level
       AND chunked.parent_asin = targets.parent_asin
    GROUP BY
        targets.sentiment_cohort,
        targets.verified_purchase,
        targets.price_band,
        targets.issue_priority_level,
        targets.parent_asin,
        targets.product_title_clean,
        targets.store_clean,
        targets.product_identification_quality,
        targets.review_count,
        targets.target_review_count_per_sentiment,
        targets.target_review_count_for_product,
        targets.average_rating,
        targets.average_helpful_vote,
        targets.average_review_text_length,
        chunked.document_chunk_number
)

SELECT
    sentiment_cohort,
    verified_purchase,
    price_band,
    issue_priority_level,
    parent_asin,
    product_title_clean,
    product_display_name,
    store_clean,
    store_display_name,
    product_identification_quality,
    review_count,
    target_review_count_per_sentiment,
    target_review_count_for_product,
    250 AS per_document_review_cap,
    document_chunk_number,
    sampled_review_count,
    sampled_review_ratio,
    average_rating,
    average_helpful_vote,
    average_review_text_length,
    document_id,
    aggregated_text
FROM chunked_documents;


-- Preparing the final Electronics text dataset for topic modeling and comparison-ready NLP analysis
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.electronics_text_modeling_ready` AS
WITH ranked_documents AS (
    SELECT
        CASE
            WHEN documents.sentiment_cohort = 'Dissatisfaction' THEN 'Topic modeling target'
            WHEN documents.sentiment_cohort = 'Satisfaction' THEN 'Comparison baseline'
            ELSE 'Other'
        END AS analysis_pool_role,
        documents.sentiment_cohort,
        documents.verified_purchase,
        documents.price_band,
        documents.issue_priority_level,
        documents.parent_asin,
        documents.product_title_clean,
        documents.product_display_name,
        documents.store_clean,
        documents.store_display_name,
        documents.product_identification_quality,
        documents.review_count,
        documents.target_review_count_per_sentiment,
        documents.target_review_count_for_product,
        documents.per_document_review_cap,
        documents.sampled_review_count,
        documents.sampled_review_ratio,
        documents.average_rating,
        documents.average_helpful_vote,
        documents.average_review_text_length,
        documents.document_id,
        documents.aggregated_text,
        ROW_NUMBER() OVER (
            PARTITION BY
                documents.sentiment_cohort,
                documents.verified_purchase,
                documents.price_band,
                documents.issue_priority_level
            ORDER BY FARM_FINGERPRINT(documents.document_id)
        ) AS document_rank_in_stratum,
        SUM(documents.sampled_review_count) OVER (
            PARTITION BY
                documents.sentiment_cohort,
                documents.verified_purchase,
                documents.price_band,
                documents.issue_priority_level
            ORDER BY FARM_FINGERPRINT(documents.document_id)
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_sampled_review_count
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.electronics_text_documents` AS documents
)

SELECT
    analysis_pool_role,
    sentiment_cohort,
    verified_purchase,
    price_band,
    issue_priority_level,
    'Evidence-backed product' AS product_evidence_segment,
    parent_asin,
    product_title_clean,
    product_display_name,
    store_clean,
    store_display_name,
    product_identification_quality,
    review_count,
    target_review_count_per_sentiment,
    target_review_count_for_product,
    per_document_review_cap,
    sampled_review_count,
    sampled_review_ratio,
    average_rating,
    average_helpful_vote,
    average_review_text_length,
    document_id,
    aggregated_text,
    LENGTH(aggregated_text) AS aggregated_text_length,
    TRUE AS is_price_band_interpretation_eligible,
    TRUE AS is_price_sensitive_theme_comparison_eligible,
    TRUE AS is_issue_priority_comparison_eligible,
    TRUE AS is_product_interpretation_eligible
FROM ranked_documents
WHERE cumulative_sampled_review_count - sampled_review_count < target_review_count_per_sentiment;