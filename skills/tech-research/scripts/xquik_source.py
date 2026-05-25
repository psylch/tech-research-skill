"""Optional Xquik source for tech-research.

This helper collects read-only X/Twitter evidence for the skill without a
browser session. It uses only the Python standard library and reads credentials
from environment variables.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urljoin
from urllib.request import Request, urlopen

DEFAULT_BASE_URL = "https://xquik.com"
DEFAULT_TIMEOUT_SECONDS = 30
MAX_LIMIT = 25


@dataclass(frozen=True)
class EvidenceItem:
    text: str
    author: str
    url: str
    likes: int | None
    reposts: int | None
    replies: int | None
    created_at: str


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def api_key() -> str:
    return os.getenv("XQUIK_API_KEY") or os.getenv("HERMES_TWEET_API_KEY") or ""


def base_url() -> str:
    return (os.getenv("XQUIK_BASE_URL") or DEFAULT_BASE_URL).rstrip("/") + "/"


def headers(key: str) -> dict[str, str]:
    if key.startswith("xq_"):
        return {"x-api-key": key}
    if key:
        return {"authorization": f"Bearer {key}"}
    return {}


def clamp_limit(value: int) -> int:
    return max(1, min(value, MAX_LIMIT))


def parse_json(text: str) -> Any:
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return {"text": text}


def get_json(path: str, query: dict[str, str], *, timeout: int) -> dict[str, Any]:
    key = api_key()
    if not key:
        return {
            "success": False,
            "skipped": True,
            "error": "Set XQUIK_API_KEY or HERMES_TWEET_API_KEY to enable Xquik source.",
        }

    url = urljoin(base_url(), path.lstrip("/"))
    if query:
        url = f"{url}?{urlencode(query)}"
    request = Request(url=url, headers=headers(key), method="GET")

    try:
        with urlopen(request, timeout=timeout) as response:
            text = response.read().decode("utf-8")
    except HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        return {
            "success": False,
            "status_code": exc.code,
            "error": "Xquik request failed.",
            "response": parse_json(body),
        }
    except URLError as exc:
        return {"success": False, "error": f"Network error: {exc.reason}"}

    parsed = parse_json(text)
    if isinstance(parsed, dict):
        return parsed
    return {"success": True, "data": parsed}


def first(mapping: dict[str, Any], names: tuple[str, ...]) -> Any:
    for name in names:
        if name in mapping:
            return mapping[name]
    return None


def as_int(value: Any) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str) and value.isdecimal():
        return int(value)
    return None


def nested_lists(value: Any) -> list[Any]:
    output: list[Any] = []
    if isinstance(value, list):
        output.extend(value)
        for item in value:
            output.extend(nested_lists(item))
    elif isinstance(value, dict):
        for key, item in value.items():
            if key in {"data", "tweets", "results", "items", "entries", "timeline"}:
                output.extend(nested_lists(item))
    return output


def author_name(item: dict[str, Any]) -> str:
    author = first(item, ("author", "user", "account"))
    if isinstance(author, dict):
        value = first(author, ("username", "screen_name", "handle", "name", "id"))
        if value:
            return str(value).lstrip("@")
    value = first(item, ("username", "screen_name", "author_username", "authorId", "userId"))
    if value:
        return str(value).lstrip("@")
    return ""


def tweet_url(item: dict[str, Any], author: str) -> str:
    value = first(item, ("url", "tweet_url", "link", "permalink"))
    if value:
        return str(value)
    tweet_id = first(item, ("id", "tweet_id", "tweetId", "rest_id"))
    if tweet_id and author:
        return f"https://x.com/{author}/status/{tweet_id}"
    if tweet_id:
        return f"https://x.com/i/web/status/{tweet_id}"
    return ""


def metric(item: dict[str, Any], *names: str) -> int | None:
    value = first(item, names)
    if value is not None:
        return as_int(value)
    metrics = first(item, ("metrics", "public_metrics", "counts", "stats"))
    if isinstance(metrics, dict):
        value = first(metrics, names)
        if value is not None:
            return as_int(value)
    return None


def normalize(item: Any) -> EvidenceItem | None:
    if not isinstance(item, dict):
        return None
    text = first(item, ("text", "full_text", "fullText", "content", "body"))
    if not isinstance(text, str) or not text.strip():
        return None
    author = author_name(item)
    return EvidenceItem(
        text=" ".join(text.split()),
        author=author,
        url=tweet_url(item, author),
        likes=metric(item, "likes", "like_count", "favorite_count", "favorites"),
        reposts=metric(item, "reposts", "retweets", "retweet_count", "repost_count"),
        replies=metric(item, "replies", "reply_count", "comments"),
        created_at=str(first(item, ("created_at", "createdAt", "date", "time")) or ""),
    )


def evidence_items(payload: Any, *, limit: int) -> list[EvidenceItem]:
    output: list[EvidenceItem] = []
    seen: set[tuple[str, str]] = set()
    for item in nested_lists(payload):
        evidence = normalize(item)
        if evidence is None:
            continue
        key = (evidence.url, evidence.text)
        if key in seen:
            continue
        seen.add(key)
        output.append(evidence)
        if len(output) >= limit:
            break
    return output


def build_payload(kind: str, source: str, raw: dict[str, Any], items: list[EvidenceItem]) -> dict[str, Any]:
    return {
        "schema_version": "tech_research.xquik_source.v1",
        "kind": kind,
        "source": source,
        "timestamp": utc_now(),
        "success": raw.get("success", True) is not False and not raw.get("skipped"),
        "skipped": bool(raw.get("skipped")),
        "error": raw.get("error"),
        "items": [
            {
                "text": item.text,
                "author": item.author,
                "url": item.url,
                "likes": item.likes,
                "reposts": item.reposts,
                "replies": item.replies,
                "created_at": item.created_at,
            }
            for item in items
        ],
    }


def command_search(args: argparse.Namespace) -> int:
    limit = clamp_limit(args.limit)
    raw = get_json(
        "/api/v1/x/tweets/search",
        {"q": args.query, "queryType": args.query_type, "limit": str(limit)},
        timeout=args.timeout,
    )
    payload = build_payload("tweet_search", args.query, raw, evidence_items(raw, limit=limit))
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if payload["success"] or payload["skipped"] else 1


def command_trends(args: argparse.Namespace) -> int:
    raw = get_json(
        "/api/v1/x/trends",
        {"woeid": str(args.woeid), "count": str(clamp_limit(args.limit))},
        timeout=args.timeout,
    )
    print(json.dumps(raw, ensure_ascii=False, indent=2))
    return 0 if raw.get("success", True) is not False or raw.get("skipped") else 1


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description="Collect optional Xquik evidence for tech-research.")
    subcommands = root.add_subparsers(dest="command", required=True)

    search = subcommands.add_parser("search", help="Search public X posts.")
    search.add_argument("query")
    search.add_argument("--query-type", choices=("Top", "Latest"), default="Top")
    search.add_argument("--limit", type=int, default=8)
    search.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_SECONDS)
    search.set_defaults(func=command_search)

    trends = subcommands.add_parser("trends", help="Fetch X trends by WOEID.")
    trends.add_argument("--woeid", type=int, default=1)
    trends.add_argument("--limit", type=int, default=10)
    trends.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_SECONDS)
    trends.set_defaults(func=command_trends)

    return root


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    sys.exit(main())
