#!/usr/bin/env python3
"""Portable packaging fault tests and a full native-C scan of the real MDX."""
import argparse
import ctypes
import hashlib
import importlib.util
import json
import subprocess
import tempfile
import time
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MERGE = ROOT / 'Dictionary Data/merge.py'


class MergeFaultTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.folder = Path(self.temp.name)
        self.output = self.folder / 'result.mdx'
        self.original = b'Previous valid user-independent build output'
        self.output.write_bytes(self.original)
        self.data = [b'Explicit fixture first binary part', b'Explicit fixture second binary part']
        self.manifest = {'format': 'dictionary-data-chunks-v1', 'total_size': sum(map(len, self.data)),
                         'sha256': hashlib.sha256(b''.join(self.data)).hexdigest(), 'parts': []}
        for i, part in enumerate(self.data, 1):
            self.manifest['parts'].append({'index': i, 'file': f'dic_data.part{i:04d}', 'size': len(part),
                                          'sha256': hashlib.sha256(part).hexdigest(), 'package': f'dic_data-package-{i:03d}.zip'})
        self.write_packages()

    def tearDown(self):
        self.temp.cleanup()

    def write_packages(self, manifest2=None, omit_part=None):
        for i, data in enumerate(self.data, 1):
            item = self.manifest['parts'][i-1]
            with zipfile.ZipFile(self.folder / item['package'], 'w', zipfile.ZIP_DEFLATED) as archive:
                archive.writestr('manifest.json', json.dumps(manifest2 if i == 2 and manifest2 else self.manifest))
                if omit_part != i:
                    archive.writestr(item['file'], data)

    def run_merge(self, success=False):
        result = subprocess.run(['python3', str(MERGE), '--package-dir', str(self.folder), '--output', str(self.output)], capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stderr)
        self.assertFalse(self.output.with_suffix('.mdx.tmp').exists())
        self.assertEqual(self.output.read_bytes(), b''.join(self.data) if success else self.original)

    def test_both_verified_parts_restore_exact_binary(self): self.run_merge(success=True)
    def test_package_001_missing_preserves_previous_output(self):
        (self.folder / 'dic_data-package-001.zip').unlink(); self.run_merge()
    def test_package_002_missing_preserves_previous_output(self):
        (self.folder / 'dic_data-package-002.zip').unlink(); self.run_merge()
    def test_mismatched_manifests_preserve_previous_output(self):
        self.write_packages(manifest2={**self.manifest, 'sha256': '0' * 64}); self.run_merge()
    def test_missing_chunk_preserves_previous_output(self):
        self.write_packages(omit_part=2); self.run_merge()
    def test_bad_part_sha_preserves_previous_output(self):
        self.manifest['parts'][1]['sha256'] = '0' * 64; self.write_packages(); self.run_merge()
    def test_bad_final_sha_preserves_previous_output(self):
        self.manifest['sha256'] = '0' * 64; self.write_packages(); self.run_merge()
    def test_part_order_is_not_guessed(self):
        self.manifest['parts'].reverse()
        # Keep package membership while intentionally corrupting declared order.
        for part in self.manifest['parts']:
            with zipfile.ZipFile(self.folder / part['package'], 'w') as archive:
                archive.writestr('manifest.json', json.dumps(self.manifest))
                archive.writestr(part['file'], self.data[part['index']-1])
        self.run_merge()


