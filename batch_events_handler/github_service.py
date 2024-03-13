import json
import os
import time
from types import FunctionType

import rate_limiter_search_field_handler
import requests


def make_get_request_to_github(url):
    github_token = os.getenv("GH_TOKEN")

    if not github_token:
        return None
    content = None

    try:
        response = requests.get(
            url=url, headers={"Authorization": f"Bearer {github_token}"}
        )
        content = response.json()

        if not response.ok:
            raise Exception("An error occurred while trying to request data from GitHub")

        return content
    except Exception as e:
        error_entry = {"severity": "WARNING", "msg": str(e), "uri": url}

        if content:
            error_entry["content"] = content
        print(json.dumps(error_entry))
        return None


def get_commits_between(repo_name, base_commit, head_commit):
    if not (repo_name and base_commit and head_commit) or (base_commit == head_commit):
        return []

    uri = f"https://api.github.com/repos/telus/{repo_name}/compare/{base_commit}...{head_commit}"
    compare_commits = make_get_request_to_github(uri)

    if not compare_commits:
        return []

    return compare_commits["commits"]


def get_pull_request_commits_url_from_a_commit_sha(commit_sha):
    fetch_rate_limit_and_wait_if_necessary()

    url_issue = f"https://api.github.com/search/issues?q={commit_sha}&org:telus"

    issues = make_get_request_to_github(url_issue)
    if not issues:
        return ""

    pull_request_urls = [
        item["pull_request"]["url"]
        for item in issues["items"]
        if item.get("pull_request")
    ]
    if not pull_request_urls:
        return ""

    return pull_request_urls[0] + "/commits"


def fetch_rate_limit_and_wait_if_necessary():
    rate_limit_url = "https://api.github.com/rate_limit"
    rate_limit_response = make_get_request_to_github(rate_limit_url)

    rate_limit_data = rate_limiter_search_field_handler.extract_rate_limit_data(
        rate_limit_response
    )

    wait_if_necessary(rate_limit_data)


def wait_if_necessary(rate_limit_data: rate_limiter_search_field_handler.RateLimitData):
    available_calls_count, calls_renewal_timespan = rate_limit_data
    if available_calls_count <= 0:
        EXTRA_WAIT_SECONDS = 5
        time.sleep(calls_renewal_timespan + EXTRA_WAIT_SECONDS)


def get_commits_from_pull_request(deployment_sha):
    if not deployment_sha:
        return []

    url_commits = get_pull_request_commits_url_from_a_commit_sha(deployment_sha)
    if not url_commits:
        return []

    commits = make_get_request_to_github(url_commits)
    if not commits:
        return []

    return [commit["sha"] for commit in commits]
