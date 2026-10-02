# Performance Test Results

## Test Environment

- Database: PostgreSQL / TimescaleDB
- Dataset: 100,006 rows
- Workload: 30-day time-series aggregation
- Tool: EXPLAIN (ANALYZE, BUFFERS)

## Baseline

The query initially used a sequential scan.

- Execution time: *54.620 ms*
- Rows processed: *42,097*
- Rows filtered: *57,909*
- Buffers hit: *1,182*
- Sort memory: *4,168 kB*

## Indexed Test

Added:

```sql
CREATE INDEX metrics_time_host_idx
ON metrics (time DESC, host);
