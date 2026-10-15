import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from project_support import validate_latest_source_run
from persist_history import capture, git, merge_history, persist, HISTORY_FILES


class PublishSafetyTest(unittest.TestCase):
    def run_fixture(self, number=10, **changes):
        return dict(id=number, run_number=number, run_attempt=1, status='completed',
                    conclusion='success', head_branch='main',
                    path='.github/workflows/build-and-publish-subscriptions.yml',
                    repository={'full_name':'henryli777/google_ssr_actions'},
                    head_repository={'full_name':'henryli777/google_ssr_actions'}) | changes

    def test_latest_successful_main_build_is_required(self):
        source = self.run_fixture()
        args = ('henryli777/google_ssr_actions', source['path'])
        validate_latest_source_run(source, [self.run_fixture(11, conclusion='failure'), source], *args)
        with self.assertRaises(ValueError):
            validate_latest_source_run(source, [self.run_fixture(11), source], *args)
        with self.assertRaises(ValueError):
            validate_latest_source_run(source, [], *args)

    def test_concurrent_snapshots_keep_remote_live_and_all_history(self):
        self.assertEqual(merge_history('data/live_urls.json', ['base'], ['remote'], ['incoming']), ['remote'])
        self.assertEqual(merge_history('data/history_urls.json', ['base'], ['base','remote'], ['base','incoming']), ['base','remote','incoming'])

    def test_daily_history_merges_dates_but_keeps_remote_conflict(self):
        base = [{'date':'2026-10-13','alive_total':1}]
        remote = base + [{'date':'2026-10-14','alive_total':2}]
        incoming = base + [{'date':'2026-10-14','alive_total':3}, {'date':'2026-10-15','alive_total':4}]
        self.assertEqual(merge_history('data/stats_daily_history.json', base, remote, incoming), remote + [incoming[-1]])

    def test_first_seen_preserves_earliest_and_does_not_add_secret_files(self):
        self.assertEqual(merge_history('data/url_first_seen.json', {}, {'a':'2026-10-14'}, {'a':'2026-10-15','b':'2026-10-15'}), {'a':'2026-10-14','b':'2026-10-15'})
        self.assertNotIn('data/serpapi_keys.json', HISTORY_FILES)

    def test_real_non_fast_forward_retry_preserves_remote_and_local_work(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            remote, build, other = (root / name for name in ('remote.git','build','other'))
            subprocess.run(['git','init','--bare',str(remote)], check=True, capture_output=True)
            subprocess.run(['git','clone',str(remote),str(build)], check=True, capture_output=True)
            git(build, 'checkout', '-b', 'main')
            git(build, 'config', 'user.name', 'Fixture')
            git(build, 'config', 'user.email', 'fixture@example.invalid')
            (build / 'data').mkdir()
            file = 'data/history_urls.json'
            (build / file).write_text('["base"]')
            git(build, 'add', '.')
            git(build, 'commit', '-m', 'base')
            git(build, 'push', 'origin', 'main')
            subprocess.run(['git','clone','--branch','main',str(remote),str(other)], check=True, capture_output=True)
            git(other, 'config', 'user.name', 'Fixture')
            git(other, 'config', 'user.email', 'fixture@example.invalid')
            (build / file).write_text('["base","incoming"]')
            (build / 'data/serpapi_keys.json').write_text('{"secret":"not for backup"}')
            (build / 'user-work.txt').write_text('uncommitted user work')
            snapshot = capture(build)
            self.assertEqual(set(snapshot), {file})
            raced = False

            def racing_git(repo, *args, **kwargs):
                nonlocal raced
                if args[:1] == ('push',) and not raced:
                    raced = True
                    (other / file).write_text('["base","remote"]')
                    git(other, 'add', '.')
                    git(other, 'commit', '-m', 'concurrent data')
                    git(other, 'push', 'origin', 'main')
                return git(repo, *args, **kwargs)

            with patch('persist_history.git', side_effect=racing_git):
                persist(build, snapshot)
            self.assertTrue(raced)
            git(other, 'pull', '--ff-only')
            self.assertEqual(json.loads((other / file).read_text()), ['base','remote','incoming'])
            self.assertEqual((build / file).read_text(), '["base","incoming"]')
            self.assertEqual((build / 'user-work.txt').read_text(), 'uncommitted user work')
            self.assertFalse((other / 'data/serpapi_keys.json').exists())


if __name__ == '__main__':
    unittest.main()
