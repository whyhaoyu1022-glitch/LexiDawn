#!/usr/bin/env python3
"""Check explicit required states against captured native evidence, never test-call counts."""
import argparse
import json
import re
from pathlib import Path


def verify(requirements_path, manifest_path, report_path):
    specification = json.loads(requirements_path.read_text())
    requirements = specification['requirements']
    manifest = json.loads(manifest_path.read_text())
    rows = manifest.get('screenshots', [])
    result = []
    for requirement in requirements:
        matches = [row for row in rows if re.search(requirement['screenshotIDPattern'], row['screenshotID'])]
        result.append({**requirement, 'captured': bool(matches), 'evidence': [row['fileName'] for row in matches]})
    source_rows = {}
    for row in rows:
        match = re.match(r'^R3-S-(.+?)-(library|body|scrolled|end)-', row['screenshotID'])
        if match:
            source_rows.setdefault(match[1], set()).add(match[2])
    complete_sources = sorted(source for source, states in source_rows.items() if states == {'library', 'body', 'scrolled', 'end'})
    missing_sources = sorted(source for source in source_rows if source not in complete_sources)
    failed = [item for item in result if not item['captured']]
    missing_devices = []
    for label, device in specification.get('requiredDeviceModels', {}).items():
        for capture in ['R3-R02-', 'R3-M06-', 'R3-R06-', 'R3-R07-', 'R3-R08-']:
            if not any(row['device'] == device and row['screenshotID'].startswith(capture) and row['orientation'] == 'landscape' for row in rows):
                missing_devices.append(label + ':' + capture)
    lines = ['# Round 3 原生截图覆盖核对', '', '代码：`' + manifest.get('sourceCommit', 'not-declared') + '`', '',
             '这份核对只确认实际索引含对应原始 PNG，不能代替视觉审阅、测试结果或 VoiceOver 听读。', '',
             f'已索引 {len(rows)} 张；要求 {len(result)} 项，未匹配 {len(failed)} 项；完整逐源首/中/末证据 {len(complete_sources)} 源。', '',
             '| 需求编号 | 状态 | 实际 PNG |', '|---|---|---|']
    for item in result:
        files = ', '.join(item['evidence']) or '**MISSING**'
        lines.append('| ' + item['requirementID'] + ' | ' + item['state'] + ' | ' + files + ' |')
    lines += ['', '完整逐源证据：' + (', '.join(complete_sources) or 'MISSING'), '', '不完整逐源证据：' + (', '.join(missing_sources) or '无'), '']
    report_path.write_text('\n'.join(lines))
    lines += ['缺失设备专项：' + (', '.join(missing_devices) or '无'), '']
    report_path.write_text('\n'.join(lines))
    summary = {'missingDeviceEvidence': missing_devices, 'requiredStates': len(result), 'missingStates': [item['requirementID'] for item in failed], 'completeLiveSources': complete_sources, 'incompleteLiveSources': missing_sources}
    print(json.dumps(summary, ensure_ascii=False))
    return not failed and len(complete_sources) >= 5 and not missing_sources and not missing_devices


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--requirements', type=Path, default=Path('artifacts/round-3/screenshots/coverage-requirements.json'))
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(0 if verify(args.requirements, args.manifest, args.report) else 1)
