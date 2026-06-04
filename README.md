# Amazon Reviews : Product Risk and Dissatisfaction Patterns

A cloud-based analytics project built on the **Amazon Reviews 2023** dataset to identify **customer dissatisfaction patterns, product risk signals, review trust behavior, content readiness gaps and category-level business priorities** across selected Amazon product categories.

This project combines :
- **BigQuery SQL pipelines** for large-scale data preparation and business reporting
- **Python automation** for ingestion and orchestration
- **Jupyter notebooks** for quality analysis and advanced Electronics NLP
- **Looker Studio dashboards** for business-facing reporting and exploration

## Project Scope

### Categories analyzed
- Home_and_Kitchen
- Beauty_and_Personal_Care
- Electronics
- Books
- Movies_and_TV

### Main goals
The project answers two connected sets of questions :

#### Part 1 : Category and product risk analysis
- Which categories show the highest dissatisfaction?
- Which products should be prioritized for intervention?
- How do price bands affect dissatisfaction behavior?
- How do verified and non-verified reviews differ in quality and trust?
- Which categories have strong enough metadata and content coverage for reliable downstream analysis?

#### Part 2 : Electronics dissatisfaction analysis
- Which Electronics issue themes are most associated with dissatisfied reviews?
- Which issue themes intensify across premium and priority products?
- Which issue themes co-occur and form broader customer experience risk patterns?

## Project Architecture

### Data source
- **Amazon Reviews 2023** from the McAuley Lab release on Hugging Face

### Core stack
- Python
- BigQuery
- Google Cloud Storage
- Jupyter Notebook
- Pandas / Scikit-learn
- Looker Studio

## Repository Structure

```text
Amazon Reviews Intelligence/
├── notebooks/
│   ├── 01_environment_check.ipynb
│   ├── 02_data_quality_and_behavioral_analysis.ipynb
│   └── 03_electronics_nlp_analysis.ipynb
├── scripts/
│   ├── bootstrap.py
│   ├── ingest_amazon_reviews_raw.py
│   ├── run_ingestion_pipeline.py
│   └── run_sql_scripts.py
├── sql scripts/
│   ├── 01_create_datasets.sql
│   ├── 02_build_core_reviews.sql
│   ├── 03_build_core_products.sql
│   ├── 04_build_filtered_category_products.sql
│   ├── 05_profile_core_tables.sql
│   ├── 06_profile_analysis_readiness.sql
│   ├── 07_build_analysis_base_tables.sql
│   ├── 08_build_analysis_scope_tables.sql
│   ├── 09_build_analysis_quality_governance.sql
│   ├── 10_build_behavioral_signal_base.sql
│   ├── 11_build_behavioral_insights.sql
│   ├── 12_build_business_strategy_tables.sql
│   ├── 13_build_reporting_output_tables.sql
│   └── 14_build_electronics_text_foundation.sql
├── looker dashboards/
│   └── Looker Report.pdf
├── .env/
├── credentials/
├── requirements.txt
└── .gitignore
```

## End-to-End Implementation Flow

## 1. Environment setup
The project uses a local virtual environment and Python dependencies defined in `requirements.txt`.

Bootstrap script :
```bash
python scripts/bootstrap.py
```

This script :
- creates `.venv/` if needed
- upgrades `pip`
- installs all required packages

## 2. Raw data ingestion
The ingestion pipeline :
- downloads review and metadata files for the selected categories
- uploads them to Google Cloud Storage
- loads them into BigQuery raw tables
- validates required schema fields
- builds initial core review and product tables

Run :
```bash
python scripts/run_ingestion_pipeline.py
```

### Categories ingested
For each selected category, the project ingests :
- `review_<category>_raw`
- `meta_<category>_raw`

### Raw ingestion source pattern
- Review files : `raw/review_categories/<Category>.jsonl`
- Metadata files : `raw/meta_categories/meta_<Category>.jsonl`

## 3. SQL warehouse build
After ingestion, the BigQuery warehouse is built in layers using the SQL scripts under `sql scripts/`.

### SQL pipeline order
1. `01_create_datasets.sql`
2. `02_build_core_reviews.sql`
3. `03_build_core_products.sql`
4. `04_build_filtered_category_products.sql`
5. `05_profile_core_tables.sql`
6. `06_profile_analysis_readiness.sql`
7. `07_build_analysis_base_tables.sql`
8. `08_build_analysis_scope_tables.sql`
9. `09_build_analysis_quality_governance.sql`
10. `10_build_behavioral_signal_base.sql`
11. `11_build_behavioral_insights.sql`
12. `12_build_business_strategy_tables.sql`
13. `13_build_reporting_output_tables.sql`
14. `14_build_electronics_text_foundation.sql`

