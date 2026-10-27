#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

init_run_dir
exec > >(tee "$RUN_DIR/prepare-setup.log") 2>&1
printf 'Results directory: %s\n' "$RUN_DIR"

if [[ "$ENGINE" == gluten && (
  "$(uname -s)" != Linux || "$(uname -m)" != x86_64
) ]]; then
  printf 'Gluten binary tests support only Linux x86_64.\n' >&2
  exit 1
fi

require_java

for tool in git tar python3 curl; do
  command -v "$tool" >/dev/null || {
    printf 'Missing tool: %s\n' "$tool" >&2
    exit 1
  }
done

mkdir -p "$WORK_DIR" "$DOWNLOADS"
download "$SPARK_URL" "$DOWNLOADS/$SPARK_ARCHIVE"

if [[ ! -x "$SPARK_HOME/bin/spark-submit" ]]; then
  tar -xzf "$DOWNLOADS/$SPARK_ARCHIVE" -C "$WORK_DIR"
fi

if [[ ! -d "$TOOLS_DIR/.git" ]]; then
  git clone https://github.com/auron-project/tpcds-tools "$TOOLS_DIR"
fi

git -C "$TOOLS_DIR" checkout --detach "$TOOLS_REV"

build_module "$RUNNER" "$RUN_DIR/build.log"

if [[ "$ENGINE" == gluten ]]; then
  download "$GLUTEN_URL" "$DOWNLOADS/$GLUTEN_ARCHIVE"

  if [[ ! -f "$GLUTEN_DIR/extraction.complete" ]]; then
    mkdir -p "$GLUTEN_DIR"
    tar -xzf "$DOWNLOADS/$GLUTEN_ARCHIVE" -C "$GLUTEN_DIR"
    touch "$GLUTEN_DIR/extraction.complete"
  fi
fi
