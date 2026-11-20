#!/usr/bin/env python3
"""Read-only stack capture for the isolated native lookup diagnostic job."""
import pathlib
import subprocess
import sys
import time


def monitor(root):
    output = root / 'lookup-samples'
    output.mkdir(parents=True, exist_ok=True)
    started = {}
    captured = set()
    stop = root / 'lookup-sample-stop'
    deadline = time.monotonic() + 25 * 60
    while not stop.exists() and time.monotonic() < deadline:
        try:
            result = subprocess.run(['pgrep', '-x', 'LexiDawn'], capture_output=True, text=True, timeout=5, check=False)
            if result.returncode not in (0, 1):
                print('App process lookup failed:', result.returncode, result.stderr, flush=True)
            for pid in result.stdout.split():
                if not pid.isdecimal():
                    continue
                now = time.monotonic()
                started.setdefault(pid, now)
                for threshold in (45, 90, 150, 240, 330):
                    if now - started[pid] < threshold or (pid, threshold) in captured:
                        continue
                    captured.add((pid, threshold))
                    path = output / f'app-{pid}-{threshold}s.txt'
                    try:
                        sample = subprocess.run(['/usr/bin/sample', pid, '3', '-file', str(path)],
                                                capture_output=True, text=True, timeout=15, check=False)
                        print(f'Native sample pid={pid} age={threshold}s exit={sample.returncode}', flush=True)
                        if sample.returncode:
                            path.with_suffix('.error.txt').write_text(sample.stdout + sample.stderr)
                    except subprocess.TimeoutExpired as error:
                        print('Native sample timed out:', error, flush=True)
                    break
        except subprocess.TimeoutExpired as error:
            print('App process lookup timed out:', error, flush=True)
        time.sleep(1)


def summarize(root):
    for path in sorted((root / 'lookup-samples').glob('*.txt')):
        lines = path.read_text(errors='replace').splitlines()
        chosen = set(range(min(140, len(lines))))
        for i, line in enumerate(lines):
            if any(word in line for word in ['Dictionary', 'MDX', 'NLEmbedding', 'NLTagger', 'WordLookup', 'ReaderView', 'AttributeGraph']):
                chosen.update(range(max(0, i - 2), min(len(lines), i + 3)))
        print('LOOKUP_NATIVE_STACK_BEGIN', path.name)
        for i in sorted(chosen)[:350]:
            print(lines[i])
        print('LOOKUP_NATIVE_STACK_END', path.name)


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in ('monitor', 'summarize'):
        raise SystemExit('Usage: ci-lookup-samples.py monitor|summarize RUN_DIRECTORY')
    directory = pathlib.Path(sys.argv[2])
    (monitor if sys.argv[1] == 'monitor' else summarize)(directory)
