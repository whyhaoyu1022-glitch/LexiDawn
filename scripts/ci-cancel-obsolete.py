#!/usr/bin/env python3
"""Cancel superseded main iOS runs, including re-runs with an older concurrency policy.

Uses only the ephemeral workflow token; never deletes runs, artifacts, or another branch.
"""
import json
import os
import re
import urllib.error
import urllib.request


def obsolete(runs, current_sha):
    return [run for run in runs
            if run.get('head_branch') == 'main'
            and run.get('head_sha') != current_sha
            and run.get('status') != 'completed'
            and run.get('event') in {'push', 'workflow_dispatch'}]


def main():
    repository = os.environ['GITHUB_REPOSITORY']
    current_sha = os.environ['GITHUB_SHA']
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
    runs = request('/actions/workflows/ios-ci.yml/runs?branch=main&per_page=100')['workflow_runs']
    for run in obsolete(runs, current_sha):
        # Recheck the branch lease immediately before each mutation.
        if request('/git/ref/heads/main')['object']['sha'] != current_sha:
            print('Main advanced during cleanup; stopping.'); return
        try:
            request('/actions/runs/' + str(int(run['id'])) + '/cancel', 'POST')
            print('Cancelled superseded iOS run', run['id'])
        except urllib.error.HTTPError as error:
            if error.code != 409:
                raise
            print('Run already finished or is being cancelled', run['id'])


if __name__ == '__main__':
    main()