def native_scan(path, directory):
    library = directory / 'libLexiDawnMDX.so'
    source = ROOT / 'LexiDawn/Data/MDX/MDXReader.c'
    subprocess.run(['cc', '-std=gnu11', '-O2', '-Wall', '-Wextra', '-Werror', '-shared', '-fPIC', str(source), '-lz', '-o', str(library)], check=True)
    lib = ctypes.CDLL(str(library)); pointer = ctypes.c_void_p; size = ctypes.c_size_t
    lib.ld_mdx_open.argtypes = [ctypes.c_char_p, ctypes.c_char_p, size]; lib.ld_mdx_open.restype = pointer
    lib.ld_mdx_count.argtypes = [pointer]; lib.ld_mdx_count.restype = size
    lib.ld_mdx_key.argtypes = [pointer, size]; lib.ld_mdx_key.restype = ctypes.c_char_p
    lib.ld_mdx_record.argtypes = [pointer, size, ctypes.POINTER(pointer), ctypes.POINTER(size), ctypes.c_char_p, size]
    lib.ld_mdx_free.argtypes = [pointer]; lib.ld_mdx_close.argtypes = [pointer]
    error = ctypes.create_string_buffer(512)
    if lib.ld_mdx_open(str(directory / 'missing.mdx').encode(), error, 512):
        raise ValueError('Missing MDX incorrectly opened')
    damaged = directory / 'damaged.mdx'; damaged.write_bytes(path.read_bytes()[:1200])
    if lib.ld_mdx_open(str(damaged).encode(), error, 512):
        raise ValueError('Truncated MDX incorrectly opened')
    reader = lib.ld_mdx_open(str(path).encode(), error, 512)
    if not reader: raise ValueError(error.value.decode())
    started = time.monotonic()
    try:
        keys = [lib.ld_mdx_key(reader, i).decode('utf8') for i in range(lib.ld_mdx_count(reader))]
        if len(keys) != 203181: raise ValueError('Wrong native index size')
        keyset = set(keys); links = {}; html = 0; total = 0; largest = 0
        def record(i):
            data = pointer(); count = size()
            if not lib.ld_mdx_record(reader, i, ctypes.byref(data), ctypes.byref(count), error, 512):
                raise ValueError(error.value.decode())
            try: return ctypes.string_at(data, count.value)
            finally: lib.ld_mdx_free(data)
        for i, key in enumerate(keys):
            data = record(i); text = data.rstrip(b'\0\r\n').decode('utf8')
            total += len(data); largest = max(largest, len(data))
            if text.startswith('@@@LINK='):
                target = text[8:]
                if target not in keyset: raise ValueError('Missing internal link target')
                links.setdefault(key, set()).add(target)
            else:
                if '<' not in text: raise ValueError('Non-HTML record')
                html += 1
        def check_links(key, path):
            if key not in links: return
            if key in path or len(path) >= 16: raise ValueError('Cyclic or over-deep internal link')
            for target in links[key]: check_links(target, path | {key})
        for key in links: check_links(key, set())
        # Random/backward seeks and the largest real record exercise cross-block reassembly.
        for key in ['user', 'nod', 'may', 'May', 'take off', 'visit', 'hello']:
            if key not in keyset: raise ValueError('Missing common headword ' + key)
            positions = [i for i, value in enumerate(keys) if value == key]
            if not all(record(i).startswith(b'@@@LINK=') for i in positions):
                raise ValueError('Expected actual alias path for common test headword')
        return {'nativeReader': 'C on host; not iOS XCTest', 'indexedEntries': len(keys),
                'linkedRecords': len(keys)-html, 'htmlRecords': html, 'decompressedBytes': total,
                'largestRecordBytes': largest, 'allRecordsUTF8': True, 'allLinkTargetsPresent': True,
                'allLinkPathsAcyclic': True, 'seconds': round(time.monotonic()-started, 3)}
    finally: lib.ld_mdx_close(reader)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    results = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(MergeFaultTests))
    if not results.wasSuccessful(): raise SystemExit(1)
    with tempfile.TemporaryDirectory() as directory:
        directory = Path(directory); path = directory / 'BundledDictionary.mdx'
        subprocess.run(['python3', str(MERGE), '--package-dir', str(ROOT / 'Dictionary Data'), '--output', str(path)], check=True)
        subprocess.run(['python3', str(ROOT / 'scripts/verify-bundled-dictionary.py'), '--mdx', str(path)], check=True)
        report = native_scan(path, directory)
        report['mdxSHA256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    report['packagingFixtureTests'] = results.testsRun
    report['iOSBuildExecuted'] = False
    report['simulatorExecuted'] = False
    report['sourceCommit'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    report['workingTreeModified'] = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True))
    report['readerSourceSHA256'] = hashlib.sha256((ROOT / 'LexiDawn/Data/MDX/MDXReader.c').read_bytes()).hexdigest()
    text = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True); args.report.write_text(text)
    print(text)


if __name__ == '__main__': main()
