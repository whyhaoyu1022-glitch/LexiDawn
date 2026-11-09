#!/usr/bin/env python3
"""Index original xcresult screenshots; enrich metadata, never redraw pixels."""
import argparse
import contextlib
import csv
import importlib.util
import io
import json
import re
import zipfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--commit', required=True)
parser.add_argument('--run-url', required=True)
parser.add_argument('--test-log', nargs='*', type=Path, default=[])
args = parser.parse_args()
assert re.fullmatch('[0-9a-f]{40}', args.commit)
spec = importlib.util.spec_from_file_location('native_png_index', Path(__file__).with_name('export-round3-evidence.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with contextlib.redirect_stdout(io.StringIO()):
    module.index(args.source, args.output)
manifest_path = args.output/'manifest.json'
manifest = json.loads(manifest_path.read_text())
manifest['status'] = 'captured-pending-visual-review'
manifest['sourceCommit'] = args.commit
manifest['workflowRun'] = args.run_url
test_results = {}
for log in args.test_log:
    for name, outcome in re.findall(r"Test Case '([^']+)' (passed|failed)", log.read_text()):
        test_results[name] = outcome
# Existing test names are retained as regression contracts. These current-run
# screenshots can support Round 4, but this association is not acceptance success.
legacy_support = {
    'R3-S01': ['01','02','03'], 'R3-L01': ['04'], 'R3-L04': ['04'],
    'R3-R10': ['07'], 'R3-R11': ['07'], 'R3-X01': ['13'], 'R3-X02': ['13'],
    'R3-D67': ['14'], 'R3-D41': ['15','22'], 'R3-D01': ['16'],
    'R3-N02': ['17'], 'R3-N03': ['15','17'], 'R3-M07': ['11','24'],
    'R3-G10': ['18','24'], 'R3-V05': ['09','23'], 'R3-V06': ['09','23'],
}
for row in manifest['screenshots']:
    row['sourceCommit'] = args.commit
    row['workflowRun'] = args.run_url
    match = re.match(r'R4-([PF])(\d\d)', row['screenshotID'])
    row['feedbackImageID'] = 'R4-P'+match[2] if match and match[1]=='P' else ''
    row['requirementIDs'] = ['R4-F'+match[2]] if match else []
    if not match:
        for prefix, numbers in legacy_support.items():
            if row['screenshotID'].startswith(prefix+'-'):
                row['requirementIDs'] = ['R4-F'+n for n in numbers]
                row['relatedFeedbackImageIDs'] = ['R4-P'+n for n in numbers if int(n) <= 21]
                break
    row['acceptanceIDs'] = row.get('acceptanceIDs', [])
    row['fontSize'] = row.get('fontSize', 'not-recorded-by-historical-test')
    row['actualTestResult'] = test_results.get(row['testName'], 'not-verified-from-test-log')
    row['referenceImageIDs'] = ['R4-R01','R4-R02','R4-R03'] if match and match[2] in ['22','23','24'] else []
    row['visualReviewStatus'] = 'pending'
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
fields = list(module.FIELDS) + ['osVersion','fontSize','feedbackImageID','requirementIDs','referenceImageIDs','acceptanceIDs','sourceCommit','workflowRun','sha256','actualTestResult','visualReviewStatus']
with (args.output/'screenshots.csv').open('w', newline='') as stream:
    writer = csv.DictWriter(stream, fieldnames=fields, extrasaction='ignore')
    writer.writeheader()
    for row in manifest['screenshots']:
        writer.writerow({k: json.dumps(v, ensure_ascii=False) if isinstance(v,list) else v for k,v in row.items()})
lines = ['# Round 4 native screenshot index', '', 'Status: captured; visual review pending. Fixtures and production evidence remain distinguished.', '', '| ID | File | State | Test |', '|---|---|---|---|']
for row in manifest['screenshots']:
    lines.append(f"| {row['screenshotID']} | [{row['fileName']}]({row['fileName']}) | {row['state']} | {row['testName']} |")
(args.output/'INDEX.md').write_text('\n'.join(lines)+'\n')
specification = json.loads((Path(__file__).resolve().parents[1]/'docs/reviews/round-4-feedback-manifest.json').read_text())
requirements = specification['issues'] + specification['supplementalRequirements']
coverage = ['# Round 4 截图覆盖（不是验收通过）', '', f'代码：`{args.commit}`', '', '只关联本次运行的原始 PNG；Fixture、真实 MDX 和资源故障仍分别标记。每项验收必须另核对测试、源码和视觉结果。', '', '| 功能 / 测试族 | 原始截图 | 状态 |', '|---|---|---|']
for requirement in requirements:
    support = [row['fileName'] for row in manifest['screenshots'] if requirement['requirementID'] in row['requirementIDs']]
    coverage.append('| '+requirement['requirementID']+' / '+requirement['testSuiteID']+' | '+(', '.join(support) or 'MISSING')+' | '+('captured; review pending' if support else 'missing')+' |')
(args.output/'COVERAGE.md').write_text('\n'.join(coverage)+'\n')
with zipfile.ZipFile(args.output.parent/'original-pngs.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(args.source.rglob('*')):
        if path.is_file() and path.suffix.lower() in ['.png','.json']:
            archive.write(path, 'xcresult-originals/'+str(path.relative_to(args.source)))
    for path in sorted(args.output.iterdir()):
        if path.is_file(): archive.write(path, 'screenshots/'+path.name)
print('ROUND4_SCREENSHOT_MANIFEST='+json.dumps(manifest,ensure_ascii=False))
print('Indexed', len(manifest['screenshots']), 'actual PNGs; visual review is still required.')
