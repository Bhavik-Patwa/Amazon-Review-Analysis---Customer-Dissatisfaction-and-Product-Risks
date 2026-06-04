import sys
from pathlib import Path

from google.cloud import bigquery
from run_sql_scripts import configure_google_credentials
from ingest_amazon_reviews_raw import main as ingest_raw_data
from run_sql_scripts import execute_sql_file
from run_sql_scripts import load_project_configuration


PROJECT_ROOT = Path(__file__).resolve().parents[1]

SQL_FILE_PATHS = {"create_datasets": "sql scripts/01_create_datasets.sql",
                  "build_core_reviews": "sql scripts/02_build_core_reviews.sql",
                  "build_core_products": "sql scripts/03_build_core_products.sql"
}

# Validation metrics
SELECTED_CATEGORIES = ["Home_and_Kitchen", "Beauty_and_Personal_Care", "Electronics",
                       "Books", "Movies_and_TV"
]

REQUIRED_REVIEW_COLUMNS = ["asin", "parent_asin", "user_id", "rating", 
                           "title", "text", "timestamp"
]

REQUIRED_META_COLUMNS = ["parent_asin", "title", "main_category", "store",
                         "average_rating", "rating_number", "price"
]

# Validating raw BigQuery tables after ingestion
def validate_raw_tables(configuration):
    configure_google_credentials(credentials_path_value = configuration["credentials_path"])

    client = bigquery.Client(project = configuration["gcp_project_id"])

    for category_name in SELECTED_CATEGORIES:
        normalized_category_name = category_name.lower()

        tables_to_validate = [{"table_name": f"review_{normalized_category_name}_raw",
                               "required_columns": REQUIRED_REVIEW_COLUMNS
        },
                              {"table_name": f"meta_{normalized_category_name}_raw",
                               "required_columns": REQUIRED_META_COLUMNS
        }]

        for table_definition in tables_to_validate:
            table_name = table_definition["table_name"]
            required_columns = table_definition["required_columns"]
            full_table_id = (f"{configuration['gcp_project_id']}."
                             f"{configuration['bigquery_raw_dataset_id']}."
                             f"{table_name}"
            )

            table = client.get_table(full_table_id)

            if table.num_rows == 0:
                raise ValueError(f"Validation failed : table {full_table_id} has zero rows")

            actual_column_names = {field.name for field in table.schema}
            missing_columns = [column_name for column_name in required_columns
                               if column_name not in actual_column_names
            ]

            if missing_columns:
                raise ValueError(f"Validation failed : missing columns in table {full_table_id} -> {missing_columns}")

            print(f"Validated raw table : {full_table_id} | rows = {table.num_rows}")


# Running ingestion, validation and core table creation steps
def run_pipeline():
    configuration = load_project_configuration()

    print("\nStep 1 of 5 : Creating BigQuery datasets")
    execute_sql_file(sql_file_path = SQL_FILE_PATHS["create_datasets"],
                     configuration = configuration
    )

    print("\nStep 2 of 5 : Ingesting raw category files into Cloud Storage and BigQuery raw tables")
    ingest_raw_data()

    print("\nStep 3 of 5 : Validating raw BigQuery tables")
    validate_raw_tables(configuration = configuration)

    print("\nStep 4 of 5 : Building BigQuery core reviews table")
    execute_sql_file(sql_file_path = SQL_FILE_PATHS["build_core_reviews"],
                     configuration = configuration
    )

    print("\nStep 5 of 5 : Building BigQuery core products table")
    execute_sql_file(sql_file_path = SQL_FILE_PATHS["build_core_products"],
                     configuration = configuration
    )

    print("\nIngestion pipeline completed successfully.")



def main():
    run_pipeline()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Ingestion pipeline failed : {exc}")
        sys.exit(1)