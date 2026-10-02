# TimescaleDB Operations Runbook

## Health Check
Run ./scripts/health-check.sh.
If it fails, verify database connectivity and credentials.

## Backup
Run ./scripts/backup.sh.
Confirm a new CSV appears in ~/timescaledb-metrics-backups/.

## Recovery
Run ./scripts/restore.sh /path/to/backup.csv.
Verify the restored row count.

## Slow Queries
Use EXPLAIN (ANALYZE, BUFFERS) to inspect execution time, scan type, buffers, filtering, and index usage.

## Monitoring
Run curl http://localhost:9187/metrics | grep pg_up.
Expected result: pg_up 1.

Prometheus runs on port 9090.

## Recovery Principle
Diagnose before changing configuration. Protect valid backups. Verify recovery before declaring the incident resolved.
