#!/usr/bin/env python3
"""Cancel superseded main iOS runs, including re-runs with an older concurrency policy.

Uses only the ephemeral workflow token; never deletes runs, artifacts, or another branch.
"""
import json
import os
import re
import urllib.error
import urllib.request


def obsolete(runs, current_sha, cleanup_run_id):
    return [run for run in runs
            if run.get('head_branch') == 'main'
            and run.get('head_sha') != current_sha
            and run.get('status') in {'queued', 'in_progress', 'waiting', 'pending', 'requested'}
            and run.get('id', cleanup_run_id) < cleanup_run_id
            and run.get('event') in {'push', 'workflow_dispatch', 'workflow_run'}]


def main():
    repository = os.environ['GITHUB_REPOSITORY']
    current_sha = os.environ['GITHUB_SHA']
    cleanup_run_id = int(os.environ['GITHUB_RUN_ID'])
    if os.environ.get('GITHUB_EVENT_NAME') != 'push' or os.environ.get('GITHUB_REF') != 'refs/heads/main':
        print('Supersession only applies to a main push.'); return
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise SystemExit('Invalid repository identity')
    token = os.environ['GH_TOKEN']
    base = 'https://api.github.com/repos/' + repository

    def request(path, method='GET'):
        req = urllib.request.Request(base + path, method=method, headers={
            'Authorization': 'Bearer ' + token,
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2026-03-10',
        })
        with urllib.request.urlopen(req, timeout=30) as response:
            data = response.read()
            return json.loads(data) if data else None

    # A delayed older cleanup must never cancel a newer main run.
    if request('/git/ref/heads/main')['object']['sha'] != current_sha:
        print('A newer main already exists; no runs were touched.'); return
    workflows = ['ios-ci.yml']
    if os.environ.get('LEXIDAWN_FINAL_ACCEPTANCE') == 'true':
        workflows += ['unsigned-ipa.yml', 'round4-evidence-recovery.yml']
    runs = [run for workflow in workflows
            for run in request('/actions/workflows/' + workflow + '/runs?branch=main&per_page=100')['workflow_runs']]
    superseded = obsolete(runs, current_sha, cleanup_run_id)
    if not superseded:
        print('No superseded active runs found.')
    for run in superseded:
        # Recheck the branch lease immediately before each mutation.
        if request('/git/ref/heads/main')['object']['sha'] != current_sha:
            print('Main advanced during cleanup; stopping.'); return
        try:
            request('/actions/runs/' + str(int(run['id'])) + '/cancel', 'POST')
            print('Cancellation requested for superseded run', run['id'], run['name'])
        except urllib.error.HTTPError as error:
            if error.code != 409:
                raise
            print('Run already finished or is being cancelled', run['id'])


if __name__ == '__main__':
    main()
