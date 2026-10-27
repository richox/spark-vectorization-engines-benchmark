#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

init_run_dir
exec > >(tee "$RUN_DIR/run-setup.log") 2>&1

require_java

[[ "$ROUNDS" =~ ^[1-9][0-9]*$ ]] || {
  printf 'ROUNDS must be a positive integer.\n' >&2
  exit 1
}

QUERY_FILTER="$(
  printf '%s' "$QUERY_FILTER" |
    tr '[:upper:]' '[:lower:]' |
    tr -d '[:space:]'
)"

export SPARK_LOCAL_IP=127.0.0.1
export SPARK_CONF_DIR="$RUN_DIR/conf"
export SPARK_LOCAL_DIRS="$RUN_DIR/spark-local"

mkdir -p "$SPARK_CONF_DIR" "$SPARK_LOCAL_DIRS"
cp "$SPARK_DEFAULTS_CONF" "$SPARK_CONF_DIR/spark-defaults.conf"

if [[ "$ENGINE" == gluten ]]; then
  printf '\n' >> "$SPARK_CONF_DIR/spark-defaults.conf"
  cat "$GLUTEN_CONF" >> "$SPARK_CONF_DIR/spark-defaults.conf"

  [[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || {
    printf 'Gluten requires Linux x86_64.\n' >&2
    exit 1
  }

  find "$GLUTEN_DIR" -type f -name 'gluten-*.jar' \
    -exec cp {} "$SPARK_HOME/jars/" \;
fi

args=(
  --data-location "$DATA_LOCATION"
  --format parquet
  --output-dir "$RUN_DIR/benchmark-result"
  --round "$ROUNDS"
)

[[ -z "$QUERY_FILTER" ]] || args+=(--query-filter "$QUERY_FILTER")

printf 'Engine: %s, configuration: %s\n' "$ENGINE" "$SPARK_DEFAULTS_CONF"
bash "$RUNNER/bin/run" "${args[@]}" 2>&1 | tee "$RUN_DIR/spark.log"

logs=("$RUN_DIR"/benchmark-result/*/log)

[[ ${#logs[@]} -eq 1 && -s "${logs[0]}" ]] || {
  printf 'Missing benchmark results log.\n' >&2
  exit 1
}

python3 "$ROOT/scripts/validate-tpcds-results.py" \
  "${logs[0]}" \
  "$RUNNER/src/main/resources/tpcds/queries" \
  "$ROUNDS" \
  "$QUERY_FILTER"
