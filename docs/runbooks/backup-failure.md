# Backup Failure Runbook

## Symptoms

- backup.sh exits with a non-zero status.
- No new backup file appears in ~/timescaledb-metrics-backups.
- PostgreSQL connection or authentication errors are displayed.

## Investigation

### 1. Test database connectivity

```bash
./scripts/health-check.sh
