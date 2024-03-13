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

import base64
import json
import os
from datetime import datetime
import hashlib
from dynatrace_entity import determine_repositories


def parser(msg):

    try:
        event = process_new_source_event(msg)
        metadata = json.loads(msg.decode('utf-8'))
        env = None
        status = metadata["ProblemDetailsJSONv2"]["status"]

        allowed_severities = [
            "AVAILABILITY",
            "ERROR",
            "CUSTOM_ALERT",
            "PERFORMANCE",
            "RESOURCE_CONTENTION",
        ]
        if metadata["ProblemDetailsJSONv2"]["severityLevel"] not in allowed_severities:
            return "", 204

        for tag in metadata["ProblemDetailsJSONv2"]["entityTags"]:
            if tag["key"] == "Environment":
                env = tag["value"]
                break

        if env != "production" or status == "OPEN":
            raise Exception(
                f"Problem is not related to production environment or it is still open: env {env}, status {status}"
            )

        for evidence in metadata["ProblemDetailsJSONv2"]["evidenceDetails"]["details"]:
            if evidence["endTime"] == -1:
                raise Exception("Problem is already closed, but some evidences are not.")

        return event
    except Exception as e:
        entry = {
            "severity": "WARNING",
            "msg": "Data not saved to BigQuery",
            "errors": str(e),
            "json_payload": "envelop - TBD",
        }
        print(json.dumps(entry))

    return "", 204


def process_new_source_event(msg):
    metadata = json.loads(msg.decode('utf-8'))

    problem_details = metadata["ProblemDetailsJSONv2"]
    entity_tags = problem_details["entityTags"]

    team = "Unknown"
    outcome = "Unknown"

    for tag in entity_tags:
        if "Squad_" in tag["key"]:
            team = tag["value"]
        elif "Team_" in tag["key"]:
            outcome = tag["key"][5:]

    metadata["team_outcome"] = f"{team}/{outcome}"
    metadata["repositories"] = determine_repositories(metadata)

    timestamp = problem_details["startTime"] / 1000
    time_created = datetime.fromtimestamp(timestamp).isoformat()

    new_source_event = {
        "event_type": "digital_caused_incident",  # Event type, eg "push", "pull_reqest", etc
        "id": metadata["ProblemID"],  # Object ID, eg pull request ID
        "metadata": metadata,  # The body of the msg
        "time_created": time_created,  # The timestamp of with the event
        "signature": create_unique_id(metadata),  # The unique event signature
        "msg_id": "TBD",  # The pubsub message id
        "source": "dynatrace",  # The name of the source, eg "github"
    }
    return new_source_event


def create_unique_id(msg):
    hashed = hashlib.sha1(bytes(json.dumps(msg), "utf-8"))
    return hashed.hexdigest()
