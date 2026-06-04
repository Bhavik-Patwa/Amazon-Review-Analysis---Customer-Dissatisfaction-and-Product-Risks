import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from google.cloud import bigquery


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ENV_FILE_PATH = PROJECT_ROOT / ".env"


# Loading BigQuery and credential settings
def load_project_configuration():
    load_dotenv(dotenv_path = ENV_FILE_PATH)

    configuration = {"gcp_project_id": os.getenv("GCP_PROJECT_ID"),
                     "bigquery_location": os.getenv("BIGQUERY_LOCATION"),
                     "bigquery_raw_dataset_id": os.getenv("BIGQUERY_RAW_DATASET_ID"),
                     "bigquery_core_dataset_id": os.getenv("BIGQUERY_CORE_DATASET_ID"),
                     "credentials_path": os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    }

    missing_keys = [key for key, value in configuration.items() if not value]
    if missing_keys:
        raise ValueError(f"Missing required environment variables : {missing_keys}")

    return configuration


# Setting Google Cloud authentication
def configure_google_credentials(credentials_path_value):
    credentials_file_path = (PROJECT_ROOT / credentials_path_value).resolve()

    if not credentials_file_path.exists():
        raise FileNotFoundError(f"Credentials file not found : {credentials_file_path}")

    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = str(credentials_file_path)


# Replacing SQL placeholders with project settings
def render_sql(sql_text, configuration):
    rendered_sql = sql_text
    rendered_sql = rendered_sql.replace("{{GCP_PROJECT_ID}}", configuration["gcp_project_id"])
    rendered_sql = rendered_sql.replace("{{BIGQUERY_LOCATION}}", configuration["bigquery_location"])
    rendered_sql = rendered_sql.replace("{{BIGQUERY_RAW_DATASET_ID}}", configuration["bigquery_raw_dataset_id"])
    rendered_sql = rendered_sql.replace("{{BIGQUERY_CORE_DATASET_ID}}", configuration["bigquery_core_dataset_id"])
    return rendered_sql


# Executing one SQL file in BigQuery
def execute_sql_file(sql_file_path, configuration = None):
    sql_file_path = Path(sql_file_path)

    if not sql_file_path.is_absolute():
        sql_file_path = (PROJECT_ROOT / sql_file_path).resolve()

    if not sql_file_path.exists():
        raise FileNotFoundError(f"SQL file not found : {sql_file_path}")

    if configuration is None:
        configuration = load_project_configuration()

    configure_google_credentials(credentials_path_value = configuration["credentials_path"])

    client = bigquery.Client(project = configuration["gcp_project_id"])

    sql_text = sql_file_path.read_text(encoding = "utf-8")
    rendered_sql = render_sql(sql_text = sql_text, configuration = configuration)

    query_job = client.query(
        rendered_sql,
        location = configuration["bigquery_location"]
    )
    query_job.result()

    print(f"SQL script executed successfully : {sql_file_path}")



# Running a SQL script from the command line
def main():
    if len(sys.argv) != 2:
        raise ValueError("Usage : python scripts/run_sql_scripts.py <sql_file_path>")

    configuration = load_project_configuration()
    execute_sql_file(sql_file_path = sys.argv[1], configuration = configuration)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"SQL execution failed : {exc}")
        sys.exit(1)