#!/usr/bin/env python3
"""Combine byte-identical native evidence from all jobs of one workflow/commit."""
import argparse
import csv
import hashlib
import json
import shutil
import zipfile
from pathlib import Path

FIELDS = ["screenshotID", "featureID", "screenName", "state", "device", "orientation", "theme", "testName", "fixtureOrProduction", "fileName", "notes"]


def merge(source, output, commit, run_url):
    destination = output / "screenshots"
    destination.mkdir(parents=True, exist_ok=True)
    rows = {}
    for path in sorted(source.rglob("manifest.json")):
        try:
            document = json.loads(path.read_text())
        except (ValueError, UnicodeError):
            continue
        if not isinstance(document, dict) or "screenshots" not in document:
            continue
        for row in document["screenshots"]:
            if not all(field in row for field in FIELDS):
                raise SystemExit("Incomplete native screenshot metadata")
            filename = row["fileName"]
            if Path(filename).name != filename:
                raise SystemExit("Unsafe screenshot filename")
            image = path.parent / filename
            data = image.read_bytes()
            digest = hashlib.sha256(data).hexdigest()
            if not data.startswith(b"\x89PNG\r\n\x1a\n") or digest != row.get("sha256"):
                raise SystemExit("Native PNG signature/hash mismatch")
            identifier = row["screenshotID"]
            if identifier in rows and rows[identifier]["sha256"] != digest:
                raise SystemExit("Conflicting evidence for one screenshot ID")
            rows[identifier] = row
            shutil.copyfile(image, destination / filename)
    if not rows:
        raise SystemExit("No verified native screenshot metadata was found")
    ordered = [rows[key] for key in sorted(rows)]
    manifest = {"status": "captured-not-independent-acceptance", "sourceCommit": commit, "workflowRun": run_url, "screenshots": ordered}
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    with (output / "screenshots.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS, extrasaction="ignore")
        writer.writeheader(); writer.writerows(ordered)
    index = ["# Round 3 原始截图逐张索引", "", f"代码：`{commit}`", "", f"运行：{run_url}", "", "截图是原生Simulator附件；测试通过与视觉验收须另行核对。", "", "| 编号 | 原始PNG文件 | 功能 / 状态 | 设备 | 数据性质 |", "|---|---|---|---|---|"]
    for row in ordered:
        values = [row["screenshotID"], row["fileName"], row["featureID"] + " / " + row["state"], row["device"], row["fixtureOrProduction"]]
        index.append("| " + " | ".join(str(value).replace("|", "/").replace("\n", " ") for value in values) + " |")
    (output / "INDEX.md").write_text("\n".join(index) + "\n")
    with zipfile.ZipFile(output / "original-pngs.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(destination.iterdir()):
            archive.write(path, "screenshots/" + path.name)
        for name in ["manifest.json", "screenshots.csv", "INDEX.md"]:
            archive.write(output / name, name)
        # Preserve every original attachment PNG, including automatic failure captures.
        # No image decoding, rotation, resizing, rendering or re-encoding occurs.
        for number, package in enumerate(sorted(source.rglob("original-pngs.zip"))):
            with zipfile.ZipFile(package) as original:
                for item in original.infolist():
                    if item.filename.lower().endswith(".png") and item.filename.startswith("xcresult-originals/"):
                        archive.writestr(f"xcresult-originals/job-{number}/" + item.filename.removeprefix("xcresult-originals/"), original.read(item))
    print("ROUND3_COMBINED_MANIFEST=" + json.dumps(manifest, ensure_ascii=False))
    print(f"Combined {len(ordered)} verified native screenshots")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path); parser.add_argument("output", type=Path)
    parser.add_argument("--commit", required=True); parser.add_argument("--run-url", required=True)
    args = parser.parse_args()
    merge(args.source, args.output, args.commit, args.run_url)
