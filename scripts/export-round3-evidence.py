#!/usr/bin/env python3
"""Index only real xcresult PNG attachments. Never generate or redraw screenshots."""
import argparse
import csv
import hashlib
import json
import re
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
    attachment_manifests = {}
    for path in sorted(source.rglob("*.json")):
        try:
            value = json.loads(path.read_text())
        except (ValueError, UnicodeError):
            continue
        documents.append(value)
        if path.name == "manifest.json" and isinstance(value, list):
            attachment_manifests[path.parent] = value
        if isinstance(value, dict) and all(key in value for key in FIELDS):
            metadata.append((path, value))
    pngs = list(source.rglob("*.png"))
    if not pngs:
        raise SystemExit("No native Simulator PNG attachments were exported")
    rows = []
    identifiers = {entry["screenshotID"] for _, entry in metadata}
    counts = {}
    for _, entry in metadata:
        identifier = entry["screenshotID"]
        counts[identifier] = counts.get(identifier, 0) + 1
    for metadata_path, entry in sorted(metadata, key=lambda item: (item[1]["screenshotID"], item[1]["testName"], item[0])):
        identifier = entry["screenshotID"]
        matches = []
        native_manifest = attachment_manifests.get(metadata_path.parent, [])
        for test in native_manifest:
            attachments = test.get("attachments", [])
            sidecar = next((item for item in attachments if item.get("exportedFileName") == metadata_path.name), None)
            if sidecar is None:
                continue
            name = sidecar.get("suggestedHumanReadableName", "")
            sequence = re.match(re.escape(identifier) + r"-metadata_(\d+)_", name)
            if sequence:
                prefix = identifier + "_" + sequence[1] + "_"
                matches = [
                    metadata_path.parent / item["exportedFileName"] for item in attachments
                    if item.get("suggestedHumanReadableName", "").startswith(prefix)
                    and Path(item.get("exportedFileName", "")).suffix.lower() == ".png"
                ]
            break
        if not matches:
            matches = [path for path in pngs if path.parent == metadata_path.parent and identifier in path.name]
        if not matches:
            candidates = []
            for document in documents:
                for node in nodes(document):
                    text = json.dumps(node)
                    if identifier not in text:
                        continue
                    names = [value for value in node.values() if isinstance(value, str) and value.lower().endswith(".png")]
                    for name in names:
                        paths = [path for path in pngs if path.parent == metadata_path.parent and path.name == Path(name).name]
                        candidates.extend((len(text), path) for path in paths)
            if candidates:
                minimum = min(length for length, _ in candidates)
                matches = list({path for length, path in candidates if length == minimum})
        if len(matches) != 1:
            raise SystemExit(f"Cannot uniquely match screenshot metadata {identifier} to a real PNG")
        data = matches[0].read_bytes()
        if not data.startswith(b"\x89PNG\r\n\x1a\n"):
            raise SystemExit(f"Invalid PNG attachment: {identifier}")
        if counts[identifier] > 1:
            suffix = re.sub(r"[^A-Za-z0-9-]+", "-", entry["testName"]).strip("-")
            candidate = identifier + "-" + suffix
            occurrence = 2
            while candidate in identifiers:
                candidate = identifier + "-" + suffix + "-" + str(occurrence)
                occurrence += 1
            identifiers.add(candidate)
            entry["screenshotID"] = candidate
        destination = output / (entry["screenshotID"] + ".png")
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
            # PNG/metadata only. Full videos remain in native attachments and xcresult;
            # duplicating compressed MP4 inside the PNG ZIP wastes CPU, transfer and storage.
            if path.is_file() and path.suffix.lower() in {".png", ".json"}:
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
