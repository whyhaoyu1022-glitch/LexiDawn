#!/usr/bin/env python3
"""Split a binary file into ZIP packages with SHA-256 manifest."""

import argparse
import hashlib
import json
import tempfile
import zipfile
from pathlib import Path

DEFAULT_CHUNK_SIZE = 20_000_000

INSTRUCTIONS = """Dictionary Data upload package

Upload every dic_data-package-XXX.zip file into the GitHub folder:
Dictionary Data/

Keep the ZIP filenames unchanged. Do not extract them before uploading.
Each ZIP contains one binary part and the same manifest.json.
After all packages are uploaded, use merge.py to reconstruct and verify
the original file.

Only store and use this data within the scope of your applicable license.
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Path to the original binary file")
    parser.add_argument("--output-dir", type=Path, default=Path("."),
                        help="Directory for ZIP packages (default: current directory)")
    parser.add_argument("--chunk-size", type=int, default=DEFAULT_CHUNK_SIZE,
                        help="Bytes per part (default: 20000000)")
    args = parser.parse_args()

    if not args.input.is_file():
        parser.error(f"Input file not found: {args.input}")
    if args.chunk_size <= 0:
        parser.error("--chunk-size must be greater than zero")

    out_dir = args.output_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    whole_hash = hashlib.sha256()
    parts = []
    total_size = 0

    with tempfile.TemporaryDirectory(prefix="dictionary_parts_", dir=out_dir) as temp:
        temp_dir = Path(temp)

        with args.input.open("rb") as source:
            index = 1
            while True:
                data = source.read(args.chunk_size)
                if not data:
                    break

                part_name = f"dic_data.part{index:04d}"
                part_path = temp_dir / part_name
                part_path.write_bytes(data)

                whole_hash.update(data)
                total_size += len(data)
                parts.append({
                    "index": index,
                    "file": part_name,
                    "size": len(data),
                    "sha256": hashlib.sha256(data).hexdigest(),
                    "package": f"dic_data-package-{index:03d}.zip",
                })
                index += 1

        manifest = {
            "format": "dictionary-data-chunks-v1",
            "source_name": args.input.name,
            "total_size": total_size,
            "chunk_size": args.chunk_size,
            "sha256": whole_hash.hexdigest(),
            "parts": parts,
        }
        manifest_bytes = (
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
        ).encode("utf-8")

        (out_dir / "manifest.json").write_bytes(manifest_bytes)

        for part in parts:
            package_path = out_dir / part["package"]
            part_path = temp_dir / part["file"]
            with zipfile.ZipFile(
                package_path, "w",
                compression=zipfile.ZIP_DEFLATED,
                compresslevel=6,
                allowZip64=True,
            ) as archive:
                archive.writestr("manifest.json", manifest_bytes)
                archive.writestr("UPLOAD_INSTRUCTIONS.txt", INSTRUCTIONS)
                archive.write(part_path, arcname=part["file"])
            print(f"Created {package_path} ({package_path.stat().st_size} bytes)")

    print(f"Total source size: {total_size} bytes")
    print(f"Source SHA-256: {whole_hash.hexdigest()}")


if __name__ == "__main__":
    main()
