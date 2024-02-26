import json
import os
import sys

from google.cloud import storage
from dotenv import load_dotenv
from datetime import datetime
import gcs_writer as gcs

load_dotenv()
bucket_name = os.getenv("BUCKET_NAME")

def has_valid_fields(log_data):
    actor = log_data.get("actor")
    user = log_data.get("user")

    if (
        (not any([actor, user]))
        or (actor == user == "dependabot[bot]")
        or (actor == "github-actions[bot]" and user == "dependabot[bot]")
        or (
            actor
            in [
                "deploy_key",
                "dependabot[bot]",
                "github-actions[bot]",
                "github-pages[bot]",
                "seed-deploy[bot]",
            ]
            and not user
        )
    ):
        return False
    return True


def to_bucket_station(log_data):
    if "_document_id" not in log_data:
        print(f"Ignoring log missing _document_id: {json.dumps()}.")
        return

    if not has_valid_fields(log_data):
        print(f"Ignoring log: {log_data['_document_id']}.")
        return 

    def fix_timestamp(ts):
        return datetime.utcfromtimestamp(int(ts) / 1000).strftime('%Y-%m-%d %H:%M:%S')

    payload = {
        "document_id": log_data["_document_id"],
        "timestamp": fix_timestamp(log_data["@timestamp"]),
        "metadata": log_data,
        "actor": log_data["actor"] if "actor" in log_data else None,
        "user": log_data["user"] if "user" in log_data else None,
        "action": log_data["action"] if "action" in log_data else None,
        "org": log_data["org"] if "org" in log_data else None,
        "repo": log_data["repo"] if "repo" in log_data else None,
        "team": log_data["team"] if "team" in log_data else None,
        "pull_request_id": log_data["pull_request_id"] if "pull_request_id" in log_data else None
    }    
    
    errors = gcs.upload_to_gcs(payload)
    if errors:
        print(f"[BigQuery] Error: {errors}", file=sys.stderr)


def read_gcs_object(file_name, bucket_name):  
    if not file_name.endswith(".json.log.gz"):
        print(f"Skiping file: {file_name}.")
        return

    client = storage.Client()
    bucket = client.bucket(bucket_name)
    file_content = bucket.blob(file_name).download_as_text()

    print(f"Processing file: {file_name}.")
    for line_content in file_content.splitlines():        
        log_content = json.loads(line_content)        
        yield log_content

def persist_data(event, context):
    """Triggered by a change to a Cloud Storage bucket.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    for log_content in read_gcs_object(event["name"], event["bucket"]):
        to_bucket_station(log_content)  