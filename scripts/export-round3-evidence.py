#!/usr/bin/env python3
"""Index only real xcresult PNG attachments. Never generate or redraw screenshots."""
import argparse
import csv
import hashlib
import json
import shutil
import zipfile
from pathlib import Path

FIELDS = ["screenshotID", "featureID", "screenName", "state", "device", "orientation", "theme", "testName", "fixtureOrProduction", "fileName", "notes"]


def nodes(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from nodes(child)
    elif isinstance(value, list):
        for child in value:
            yield from nodes(child)


def index(source, output):
    output.mkdir(parents=True, exist_ok=True)
    documents = []
    metadata = []
    for path in source.rglob("*.json"):
        try:
            value = json.loads(path.read_text())
        except (ValueError, UnicodeError):
            continue
        documents.append(value)
        if isinstance(value, dict) and all(key in value for key in FIELDS):
            metadata.append(value)
    pngs = list(source.rglob("*.png"))
    if not pngs:
        raise SystemExit("No native Simulator PNG attachments were exported")
    rows = []
    for entry in sorted(metadata, key=lambda entry: entry["screenshotID"]):
        identifier = entry["screenshotID"]
        matches = [path for path in pngs if identifier in path.name]
        if not matches:
            candidates = []
            for document in documents:
                for node in nodes(document):
                    text = json.dumps(node)
                    if identifier not in text:
                        continue
                    names = [value for value in node.values() if isinstance(value, str) and value.lower().endswith(".png")]
                    for name in names:
                        paths = [path for path in pngs if path.name == Path(name).name]
                        candidates.extend((len(text), path) for path in paths)
            if candidates:
                minimum = min(length for length, _ in candidates)
                matches = list({path for length, path in candidates if length == minimum})
        if len(matches) != 1:
            raise SystemExit(f"Cannot uniquely match screenshot metadata {identifier} to a real PNG")
        data = matches[0].read_bytes()
        if not data.startswith(b"\x89PNG\r\n\x1a\n"):
            raise SystemExit(f"Invalid PNG attachment: {identifier}")
        destination = output / (identifier + ".png")
        shutil.copyfile(matches[0], destination)
        entry["fileName"] = destination.name
        entry["sha256"] = hashlib.sha256(data).hexdigest()
        rows.append(entry)
    if not rows:
        raise SystemExit("Round 3 screenshot metadata is missing; legacy screenshots are not Round 3 evidence")
    manifest = {"status": "captured-not-independent-acceptance", "screenshots": rows}
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    with (output / "screenshots.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    with zipfile.ZipFile(output.parent / "original-pngs.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(source.rglob("*")):
            if path.is_file():
                archive.write(path, "xcresult-originals/" + str(path.relative_to(source)))
        for path in sorted(output.iterdir()):
            if path.is_file():
                archive.write(path, "screenshots/" + path.name)
    # Machine-readable log evidence allows an exact index to be committed after the run.
    print("ROUND3_SCREENSHOT_MANIFEST=" + json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    index(args.source, args.output)
