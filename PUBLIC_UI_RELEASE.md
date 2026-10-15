# Public UI-Only Release

Only `henryli777/google_ssr_actions` is a publication target. The `liebesu`
upstream is read-only. A code push now runs public UI tests only; it does not
collect subscriptions, call discovery services, or deploy Pages.

Collection remains on the existing three-hour schedule and explicit dispatch
of `build-and-publish-subscriptions.yml`. Do not dispatch that workflow merely
to verify or publish a UI change.

## Publish Existing Data With Current UI

After approved code reaches the Henry-owned `main` and its UI tests pass:

1. Find the latest successful main run of the collector workflow:

   ```sh
   gh api 'repos/henryli777/google_ssr_actions/actions/workflows/build-and-publish-subscriptions.yml/runs?branch=main&status=success&per_page=10' \
     --jq '.workflow_runs[] | [.id, .run_number, .created_at, .head_sha] | @tsv'
   ```

2. Inspect that run and confirm its `github-pages` artifact is available.
3. Explicitly dispatch the UI-only workflow with that run ID:

   ```sh
   gh workflow run publish-support-navigation.yml \
     --repo henryli777/google_ssr_actions --ref main \
     -f source_run_id=LATEST_SUCCESSFUL_COLLECTOR_RUN_ID
   ```

The workflow serializes with scheduled collection using the same `pages`
concurrency group. It checks source ownership, main branch, workflow,
successful completion, latest successful run, and unchanged run attempt.
It also requires the UI workflow's checkout SHA to match current remote main.
Both checks run again immediately before deployment. If a newer source succeeds
while this request waits, it refuses to deploy the older data. Retry with
the new successful run ID rather than bypassing this check.

Only public `index.html`, `source.html`, `404.html`, and `public-refresh.js`
may change. Existing subscription files, health, statistics, private pages,
and other artifact files must remain byte-for-byte unchanged. Current public
templates use the original artifact's health values, not a new collection.
An expired or missing artifact fails without starting a collector.

## Browser Refresh

Public index and source detail pages check same-origin `health.json` every
60 seconds while visible and when focus, visibility, online state, or bfcache
restore returns. An unchanged publication does not rebuild the page. Changed
data is accepted only after every required resource succeeds and the health
snapshot still matches. Requests, including their bodies, have a 12-second
deadline. Failure preserves the last complete success and retries later.
Optional speed ranking may be absent. Automatic refresh never runs upstream
speed tests. Manual speed buttons remain available with an 8-second deadline.
Transient optional failures retry on subsequent checks even when health is
unchanged; recovery redraws only the ranking without resetting primary views.

No page reload or navigation occurs, preserving the URL query and page state.
Source text refresh preserves selection and scroll. Existing index has no
search or pagination controls to reset. Public support navigation remains
sticky on desktop and mobile; private/admin/login pages are not modified.

## History Persistence

Collection saves an allowlisted history backup artifact for 30 days.
`persist-history` runs independently of Pages deployment. It merges onto
fresh `origin/main`, uses non-force pushes, and retries a concurrent push up
to three times. Distinct history entries survive merges; concurrent live
membership and conflicting daily records retain the remote snapshot.
First-seen dates retain the earliest value. Only explicit state files can be
saved; `data/serpapi_keys.json` and arbitrary `data/*.json` are excluded.
The optional persistence job has a ten-minute budget so network failures cannot
hold the shared publication queue indefinitely.
If persistence fails, inspect the optional job and retained history artifact;
the already-generated public Pages artifact remains deployable.

## Local Verification Without Collection

```sh
python3 -m unittest test_project_support test_publish_safety -v
node --test test_public_refresh.cjs
```

These tests use local fixtures, including a local bare Git remote for the
non-fast-forward retry test. They never call discovery or collector entrypoints.
