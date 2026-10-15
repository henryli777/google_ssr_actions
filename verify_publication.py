"""Read-only GitHub provenance check for UI-only public artifact republishing."""

import json
import os
from pathlib import Path
import re
import subprocess

from project_support import validate_latest_source_run

REPOSITORY = 'henryli777/google_ssr_actions'
WORKFLOW = '.github/workflows/build-and-publish-subscriptions.yml'


def api(path):
    return json.loads(subprocess.check_output(['gh','api',path], text=True))


def main():
    if os.environ.get('GITHUB_REPOSITORY') != REPOSITORY or os.environ.get('GITHUB_REF') != 'refs/heads/main':
        raise ValueError('UI-only publication must run on the Henry-owned main branch')
    checkout_sha = os.environ.get('GITHUB_SHA', '')
    if not re.fullmatch(r'[a-f0-9]{40}', checkout_sha):
        raise ValueError('UI-only publication requires a valid checkout SHA')
    current_main = api(f'repos/{REPOSITORY}/git/ref/heads/main')
    if (current_main.get('object') or {}).get('sha') != checkout_sha:
        raise ValueError('UI checkout must match current remote main; dispatch again from the latest main')
    run_id = os.environ['SOURCE_RUN_ID']
    if not run_id.isdecimal():
        raise ValueError('Source run id must be numeric')
    source = api(f'repos/{REPOSITORY}/actions/runs/{run_id}')
    latest = api(f'repos/{REPOSITORY}/actions/workflows/build-and-publish-subscriptions.yml/runs?branch=main&status=success&per_page=100')
    validate_latest_source_run(source, latest['workflow_runs'], REPOSITORY, WORKFLOW)
    saved = Path('source-run.json')
    if saved.exists():
        previous = json.loads(saved.read_text(encoding='utf-8'))
        if any(previous.get(key) != source.get(key) for key in ('id','head_sha','run_attempt')):
            raise ValueError('Source build changed after artifact download; retry from the current successful build')
    saved.write_text(json.dumps(source), encoding='utf-8')
    print('Verified latest successful own-main build:', source['id'], source['head_sha'])


if __name__ == '__main__':
    main()
