#!/bin/bash

set -euo pipefail

DB_URL="postgres://tsdbadmin@u8jxn3ylxk.rxph6hft6e.tsdb.cloud.timescale.com:37318/tsdb?sslmode=require"

echo "Checking TimescaleDB connectivity..."

if psql "$DB_URL" -tAc "SELECT 1;" | grep -q 1; then
    echo "Database health check: OK"
else
    echo "Database health check: FAILED"
    exit 1
fi
