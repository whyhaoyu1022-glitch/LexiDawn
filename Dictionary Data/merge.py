#!/usr/bin/env python3
"""Reassemble chunks created by split.py and verify SHA-256 checksums."""

import argparse
import hashlib
import json
from pathlib import Path


def digest_stream(stream, output=None):
    digest = hashlib.sha256()
    size = 0
    while True:
        block = stream.read(1024 * 1024)
        if not block:
            break
        digest.update(block)
        size += len(block)
        if output is not None:
            output.write(block)
    return size, digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=Path("manifest.json"))
    parser.add_argument("--output", type=Path, default=Path("dic_data.reassembled"))
    args = parser.parse_args()

    if not args.manifest.is_file():
        parser.error(f"Manifest not found: {args.manifest}")

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if manifest.get("format") != "dictionary-data-chunks-v1":
        parser.error("Unsupported or invalid manifest format")

    base_dir = args.manifest.parent
    temp_output = args.output.with_name(args.output.name + ".tmp")
    whole_hash = hashlib.sha256()
    total_size = 0

    try:
        with temp_output.open("wb") as target:
            for expected in manifest["parts"]:
                name = expected["file"]
                if Path(name).name != name:
                    raise ValueError(f"Unsafe part filename in manifest: {name!r}")
                part_path = base_dir / name
                if not part_path.is_file():
                    raise FileNotFoundError(f"Missing part: {part_path}")

                part_hash = hashlib.sha256()
                part_size = 0
                with part_path.open("rb") as part:
                    while True:
                        block = part.read(1024 * 1024)
                        if not block:
                            break
                        target.write(block)
                        part_hash.update(block)
                        whole_hash.update(block)
                        part_size += len(block)
                        total_size += len(block)

                actual_hash = part_hash.hexdigest()
                if part_size != expected["size"]:
                    raise ValueError(f"Size mismatch for {name}: {part_size} != {expected['size']}")
                if actual_hash != expected["sha256"]:
                    raise ValueError(f"SHA-256 mismatch for {name}")

        if total_size != manifest["total_size"]:
            raise ValueError(f"Total size mismatch: {total_size} != {manifest['total_size']}")
        if whole_hash.hexdigest() != manifest["sha256"]:
            raise ValueError("Final SHA-256 mismatch; output is not trusted")

        temp_output.replace(args.output)
        print(f"Verified and created: {args.output}")
        print(f"Size: {total_size} bytes")
        print(f"SHA-256: {whole_hash.hexdigest()}")
    except Exception:
        if temp_output.exists():
            temp_output.unlink()
        raise


if __name__ == "__main__":
    main()
