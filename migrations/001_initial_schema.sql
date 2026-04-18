-- BIXI Station Availability Prediction System
-- Phase 1 schema — all tables include system_id for multi-city support
--
-- TimescaleDB is optional: if not installed, tables work as plain PostgreSQL.
-- Run 002_add_hypertables.sql after installing TimescaleDB to add optimizations.

-- ---------------------------------------------------------------------------
-- Static / semi-static tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS system_info (
  system_id    TEXT PRIMARY KEY,
  name         TEXT,
  operator     TEXT,
  timezone     TEXT,
  url          TEXT,
  phone_number TEXT,
  email        TEXT,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS station_info (
  system_id                       TEXT             NOT NULL,
  station_id                      TEXT             NOT NULL,
  external_id                     TEXT,
  name                            TEXT             NOT NULL,
  short_name                      TEXT,
  lat                             DOUBLE PRECISION NOT NULL,
  lon                             DOUBLE PRECISION NOT NULL,
  capacity                        SMALLINT         NOT NULL,
  has_kiosk                       BOOLEAN          DEFAULT TRUE,
  is_charging                     BOOLEAN          DEFAULT FALSE,
  rental_methods                  TEXT[],
  electric_bike_surcharge_waiver  BOOLEAN          DEFAULT FALSE,
  updated_at                      TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
  PRIMARY KEY (system_id, station_id)
);

CREATE TABLE IF NOT EXISTS vehicle_types (
  system_id        TEXT        NOT NULL,
  vehicle_type_id  TEXT        NOT NULL,
  form_factor      TEXT,
  propulsion_type  TEXT,
  max_range_meters REAL,
  name             TEXT,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (system_id, vehicle_type_id)
);

-- ---------------------------------------------------------------------------
-- Time-series tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS station_snapshots (
  time                      TIMESTAMPTZ  NOT NULL,
  station_id                TEXT         NOT NULL,
  system_id                 TEXT         NOT NULL,
  num_bikes_available       SMALLINT     NOT NULL,
  num_ebikes_available      SMALLINT     NOT NULL DEFAULT 0,
  num_docks_available       SMALLINT     NOT NULL,
  num_bikes_disabled        SMALLINT     NOT NULL DEFAULT 0,
  num_docks_disabled        SMALLINT     NOT NULL DEFAULT 0,
  is_installed              BOOLEAN      NOT NULL DEFAULT TRUE,
  is_renting                BOOLEAN      NOT NULL DEFAULT TRUE,
  is_returning              BOOLEAN      NOT NULL DEFAULT TRUE,
  is_charging               BOOLEAN      NOT NULL DEFAULT FALSE,
  eightd_has_available_keys BOOLEAN               DEFAULT FALSE,
  last_reported             TIMESTAMPTZ,
  vehicle_types_available   JSONB,
  PRIMARY KEY (system_id, station_id, time)
);
CREATE INDEX IF NOT EXISTS idx_snapshots_lookup ON station_snapshots (system_id, station_id, time DESC);

CREATE TABLE IF NOT EXISTS system_alerts (
  time               TIMESTAMPTZ  NOT NULL,
  system_id          TEXT         NOT NULL,
  alert_id           TEXT         NOT NULL,
  type               TEXT,
  summary            TEXT,
  description        TEXT,
  station_ids        TEXT[],
  url                TEXT,
  alert_last_updated TIMESTAMPTZ,
  times              JSONB,
  PRIMARY KEY (system_id, alert_id, time)
);

CREATE TABLE IF NOT EXISTS weather_observations (
  time             TIMESTAMPTZ  NOT NULL,
  system_id        TEXT         NOT NULL,
  temperature_c    REAL,
  feels_like_c     REAL,
  precipitation_mm REAL,
  rain_mm          REAL,
  snowfall_mm      REAL,
  weather_code     SMALLINT,
  wind_speed_kmh   REAL,
  wind_gusts_kmh   REAL,
  humidity_pct     REAL,
  cloud_cover_pct  REAL,
  PRIMARY KEY (system_id, time)
);

CREATE TABLE IF NOT EXISTS trip_history (
  start_time         TIMESTAMPTZ  NOT NULL,
  start_station_code TEXT         NOT NULL,
  system_id          TEXT         NOT NULL,
  end_time           TIMESTAMPTZ  NOT NULL,
  end_station_code   TEXT         NOT NULL,
  duration_sec       INTEGER      NOT NULL,
  is_member          BOOLEAN      NOT NULL,
  PRIMARY KEY (system_id, start_station_code, start_time)
);
CREATE INDEX IF NOT EXISTS idx_trips_end_station ON trip_history (system_id, end_station_code, start_time DESC);

-- ---------------------------------------------------------------------------
-- Events (manual curation)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS events (
  event_id            SERIAL           PRIMARY KEY,
  system_id           TEXT             NOT NULL,
  name                TEXT             NOT NULL,
  start_date          DATE             NOT NULL,
  end_date            DATE             NOT NULL,
  daily_start_time    TIME,
  daily_end_time      TIME,
  lat                 DOUBLE PRECISION NOT NULL,
  lon                 DOUBLE PRECISION NOT NULL,
  expected_attendance INTEGER,
  category            TEXT
);

-- ---------------------------------------------------------------------------
-- Features + predictions cache (written by Python pipeline, read by API)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS features_cache (
  time                  TIMESTAMPTZ  NOT NULL,
  station_id            TEXT         NOT NULL,
  system_id             TEXT         NOT NULL,
  bikes_available       SMALLINT,
  ebikes_available      SMALLINT,
  docks_available       SMALLINT,
  fill_ratio            REAL,
  ebike_ratio           REAL,
  bikes_lag_5m          REAL,
  drain_rate_per_min    REAL,
  bikes_rolling_avg_30m REAL,
  hour_sin              REAL,
  hour_cos              REAL,
  is_weekend            BOOLEAN,
  is_holiday            BOOLEAN,
  has_active_alert      BOOLEAN,
  temperature_c         REAL,
  is_raining            BOOLEAN,
  event_within_500m     BOOLEAN,
  neighbor_avg_bikes    REAL,
  p_empty_15m           REAL,
  p_empty_30m           REAL,
  p_empty_60m           REAL,
  p_full_15m            REAL,
  p_full_30m            REAL,
  p_full_60m            REAL,
  p_ebike_empty_15m     REAL,
  p_ebike_empty_30m     REAL,
  p_ebike_empty_60m     REAL,
  PRIMARY KEY (system_id, station_id, time)
);
CREATE INDEX IF NOT EXISTS idx_features_latest ON features_cache (system_id, station_id, time DESC);
