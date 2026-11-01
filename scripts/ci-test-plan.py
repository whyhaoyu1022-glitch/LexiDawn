#!/usr/bin/env python3
"""Exhaustive UI sharding: every discovered XCTest method runs once on the main device."""
import argparse
import collections
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def plan():
    methods = []
    for path in sorted((ROOT / 'LexiDawnUITests').glob('*.swift')):
        text = path.read_text()
        for method in re.findall(r'\bfunc\s+(test\w+)\s*\(', text):
            methods.append(f'LexiDawnUITests/{path.stem}/{method}')
    if len(methods) != len(set(methods)) or not methods:
        raise SystemExit('Duplicate or missing UI methods')
    def weight(name):
        if 'LiveMultipleSources' in name: return 440
        if 'ProviderFailureEmptyLoading' in name or 'SynonymComparison' in name: return 200
        if 'InjectedImportFailureMatrix' in name: return 180
        if 'Gallery' in name: return 110
        if 'LiveColdStart' in name: return 100
        return 50
    groups, loads = [[] for _ in range(4)], [0] * 4
    for name in sorted(methods, key=lambda x: (-weight(x), x)):
        index = min(range(4), key=lambda i: (loads[i], i))
        groups[index].append(name); loads[index] += weight(name)
    result = {f'full-{i + 1}': sorted(values) for i, values in enumerate(groups)}
    base = ['testReaderBodySurvivesTenRotationsAndWordRemainsTappable', 'testMatchingDrawsVisibleLinesDisablesBothEndsAndRotates', 'testLargeDynamicTypeThreeThemesRemainReadableInLandscape']
    prefix = 'LexiDawnUITests/Round3UITests/'
    result['large'] = [prefix + name for name in base]
    result['small'] = result['large'] + [prefix + name for name in ['testLiveColdStartImportReadingLookupPersonalMeaningReviewAndRestart', 'testImportRetryDedupSearchFavoritesAndLocalRestart', 'testDictionaryProviderFailureEmptyLoadingAndOfflineCacheEvidence', 'testVocabularySaveFailureDoesNotClaimSuccessAndRetryPersists']]
    executed = [name for key, values in result.items() if key.startswith('full-') for name in values]
    if collections.Counter(executed) != collections.Counter(methods):
        raise SystemExit('Full regression sharding lost or duplicated a test')
    if any(name not in methods for key in ['large', 'small'] for name in result[key]):
        raise SystemExit('Device regression references a missing method')
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('mode', choices=['matrix', 'selectors', 'verify']); parser.add_argument('suite', nargs='?'); args = parser.parse_args()
    result = plan()
    if args.mode == 'matrix':
        print(json.dumps({'include': [{'suite': key, 'device': 'iPhone-SE-3rd-generation' if key == 'small' else 'iPhone-17-Pro-Max' if key == 'large' else 'iPhone-17-Pro'} for key in result]}))
    elif args.mode == 'selectors':
        for method in result[args.suite]: print('-only-testing:' + method)
    else:
        print(json.dumps({'mainTotal': sum(len(v) for k, v in result.items() if k.startswith('full-')), 'suites': {k: len(v) for k, v in result.items()}}, indent=2))
