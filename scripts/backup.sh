#!/bin/bash
set -euo pipefail

BACKUP_DIR="$HOME/timescaledb-metrics-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/metrics-$TIMESTAMP.csv"

mkdir -p "$BACKUP_DIR"

echo "Exporting metrics data..."
echo "Output: $BACKUP_FILE"

psql "postgres://tsdbadmin@u8jxn3ylxk.rxph6hft6e.tsdb.cloud.timescale.com:37318/tsdb?sslmode=require" \
  -c "\copy (SELECT time, host, cpu_usage, memory_usage, disk_usage, network_mb, region FROM metrics ORDER BY time) TO '$BACKUP_FILE' CSV HEADER"

echo "Backup completed successfully."
ls -lh "$BACKUP_FILE"
