#!/bin/bash
set -euo pipefail
xcodebuild -version
swift --version
echo 'LEXIDAWN_CI_DEPLOYMENT_TARGET=26.5' >> "$GITHUB_ENV"
if ! xcrun simctl list runtimes | grep -F 'iOS 26.5' >/dev/null; then
  xcodebuild -downloadPlatform iOS
fi
if ! xcrun simctl list runtimes | grep -F 'iOS 26.5' >/dev/null; then
  echo '::error::Approved iOS 26.5 runtime is unavailable.'
  exit 1
fi
python3 - <<'PY'
from pathlib import Path
path = Path('LexiDawn.xcodeproj/project.pbxproj')
original = path.read_text()
assert 'IPHONEOS_DEPLOYMENT_TARGET = 27.0;' in original
path.write_text(original.replace('IPHONEOS_DEPLOYMENT_TARGET = 27.0;', 'IPHONEOS_DEPLOYMENT_TARGET = 26.5;'))
PY
