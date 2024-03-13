import base64
import json
import os
import sys
from datetime import datetime
import github_service as gs
import shared


def process_github_event(headers, msg):  # noqa: C901
    event_type = headers["X-Github-Event"]
    signature = headers["X-Hub-Signature"]
    source = "github"

    if "Mock" in headers:
        source += "mock"

    types = {
        "push",
        "pull_request",
        "pull_request_review",
        "pull_request_review_comment",
        "issues",
        "issue_comment",
        "check_run",
        "check_suite",
        "status",
        "deployment_status",
        "release",
        "workflow_job",
        "workflow_run",
        "secret_scanning_alert",
        "secret_scanning_alert_location",
        "code_scanning_alert",
        "branch_protection_rule",
        "commit_comment",
        "create",  # refers to branches/tags
        "delete",  # same as ^
        "dependabot_alert",
        "deploy_key",
        "deployment",
        "deployment_protection_rule",
        "discussion",
        "discussion_comment",
        "fork",
        "github_app_authorization",
        "gollum",
        "installation",
        "installation_repositories",
        "installation_target",
        "label",
        "marketplace_purchase",
        "member",
        "membership",
        "merge_group",
        "meta",
        "milestone",
        "org_block",
        "organization",
        "package",
        "page_build",
        "personal_access_token_request",
        "ping",
        "project_card",
        "project",
        "project_column",
        "projects_v2",
        "projects_v2_item",
        "public",
        "pull_request_review_thread",
        "registry_package",
        "repository_advisory",
        "repository",
        "repository_dispatch",
        "repository_import",
        "repository_vulnerability_alert",
        "security_advisory",
        "security_and_analysis",
        "sponsorship",
        "star",
        "team_add",
        "team",
        "watch",
        "workflow_dispatch"
    }

    # no id or timestamp properties in their payloads
    unsupported_event = {
        "create",
        "delete",
        "fork",
        "github_app_authorization",
        "gollum",
        "installation",
        "installation_repositories",
        "installation_target",
        "label",
        "marketplace_purchase",
        "member",
        "membership",
        "merge_group",
        "org_block",
        "organization",
        "public",
        "pull_request_review_thread",
        "repository",
        "repository_dispatch",
        "repository_import",
        "star",
        "team_add",
        "team",
        "watch",
        "workflow_dispatch",
        "security_and_analysis"
    }

    # contains an object with the same name as the event type
    standard_event = {
        "pull_request",
        "release",
        "deployment",
        "discussion",
        "milestone",
        "package",
        "page_build",
        "personal_access_token_request",
        "project_card",
        "project",
        "project_column",
        "projects_v2",
        "projects_v2_item",
        "registry_package",
        "sponsorship",
        "workflow_run",
        "workflow_job"
    }

    # contains an "alert" object
    alert_event = {
        "secret_scanning_alert",
        "secret_scanning_alert_location",
        "code_scanning_alert",
        "dependabot_alert",
        "repository_vulnerability_alert"
    }

    # contains a "comment" object
    comment_event = {
        "pull_request_review_comment",
        "discussion_comment",
        "issue_comment",
        "commit_comment"
    }

    # has the "ghsa_id" property
    advisory_event = {
        "repository_advisory",
        "security_advisory"
    }

    # contains a "hook" object
    hook_event = {
        "meta",
        "ping"
    }

    check_event = {
        "check_run",
        "check_suite"
    }

    if event_type not in types or event_type in unsupported_event:
        raise Exception("Unsupported GitHub event: '%s'" % event_type)
    # metadata = json.loads(base64.b64decode(msg["data"]).decode("utf-8").strip())
    metadata = json.loads(msg.decode('utf-8'))

    if event_type in standard_event:
        time_created = (metadata[event_type]["created_at"]
                        or metadata[event_type]["updated_at"])
        e_id = (metadata[event_type]["id"] or metadata[event_type]["node_id"])

    elif event_type in alert_event:
        time_created = (metadata["alert"]["created_at"]
                        or metadata["alert"]["updated_at"])
        e_id = metadata[event_type]["number"]

    elif event_type in comment_event:
        time_created = (metadata["comment"]["created_at"]
                        or metadata["comment"]["updated_at"])
        e_id = metadata[event_type]["id"]

    elif event_type in hook_event:
        time_created = (metadata["hook"]["created_at"] or metadata["hook"]["updated_at"])
        e_id = metadata["hook"]["id"]

    elif event_type in advisory_event:
        time_created = (metadata[event_type]["created_at"]
                        or metadata[event_type]["updated_at"])
        e_id = metadata[event_type]["ghsa_id"]

    elif event_type in check_event:
        time_created = (metadata[event_type]["started_at"]
                        or metadata[event_type]["completed_at"])
        e_id = metadata[event_type]["id"]

    elif event_type == "push":
        if not metadata["head_commit"]:
            repo_name = metadata["repository"]["name"]
            raise Exception(f"This push from {repo_name} does not have head_commit")

        time_created = metadata["head_commit"]["timestamp"]
        e_id = metadata["head_commit"]["id"]

    elif event_type == "pull_request_review":
        time_created = metadata["review"]["submitted_at"]
        e_id = metadata["review"]["id"]

    elif event_type == "issues":
        time_created = metadata["issue"]["updated_at"]
        e_id = metadata["issue"]["number"]

    elif event_type == "deployment_status":
        time_created = metadata["deployment_status"]["updated_at"]
        e_id = metadata["deployment_status"]["id"]
        metadata["deployment"]["additional_sha"] = []

        if metadata["deployment"]["environment"] == "production":
            repo_name = metadata["repository"]["name"]
            main_commit = metadata["deployment"]["sha"]
            previous_deployment = shared.get_previous_deployment(repo_name)

            if (
                previous_deployment is not None
                and not deployments_happened_within_60_secs(
                    previous_deployment.get("time_created"), time_created
                )
            ):
                previous_deployment_metadata = json.loads(
                    previous_deployment.get("metadata")
                )
                same_deployment = shared.get_deployment_by_main_commit(
                    repo_name, main_commit
                )

                if same_deployment is not None:
                    create_rollback_incident(
                        msg["message_id"], previous_deployment_metadata, time_created
                    )
                elif is_hotfix_deployment(
                    previous_deployment.get("time_created"), time_created
                ):
                    create_hotfix_incident(
                        msg["message_id"], previous_deployment_metadata, time_created
                    )

                metadata["deployment"]["additional_sha"] = get_all_commits(
                    repo_name=repo_name,
                    previous_deployment_sha=previous_deployment_metadata["deployment"][
                        "sha"
                    ],
                    current_deployment_sha=main_commit,
                )

    elif event_type == "status":
        time_created = metadata["updated_at"]
        e_id = metadata["id"]

    elif event_type == "branch_protection_rule":
        time_created = metadata["rule"]["created_at"]
        e_id = metadata["rule"]["id"]

    elif event_type == "deploy_key":
        time_created = metadata["key"]["created_at"]
        e_id = metadata["key"]["id"]

    elif event_type == "deployment_protection_rule":
        time_created = metadata["deployment"]["created_at"]
        e_id = metadata["deployment"]["id"]

    github_event = {
        "event_type": event_type,
        "id": e_id,
        "metadata": metadata,
        "time_created": time_created,
        "signature": signature,
        "msg_id": "TBD",
        "source": source,
    }

    return github_event


