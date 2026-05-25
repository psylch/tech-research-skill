from __future__ import annotations

import importlib.util
import json
import os
import sys
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

MODULE_PATH = Path(__file__).with_name("xquik_source.py")
SPEC = importlib.util.spec_from_file_location("xquik_source", MODULE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Unable to load xquik_source.py")
xquik_source = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = xquik_source
SPEC.loader.exec_module(xquik_source)


class XquikSourceTest(unittest.TestCase):
    def test_headers_support_xquik_key(self) -> None:
        self.assertEqual(xquik_source.headers("xq_test"), {"x-api-key": "xq_test"})

    def test_headers_support_bearer_token(self) -> None:
        self.assertEqual(xquik_source.headers("token"), {"authorization": "Bearer token"})

    def test_evidence_items_normalize_nested_tweets(self) -> None:
        payload = {
            "data": {
                "tweets": [
                    {
                        "id": "123",
                        "text": "  Developers   like this  ",
                        "author": {"username": "alice"},
                        "metrics": {"likes": 8, "retweets": 2, "replies": 1},
                    },
                    {
                        "id": "123",
                        "text": "Developers like this",
                        "author": {"username": "alice"},
                    },
                ]
            }
        }
        items = xquik_source.evidence_items(payload, limit=5)
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0].text, "Developers like this")
        self.assertEqual(items[0].author, "alice")
        self.assertEqual(items[0].url, "https://x.com/alice/status/123")
        self.assertEqual(items[0].likes, 8)
        self.assertEqual(items[0].reposts, 2)
        self.assertEqual(items[0].replies, 1)

    def test_missing_key_returns_skipped_payload(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            output = StringIO()
            with redirect_stdout(output):
                code = xquik_source.main(["search", "Claude Code", "--limit", "1"])
        self.assertEqual(code, 0)
        payload = json.loads(output.getvalue())
        self.assertTrue(payload["skipped"])
        self.assertEqual(payload["items"], [])

    def test_build_payload_marks_success(self) -> None:
        payload = xquik_source.build_payload(
            "tweet_search",
            "Claude Code",
            {"success": True},
            [
                xquik_source.EvidenceItem(
                    text="Useful note",
                    author="alice",
                    url="https://x.com/alice/status/1",
                    likes=1,
                    reposts=2,
                    replies=3,
                    created_at="",
                )
            ],
        )
        self.assertTrue(payload["success"])
        self.assertEqual(payload["items"][0]["author"], "alice")


if __name__ == "__main__":
    unittest.main()