You can run any single SQL file with :
```bash
python scripts/run_sql_scripts.py "sql scripts/<file_name>.sql"
```

## 4. Notebook 1 : Environment validation
`01_environment_check.ipynb`

Purpose :
- confirm package availability
- confirm environment readiness
- confirm project and cloud access before running the main analytical workflow

## 5. Notebook 2 : Data quality and behavioral analysis
`02_data_quality_and_behavioral_analysis.ipynb`

Purpose :
- profile review and metadata quality
- analyze category-level dissatisfaction behavior
- study verified purchase behavior
- analyze price-band patterns
- assess coverage and readiness for pricing, text and content analysis
- generate business-facing summary outputs used later in reporting

This notebook supports the structured reporting layer used in Looker Studio.

## 6. Notebook 3 : Electronics NLP analysis
`03_electronics_nlp_analysis.ipynb`

Purpose :
- build a focused dissatisfaction analysis workflow for Electronics
- compare dissatisfied vs satisfied Electronics review documents
- evaluate broad topic modeling, root-cause-focused topic modeling and pure product-cause topic modeling
- finalize a validated rule-based issue-bucket framework for Electronics

### Notebook 3 analytical stages

#### A. Electronics document preparation
- builds Electronics review documents from the BigQuery text foundation
- profiles text readiness and review aggregation quality
- prepares balanced and full-corpus NLP inputs

#### B. Exploratory topic modeling
- evaluates different NMF topic counts
- compares broad topic distributions across dissatisfaction and satisfaction cohorts
- measures topic assignment confidence
- studies price-band and priority-level topic exposure

#### C. Root-cause and product-cause refinement
- removes remedy, transaction and evaluative language
- builds root-cause-focused text
- builds product-cause-focused text
- compares the broad, root-cause and pure-product analytical views

#### D. Rule-based issue-theme classification
Final Electronics interpretation is based on validated issue buckets rather than raw topic labels alone.

Issue themes :
- Charging / Power Failure
- Connectivity / Pairing Failure
- Storage / Data Reliability
- Compatibility / Fit Issue
- Physical Build / Installation Failure
- Audio Device Failure
- Video / Display Failure
- Input / Control Failure
- Wearable Tracking Failure
- Antenna / Reception Failure

#### E. Validation
The issue-bucket framework includes :
- positive-match precision validation
- false-negative sampling
- threshold sensitivity audits
- dissatisfaction vs satisfaction comparison
- exposure analysis by price band and priority level
- issue-theme co-occurrence analysis

#### F. Final dashboard tables
Notebook 3 produces final BigQuery dashboard tables for Electronics NLP reporting, including :
- `electronics_nlp_bucket_dictionary`
- `electronics_nlp_scope_quality`
- `electronics_nlp_validation_quality`
- `electronics_nlp_false_negative_quality`
- `electronics_nlp_bucket_overview`
- `electronics_nlp_price_bucket_exposure`
- `electronics_nlp_priority_bucket_exposure`
- `electronics_nlp_bucket_cooccurrence`
- `electronics_nlp_multibucket_intensity`
- `electronics_nlp_top_products_by_bucket`

## BigQuery Reporting Outputs

The SQL and notebook pipeline produces dashboard-ready outputs such as :

### Category and product reporting tables
- `reporting_category_overview`
- `reporting_category_price_behavior`
- `reporting_category_review_trust`
- `reporting_category_trends`
- `reporting_product_issue_actions`
- `reporting_product_content_actions`
- `reporting_category_metadata`

### Electronics NLP reporting tables
- `electronics_nlp_bucket_dictionary`
- `electronics_nlp_scope_quality`
- `electronics_nlp_validation_quality`
- `electronics_nlp_false_negative_quality`
- `electronics_nlp_bucket_overview`
- `electronics_nlp_price_bucket_exposure`
- `electronics_nlp_priority_bucket_exposure`
- `electronics_nlp_bucket_cooccurrence`
- `electronics_nlp_multibucket_intensity`
- `electronics_nlp_top_products_by_bucket`

## Looker Studio Reporting

The final reporting layer is designed for a multi-page Looker Studio dashboard covering :

- Executive Risk & Customer Experience Overview
- Category Dissatisfaction & Risk Signals
- Price Band & Review Trust Analysis
- Content & Metadata Readiness
- Product Risk Prioritization
- Electronics Customer Dissatisfaction Themes
- Electronics Risk by Price & Priority
- Electronics Dissatisfaction Pattern Relationships

## Key Business Findings

### Cross-category findings
- **Electronics** and **Beauty_and_Personal_Care** show the highest dissatisfaction rates.
- **Home_and_Kitchen** also carries meaningful dissatisfaction volume because of its large scale.
- **Books** shows the lowest dissatisfaction rate among the selected categories.

