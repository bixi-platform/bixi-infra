-- Fix schema issues found in code review.
-- Safe to run multiple times (idempotent ALTER TABLE).

-- 1. Remove hardcoded DEFAULT 'bixi-montreal' from time-series tables.
--    system_id should always be supplied explicitly by the collector.
ALTER TABLE station_snapshots   ALTER COLUMN system_id DROP DEFAULT;
ALTER TABLE system_alerts       ALTER COLUMN system_id DROP DEFAULT;
ALTER TABLE weather_observations ALTER COLUMN system_id DROP DEFAULT;
ALTER TABLE trip_history        ALTER COLUMN system_id DROP DEFAULT;
ALTER TABLE features_cache      ALTER COLUMN system_id DROP DEFAULT;
ALTER TABLE events              ALTER COLUMN system_id DROP DEFAULT;

-- 2. Fix vehicle_types.max_range_meters type: GBFS spec uses float, not int.
ALTER TABLE vehicle_types
  ALTER COLUMN max_range_meters TYPE REAL USING max_range_meters::REAL;