def get_all_commits(repo_name, previous_deployment_sha, current_deployment_sha):
    commits_compare = gs.get_commits_between(
        repo_name, previous_deployment_sha, current_deployment_sha
    )

    squash_merge_commits = [
        commit["sha"]
        for commit in commits_compare
        if commit["commit"]["committer"]["name"] == "GitHub"
    ]

    commits_pull_request = []
    for commit in squash_merge_commits:
        if commit in commits_pull_request:
            continue
        commits_pull_request = commits_pull_request + gs.get_commits_from_pull_request(
            commit
        )

    list_commits_between = [commit["sha"] for commit in commits_compare]
    unique_commits = set(list_commits_between + commits_pull_request)
    unique_commits.difference_update([current_deployment_sha] + squash_merge_commits)

    return list(unique_commits)


def is_hotfix_deployment(
    previous_deployment_time_created, current_deployment_time_created
):
    previous_deployment_timestamp = previous_deployment_time_created.timestamp()
    current_deployment_timestamp = datetime.strptime(
        current_deployment_time_created, "%Y-%m-%dT%H:%M:%SZ"
    ).timestamp()
    threshold_in_seconds = int(os.getenv("HOTFIX_THRESHOLD_IN_MINUTES", 40)) * 60
    return (
        60
        < (current_deployment_timestamp - previous_deployment_timestamp)
        <= threshold_in_seconds
    )


def create_hotfix_incident(
    message_id, previous_deployment_metadata, current_deployment_time_created
):
    id = "INC{}".format(previous_deployment_metadata["deployment_status"]["id"])
    time_created = previous_deployment_metadata["deployment_status"]["updated_at"]
    shared.insert_row_into_bigquery(
        {
            "event_type": "digital_caused_incident",
            "id": id,
            "metadata": json.dumps(
                {
                    "ticket_number": id,
                    "start_datetime": time_created,
                    "end_datetime": current_deployment_time_created,
                    "team_outcome": "Unknown/Unknown",
                    "digital_caused": True,
                    "resolving_team": "Unknown",
                }
            ),
            "time_created": time_created,
            "signature": shared.create_unique_id(previous_deployment_metadata),
            "msg_id": message_id,
            "source": "github",
        }
    )


def create_rollback_incident(
    message_id, previous_deployment_metadata, current_deployment_time_created
):
    id = "INC{}".format(previous_deployment_metadata["deployment_status"]["id"])
    time_created = previous_deployment_metadata["deployment_status"]["updated_at"]
    shared.insert_row_into_bigquery(
        {
            "event_type": "digital_caused_incident",
            "id": id,
            "metadata": json.dumps(
                {
                    "ticket_number": id,
                    "start_datetime": time_created,
                    "end_datetime": current_deployment_time_created,
                    "team_outcome": "Unknown/Unknown",
                    "digital_caused": True,
                    "resolving_team": "Unknown",
                }
            ),
            "time_created": time_created,
            "signature": shared.create_unique_id(previous_deployment_metadata),
            "msg_id": message_id,
            "source": "github",
        }
    )


def deployments_happened_within_60_secs(
    prev_deploy_time_created, curr_deploy_time_created
):
    curr_deploy_timestamp = datetime.strptime(
        curr_deploy_time_created, "%Y-%m-%dT%H:%M:%SZ"
    ).timestamp()
    prev_deploy_timestamp = prev_deploy_time_created.timestamp()
    return (curr_deploy_timestamp - prev_deploy_timestamp) <= 60
