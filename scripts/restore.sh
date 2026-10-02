#!/bin/bash
set -euo pipefail

BACKUP_FILE="${1:-}"

if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup.csv>"
    exit 1
fi

CONTAINER="timescaledb-restore-automation"

echo "Restoring metrics backup..."

docker exec -i "$CONTAINER" \
    psql -U postgres -d postgres \
    -c "DROP TABLE IF EXISTS metrics;"

docker exec -i "$CONTAINER" \
    psql -U postgres -d postgres \
    -c "CREATE TABLE metrics (
        time TIMESTAMPTZ NOT NULL,
        host TEXT NOT NULL,
        cpu_usage DOUBLE PRECISION,
        memory_usage DOUBLE PRECISION,
        disk_usage DOUBLE PRECISION,
        network_mb DOUBLE PRECISION,
        region TEXT
    );"

tail -n +2 "$BACKUP_FILE" | \
docker exec -i "$CONTAINER" \
    psql -U postgres -d postgres \
    -c "\copy metrics FROM STDIN CSV"

echo "Verifying restored data..."

docker exec "$CONTAINER" \
    psql -U postgres -d postgres \
    -c "SELECT COUNT(*) AS restored_rows FROM metrics;"

echo "Restore completed successfully."