### Product prioritization findings
- The project identifies high-risk products using dissatisfaction rates, review volume, evidence strength and comparison scope rather than raw rating alone.
- This allows a more defensible prioritization layer for intervention and monitoring.

### Price and trust findings
- Dissatisfaction patterns vary across price bands, but price interpretation strength depends on category-level price coverage.
- Verified and non-verified reviews differ meaningfully in average review length and helpfulness behavior.

### Metadata readiness findings
- Most selected categories are strong enough for downstream structured analysis.
- `Movies_and_TV` is materially weaker for content and metadata-driven interpretation than the other selected categories.

### Electronics findings
The final Electronics NLP layer shows that dissatisfaction is strongly associated with issue themes such as :
- charging/power failures
- compatibility/fit issues
- connectivity/pairing failures
- physical build/installation failures
- audio and video/display failures

It also shows :
- which issue themes are most concentrated in dissatisfied reviews
- which themes are more exposed in premium products
- which themes are more common in priority products
- which issue pairs frequently co-occur in the same dissatisfied documents

## Configuration

The project expects a `.env` file with cloud settings such as :
- `GCP_PROJECT_ID`
- `BIGQUERY_LOCATION`
- `BIGQUERY_RAW_DATASET_ID`
- `BIGQUERY_CORE_DATASET_ID`
- `GCS_RAW_BUCKET_NAME`
- `GOOGLE_APPLICATION_CREDENTIALS`

Credentials for GCP authentication are loaded from the local `credentials/` path and are excluded from version control.

## Python Dependencies

From `requirements.txt` :
- jupyter
- ipykernel
- python-dotenv
- pandas
- pyarrow
- google-cloud-bigquery
- google-cloud-bigquery-storage
- google-cloud-storage
- db-dtypes
- matplotlib
- seaborn
- duckdb
- polars
- requests
- scikit-learn
- pandas-gbq

## How to Reproduce

### Step 1
Create the environment :
```bash
python scripts/bootstrap.py
```

### Step 2
Populate raw datasets and core tables :
```bash
python scripts/run_ingestion_pipeline.py
```

### Step 3
Run notebooks in order :
1. `01_environment_check.ipynb`
2. `02_data_quality_and_behavioral_analysis.ipynb`
3. `03_electronics_nlp_analysis.ipynb`

SQL scripts will run within `02_data_quality_and_behavioral_analysis.ipynb` and `03_electronics_nlp_analysis.ipynb` notebooks.

Optionally, one may run them in sequence, as :
```bash
python scripts/run_sql_scripts.py "sql scripts/04_build_filtered_category_products.sql"
python scripts/run_sql_scripts.py "sql scripts/05_profile_core_tables.sql"
python scripts/run_sql_scripts.py "sql scripts/06_profile_analysis_readiness.sql"
python scripts/run_sql_scripts.py "sql scripts/07_build_analysis_base_tables.sql"
python scripts/run_sql_scripts.py "sql scripts/08_build_analysis_scope_tables.sql"
python scripts/run_sql_scripts.py "sql scripts/09_build_analysis_quality_governance.sql"
python scripts/run_sql_scripts.py "sql scripts/10_build_behavioral_signal_base.sql"
python scripts/run_sql_scripts.py "sql scripts/11_build_behavioral_insights.sql"
python scripts/run_sql_scripts.py "sql scripts/12_build_business_strategy_tables.sql"
python scripts/run_sql_scripts.py "sql scripts/13_build_reporting_output_tables.sql"
python scripts/run_sql_scripts.py "sql scripts/14_build_electronics_text_foundation.sql"
```

## Conclusions

- Customer dissatisfaction is not evenly distributed across categories. Electronics and Beauty_and_Personal_Care show the strongest dissatisfaction pressure, while Books is comparatively lower-risk.
- Product risk should be evaluated using dissatisfaction rate, review volume, evidence strength and comparison scope together rather than rating alone.
- Price and review-trust patterns add useful business context, but their strength depends on category-level coverage and evidence quality.
- Metadata readiness is uneven across categories, which affects how confidently content- and NLP-driven findings can be interpreted.
- In Electronics, dissatisfaction is most strongly linked to concrete failure themes such as charging/power, compatibility, connectivity, physical build and audio/video performance issues.
- The final reporting layer supports both executive monitoring and product-level intervention by connecting broad category risk patterns with specific Electronics issue themes.

## Notes and Interpretation Boundaries

- Price-band conclusions should be interpreted in the context of category-specific price coverage.
- Metadata/content-driven conclusions are stronger in categories with higher coverage ratios.
- The Electronics NLP layer is based on **comparison-eligible, text-ready, evidence-backed Electronics documents**, not the full universe of all Electronics reviews.
- The rule-based issue-bucket framework was used to produce more stable and business-interpretable results than unsupervised topic modeling alone.