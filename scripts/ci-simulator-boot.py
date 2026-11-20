#!/usr/bin/env python3
"""Bounded readiness checks for the disposable simulator created by this job."""
import subprocess
import sys


def boot_simulator(identifier, run=subprocess.run, report=print):
    for attempt in range(2):
        report(f'Booting isolated simulator {identifier}, attempt {attempt + 1}/2', flush=True)
        try:
            result = run(['xcrun', 'simctl', 'boot', identifier], check=False, timeout=60)
            if result.returncode:
                report(f'Boot command returned {result.returncode}; checking actual readiness.', flush=True)
            # A device may already be booted. Only bootstatus success proves ready.
            run(['xcrun', 'simctl', 'bootstatus', identifier, '-b'], check=True, timeout=360)
            return
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError) as error:
            report(f'Simulator startup failed: {error}', flush=True)
            # A failed diagnostic must never prevent shutdown of this job's
            # disposable device before the next attempt. No other device is touched.
            commands = [(['xcrun', 'simctl', 'list', 'devices', 'available'], 30),
                        (['xcrun', 'simctl', 'shutdown', identifier], 60)]
            for command, timeout in commands:
                try:
                    run(command, check=True, timeout=timeout)
                except (subprocess.TimeoutExpired, subprocess.CalledProcessError) as diagnostic_error:
                    report(f'Simulator cleanup command failed: {diagnostic_error}', flush=True)
            if attempt == 1:
                raise SystemExit('Simulator failed to become ready after two attempts.') from error


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Usage: ci-simulator-boot.py SIMULATOR_ID')
    boot_simulator(sys.argv[1])
