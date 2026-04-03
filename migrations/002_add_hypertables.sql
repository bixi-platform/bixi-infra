-- Run this AFTER installing TimescaleDB (sudo apt-get install timescaledb-2-postgresql-16)
-- and restarting PostgreSQL.
--
-- Usage: psql -h localhost -p 5434 -U bixi -d bixi -f migrations/002_add_hypertables.sql

CREATE EXTENSION IF NOT EXISTS timescaledb;

SELECT create_hypertable('station_snapshots',   'time', if_not_exists => TRUE, migrate_data => TRUE);
SELECT create_hypertable('system_alerts',       'time', if_not_exists => TRUE, migrate_data => TRUE);
SELECT create_hypertable('weather_observations','time', if_not_exists => TRUE, migrate_data => TRUE);
SELECT create_hypertable('trip_history',        'start_time', if_not_exists => TRUE, migrate_data => TRUE);
SELECT create_hypertable('features_cache',      'time', if_not_exists => TRUE, migrate_data => TRUE);

SELECT add_retention_policy('station_snapshots', INTERVAL '6 months', if_not_exists => TRUE);
SELECT add_retention_policy('features_cache',    INTERVAL '7 days',   if_not_exists => TRUE);
