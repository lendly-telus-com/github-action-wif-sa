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
    try:
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
        
        return payload   
    except Exception as error:        
        print(f"An error occurred in get_target_file: {error}")
        return None      

def read_gcs_object(file_name, bucket_name):  
    if not file_name.endswith(".json.log.gz"):
        print(f"Skiping file: {file_name}.")
        return

    client = storage.Client()
    bucket = client.bucket(bucket_name)
    file_content = bucket.blob(file_name).download_as_text()
    #bucket = client.get_bucket(bucket_name)
    #blob = bucket.get_blob(file_name)
    #file_content = blob.download_as_text()
    
    # # local/mock test
    # client = storage.Client.from_service_account_json(sa_path)  
    # bucket = client.bucket(bucket_name)
    # file_content = bucket.blob(file_path).download_as_text()
    

    print(f"Processing file: {file_name}.")
    for line_content in file_content.splitlines():        
        log_content = json.loads(line_content)        
        yield log_content

# # local/mock test
## ENTRY HERE were mocking the event in Storage by creating a bucket in GCP harcoded with event log 2024/01/01/test1.json.log.gz
# def persist_data(event):
#     for log_content in read_gcs_object(event["name"], event["bucket"]):
#         to_bucket_station(log_content)        
# persist_data({"name": file_path ,"bucket":bucket_name})   


def persist_data(event, context):
    """Triggered by a change to a Cloud Storage bucket.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    results = []
    for log_content in read_gcs_object(event["name"], event["bucket"]):
        results.append(to_bucket_station(log_content))    
    try:
        gcs.upload_to_gcs(results)        
    except Exception as error:        
        print(f"An error occurred in get_target_file: {error}")
         