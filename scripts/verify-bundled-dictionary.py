#!/usr/bin/env python3
"""Verify the approved single MDX, including an actual .app or IPA resource."""
import argparse
import hashlib
import json
import struct
import xml.etree.ElementTree as ET
import zipfile
import zlib
from pathlib import Path

SIZE = 38_774_534
SHA256 = '095e9a98a95ec2a8ce7f4489fa3f338891aa29abce20e88e38ca2c5b117ba443'


def verify(stream):
    digest = hashlib.sha256()
    size = 0
    while data := stream.read(1024 * 1024):
        size += len(data)
        digest.update(data)
    if size != SIZE or digest.hexdigest() != SHA256:
        raise ValueError(f'MDX identity mismatch: size={size}, sha256={digest.hexdigest()}')
    stream.seek(0)
    length = struct.unpack('>I', stream.read(4))[0]
    if not 0 < length <= 1_048_576 or length % 2:
        raise ValueError('Invalid MDX UTF-16LE header length')
    header = stream.read(length)
    checksum = struct.unpack('<I', stream.read(4))[0]
    if checksum != zlib.adler32(header):
        raise ValueError('MDX header checksum mismatch')
    attributes = ET.fromstring(header.decode('utf-16le').rstrip('\0\r\n')).attrib
    expected = {'RequiredEngineVersion': '2.0', 'Encoding': 'UTF-8', 'Encrypted': 'No', 'Format': 'Html'}
    if any(attributes.get(key) != value for key, value in expected.items()):
        raise ValueError('Unsupported MDX metadata: ' + str(attributes))
    key_header = stream.read(40)
    if len(key_header) != 40 or zlib.adler32(key_header) != struct.unpack('>I', stream.read(4))[0]:
        raise ValueError('MDX key-header checksum mismatch')
    key_blocks, entries, _, _, _ = struct.unpack('>5Q', key_header)
    if (key_blocks, entries) != (218, 203_181):
        raise ValueError('Unexpected MDX index')
    return {'bytes': size, 'sha256': digest.hexdigest(), 'format': 'MDX 2.0',
            'encoding': attributes['Encoding'], 'encrypted': False, 'keyBlocks': key_blocks,
            'indexedEntries': entries, 'title': attributes['Title']}


def inspect_app(app):
    path = app / 'BundledDictionary.mdx'
    if any(app.glob('dic_data-package-*.zip')) or (app / 'cedict-reverse.json').exists():
        raise ValueError('Dictionary ZIP packages or retired dictionary leaked into App Bundle')
    with path.open('rb') as stream:
        return verify(stream)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--mdx', type=Path)
    group.add_argument('--app', type=Path)
    group.add_argument('--ipa', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    if args.app:
        report = inspect_app(args.app)
    elif args.ipa:
        with zipfile.ZipFile(args.ipa) as archive:
            if archive.testzip() is not None:
                raise ValueError('IPA CRC validation failed')
            names = archive.namelist()
            resource = 'Payload/LexiDawn.app/BundledDictionary.mdx'
            if names.count(resource) != 1:
                raise ValueError('IPA must contain exactly one complete MDX')
            if any('dic_data-package-' in name or name.endswith('/cedict-reverse.json') for name in names):
                raise ValueError('Retired dictionary or ZIP package in IPA')
            with archive.open(resource) as stream:
                report = verify(stream)
    else:
        with args.mdx.open('rb') as stream:
            report = verify(stream)
    report['inspectedPath'] = str(args.app or args.ipa or args.mdx)
    text = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(text)
    print(text, end='')


if __name__ == '__main__':
    main()
