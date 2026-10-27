#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

init_run_dir
exec > >(tee "$RUN_DIR/generate-setup.log") 2>&1
printf 'Results directory: %s\n' "$RUN_DIR"

if [[ ! -f "$DATA_LOCATION/generation.complete" ]]; then
  require_java

  export SPARK_LOCAL_IP=127.0.0.1
  export SPARK_CONF_DIR="$RUN_DIR/datagen-conf"

  mkdir -p "$SPARK_CONF_DIR" "$RUN_DIR/datagen-spark-local"

  if [[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]]; then
    command -v make >/dev/null
    command -v gcc >/dev/null

    NATIVE_TOOLS="$DATAGEN/thirdparty/tpcds-kit/tools"

    make \
      -C "$NATIVE_TOOLS" \
      -f Makefile.osx \
      OSX_CFLAGS='-O2 -std=gnu89 -Wall -Wno-error=implicit-function-declaration' \
      dsdgen tpcds.idx \
      2>&1 | tee "$RUN_DIR/native-build.log"

    cp \
      "$NATIVE_TOOLS/dsdgen" \
      "$NATIVE_TOOLS/tpcds.idx" \
      "$DATAGEN/src/main/resources/binaries/Mac/aarch64/"
  fi

  build_module "$DATAGEN" "$RUN_DIR/datagen-build.log"

  "$SPARK_HOME/bin/spark-submit" \
    --master 'local[4]' \
    --driver-memory 4g \
    --conf spark.driver.host=127.0.0.1 \
    --conf spark.driver.bindAddress=127.0.0.1 \
    --conf spark.local.dir="$RUN_DIR/datagen-spark-local" \
    --conf spark.ui.enabled=false \
    --conf spark.sql.shuffle.partitions=10 \
    --conf spark.sql.adaptive.enabled=true \
    --conf spark.sql.parquet.enableVectorizedReader=true \
    --conf spark.sql.parquet.compression.codec=zstd \
    --conf spark.tpcds.gen.defaultParallel=10 \
    --conf spark.sql.session.timeZone=UTC \
    --class org.apache.spark.sql.execution.benchmark.TPCDSDatagen \
    "$DATAGEN/target/spark-tpcds-datagen_2.12-0.1.0-SNAPSHOT-with-dependencies.jar" \
    --output-location "$DATA_LOCATION" \
    --scale-factor 10 \
    --format parquet \
    --use-double-for-decimal \
    --use-string-for-char \
    --overwrite \
    2>&1 | tee "$RUN_DIR/datagen.log"
fi

validate_data
touch "$DATA_LOCATION/generation.complete"
