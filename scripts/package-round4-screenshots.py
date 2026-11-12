#!/usr/bin/env python3
"""Pair verified original HEICs and reference JPEGs with untouched Simulator captures."""

import argparse
import hashlib
import json
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def verified_bytes(content, expected, name, size=None):
    if (size is not None and len(content) != size) or hashlib.sha256(content).hexdigest() != expected:
        raise ValueError(f"Size or SHA-256 mismatch: {name}")
    return content


def safe_filename(value):
    if not value or "/" in value or "\\" in value or value in (".", ".."):
        raise ValueError(f"Invalid screenshot filename: {value!r}")
    return value


def package(original_zip, screenshots, output):
    review = json.loads((ROOT / "artifacts/round-4/original-image-recheck.json").read_text())
    feedback = json.loads((ROOT / "docs/reviews/round-4-feedback-manifest.json").read_text())
    manifest = json.loads((screenshots / "manifest.json").read_text())
    if len(review["images"]) != 21 or len(feedback["referenceImages"]) != 3 or not manifest["screenshots"]:
        raise ValueError("The package requires 21 original photos, 3 references and native captures")
    verified_bytes(original_zip.read_bytes(), review["archiveSHA256"], original_zip.name)
    indexed = {}
    rows = []
    with zipfile.ZipFile(original_zip) as source, zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for row in review["images"]:
            filename = safe_filename(row["originalFile"])
            matches = [name for name in source.namelist() if Path(name).name == filename and "__MACOSX" not in Path(name).parts]
            if len(matches) != 1:
                raise ValueError(f"Expected exactly one original image: {filename}")
            path = "original/" + filename
            archive.writestr(path, verified_bytes(source.read(matches[0]), row["sha256"], filename, row["sizeBytes"]))
            rows.append((row["imageID"], path))
        for row in feedback["referenceImages"]:
            filename = safe_filename(row["originalFile"])
            content = (ROOT / row["repositoryFile"]).read_bytes()
            archive.writestr("reference/" + filename, verified_bytes(content, row["sha256"], filename, row["sizeBytes"]))
        for row in manifest["screenshots"]:
            filename = safe_filename(row["fileName"])
            if filename in indexed or not filename.endswith(".png"):
                raise ValueError(f"Duplicate or invalid native screenshot: {filename}")
            png = verified_bytes((screenshots / filename).read_bytes(), row["sha256"], filename)
            if not png.startswith(b"\x89PNG\r\n\x1a\n"):
                raise ValueError(f"Invalid PNG signature: {filename}")
            archive.writestr("native/" + filename, png)
            indexed[filename] = row
            if row["actualTestResult"] == "failed" or any(
                state in row["state"].lower() for state in ("failed", "failure", "error", "corrupt", "missing")
            ):
                archive.writestr("failures/" + filename, png)
        for filename in ("manifest.json", "screenshots.csv", "INDEX.md", "COVERAGE.md", "COMPARISON.md"):
            archive.write(screenshots / filename, "native/" + filename)
        table = [
            "# Round 4 原图与运行截图",
            "",
            "原图、参考图和运行 PNG 保留原始字节。运行结果按具体设备与方法记录，逐图视觉验收仍需独立确认。",
            "",
            "| 编号 | 原件 | 本次运行截图（测试结果） |",
            "|---|---|---|",
        ]
        for issue, path in rows:
            matches = []
            for filename, row in indexed.items():
                if (row["feedbackImageID"] == issue or issue in row.get("relatedFeedbackImageIDs", [])
                        or issue.replace("R4-P", "R4-F") in row["requirementIDs"]):
                    matches.append(f"[{filename}](native/{filename}) ({row['actualTestResult']})")
            table.append(f"| {issue} | [{Path(path).name}]({path}) | {', '.join(matches) or '缺少本次运行图'} |")
        archive.writestr("INDEX.md", "\n".join(table) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original-zip", type=Path, required=True)
    parser.add_argument("--screenshots", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.original_zip.resolve() == args.output.resolve():
        parser.error("The output must differ from the original ZIP")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=args.output.parent) as temporary:
        staged = Path(temporary) / "screenshots.zip"
        package(args.original_zip, args.screenshots, staged)
        with zipfile.ZipFile(staged) as archive:
            damaged = archive.testzip()
            if damaged:
                raise ValueError(f"Archive CRC verification failed: {damaged}")
        staged.replace(args.output)


if __name__ == "__main__":
    main()
