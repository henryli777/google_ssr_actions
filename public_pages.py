"""Pure public-template rendering, also usable without importing the collector."""

import html
import json
from pathlib import Path

METRICS = {
    'TS':'build_time_utc', 'TS_CN':'build_time_cn', 'NEXT':'next_run_utc', 'NEXT_CN':'next_run_cn',
    'ALIVE':'source_alive', 'TOTAL':'source_total', 'NODES':'nodes_total', 'NEW':'sources_new',
    'REMOVED':'sources_removed', 'DAILY_NEW':'daily_new_urls', 'QLEFT':'quota_total_left',
    'QCAP':'quota_total_capacity', 'KOK':'keys_ok', 'KTOTAL':'keys_total',
    'GCOUNT':'google_urls_count', 'GHCOUNT':'github_urls_count', 'TGCOUNT':'telegram_urls_count',
}
for token, protocol in [('SS','ss'), ('VMESS','vmess'), ('VLESS','vless'), ('TROJAN','trojan'), ('HY2','hysteria2')]:
    METRICS[token] = 'protocol_counts.' + protocol
for token, protocol in [('SS','ss'), ('VMESS','vmess'), ('VLESS','vless'), ('TROJAN','trojan'), ('HYSTERIA2','hysteria2')]:
    METRICS[token + '_COUNT'] = 'protocol_counts.' + protocol
for region in ['HK','JP','US','SG','TW','KR']:
    METRICS[region + '_COUNT'] = 'region_counts.' + region.lower()


def render_index(health):
    template = (Path(__file__).parent / 'static/index.html.tpl').read_text(encoding='utf-8')
    head, body = template.split('</head>', 1)
    # Authentication literals remain JavaScript strings; metrics in the body are live text only.
    for token, key in [('AUTH_HASH','auth_sha256'), ('AUTH_USER','auth_user')]:
        head = head.replace('__' + token + '__', json.dumps(str(health.get(key, '')))[1:-1])
    for token, path in METRICS.items():
        value = health
        for key in path.split('.'):
            value = value.get(key, 0) if isinstance(value, dict) else 0
        value = '' if value is None else str(value)
        head = head.replace('__' + token + '__', value)
        body = body.replace('__' + token + '__', '<span data-health="' + path + '">' + html.escape(value) + '</span>')
    return head + '</head>' + body
