#!/usr/bin/env python3
"""Split a binary dictionary data file into ordered chunks with SHA-256 manifest."""

import argparse
import hashlib
import json
from pathlib import Path

DEFAULT_CHUNK_SIZE = 4 * 1024 * 1024


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Path to the original binary file")
    parser.add_argument("--output-dir", type=Path, default=Path("."),
                        help="Directory for parts and manifest (default: current directory)")
    parser.add_argument("--chunk-size", type=int, default=DEFAULT_CHUNK_SIZE,
                        help="Bytes per part (default: 4194304)")
    args = parser.parse_args()

    source = args.input
    if not source.is_file():
        parser.error(f"Input file not found: {source}")
    if args.chunk_size <= 0:
        parser.error("--chunk-size must be greater than zero")

    out_dir = args.output_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    whole_hash = hashlib.sha256()
    parts = []
    total_size = 0

    with source.open("rb") as src:
        index = 1
        while True:
            data = src.read(args.chunk_size)
            if not data:
                break

            filename = f"{source.name}.part{index:04d}"
            destination = out_dir / filename
            part_hash = hashlib.sha256(data).hexdigest()
            destination.write_bytes(data)

            whole_hash.update(data)
            total_size += len(data)
            parts.append({
                "index": index,
                "file": filename,
                "size": len(data),
                "sha256": part_hash,
            })
            print(f"Wrote {destination} ({len(data)} bytes)")
            index += 1

    manifest = {
        "format": "dictionary-data-chunks-v1",
        "source_name": source.name,
        "total_size": total_size,
        "chunk_size": args.chunk_size,
        "sha256": whole_hash.hexdigest(),
        "parts": parts,
    }
    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Created {manifest_path}")
    print(f"Total: {total_size} bytes; SHA-256: {manifest['sha256']}")


if __name__ == "__main__":
    main()
