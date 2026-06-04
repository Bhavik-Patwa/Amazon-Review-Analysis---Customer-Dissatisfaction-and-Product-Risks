-- Creating the raw dataset for storing imported source files
CREATE SCHEMA IF NOT EXISTS `{{GCP_PROJECT_ID}}.{{BIGQUERY_RAW_DATASET_ID}}`
OPTIONS (
    location = '{{BIGQUERY_LOCATION}}'
);


-- Creating the core dataset for storing cleaned and analysis-ready tables
CREATE SCHEMA IF NOT EXISTS `{{GCP_PROJECT_ID}}.{{BIGQUERY_CORE_DATASET_ID}}`
OPTIONS (
    location = '{{BIGQUERY_LOCATION}}'
);