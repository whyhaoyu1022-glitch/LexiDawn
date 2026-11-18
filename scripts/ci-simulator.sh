#!/bin/bash
set -euo pipefail
CI_DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.${1:?Missing simulator type}"
CI_SIM_ID="$(xcrun simctl create 'LexiDawn isolated CI' "$CI_DEVICE_TYPE" com.apple.CoreSimulator.SimRuntime.iOS-26-5)"
export LEXIDAWN_BOOT_DEVICE_ID="$CI_SIM_ID"
python3 - <<'PYBOOT'
import os
import subprocess

identifier = os.environ['LEXIDAWN_BOOT_DEVICE_ID']
for attempt in range(2):
    print(f'Booting isolated simulator {identifier}, attempt {attempt + 1}/2', flush=True)
    try:
        subprocess.run(['xcrun', 'simctl', 'boot', identifier], check=True, timeout=60)
        subprocess.run(['xcrun', 'simctl', 'bootstatus', identifier, '-b'], check=True, timeout=360)
        break
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError) as error:
        print(f'Simulator startup failed: {error}', flush=True)
        # Only this job-created disposable simulator is restarted. Captured
        # test databases and device files from other jobs are never touched.
        try:
            subprocess.run(['xcrun', 'simctl', 'list', 'devices', 'available'], check=True, timeout=30)
            subprocess.run(['xcrun', 'simctl', 'shutdown', identifier], check=False, timeout=60)
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError) as diagnostic_error:
            print(f'Boot diagnostics failed: {diagnostic_error}', flush=True)
        if attempt == 1:
            raise SystemExit('Simulator failed to become ready after two attempts.') from error
PYBOOT
xcrun simctl list devices available | grep -F "($CI_SIM_ID)"
echo "LEXIDAWN_SIMULATOR_ID=$CI_SIM_ID" >> "$GITHUB_ENV"
