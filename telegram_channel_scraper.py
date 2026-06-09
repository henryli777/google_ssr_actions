#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Telegram public channel discovery.

This scraper only reads public Telegram web preview pages, for example:
https://t.me/s/dingyue_Center

It does not require Telegram login, API credentials, or private group access.
"""

import html
import os
import re
import time
import typing as t
from dataclasses import dataclass
from urllib.parse import urlparse

import requests
from bs4 import BeautifulSoup  # type: ignore

from url_extractor import URLExtractor  # type: ignore


DEFAULT_UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)

DEFAULT_CHANNELS = ["dingyue_Center"]


@dataclass
class TelegramScrapeConfig:
    channels: t.List[str]
    request_delay_sec: float = 1.5
    timeout_sec: int = 12


def normalize_channel_name(value: str) -> str:
    value = (value or "").strip()
    if not value:
        return ""
    if value.startswith("@"):
        value = value[1:]
    if value.startswith("http://") or value.startswith("https://"):
        parsed = urlparse(value)
        parts = [p for p in parsed.path.split("/") if p]
        if parts and parts[0] == "s":
            parts = parts[1:]
        value = parts[0] if parts else ""
    value = value.strip().strip("/")
    if not re.fullmatch(r"[A-Za-z0-9_]{5,64}", value):
        return ""
    return value


def parse_channels(raw: t.Optional[str]) -> t.List[str]:
    if not raw:
        return list(DEFAULT_CHANNELS)
    channels: t.List[str] = []
    seen: t.Set[str] = set()
    for item in re.split(r"[\s,;]+", raw):
        channel = normalize_channel_name(item)
        if channel and channel not in seen:
            seen.add(channel)
            channels.append(channel)
    return channels or list(DEFAULT_CHANNELS)


class TelegramChannelScraper:
    def __init__(self, config: TelegramScrapeConfig) -> None:
        self.config = config
        self.extractor = URLExtractor()
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": DEFAULT_UA,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Connection": "keep-alive",
        })

    def _channel_url(self, channel: str) -> str:
        return f"https://t.me/s/{channel}"

    def _fetch_text(self, url: str) -> str:
        try:
            resp = self.session.get(url, timeout=self.config.timeout_sec)
            if resp.status_code == 200:
                return resp.text
            return ""
        except Exception:
            return ""

    def extract_from_html(self, page_html: str) -> t.List[str]:
        if not page_html:
            return []

        soup = BeautifulSoup(page_html, "lxml")
        text_parts = [
            soup.get_text("\n"),
            str(soup),
        ]
        for a in soup.find_all("a", href=True):
            text_parts.append(a.get("href") or "")

        combined = html.unescape("\n".join(text_parts))
        urls: t.List[str] = []
        seen: t.Set[str] = set()
        for url in self.extractor.extract_subscription_urls(combined):
            if url not in seen:
                seen.add(url)
                urls.append(url)
        return urls

    def run(self) -> t.List[str]:
        discovered: t.List[str] = []
        seen: t.Set[str] = set()
        for channel in self.config.channels:
            channel = normalize_channel_name(channel)
            if not channel:
                continue
            page_html = self._fetch_text(self._channel_url(channel))
            for url in self.extract_from_html(page_html):
                if url not in seen:
                    seen.add(url)
                    discovered.append(url)
            time.sleep(self.config.request_delay_sec)
        return discovered


def discover_from_telegram(channels: t.Optional[t.List[str]] = None) -> t.List[str]:
    if channels is None:
        channels = parse_channels(os.getenv("TELEGRAM_CHANNELS", ""))
    timeout = int(os.getenv("TELEGRAM_REQUEST_TIMEOUT", "12"))
    delay = float(os.getenv("TELEGRAM_REQUEST_DELAY", "1.5"))
    config = TelegramScrapeConfig(channels=channels, timeout_sec=timeout, request_delay_sec=delay)
    return TelegramChannelScraper(config).run()
