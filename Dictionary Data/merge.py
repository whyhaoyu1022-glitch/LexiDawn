#!/usr/bin/env python3
"""Reassemble ZIP-packaged binary chunks and verify SHA-256 checksums."""

import argparse
import hashlib
import json
import zipfile
from pathlib import Path


def read_manifest(package_path: Path) -> dict:
    with zipfile.ZipFile(package_path, "r") as archive:
        try:
            raw = archive.read("manifest.json")
        except KeyError as exc:
            raise ValueError(f"manifest.json is missing from {package_path}") from exc
    return json.loads(raw.decode("utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package-dir", type=Path, default=Path("."),
                        help="Directory containing all ZIP packages")
    parser.add_argument("--manifest-package", default="dic_data-package-001.zip",
                        help="ZIP package from which to read manifest.json")
    parser.add_argument("--output", type=Path, default=Path("dic_data.reassembled"),
                        help="Path for the reconstructed binary file")
    args = parser.parse_args()

    if Path(args.manifest_package).name != args.manifest_package:
        parser.error("Invalid manifest package filename")

    manifest_package = args.package_dir / args.manifest_package
    if not manifest_package.is_file():
        parser.error(f"Manifest package not found: {manifest_package}")

    manifest = read_manifest(manifest_package)
    if manifest.get("format") != "dictionary-data-chunks-v1":
        parser.error("Unsupported or invalid manifest format")

    parts = manifest.get("parts")
    if not isinstance(parts, list) or not parts:
        parser.error("Manifest contains no parts")

    expected_indices = list(range(1, len(parts) + 1))
    actual_indices = [item.get("index") for item in parts]
    if actual_indices != expected_indices:
        parser.error("Manifest parts are not in sequential order")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    temp_output = args.output.with_name(args.output.name + ".tmp")
    whole_hash = hashlib.sha256()
    total_size = 0

    try:
        with temp_output.open("wb") as target:
            for expected in parts:
                package_name = expected.get("package")
                part_name = expected.get("file")
                if not isinstance(package_name, str) or Path(package_name).name != package_name:
                    raise ValueError(f"Unsafe package filename: {package_name!r}")
                if not isinstance(part_name, str) or Path(part_name).name != part_name:
                    raise ValueError(f"Unsafe part filename: {part_name!r}")

                package_path = args.package_dir / package_name
                if not package_path.is_file():
                    raise FileNotFoundError(f"Missing package: {package_path}")

                with zipfile.ZipFile(package_path, "r") as archive:
                    package_manifest = json.loads(archive.read("manifest.json").decode("utf-8"))
                    if package_manifest != manifest:
                        raise ValueError(f"Manifest mismatch in {package_name}")

                    try:
                        part_stream = archive.open(part_name, "r")
                    except KeyError as exc:
                        raise FileNotFoundError(
                            f"{part_name} is missing from {package_name}"
                        ) from exc

                    part_hash = hashlib.sha256()
                    part_size = 0
                    with part_stream:
                        while True:
                            block = part_stream.read(1024 * 1024)
                            if not block:
                                break
                            target.write(block)
                            part_hash.update(block)
                            whole_hash.update(block)
                            part_size += len(block)
                            total_size += len(block)

                if part_size != expected["size"]:
                    raise ValueError(
                        f"Size mismatch for {part_name}: {part_size} != {expected['size']}"
                    )
                if part_hash.hexdigest() != expected["sha256"]:
                    raise ValueError(f"SHA-256 mismatch for {part_name}")

        if total_size != manifest["total_size"]:
            raise ValueError(
                f"Total size mismatch: {total_size} != {manifest['total_size']}"
            )
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
