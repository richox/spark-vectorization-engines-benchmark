#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

[[ -n "${RUN_DIR:-}" && -d "$RUN_DIR" ]] || {
  printf 'RUN_DIR must point to an existing benchmark results directory.\n' >&2
  exit 1
}

logs=("$RUN_DIR"/benchmark-result/*/log)

if [[ ${#logs[@]} -ne 1 || ! -s "${logs[0]}" ]]; then
  printf 'Missing benchmark-runner results log: %s\n' "$RUN_DIR" >&2
  exit 1
fi

if [[ "$(uname -s)" == Darwin ]]; then
  command -v brew >/dev/null || {
    printf 'macOS requires GNU grep from Homebrew.\n' >&2
    exit 1
  }

  grep_prefix="$(brew --prefix grep)"
  export PATH="$grep_prefix/libexec/gnubin:$PATH"
fi

printf 'true\n' | grep -P 'true' >/dev/null || {
  printf 'stat requires GNU grep.\n' >&2
  exit 1
}

bash "$RUNNER/bin/stat" "${logs[0]}" | tee "$RUN_DIR/stat.txt"
