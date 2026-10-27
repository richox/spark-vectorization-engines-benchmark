#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export WORK_DIR="${WORK_DIR:-$ROOT/benchmark}"
export RESULTS_DIR="${RESULTS_DIR:-$ROOT/results}"
export DOWNLOADS="$WORK_DIR/downloads"

export ENGINE="${ENGINE:-spark}"
export ROUNDS="${ROUNDS:-2}"
export QUERY_FILTER="${QUERY_FILTER:-}"

export SPARK_DEFAULTS_CONF="${SPARK_DEFAULTS_CONF:-$ROOT/conf/spark-defaults.conf}"
export GLUTEN_CONF="${GLUTEN_CONF:-$ROOT/conf/gluten.conf}"

export SPARK_VERSION=3.5.9
export SPARK_HOME="$WORK_DIR/spark-$SPARK_VERSION-bin-hadoop3"
export SPARK_ARCHIVE="spark-$SPARK_VERSION-bin-hadoop3.tgz"
export SPARK_URL="https://dlcdn.apache.org/spark/spark-$SPARK_VERSION/$SPARK_ARCHIVE"

export TOOLS_REV=c75dc2b947fd83dbf5295ef9db808afcb70e40e1
export TOOLS_DIR="$WORK_DIR/tpcds-tools"
export RUNNER="$TOOLS_DIR/benchmark-runner"
export DATAGEN="$TOOLS_DIR/datagen"
export DATA_LOCATION="$WORK_DIR/data/tpcds-sf10-parquet-zstd-$TOOLS_REV"

export GLUTEN_ARCHIVE=apache-gluten-1.7.0-bin-spark-3.5.tar.gz
export GLUTEN_URL="https://dlcdn.apache.org/gluten/1.7.0/$GLUTEN_ARCHIVE"
export GLUTEN_DIR="$WORK_DIR/gluten-1.7.0-spark-3.5"

require_java() {
  command -v java >/dev/null || {
    printf 'Missing tool: java\n' >&2
    exit 1
  }

  local java_version
  java_version="$(java -version 2>&1)"

  [[ "$java_version" == *'version "17.'* ]] || {
    printf 'Set JAVA_HOME and PATH to use Java 17.\n' >&2
    exit 1
  }
}

init_run_dir() {
  [[ "$ENGINE" == spark || "$ENGINE" == gluten ]] || {
    printf 'ENGINE must be spark or gluten.\n' >&2
    exit 1
  }

  mkdir -p "$RESULTS_DIR"

  if [[ -z "${RUN_DIR:-}" ]]; then
    RUN_DIR="$(mktemp -d "$RESULTS_DIR/$ENGINE-spark-$SPARK_VERSION-tpcds-10g-XXXXXXXX")"
  fi

  mkdir -p "$RUN_DIR"
  RUN_DIR="$(cd "$RUN_DIR" && pwd)"
  export RUN_DIR

  if [[ -n "${GITHUB_ENV:-}" ]]; then
    printf 'RUN_DIR=%s\n' "$RUN_DIR" >> "$GITHUB_ENV"
  fi
}

download() {
  local url="$1" destination="$2"

  if [[ ! -f "$destination" ]]; then
    curl \
      --fail \
      --location \
      --retry 3 \
      --connect-timeout 30 \
      --output "$destination.part" \
      "$url"

    mv "$destination.part" "$destination"
  fi
}

build_module() {
  local module="$1" log="$2"

  command -v mvn >/dev/null || {
    printf 'Missing tool: mvn\n' >&2
    exit 1
  }

  JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-XX:+IgnoreUnrecognizedVMOptions" \
  mvn \
    -B \
    -f "$module/pom.xml" \
    package \
    -DskipTests \
    -Dscalastyle.skip=true \
    -Dproject.parent.build.directory="$module/target" \
    -Dspark.version="$SPARK_VERSION" \
    -Dscala.version=2.12.18 \
    -Dsnappy-java.version=1.1.10.5 \
    2>&1 | tee "$log"
}

validate_data() {
  python3 "$ROOT/scripts/validate-tpcds-data.py" "$DATA_LOCATION"
}
