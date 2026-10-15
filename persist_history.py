"""Persist allowlisted collector history without blocking public deployment."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

HISTORY_FILES = (
    'data/history_urls.json', 'data/live_urls.json', 'data/url_first_seen.json',
    'data/stats_daily_history.json', 'data/rate_limit.json',
    'api_urls_results.json', 'discovered_urls.json', 'visited_urls.json',
)


def merge_history(name, base, remote, incoming):
    if name == 'data/url_first_seen.json':
        merged = dict(remote or {})
        for key, value in (incoming or {}).items():
            merged[key] = min(str(merged[key]), str(value)) if key in merged else value
        return merged
    if remote == base:
        return incoming
    if incoming == base:
        return remote
    if name in ('data/history_urls.json', 'discovered_urls.json', 'visited_urls.json'):
        return list(dict.fromkeys((remote or []) + (incoming or [])))
    if name == 'data/stats_daily_history.json':
        original = {item['date']:item for item in base or []}
        merged = {item['date']:item for item in remote or []}
        for item in incoming or []:
            if item['date'] not in merged or merged[item['date']] == original.get(item['date']):
                merged[item['date']] = item
        return [merged[date] for date in sorted(merged)]
    if isinstance(remote, dict) and isinstance(incoming, dict):
        merged = dict(remote)
        for key, value in incoming.items():
            if key not in merged or merged[key] == (base or {}).get(key):
                merged[key] = value
        return merged
    # Live membership is a snapshot, not a history union: concurrent remote updates win.
    return remote


def git(repo, *args, check=True):
    return subprocess.run(['git', '-C', str(repo), *args], check=check,
                          capture_output=True, text=True)


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8')) if path.is_file() else None


def capture(repo):
    files = {}
    for name in HISTORY_FILES:
        incoming = read_json(repo / name)
        original = git(repo, 'show', 'HEAD:' + name, check=False)
        base = json.loads(original.stdout) if original.returncode == 0 else None
        if incoming is not None and incoming != base:
            files[name] = {'base':base, 'incoming':incoming}
    return files


def persist(repo, snapshot, attempts=3):
    if any(name not in HISTORY_FILES for name in snapshot):
        raise ValueError('History snapshot contains a non-allowlisted file')
    if not snapshot:
        return
    for attempt in range(attempts):
        git(repo, 'fetch', 'origin', 'main')
        with tempfile.TemporaryDirectory(prefix='history-persist-') as directory:
            worktree = Path(directory) / 'checkout'
            git(repo, 'worktree', 'add', '--detach', str(worktree), 'FETCH_HEAD')
            try:
                for name, versions in snapshot.items():
                    path = worktree / name
                    merged = merge_history(name, versions['base'], read_json(path), versions['incoming'])
                    if merged is not None:
                        path.parent.mkdir(parents=True, exist_ok=True)
                        path.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
                        git(worktree, 'add', '--', name)
                if git(worktree, 'diff', '--cached', '--quiet', check=False).returncode == 0:
                    return
                git(worktree, '-c', 'user.name=github-actions[bot]',
                    '-c', 'user.email=41898282+github-actions[bot]@users.noreply.github.com',
                    'commit', '-m', 'chore(data): merge collected history [skip ci]')
                result = git(worktree, 'push', 'origin', 'HEAD:main', check=False)
                if result.returncode == 0:
                    return
                if attempt == attempts - 1:
                    raise RuntimeError('History push failed after bounded retries; backup artifact is retained')
            finally:
                git(repo, 'worktree', 'remove', '--force', str(worktree))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['snapshot','persist'])
    parser.add_argument('snapshot', type=Path)
    args = parser.parse_args()
    repo = Path.cwd()
    if args.operation == 'snapshot':
        args.snapshot.parent.mkdir(parents=True, exist_ok=True)
        args.snapshot.write_text(json.dumps(capture(repo), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    else:
        origin = git(repo, 'remote', 'get-url', 'origin').stdout.strip()
        if os.environ.get('GITHUB_REPOSITORY') != 'henryli777/google_ssr_actions' or not re.fullmatch(
            r'https://(?:[^/@]+@)?github\.com/henryli777/google_ssr_actions(?:\.git)?', origin
        ):
            raise ValueError('Only the Henry-owned origin may receive history commits')
        persist(repo, json.loads(args.snapshot.read_text(encoding='utf-8')))
