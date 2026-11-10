#!/usr/bin/env python3
"""Require actual XCTest outcomes for every method assigned to this UI shard."""
import argparse
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('selectors', type=Path)
parser.add_argument('log', type=Path)
args = parser.parse_args()
expected = set()
for line in args.selectors.read_text().splitlines():
    match = re.fullmatch(r'-only-testing:LexiDawnUITests/(\w+)/(test\w+)', line)
    if not match:
        raise SystemExit('Invalid assigned UI selector: ' + line)
    expected.add((match[1], match[2]))
outcomes = re.findall(r"Test Case '-\[(?:\w+\.)?(\w+) (test\w+)\]' (passed|failed)", args.log.read_text())
actual = {(cls, method) for cls, method, _ in outcomes}
failed = {(cls, method) for cls, method, result in outcomes if result == 'failed'}
missing = expected - actual
unexpected = actual - expected
summary = {'expected': len(expected), 'executed': len(actual), 'missing': sorted(missing), 'unexpected': sorted(unexpected), 'failed': sorted(failed)}
print(json.dumps(summary))
if not expected or missing or unexpected or failed:
    raise SystemExit('Native UI shard did not execute every assigned method successfully')
