import os
import sys
from pathlib import Path

import requests
from dotenv import load_dotenv
from google.cloud import bigquery
from google.cloud import storage
from google.api_core.exceptions import NotFound

PROJECT_ROOT = Path(__file__).resolve().parents[1]
ENV_FILE_PATH = PROJECT_ROOT / ".env"

OVERWRITE_EXISTING_GCS_OBJECTS = False
OVERWRITE_EXISTING_BIGQUERY_TABLES = False
DELETE_GCS_OBJECT_AFTER_SUCCESSFUL_LOAD = False

REQUEST_TIMEOUT_SECONDS = 300
DOWNLOAD_CHUNK_SIZE_BYTES = 8 * 1024 * 1024

SELECTED_CATEGORIES = ["Home_and_Kitchen",
                       "Beauty_and_Personal_Care",
                       "Electronics",
                       "Books",
                       "Movies_and_TV"
]

ENTITY_TYPES = ["review", "meta"]


# Loading project settings from the environment file
def load_project_configuration():
    load_dotenv(dotenv_path = ENV_FILE_PATH)

    configuration = {"gcp_project_id": os.getenv("GCP_PROJECT_ID"),
                     "bigquery_location": os.getenv("BIGQUERY_LOCATION"),
                     "bigquery_raw_dataset_id": os.getenv("BIGQUERY_RAW_DATASET_ID"),
                     "gcs_raw_bucket_name": os.getenv("GCS_RAW_BUCKET_NAME"),
                     "credentials_path": os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    }

    missing_keys = [key for key, value in configuration.items() if not value]
    if missing_keys:
        raise ValueError(f"Missing required environment variables : {missing_keys}")

    return configuration


# Setting Google Cloud credentials
def configure_google_credentials(credentials_path_value):
    credentials_file_path = (PROJECT_ROOT / credentials_path_value).resolve()

    if not credentials_file_path.exists():
        raise FileNotFoundError(f"Credentials file not found : {credentials_file_path}")

    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = str(credentials_file_path)


# Building source download links
def build_source_url(entity_type, category_name):
    if entity_type == "review":
        return ("https://huggingface.co/datasets/"
                "McAuley-Lab/Amazon-Reviews-2023/resolve/main/"
                f"raw/review_categories/{category_name}.jsonl"
        )

    if entity_type == "meta":
        return ("https://huggingface.co/datasets/"
                "McAuley-Lab/Amazon-Reviews-2023/resolve/main/"
                f"raw/meta_categories/meta_{category_name}.jsonl"
        )

    raise ValueError(f"Unsupported entity type : {entity_type}")


# Creating Cloud Storage object paths
def build_gcs_object_name(entity_type, category_name):
    if entity_type == "review":
        return f"amazon_reviews_2023/review/{category_name}.jsonl"

    if entity_type == "meta":
        return f"amazon_reviews_2023/meta/meta_{category_name}.jsonl"

    raise ValueError(f"Unsupported entity type : {entity_type}")


# Creating BigQuery raw table names
def build_bigquery_table_name(entity_type, category_name):
    normalized_category_name = category_name.lower()

    if entity_type == "review":
        return f"review_{normalized_category_name}_raw"

    if entity_type == "meta":
        return f"meta_{normalized_category_name}_raw"

    raise ValueError(f"Unsupported entity type : {entity_type}")


# Downloading and uploading source files to Cloud Storage
def upload_source_file_to_gcs(bucket, source_url, object_name):
    if gcs_object_exists(bucket = bucket, object_name = object_name) and not OVERWRITE_EXISTING_GCS_OBJECTS:
        print(f"Skipping GCS upload because object already exists : {object_name}")
        return

    blob = bucket.blob(object_name)
    blob.chunk_size = DOWNLOAD_CHUNK_SIZE_BYTES

    print(f"Uploading source file to GCS : {object_name}")

    try:
        with requests.get(source_url, stream = True, timeout = REQUEST_TIMEOUT_SECONDS) as response:
            response.raise_for_status()
            expected_size_bytes = int(response.headers.get("Content-Length", "0"))

            with blob.open("wb") as output_file:
                for chunk in response.iter_content(chunk_size = DOWNLOAD_CHUNK_SIZE_BYTES):
                    if chunk:
                        output_file.write(chunk)

        blob.reload()

        if expected_size_bytes and blob.size != expected_size_bytes:
            blob.delete()
            raise ValueError(
                f"Uploaded object size mismatch for {object_name} : "
                f"expected {expected_size_bytes} bytes, found {blob.size} bytes."
            )

    except Exception:
        if blob.exists():
            blob.delete()

        raise

    print(f"Google Cloud Storage upload completed : {object_name}")


