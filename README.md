# TimescaleDB Real-Time Metrics & Analytics Lab

## Project Overview

This project is a hands-on PostgreSQL and TimescaleDB operations lab focused on managing time-series infrastructure metrics in a cloud-hosted PostgreSQL environment.

The project demonstrates practical database operations including:

- PostgreSQL schema design
- TimescaleDB hypertables and chunking
- Time-series data generation and analysis
- Query performance investigation and indexing
- Continuous aggregates
- Database backup and restore
- Schema migration
- Database monitoring and observability
- Secure TLS database connectivity

The project was built using Tiger Data Cloud with PostgreSQL 18 and TimescaleDB.

---

## Architecture

                    Tiger Data Cloud
                          │
                          │ TLS
                          ▼
                  PostgreSQL 18
                          │
                    TimescaleDB
                          │
                          ▼
                     metrics
                          │
              ┌───────────┴───────────┐
              │                       │
        Hypertable                 Chunks
              │
              ▼
       Time-Series Workload
         100,006 rows
              │
       ┌──────┼─────────┐
       │      │         │
       ▼      ▼         ▼
   Analytics Indexing Continuous
               Aggregate
                          │
                          ▼
                   metrics_hourly

---

## Technology Stack

| Technology | Purpose |
|---|---|
| PostgreSQL 18 | Relational database |
| TimescaleDB | Time-series database functionality |
| Tiger Data Cloud | Managed PostgreSQL/TimescaleDB environment |
| SQL | Schema design, analytics and administration |
| `psql` | PostgreSQL command-line client |
| `pg_dump` | Database backup |
| `pg_restore` | Database restoration |
| Docker | Local restore testing |

---

## 1. Database Schema

The initial metrics table was created with:

sql
CREATE TABLE metrics (
    time TIMESTAMPTZ NOT NULL,
    host TEXT NOT NULL,
    cpu_usage DOUBLE PRECISION,
    memory_usage DOUBLE PRECISION,
    disk_usage DOUBLE PRECISION,
    network_mb DOUBLE PRECISION
);


The table represents infrastructure metrics collected from multiple servers.

---

## 2. TimescaleDB Hypertable

The PostgreSQL table was converted into a TimescaleDB hypertable:

sql
SELECT create_hypertable(
    'metrics',
    by_range('time'),
    migrate_data => true
);


The hypertable was verified through TimescaleDB metadata:

sql
SELECT hypertable_name, num_dimensions
FROM timescaledb_information.hypertables
WHERE hypertable_name = 'metrics';


Result:

    hypertable_name
    ---------------
    metrics

The associated TimescaleDB chunks were also inspected to understand time-based data partitioning.

---

## 3. Time-Series Workload

A workload of 100,006 rows was generated across 10 simulated servers.

sql
INSERT INTO metrics (
    time,
    host,
    cpu_usage,
    memory_usage,
    disk_usage,
    network_mb
)
SELECT
    now() - (interval '1 minute' * n),
    'server-' || lpad(((n % 10) + 1)::text, 2, '0'),
    round((20 + random() * 70)::numeric, 2),
    round((40 + random() * 50)::numeric, 2),
    round((30 + random() * 60)::numeric, 2),
    round((10 + random() * 190)::numeric, 2)
FROM generate_series(1, 100000) AS n;


Final row count:

    100006

This provided enough data to perform realistic time-series queries and performance analysis.

---

## 4. Time-Series Analytics

Hourly CPU utilization was calculated using TimescaleDB's `time_bucket()` function:

sql
SELECT
    time_bucket('1 hour', time) AS hour,
    host,
    ROUND(AVG(cpu_usage)::numeric, 2) AS avg_cpu
FROM metrics
GROUP BY hour, host
ORDER BY hour, host
LIMIT 20;


This demonstrates time-bucketed aggregation over time-series data.

---

## 5. Query Performance Analysis

Query performance was investigated using:

sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT time, host, cpu_usage
FROM metrics
WHERE time >= now() - INTERVAL '24 hours'
  AND host = 'server-01'
ORDER BY time DESC;


The execution plan showed how PostgreSQL accessed the TimescaleDB chunks and indexes.

A composite index was then created based on the query's access pattern:

sql
CREATE INDEX metrics_host_time_idx
ON metrics (host, time DESC);


The query was executed again with `EXPLAIN (ANALYZE, BUFFERS)` to inspect the changed execution plan.

This exercise demonstrates practical query optimization using execution-plan analysis rather than blindly adding indexes.

---

## 6. Continuous Aggregate

An hourly continuous aggregate was created for CPU and memory metrics:

sql
CREATE MATERIALIZED VIEW metrics_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS hour,
    host,
    AVG(cpu_usage) AS avg_cpu,
    AVG(memory_usage) AS avg_memory
FROM metrics
GROUP BY hour, host;


The resulting aggregate was queried with:

sql
SELECT *
FROM metrics_hourly
ORDER BY hour DESC, host
LIMIT 10;


This demonstrates TimescaleDB continuous aggregates for precomputed time-series analytics.

---

## 7. Backup

A PostgreSQL custom-format backup was created using `pg_dump`:

