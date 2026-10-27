from pathlib import Path
import re
import sys

log, queries, rounds, query_filter = sys.argv[1:]
expected = {p.stem for p in Path(queries).glob('q*.sql')}
if query_filter:
    selected = {q for q in query_filter.split(',') if q}
    if not selected <= expected:
        raise SystemExit(f'Unknown queries: {selected - expected}')
    expected = selected
expected_records = {(q, r) for q in expected for r in range(1, int(rounds) + 1)}
records = re.findall(r'case: (\w+), round: (\d+), succeeded: (true|false),', Path(log).read_text())
actual = {(q, int(r)) for q, r, _ in records}
failures = [(q, r) for q, r, succeeded in records if succeeded != 'true']
if not expected_records or actual != expected_records or len(records) != len(expected_records) or failures:
    raise SystemExit(f'Benchmark failed: missing={expected_records - actual}, extra={actual - expected_records}, failed={failures}')
print(f'All {len(records)} query runs succeeded.')
