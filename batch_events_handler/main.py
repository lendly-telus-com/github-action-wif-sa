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

import json
import os
import sys
import uuid
import config

from flask import Flask, g, request
from datetime import datetime

import gcs_writer as gcs

import github_parser_v2 as parser

import dynatrace_parser_v2 as dyna

app = Flask(__name__)


@app.before_request
def before_request_func():
    execution_id = uuid.uuid4()
    g.start_time = datetime.utcnow().isoformat()
    g.execution_id = execution_id
    print(g.execution_id, "ROUTE CALLED ", request.url)


@app.route("/", methods=["GET", "POST"])
def index():
    """
    Receives event data from a webhook, checks if the source is authorized,
    checks if the signature is verified, and then sends the data to Pub/Sub.
    """

    # # Check if the source is authorized
    # source = sources.get_source(request.headers)

    # if source not in sources.AUTHORIZED_SOURCES:
    #     raise Exception(f"Source not authorized: {source}")

    # auth_source = sources.AUTHORIZED_SOURCES[source]
    # signature_sources = {**request.headers, **request.args}
    # signature = signature_sources.get(auth_source.signature, None)
    # body = request.data

    # # Verify the signature
    # verify_signature = auth_source.verification
    # if not verify_signature(signature, body):
    #     raise Exception("Unverified Signature")

    # # Remove the Auth header so we do not publish it to Pub/Sub
    # verify_headers = dict(request.headers)
    # if "Authorization" in verify_headers:
    #     del verify_headers["Authorization"]

    # Publish to Pub/Sub
    # publish_to_pubsub(source, body, pubsub_headers)

    # Mock Source
    source = "dynatrace"

    if source == "dynatrace":
        dyna_event = dyna.parser(request.data)
        gcs.upload_to_gcs(dyna_event)
    elif source == "GitHub-Hookshot":
        # call github-parser-v2 to verify event object and mock headers
        headers = {
            "X-Github-Event": "deployment",
            "X-Hub-Signature": "mock-123"
        }

        event = parser.process_github_event(headers, request.data)
        # call GCS Storage and save
        gcs.upload_to_gcs(event)

    # Flush the stdout to avoid log buffering.
    sys.stdout.flush()
    return "", 204


if __name__ == "__main__":
    PORT = int(os.getenv("PORT")) if os.getenv("PORT") else 8080

    # This is used when running locally. Gunicorn is used to run the
    # application on Cloud Run. See entrypoint in Dockerfile.
    app.run(host="127.0.0.1", port=PORT, debug=True)
