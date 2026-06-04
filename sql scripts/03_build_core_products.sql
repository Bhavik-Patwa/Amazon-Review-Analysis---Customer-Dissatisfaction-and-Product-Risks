-- Combining raw product metadata from all selected categories into one standardized products table
CREATE OR REPLACE TABLE `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}.products`
CLUSTER BY category_name, parent_asin AS

-- Standardizing product titles, categories, store names, ratings, prices and metadata fields
WITH combined_products AS (

    SELECT
        'Home_and_Kitchen' AS category_name,
        SAFE_CAST(parent_asin AS STRING) AS parent_asin,
        SAFE_CAST(title AS STRING) AS product_title,
        SAFE_CAST(main_category AS STRING) AS main_category,
        SAFE_CAST(store AS STRING) AS store,
        SAFE_CAST(average_rating AS FLOAT64) AS average_rating,
        SAFE_CAST(rating_number AS INT64) AS rating_number,
        SAFE_CAST(REGEXP_EXTRACT(SAFE_CAST(price AS STRING), r'(\d+(?:\.\d+)?)') AS FLOAT64) AS price_amount,
        TO_JSON_STRING(categories) AS categories_json,
        TO_JSON_STRING(features) AS features_json,
        TO_JSON_STRING(description) AS description_json,
        TO_JSON_STRING(details) AS details_json
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_RAW_DATASET_ID}}.meta_home_and_kitchen_raw`

    UNION ALL

    SELECT
        'Beauty_and_Personal_Care' AS category_name,
        SAFE_CAST(parent_asin AS STRING) AS parent_asin,
        SAFE_CAST(title AS STRING) AS product_title,
        SAFE_CAST(main_category AS STRING) AS main_category,
        SAFE_CAST(store AS STRING) AS store,
        SAFE_CAST(average_rating AS FLOAT64) AS average_rating,
        SAFE_CAST(rating_number AS INT64) AS rating_number,
        SAFE_CAST(REGEXP_EXTRACT(SAFE_CAST(price AS STRING), r'(\d+(?:\.\d+)?)') AS FLOAT64) AS price_amount,
        TO_JSON_STRING(categories) AS categories_json,
        TO_JSON_STRING(features) AS features_json,
        TO_JSON_STRING(description) AS description_json,
        TO_JSON_STRING(details) AS details_json
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_RAW_DATASET_ID}}.meta_beauty_and_personal_care_raw`

    UNION ALL

    SELECT
        'Electronics' AS category_name,
        SAFE_CAST(parent_asin AS STRING) AS parent_asin,
        SAFE_CAST(title AS STRING) AS product_title,
        SAFE_CAST(main_category AS STRING) AS main_category,
        SAFE_CAST(store AS STRING) AS store,
        SAFE_CAST(average_rating AS FLOAT64) AS average_rating,
        SAFE_CAST(rating_number AS INT64) AS rating_number,
        SAFE_CAST(REGEXP_EXTRACT(SAFE_CAST(price AS STRING), r'(\d+(?:\.\d+)?)') AS FLOAT64) AS price_amount,
        TO_JSON_STRING(categories) AS categories_json,
        TO_JSON_STRING(features) AS features_json,
        TO_JSON_STRING(description) AS description_json,
        TO_JSON_STRING(details) AS details_json
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_RAW_DATASET_ID}}.meta_electronics_raw`

    UNION ALL

    SELECT
        'Books' AS category_name,
        SAFE_CAST(parent_asin AS STRING) AS parent_asin,
        SAFE_CAST(title AS STRING) AS product_title,
        SAFE_CAST(main_category AS STRING) AS main_category,
        SAFE_CAST(store AS STRING) AS store,
        SAFE_CAST(average_rating AS FLOAT64) AS average_rating,
        SAFE_CAST(rating_number AS INT64) AS rating_number,
        SAFE_CAST(REGEXP_EXTRACT(SAFE_CAST(price AS STRING), r'(\d+(?:\.\d+)?)') AS FLOAT64) AS price_amount,
        TO_JSON_STRING(categories) AS categories_json,
        TO_JSON_STRING(features) AS features_json,
        TO_JSON_STRING(description) AS description_json,
        TO_JSON_STRING(details) AS details_json
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_RAW_DATASET_ID}}.meta_books_raw`

    UNION ALL

    SELECT
        'Movies_and_TV' AS category_name,
        SAFE_CAST(parent_asin AS STRING) AS parent_asin,
        SAFE_CAST(title AS STRING) AS product_title,
        SAFE_CAST(main_category AS STRING) AS main_category,
        SAFE_CAST(store AS STRING) AS store,
        SAFE_CAST(average_rating AS FLOAT64) AS average_rating,
        SAFE_CAST(rating_number AS INT64) AS rating_number,
        SAFE_CAST(REGEXP_EXTRACT(SAFE_CAST(price AS STRING), r'(\d+(?:\.\d+)?)') AS FLOAT64) AS price_amount,
        TO_JSON_STRING(categories) AS categories_json,
        TO_JSON_STRING(features) AS features_json,
        TO_JSON_STRING(description) AS description_json,
        TO_JSON_STRING(details) AS details_json
    FROM `{{GCP_PROJECT_ID}}.{{BIGQUERY_RAW_DATASET_ID}}.meta_movies_and_tv_raw`
)


-- Deduplicating product records and keeping one clean product metadata layer
SELECT
    category_name,
    parent_asin,
    product_title,
    main_category,
    store,
    average_rating,
    rating_number,
    price_amount,
    categories_json,
    features_json,
    description_json,
    details_json
FROM combined_products
WHERE parent_asin IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY category_name, parent_asin
    ORDER BY rating_number DESC, product_title
) = 1;
