#!/bin/bash
set -euo pipefail
TASK_ROOT="${SRCROOT:?Xcode SRCROOT is required}"
TASK_MDX="${DERIVED_FILE_DIR:?}/BundledDictionary.mdx"
TASK_RESOURCES="${TARGET_BUILD_DIR:?}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:?}"
python3 "$TASK_ROOT/Dictionary Data/merge.py" \
  --package-dir "$TASK_ROOT/Dictionary Data" \
  --manifest-package dic_data-package-001.zip --output "$TASK_MDX"
python3 "$TASK_ROOT/scripts/verify-bundled-dictionary.py" --mdx "$TASK_MDX"
mkdir -p "$TASK_RESOURCES"
cp "$TASK_MDX" "$TASK_RESOURCES/BundledDictionary.mdx"
cmp "$TASK_MDX" "$TASK_RESOURCES/BundledDictionary.mdx"
python3 "$TASK_ROOT/scripts/verify-bundled-dictionary.py" --app "$TASK_RESOURCES"
