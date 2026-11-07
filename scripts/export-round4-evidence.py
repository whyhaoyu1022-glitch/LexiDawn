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
for row in manifest['screenshots']:
    row['sourceCommit'] = args.commit
    row['workflowRun'] = args.run_url
    match = re.match(r'R4-([PF])(\d\d)', row['screenshotID'])
    row['feedbackImageID'] = 'R4-P'+match[2] if match and match[1]=='P' else ''
    row['requirementIDs'] = ['R4-F'+match[2]] if match else []
    row['referenceImageIDs'] = ['R4-R01','R4-R02','R4-R03'] if match and match[2] in ['22','23','24'] else []
    row['visualReviewStatus'] = 'pending'
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
fields = list(module.FIELDS) + ['osVersion','feedbackImageID','requirementIDs','referenceImageIDs','sourceCommit','workflowRun','sha256','visualReviewStatus']
with (args.output/'screenshots.csv').open('w', newline='') as stream:
    writer = csv.DictWriter(stream, fieldnames=fields, extrasaction='ignore')
    writer.writeheader()
    for row in manifest['screenshots']:
        writer.writerow({k: json.dumps(v, ensure_ascii=False) if isinstance(v,list) else v for k,v in row.items()})
lines = ['# Round 4 native screenshot index', '', 'Status: captured; visual review pending. Fixtures and production evidence remain distinguished.', '', '| ID | File | State | Test |', '|---|---|---|---|']
for row in manifest['screenshots']:
    lines.append(f"| {row['screenshotID']} | [{row['fileName']}]({row['fileName']}) | {row['state']} | {row['testName']} |")
(args.output/'INDEX.md').write_text('\n'.join(lines)+'\n')
with zipfile.ZipFile(args.output.parent/'original-pngs.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(args.source.rglob('*')):
        if path.is_file() and path.suffix.lower() in ['.png','.json']:
            archive.write(path, 'xcresult-originals/'+str(path.relative_to(args.source)))
    for path in sorted(args.output.iterdir()):
        if path.is_file(): archive.write(path, 'screenshots/'+path.name)
print('ROUND4_SCREENSHOT_MANIFEST='+json.dumps(manifest,ensure_ascii=False))
print('Indexed', len(manifest['screenshots']), 'actual PNGs; visual review is still required.')
