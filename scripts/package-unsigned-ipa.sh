#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
export LEXIDAWN_IPA_OUTPUT="${LEXIDAWN_IPA_OUTPUT:?Specify a dedicated output directory}"
export LEXIDAWN_DEVICE_MIN_IOS="${LEXIDAWN_DEVICE_MIN_IOS:-27.0}"
export LEXIDAWN_BUILD_NUMBER="${GITHUB_RUN_NUMBER:-1}"
TASK_DERIVED="${RUNNER_TEMP:?}/lexidawn-device-derived"
mkdir -p "$LEXIDAWN_IPA_OUTPUT"
xcodebuild -version | tee "$LEXIDAWN_IPA_OUTPUT/xcode-version.txt"
xcrun --sdk iphoneos --show-sdk-version | tee "$LEXIDAWN_IPA_OUTPUT/iphoneos-sdk.txt"
python3 scripts/verify-unsigned-ipa.py --icon-only

# A real arm64 iPhoneOS Release build. No test/build-for-testing action, simulator,
# Apple account, certificate, provisioning profile, or signing service is used.
xcodebuild -project LexiDawn.xcodeproj -scheme LexiDawn \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$TASK_DERIVED" \
  IPHONEOS_DEPLOYMENT_TARGET="$LEXIDAWN_DEVICE_MIN_IOS" \
  CURRENT_PROJECT_VERSION="$LEXIDAWN_BUILD_NUMBER" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build 2>&1 | tee "$LEXIDAWN_IPA_OUTPUT/build.log"

TASK_APP="$TASK_DERIVED/Build/Products/Release-iphoneos/LexiDawn.app"
test -d "$TASK_APP"
python3 scripts/verify-bundled-dictionary.py --app "$TASK_APP" --report "$LEXIDAWN_IPA_OUTPUT/bundled-dictionary.json"
TASK_STAGE="$(mktemp -d "${RUNNER_TEMP}/lexidawn-ipa-stage.XXXXXX")"
trap 'rm -rf "$TASK_STAGE"' EXIT
mkdir "$TASK_STAGE/Payload"
ditto "$TASK_APP" "$TASK_STAGE/Payload/LexiDawn.app"
export LEXIDAWN_STAGED_APP="$TASK_STAGE/Payload/LexiDawn.app"

# The linker may create ad-hoc signatures even with signing disabled. Strip only
# actual Mach-O signatures in our staging copy; AltServer signs these locally.
while IFS= read -r -d '' TASK_BINARY; do
  if file -b "$TASK_BINARY" | grep -q 'Mach-O'; then
    if codesign -d "$TASK_BINARY" >/dev/null 2>&1; then
      codesign --remove-signature "$TASK_BINARY"
    fi
  fi
done < <(find "$LEXIDAWN_STAGED_APP" -type f -print0)
if [[ -d "$LEXIDAWN_STAGED_APP/_CodeSignature" ]]; then
  rm -rf "$LEXIDAWN_STAGED_APP/_CodeSignature"
fi
test ! -e "$LEXIDAWN_STAGED_APP/embedded.mobileprovision"
if codesign -d "$LEXIDAWN_STAGED_APP" >/dev/null 2>&1; then
  echo '::error::Staged app is unexpectedly signed.'
  exit 1
fi
python3 scripts/verify-unsigned-ipa.py
(
  cd "$TASK_STAGE"
  /usr/bin/zip -q -r -y "$LEXIDAWN_IPA_OUTPUT/LexiDawn-unsigned.ipa" Payload
)
python3 scripts/verify-unsigned-ipa.py --archive
python3 scripts/verify-bundled-dictionary.py --ipa "$LEXIDAWN_IPA_OUTPUT/LexiDawn-unsigned.ipa" --report "$LEXIDAWN_IPA_OUTPUT/ipa-dictionary.json"
cp docs/signing.md "$LEXIDAWN_IPA_OUTPUT/INSTALL-AltServer.md"