# Defining the metadata table schema
def build_meta_table_schema():
    return [bigquery.SchemaField("parent_asin", "STRING"),
            bigquery.SchemaField("title", "STRING"),
            bigquery.SchemaField("main_category", "STRING"),
            bigquery.SchemaField("store", "STRING"),
            bigquery.SchemaField("average_rating", "FLOAT64"),
            bigquery.SchemaField("rating_number", "INT64"),
            bigquery.SchemaField("price", "STRING"),
            bigquery.SchemaField("categories", "JSON"),
            bigquery.SchemaField("features", "JSON"),
            bigquery.SchemaField("description", "JSON"),
            bigquery.SchemaField("details", "JSON")
    ]


# Loading Cloud Storage files into BigQuery tables
def load_gcs_file_to_bigquery(bigquery_client, gcp_project_id, raw_dataset_id, gcs_uri, table_name, location, entity_type):
    destination_table_id = f"{gcp_project_id}.{raw_dataset_id}.{table_name}"

    if bigquery_table_exists(bigquery_client = bigquery_client,
                             gcp_project_id = gcp_project_id,
                             raw_dataset_id = raw_dataset_id,
                             table_name = table_name
    ) and not OVERWRITE_EXISTING_BIGQUERY_TABLES:
        print(f"Skipping BigQuery load because table already exists : {destination_table_id}")
        return

    print(f"Loading into BigQuery table : {destination_table_id}")

    if entity_type == "review":
        job_config = bigquery.LoadJobConfig(
            source_format = bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
            autodetect = True,
            write_disposition = bigquery.WriteDisposition.WRITE_TRUNCATE
        )
    else:
        job_config = bigquery.LoadJobConfig(
            source_format = bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
            schema = build_meta_table_schema(),
            ignore_unknown_values = True,
            write_disposition = bigquery.WriteDisposition.WRITE_TRUNCATE
        )

    load_job = bigquery_client.load_table_from_uri(source_uris = gcs_uri,
                                                   destination = destination_table_id,
                                                   job_config = job_config,
                                                   location = location
    )
    load_job.result()

    print(f"BigQuery load completed : {destination_table_id}")


# Deleting uploaded Cloud Storage objects if required
def delete_gcs_object(bucket, object_name):
    blob = bucket.blob(object_name)
    blob.delete()
    print(f"GCS object deleted : {object_name}")


# Processing one category file from download to BigQuery
def process_single_file(storage_client, bigquery_client, configuration, entity_type, category_name):
    source_url = build_source_url(entity_type = entity_type, category_name = category_name)
    object_name = build_gcs_object_name(entity_type = entity_type, category_name = category_name)
    table_name = build_bigquery_table_name(entity_type = entity_type, category_name = category_name)

    bucket = storage_client.bucket(configuration["gcs_raw_bucket_name"])
    gcs_uri = f"gs://{configuration['gcs_raw_bucket_name']}/{object_name}"

    upload_source_file_to_gcs(bucket = bucket,
                              source_url = source_url,
                              object_name = object_name
    )

    load_gcs_file_to_bigquery(bigquery_client = bigquery_client,
                              gcp_project_id = configuration["gcp_project_id"],
                              raw_dataset_id = configuration["bigquery_raw_dataset_id"],
                              gcs_uri = gcs_uri,
                              table_name = table_name,
                              location = configuration["bigquery_location"],
                              entity_type = entity_type
    )

    if DELETE_GCS_OBJECT_AFTER_SUCCESSFUL_LOAD:
        delete_gcs_object(bucket = bucket, object_name = object_name)


# Checking if the Cloud Storage object already exists
def gcs_object_exists(bucket, object_name):
    blob = bucket.blob(object_name)
    return blob.exists()


# Running the raw-data ingestion workflow for all categories
def bigquery_table_exists(bigquery_client, gcp_project_id, raw_dataset_id, table_name):
    table_id = f"{gcp_project_id}.{raw_dataset_id}.{table_name}"

    try:
        bigquery_client.get_table(table_id)
        return True
    except NotFound:
        return False



# Running the raw-data ingestion workflow for all categories
def main():
    configuration = load_project_configuration()
    configure_google_credentials(credentials_path_value = configuration["credentials_path"])

    storage_client = storage.Client(project = configuration["gcp_project_id"])
    bigquery_client = bigquery.Client(project = configuration["gcp_project_id"])

    for category_name in SELECTED_CATEGORIES:
        print(f"\n--- {category_name} :")
        for entity_type in ENTITY_TYPES:
            print(f"\nProcessing : category = {category_name}, entity_type = {entity_type}")
            process_single_file(storage_client = storage_client,
                                bigquery_client = bigquery_client,
                                configuration = configuration,
                                entity_type = entity_type,
                                category_name = category_name
            )

    print("\nRaw Data ingestion completed successfully.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Raw Data ingestion failed : {exc}")
        sys.exit(1)