# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import hashlib
import json

from google.cloud import bigquery

project_id = "fourkeys-31337"
dataset_id = "four_keys_montreal"


def get_data_from_bigquery(query):
    try:
        client = bigquery.Client()
        query_job = client.query(query)
        return [row for row in query_job.result()]
    except Exception as e:
        entry = {
            "severity": "WARNING",
            "msg": "An error occurred while trying to get data from bigquery",
            "errors": str(e),
            "query": query,
        }

        print(json.dumps(entry))
        return []


def insert_row_into_bigquery(event):
    if not event:
        raise Exception("No data to insert")

    # Set up bigquery instance
    client = bigquery.Client()
    table_id = "events_raw"

    table_ref = client.dataset(dataset_id).table(table_id)
    table = client.get_table(table_ref)

    # Insert row
    row_to_insert = [
        (
            event["event_type"],
            event["id"],
            event["metadata"],
            event["time_created"],
            event["signature"],
            event["msg_id"],
            event["source"],
        )
    ]
    bq_errors = client.insert_rows(table, row_to_insert)

    # If errors, log to Stackdriver
    if bq_errors:
        entry = {
            "severity": "WARNING",
            "msg": "Row not inserted.",
            "errors": bq_errors,
            "row": row_to_insert,
        }
        print(json.dumps(entry))


def is_unique(client, signature):
    sql = (
        f"SELECT signature FROM {dataset_id}.events_raw WHERE signature = '{signature}'"
    )
    query_job = client.query(sql)
    results = query_job.result()
    return not results.total_rows


def create_unique_id(msg):
    hashed = hashlib.sha1(bytes(json.dumps(msg), "utf-8"))
    return hashed.hexdigest()


def get_previous_deployment(repo_name):
    query = f"""
        SELECT
          *
        FROM
          `{project_id}.{dataset_id}.events_raw`
        WHERE
          event_type = 'deployment_status'
          AND JSON_EXTRACT_SCALAR(metadata, '$.deployment_status.state') = "success"
          AND JSON_EXTRACT_SCALAR(metadata, '$.repository.name') LIKE '%{repo_name}%'
          AND JSON_EXTRACT_SCALAR(metadata, '$.deployment_status.environment') IN ('production', 'prod')
        ORDER BY
          time_created DESC
        LIMIT
          1
    """
    result = get_data_from_bigquery(query)
    return None if len(result) == 0 else result[0]


def get_deployment_by_main_commit(repo_name, sha):
    expected_query = f"""
        SELECT
          *
        FROM
          `{project_id}.{dataset_id}.events_raw`
        WHERE
          event_type = 'deployment_status'
          AND JSON_EXTRACT_SCALAR(metadata, '$.deployment_status.state') = "success"
          AND JSON_EXTRACT_SCALAR(metadata, '$.repository.name') LIKE '%{repo_name}%'
          AND JSON_EXTRACT_SCALAR(metadata, '$.deployment.sha') = '{sha}'
          AND JSON_EXTRACT_SCALAR(metadata, '$.deployment.environment') IN ('production', 'prod')
        ORDER BY
          time_created DESC
        LIMIT
          1
    """
    result = get_data_from_bigquery(expected_query)
    return None if len(result) == 0 else result[0]
