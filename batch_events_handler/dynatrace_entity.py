import re
from typing import List


def get_impacted_services_names(dynatrace_event: dict) -> List[str]:
    return [
        entity["name"]
        for entity in dynatrace_event["ProblemDetailsJSONv2"]["impactedEntities"]
        if entity["entityId"]["type"] == "SERVICE"
    ]


def determine_repositories(dynatrace_event: dict) -> List[str]:
    services_names = get_impacted_services_names(dynatrace_event)
    repos_with_nones = [determine_repository(name) for name in services_names]
    repos_without_nones = [repo for repo in repos_with_nones if repo]
    return repos_without_nones


repo_pattern = re.compile(r"^([-\w]+)(?: \(|-)prod")


def determine_repository(impacted_entity_name: str) -> str:
    match = repo_pattern.match(impacted_entity_name)
    return match and match.group(1)