bash
pg_dump -Fc \
  "postgres://tsdbadmin@HOST:PORT/tsdb?sslmode=require" \
  -f ~/timescaledb-metrics-lab.backup


The backup was inspected using:

bash
pg_restore -l ~/timescaledb-metrics-lab.backup | head -20


The resulting archive was a PostgreSQL custom-format dump created with PostgreSQL 18.6.

---

## 8. Backup Restore Test

The backup was restored into a separate local TimescaleDB Docker container.

The restore environment used:

bash
docker run \
  --name timescaledb-restore-test \
  -e POSTGRES_PASSWORD=restoretest \
  -p 55432:5432 \
  -d timescale/timescaledb:2.30.2-pg18


Before restoring the database objects, TimescaleDB restore preparation was executed:

sql
CREATE ROLE tsdbadmin;

SELECT timescaledb_pre_restore();


The backup was then restored using:

bash
pg_restore \
  -h localhost \
  -p 55432 \
  -U postgres \
  -d postgres \
  --no-owner \
  --no-acl \
  ~/timescaledb-metrics-lab.backup


The restore produced two warnings because the local Docker image did not contain the `timescaledb_toolkit` extension available in the managed source environment.

The actual project data restored successfully.

Verification:

sql
SELECT count(*) AS restored_rows
FROM metrics;

SELECT hypertable_name
FROM timescaledb_information.hypertables
WHERE hypertable_name = 'metrics';


Result:

    restored_rows
    -------------
    100006

    hypertable_name
    ---------------
    metrics

Therefore, the project data and TimescaleDB hypertable were successfully restored.

---

## 9. Schema Migration

A schema migration was performed against the production-like Tiger Data database.

A new `region` column was added:

sql
ALTER TABLE metrics
ADD COLUMN region TEXT;


Existing records were migrated:

sql
UPDATE metrics
SET region = CASE
    WHEN host LIKE 'server-0%' THEN 'us-east'
    ELSE 'eu-west'
END;


PostgreSQL reported:

    UPDATE 100006

The migration was verified with:

sql
SELECT region, COUNT(*) AS rows
FROM metrics
GROUP BY region
ORDER BY region;


Result:

     region  | rows
    ---------+-------
     eu-west | 10000
     us-east | 90006

This demonstrates a controlled schema change followed by data migration and verification.

---

## 10. Monitoring and Observability

Database health was inspected using PostgreSQL system statistics.

### Database Health

sql
SELECT
    datname,
    numbackends AS active_connections,
    pg_size_pretty(pg_database_size(datname)) AS database_size
FROM pg_stat_database
WHERE datname = current_database();


Observed result:

    datname | active_connections | database_size
    --------+--------------------+--------------
    tsdb    | 3                  | 43 MB

### Active Sessions and Queries

PostgreSQL activity was inspected using:

sql
SELECT
    pid,
    usename,
    state,
    EXTRACT(
        EPOCH FROM (clock_timestamp() - query_start)
    )::int AS query_seconds,
    LEFT(query, 80) AS query
FROM pg_stat_activity
WHERE datname = current_database()
ORDER BY query_start DESC;


This provided visibility into:

- PostgreSQL sessions
- Active and idle connections
- Query duration
- Current queries
- Database exporter activity

These checks demonstrate basic PostgreSQL operational monitoring without requiring an additional monitoring stack.

---

## 11. Security

The database connection used TLS:

    SSL connection
    Protocol: TLSv1.3

The connection credentials were entered interactively rather than stored directly in project documentation.

Passwords and connection secrets should not be committed to Git.

---

## 12. Evidence Screenshots

The project evidence includes:

- timescaledb-continuous-aggregate.png
- timescaledb-backup-restore-success.png
- timescaledb-schema-migration.png
- timescaledb-monitoring-overview.png

These screenshots demonstrate the major operational milestones of the project.

---

## 13. Skills Demonstrated

This project demonstrates practical experience with:

- PostgreSQL administration
- TimescaleDB
- Time-series database design
- Hypertables
- Time-based chunking
- SQL
- `time_bucket()`
- Continuous aggregates
- Query optimization
- `EXPLAIN (ANALYZE, BUFFERS)`
- PostgreSQL indexing
- Database backup and restore
- `pg_dump`
- `pg_restore`
- Schema migrations
- PostgreSQL monitoring
- `pg_stat_database`
- `pg_stat_activity`
- TLS database connectivity
- Docker-based database restore testing
- Troubleshooting database compatibility and restore issues

---

## 14. Project Outcome

The lab demonstrates an end-to-end operational workflow for a PostgreSQL/TimescaleDB workload:

    Design
      ↓
    Create PostgreSQL schema
      ↓
    Convert to TimescaleDB hypertable
      ↓
    Generate time-series workload
      ↓
    Run analytics
      ↓
    Analyze query performance
      ↓
    Optimize indexing
      ↓
    Create continuous aggregate
      ↓
    Back up database
      ↓
    Restore and verify backup
      ↓
    Perform schema migration
      ↓
    Monitor database health

The project was intentionally built as a hands-on infrastructure/database operations lab rather than presented as production DBA experience.

