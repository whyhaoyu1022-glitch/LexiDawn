#!/usr/bin/env python3
"""Failure-control tests only; these do not prove actual macOS simulator boot."""
import importlib.util
from pathlib import Path
import subprocess
import unittest

spec = importlib.util.spec_from_file_location('simulator_boot', Path(__file__).with_name('ci-simulator-boot.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class BootTests(unittest.TestCase):
    def execute(self, outcomes):
        calls = []
        def run(command, **options):
            calls.append(command[2])
            outcome = outcomes.pop(0)
            if isinstance(outcome, Exception):
                raise outcome
            return subprocess.CompletedProcess(command, outcome)
        module.boot_simulator('isolated-test-device', run=run, report=lambda *args, **kwargs: None)
        self.assertFalse(outcomes)
        return calls

    def test_ready_device_needs_no_cleanup(self):
        self.assertEqual(self.execute([0, 0]), ['boot', 'bootstatus'])

    def test_already_booted_still_requires_successful_readiness_check(self):
        self.assertEqual(self.execute([149, 0]), ['boot', 'bootstatus'])

    def test_diagnostic_timeout_does_not_skip_shutdown(self):
        timeout = subprocess.TimeoutExpired('explicit-fixture', 1)
        calls = self.execute([0, timeout, timeout, 0, 0, 0])
        self.assertEqual(calls, ['boot', 'bootstatus', 'list', 'shutdown', 'boot', 'bootstatus'])

    def test_second_failed_readiness_exits_without_claiming_success(self):
        timeout = subprocess.TimeoutExpired('explicit-fixture', 1)
        calls = []
        def run(command, **options):
            calls.append(command[2])
            if command[2] == 'bootstatus':
                raise timeout
            return subprocess.CompletedProcess(command, 0)
        with self.assertRaisesRegex(SystemExit, 'two attempts'):
            module.boot_simulator('isolated-test-device', run=run, report=lambda *args, **kwargs: None)
        self.assertEqual(calls.count('boot'), 2)
        self.assertEqual(calls.count('bootstatus'), 2)
        self.assertEqual(calls.count('shutdown'), 2)


if __name__ == '__main__':
    unittest.main()
