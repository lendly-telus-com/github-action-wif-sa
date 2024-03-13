from datetime import datetime, timezone
from types import FunctionType
from typing import Tuple

RateLimitData = Tuple[int, int]


def extract_rate_limit_data(rate_limit_response: dict) -> RateLimitData:
    available_calls_count = rate_limit_response["resources"]["search"]["remaining"]
    calls_renewal_timespan = rate_limit_response["resources"]["search"]["reset"] - int(
        datetime.now(timezone.utc).timestamp()
    )
    return available_calls_count, calls_renewal_timespan
