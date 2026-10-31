#!/usr/bin/env python3
"""Build the CC BY-SA 4.0 reverse index from a user-supplied official CC-CEDICT gzip.

No web scraping or downloads. Keep CONTENT-LICENSES.txt with every derived index.
The bundled snapshot is 2026-10-30. A new upstream release requires explicit review
of the checksum, source notices, release date and client cache version.
"""
import argparse
import gzip
import hashlib
import json
import re
from pathlib import Path

SNAPSHOT_SHA256 = "216f40bc26d65cb074f89d243fe2ec379ac29ad6fccb93f57ee1c9414892902f"
PHRASES = {"carry out", "look into", "new york"}


def build_index(lines):
    index = {}
    for raw in lines:
        line = raw.strip()
        match = re.fullmatch(r"\S+ (\S+) \[[^\]]+\] /(.*)/", line)
        if not match:
            continue
        chinese, glosses = match.groups()
        for gloss in glosses.split("/"):
            gloss = gloss.strip()
            if not gloss:
                continue
            sense = {"id": hashlib.sha256((line + "|" + gloss).encode()).hexdigest()[:20],
                     "en": gloss, "zh": chinese, "line": line}
            for part in gloss.split(";"):
                key = part.strip().lower()
                if key.startswith("to "):
                    key = key[3:]
                if not (re.fullmatch(r"[a-z]+(?:['-][a-z]+)*", key) or key in PHRASES):
                    continue
                values = index.setdefault(key, [])
                if len(values) < 3 and all(old["id"] != sense["id"] for old in values):
                    values.append(sense)
    return dict(sorted(index.items()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Official cedict_1_0_ts_utf-8_mdbg.txt.gz")
    parser.add_argument("output", type=Path, help="Derived JSON, CC BY-SA 4.0")
    args = parser.parse_args()
    checksum = hashlib.sha256(args.input.read_bytes()).hexdigest()
    if checksum != SNAPSHOT_SHA256:
        parser.error("Upstream snapshot differs; review the new release before changing the pinned hash")
    with gzip.open(args.input, "rt", encoding="utf-8") as stream:
        index = build_index(stream)
    args.output.write_text(json.dumps(index, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"Source SHA-256: {checksum}; reverse keys: {len(index)}")


if __name__ == "__main__":
    main()
