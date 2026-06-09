#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import unittest

from telegram_channel_scraper import (
    TelegramChannelScraper,
    TelegramScrapeConfig,
    normalize_channel_name,
    parse_channels,
)


class TelegramChannelScraperTest(unittest.TestCase):
    def test_normalizes_channel_names(self):
        self.assertEqual(normalize_channel_name("@dingyue_Center"), "dingyue_Center")
        self.assertEqual(normalize_channel_name("https://t.me/s/dingyue_Center"), "dingyue_Center")
        self.assertEqual(normalize_channel_name("https://t.me/dingyue_Center"), "dingyue_Center")
        self.assertEqual(normalize_channel_name("../bad"), "")

    def test_parse_channels_dedups_and_defaults(self):
        self.assertEqual(parse_channels(" @dingyue_Center,https://t.me/s/dingyue_Center other_channel "), ["dingyue_Center", "other_channel"])
        self.assertIn("dingyue_Center", parse_channels(""))

    def test_extracts_subscription_urls_from_telegram_html(self):
        scraper = TelegramChannelScraper(TelegramScrapeConfig(channels=["dingyue_Center"]))
        page_html = """
        <div class="tgme_widget_message_text">
          今日订阅:
          <a href="https://example.com/api/v1/client/subscribe?token=abc123def456&amp;flag=meta">link</a>
          https://two.example/api/v1/client/subscribe?token=deadbeef12345678
        </div>
        """

        urls = scraper.extract_from_html(page_html)

        self.assertIn("https://example.com/api/v1/client/subscribe?token=abc123def456&flag=meta", urls)
        self.assertIn("https://two.example/api/v1/client/subscribe?token=deadbeef12345678", urls)


if __name__ == "__main__":
    unittest.main()
