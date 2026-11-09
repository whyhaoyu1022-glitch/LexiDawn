#!/usr/bin/env python3
"""Verify actual build artifacts; never label an unsigned IPA as installed."""
import argparse
import hashlib
import json
import os
import plistlib
import struct
import subprocess
import zipfile
import zlib
from pathlib import Path

ICON = Path('LexiDawn/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png')


def verify_icon():
    data = ICON.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'Not PNG'
    offset = 8
    pixels = b''
    ended = False
    while offset < len(data):
        length = struct.unpack_from('>I', data, offset)[0]
        end = offset + 12 + length
        assert end <= len(data), 'Truncated icon chunk'
        kind = data[offset+4:offset+8]
        content = data[offset+8:end-4]
        assert zlib.crc32(kind + content) == struct.unpack_from('>I', data, end-4)[0], 'Icon CRC error'
        if kind == b'IHDR':
            width, height, depth, colour, compression, filtering, interlace = struct.unpack('>IIBBBBB', content)
            assert (width, height, depth, colour, compression, filtering, interlace) == (1024, 1024, 8, 2, 0, 0, 0), 'Expected opaque 1024 RGB icon'
        if kind == b'IDAT':
            pixels += content
        if kind == b'IEND':
            assert length == 0 and end == len(data), 'Invalid PNG end'
            ended = True
        offset = end
    assert ended and len(zlib.decompress(pixels)) == 1024 * (1024 * 3 + 1), 'Incomplete pixels'
    return hashlib.sha256(data).hexdigest()


def inspect_app(app):
    with (app / 'Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    assert info['CFBundleIdentifier'] == 'com.lexidawn.app'
    assert info['CFBundleDisplayName'] == 'LexiDawn'
    assert info['CFBundleShortVersionString'] == '0.1.0'
    assert info['CFBundleVersion'] == os.environ['LEXIDAWN_BUILD_NUMBER']
    assert info['MinimumOSVersion'] == os.environ['LEXIDAWN_DEVICE_MIN_IOS']
    assert info['CFBundleSupportedPlatforms'] == ['iPhoneOS'], 'Simulator build rejected'
    primary = info['CFBundleIcons']['CFBundlePrimaryIcon']
    assert primary['CFBundleIconName'] == 'AppIcon'
    assert primary['CFBundleIconFiles'] and (app / 'Assets.car').stat().st_size > 0
    assert list(app.glob('AppIcon*.png')), 'Compiled phone icon missing'
    assert not (app / 'embedded.mobileprovision').exists()
    assert not (app / '_CodeSignature').exists()
    assert not list(app.rglob('*.xctest')), 'Test bundle included'
    for marker in [b'-UITest', b'-forceStartupFailure', b'LEXIDAWN_SCREENSHOT_FIXTURE', b'-failNextPersistenceSave']:
        assert marker not in (app / info['CFBundleExecutable']).read_bytes(), 'Debug fixture marker included'
    binary = (app / info['CFBundleExecutable']).read_bytes()
    assert struct.unpack_from('<I', binary)[0] == 0xFEEDFACF, 'Expected thin 64-bit Mach-O'
    assert struct.unpack_from('<I', binary, 4)[0] == 0x0100000C, 'Expected arm64'
    count = struct.unpack_from('<I', binary, 16)[0]
    offset = 32
    platform = None
    for _ in range(count):
        command, size = struct.unpack_from('<II', binary, offset)
        assert size >= 8 and offset + size <= len(binary)
        assert command != 0x1D, 'Main executable still has LC_CODE_SIGNATURE'
        if command == 0x32:
            platform = struct.unpack_from('<I', binary, offset+8)[0]
        offset += size
    assert platform == 2, 'Mach-O is not a physical iOS build'
    return info


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--icon-only', action='store_true')
    parser.add_argument('--archive', action='store_true')
    args = parser.parse_args()
    icon_hash = verify_icon()
    if args.icon_only:
        print('Verified complete opaque 1024x1024 AppIcon PNG: ' + icon_hash)
        return
    app = Path(os.environ['LEXIDAWN_STAGED_APP'])
    info = inspect_app(app)
    out = Path(os.environ['LEXIDAWN_IPA_OUTPUT'])
    report = {
        'sourceCommit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
        'workflowRun': os.environ.get('GITHUB_SERVER_URL', 'https://github.com') + '/' + os.environ.get('GITHUB_REPOSITORY', 'whyhaoyu1022-glitch/LexiDawn') + '/actions/runs/' + os.environ.get('GITHUB_RUN_ID', 'local'),
        'displayName': info['CFBundleDisplayName'], 'bundleIdentifier': info['CFBundleIdentifier'],
        'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'],
        'minimumOSVersion': info['MinimumOSVersion'], 'platform': 'iPhoneOS', 'architecture': 'arm64',
        'signed': False, 'installedOnDevice': False, 'testsRerun': False, 'appIconSHA256': icon_hash,
        'xcode': (out / 'xcode-version.txt').read_text().strip(), 'sdk': (out / 'iphoneos-sdk.txt').read_text().strip(),
    }
    if args.archive:
        ipa = out / 'LexiDawn-unsigned.ipa'
        with zipfile.ZipFile(ipa) as archive:
            assert archive.testzip() is None
            assert 'Payload/LexiDawn.app/Info.plist' in archive.namelist()
            assert archive.read('Payload/LexiDawn.app/' + info['CFBundleExecutable']) == (app / info['CFBundleExecutable']).read_bytes()
            assert all(name.startswith('Payload/') for name in archive.namelist())
            assert not any(name.endswith('embedded.mobileprovision') or '/_CodeSignature/' in name for name in archive.namelist())
        report['ipaSHA256'] = hashlib.sha256(ipa.read_bytes()).hexdigest()
        report['ipaSizeBytes'] = ipa.stat().st_size
        assert report['ipaSizeBytes'] > 100000
        (out / 'SHA256SUMS.txt').write_text(report['ipaSHA256'] + '  LexiDawn-unsigned.ipa\n')
    (out / 'build-manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(report, ensure_ascii=False))


if __name__ == '__main__':
    main()
