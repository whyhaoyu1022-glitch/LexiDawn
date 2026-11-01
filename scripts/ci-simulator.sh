#!/bin/bash
set -euo pipefail
CI_DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.${1:?Missing simulator type}"
CI_SIM_ID="$(xcrun simctl create 'LexiDawn isolated CI' "$CI_DEVICE_TYPE" com.apple.CoreSimulator.SimRuntime.iOS-26-5)"
xcrun simctl boot "$CI_SIM_ID"
xcrun simctl bootstatus "$CI_SIM_ID" -b
xcrun simctl list devices available | grep -F "($CI_SIM_ID)"
echo "LEXIDAWN_SIMULATOR_ID=$CI_SIM_ID" >> "$GITHUB_ENV"
