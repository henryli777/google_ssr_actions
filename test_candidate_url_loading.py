#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import tempfile
import unittest
from pathlib import Path

from aggregator_cli import extract_subscribe_urls_from_candidate, load_candidate_urls


class CandidateUrlLoadingTest(unittest.TestCase):
    def test_extracts_embedded_and_concatenated_subscribe_urls(self):
        noisy = (
            "https://not-a-source.example/link/abc"
            "ERROR:https://bigairport.date/api/v1/client/subscribe?token=1d13e767fc91e01161c37768eb5502f9"
        )
        concatenated = (
            "https://one.example/api/v1/client/subscribe?token=aaaaaaaa"
            "https://two.example/api/v1/client/subscribe?token=bbbbbbbb&amp;flag=meta"
        )
        suffixed = (
            "https://three.example/api/v1/client/subscribe?token=1234567890abcdef1234567890abcdefSub"
            " vless://example-node"
        )

        urls = (
            extract_subscribe_urls_from_candidate(noisy)
            + extract_subscribe_urls_from_candidate(concatenated)
            + extract_subscribe_urls_from_candidate(suffixed)
        )

        self.assertIn(
            "https://bigairport.date/api/v1/client/subscribe?token=1d13e767fc91e01161c37768eb5502f9",
            urls,
        )
        self.assertIn("https://one.example/api/v1/client/subscribe?token=aaaaaaaa", urls)
        self.assertIn("https://two.example/api/v1/client/subscribe?token=bbbbbbbb&flag=meta", urls)
        self.assertIn(
            "https://three.example/api/v1/client/subscribe?token=1234567890abcdef1234567890abcdef",
            urls,
        )

    def test_load_candidate_urls_reads_results_dict_urls(self):
        with tempfile.TemporaryDirectory() as tmp:
            base_dir = Path(tmp)
            data_dir = base_dir / "data"
            data_dir.mkdir()

            (base_dir / "api_urls.txt").write_text(
                "https://seed.example/api/v1/client/subscribe?token=seed123\n",
                encoding="utf-8",
            )
            (base_dir / "discovered_urls.json").write_text(
                json.dumps(
                    [
                        "prefix:https://discovered.example/api/v1/client/subscribe?token=disc123"
                        "https://second.example/api/v1/client/subscribe?token=second123"
                    ]
                ),
                encoding="utf-8",
            )
            (base_dir / "api_urls_results.json").write_text(
                json.dumps(
                    {
                        "total_urls": 1,
                        "urls": [
                            "https://result.example/api/v1/client/subscribe?token=result123",
                        ],
                    }
                ),
                encoding="utf-8",
            )
            (data_dir / "history_urls.json").write_text(
                json.dumps(["https://history.example/api/v1/client/subscribe?token=hist123"]),
                encoding="utf-8",
            )

            urls = set(load_candidate_urls(str(base_dir), str(data_dir)))

        self.assertIn("https://seed.example/api/v1/client/subscribe?token=seed123", urls)
        self.assertIn("https://discovered.example/api/v1/client/subscribe?token=disc123", urls)
        self.assertIn("https://second.example/api/v1/client/subscribe?token=second123", urls)
        self.assertIn("https://result.example/api/v1/client/subscribe?token=result123", urls)
        self.assertIn("https://history.example/api/v1/client/subscribe?token=hist123", urls)


if __name__ == "__main__":
    unittest.main()
