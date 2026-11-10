-- ============================================================================
--  Disaster Alert — SQLite schema
--  Mirrors lib/data/local/database/app_database.dart  (schemaVersion = 2)
--
--  The Flutter app creates this schema automatically through sqflite.
--  This file is the standalone equivalent, useful for:
--    * inspecting / recreating the database outside the app
--    * backend or tooling that consumes the same offline cache
--    * documentation and SQL-based testing
--
--  Usage:
--    sqlite3 disaster_alert.db < database/schema.sql
--    sqlite3 disaster_alert.db < database/seed.sql   -- optional demo data
--
--  Notes:
--    * Timestamps are stored as INTEGER Unix epoch MILLISECONDS
--      (DateTime.millisecondsSinceEpoch in Dart).
--    * Booleans are stored as INTEGER 0/1.
--    * Lists (sos channels / contact ids) are stored as JSON TEXT.
-- ============================================================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;

-- ----------------------------------------------------------------------------
-- 1. users — local profile / device registration
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id            TEXT PRIMARY KEY,
  name          TEXT,
  device_id     TEXT,
  is_registered INTEGER NOT NULL DEFAULT 0,
  created_at    INTEGER,
  updated_at    INTEGER
);

CREATE INDEX IF NOT EXISTS idx_users_device ON users(device_id);

-- ----------------------------------------------------------------------------
-- 2. disasters — cached incidents from server / simulator / official feeds
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS disasters (
  id                 TEXT PRIMARY KEY,
  type               TEXT NOT NULL,                    -- earthquake | flood | cyclone | ...
  title              TEXT NOT NULL,
  description        TEXT,
  latitude           REAL NOT NULL,
  longitude          REAL NOT NULL,
  affected_radius_km REAL NOT NULL DEFAULT 0,
  severity           TEXT NOT NULL DEFAULT 'info',     -- info | minor | moderate | severe | extreme
  magnitude          REAL,
  status             TEXT NOT NULL DEFAULT 'active',   -- active | resolved | expired
  occurred_at        INTEGER,
  expires_at         INTEGER,
  created_at         INTEGER,
  updated_at         INTEGER,
  source             TEXT,
  provider           TEXT NOT NULL DEFAULT 'server',   -- server | simulator | local
  payload_hash       TEXT,
  instructions       TEXT,
  area               TEXT,
  external_url       TEXT
);

CREATE INDEX IF NOT EXISTS idx_disasters_provider ON disasters(provider);
CREATE INDEX IF NOT EXISTS idx_disasters_status   ON disasters(status);
CREATE INDEX IF NOT EXISTS idx_disasters_geo      ON disasters(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_disasters_expires  ON disasters(expires_at);

-- ----------------------------------------------------------------------------
-- 3. emergency_contacts — people notified by SOS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS emergency_contacts (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  phone       TEXT NOT NULL,
  relationship TEXT,
  is_primary  INTEGER NOT NULL DEFAULT 0,
  is_verified INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER
);

CREATE INDEX IF NOT EXISTS idx_contacts_primary ON emergency_contacts(is_primary);

-- ----------------------------------------------------------------------------
-- 4. shelters — safe places near the active location
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shelters (
  id        TEXT PRIMARY KEY,
  name      TEXT NOT NULL,
  address   TEXT,
  latitude  REAL NOT NULL,
  longitude REAL NOT NULL,
  phone     TEXT,
  type      TEXT NOT NULL DEFAULT 'shelter', -- shelter | hospital | police_station | relief_camp | safe_zone
  capacity  INTEGER,
  is_open   INTEGER NOT NULL DEFAULT 1,
  source    TEXT
);

CREATE INDEX IF NOT EXISTS idx_shelters_type ON shelters(type);
CREATE INDEX IF NOT EXISTS idx_shelters_geo  ON shelters(latitude, longitude);

-- ----------------------------------------------------------------------------
-- 5. alert_history — assessed alert level snapshots per disaster
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS alert_history (
  id                  TEXT PRIMARY KEY,
  disaster_id         TEXT NOT NULL,
  distance_km         REAL,
  previous_level      TEXT,                       -- safe | warning | danger | critical | NULL
  new_level           TEXT NOT NULL,              -- safe | warning | danger | critical
  triggered_at        INTEGER,
  notification_status TEXT NOT NULL DEFAULT 'none', -- none | scheduled | sent | failed | suppressed
  FOREIGN KEY (disaster_id) REFERENCES disasters(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_history_disaster ON alert_history(disaster_id);
CREATE INDEX IF NOT EXISTS idx_history_time     ON alert_history(triggered_at DESC);

-- ----------------------------------------------------------------------------
-- 6. sos_events — emergency events (offline-first, retried via sync_queue)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sos_events (
  id          TEXT PRIMARY KEY,
  latitude    REAL NOT NULL,
  longitude   REAL NOT NULL,
  accuracy    REAL,
  status      TEXT NOT NULL DEFAULT 'pending', -- pending | queued | sent | delivered | failed
  channels    TEXT,                            -- JSON array: ["sms","call","whatsapp","location"]
  contact_ids TEXT,                            -- JSON array of emergency_contacts.id
  message     TEXT,
  captured_at INTEGER,
  updated_at  INTEGER
);

CREATE INDEX IF NOT EXISTS idx_sos_status ON sos_events(status);

-- ----------------------------------------------------------------------------
-- 7. app_settings — key/value preferences (AppSettings JSON under 'app_settings')
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app_settings (
  key        TEXT PRIMARY KEY,
  value      TEXT,
  updated_at INTEGER
);

-- ----------------------------------------------------------------------------
-- 8. sync_queue — offline outbox of operations waiting for connectivity
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_queue (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type TEXT NOT NULL,
  entity_id   TEXT,
  operation   TEXT NOT NULL,
  payload     TEXT,
  status      TEXT NOT NULL DEFAULT 'pending', -- pending | synced | failed
  attempts    INTEGER NOT NULL DEFAULT 0,
  error       TEXT,
  created_at  INTEGER,
  synced_at   INTEGER
);

CREATE INDEX IF NOT EXISTS idx_sync_status ON sync_queue(status, created_at);

-- ----------------------------------------------------------------------------
-- 9. locations — saved / manual places and the active reference point
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS locations (
  id          TEXT PRIMARY KEY,
  label       TEXT NOT NULL,
  latitude    REAL NOT NULL,
  longitude   REAL NOT NULL,
  mode        TEXT NOT NULL DEFAULT 'manual', -- gps | manual
  city        TEXT,
  district    TEXT,
  state       TEXT,
  pin_code    TEXT,
  address     TEXT,
  is_selected INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER,
  updated_at  INTEGER
);

CREATE INDEX IF NOT EXISTS idx_locations_selected ON locations(is_selected);

-- ----------------------------------------------------------------------------
-- 10. sync_metadata — last-sync watermarks per source (and global sync)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_metadata (
  key        TEXT PRIMARY KEY,
  value      TEXT,
  updated_at INTEGER
);

-- ============================================================================
--  Views — read-only convenience queries (safe to drop/ignore)
-- ============================================================================

-- Active incidents that have not expired yet.
CREATE VIEW IF NOT EXISTS v_active_disasters AS
SELECT *
FROM disasters
WHERE status = 'active'
  AND (expires_at IS NULL OR expires_at > (strftime('%s', 'now') * 1000))
ORDER BY severity DESC, occurred_at DESC;

-- Alert history joined with its disaster for display.
CREATE VIEW IF NOT EXISTS v_alert_history_detail AS
SELECT
  h.id,
  h.disaster_id,
  h.distance_km,
  h.previous_level,
  h.new_level,
  h.triggered_at,
  h.notification_status,
  d.type        AS disaster_type,
  d.title       AS disaster_title,
  d.severity    AS disaster_severity,
  d.status      AS disaster_status,
  d.latitude,
  d.longitude,
  d.affected_radius_km
FROM alert_history h
JOIN disasters d ON d.id = h.disaster_id;

-- Current reference location (at most one row by app convention).
CREATE VIEW IF NOT EXISTS v_selected_location AS
SELECT *
FROM locations
WHERE is_selected = 1
LIMIT 1;

-- Shelters that are currently open, nearest first is computed by the app.
CREATE VIEW IF NOT EXISTS v_open_shelters AS
SELECT *
FROM shelters
WHERE is_open = 1
ORDER BY type, name;

-- Offline outbox backlog.
CREATE VIEW IF NOT EXISTS v_pending_sync AS
SELECT *
FROM sync_queue
WHERE status = 'pending'
ORDER BY created_at ASC;

-- ============================================================================
--  Triggers — keep the single-selected-location invariant
--  (The Dart repository clears the previous selection explicitly; this makes
--  the same rule hold for any external SQL writer.)
-- ============================================================================
CREATE TRIGGER IF NOT EXISTS trg_locations_single_selected_insert
AFTER INSERT ON locations
WHEN NEW.is_selected = 1
BEGIN
  UPDATE locations
     SET is_selected = 0
   WHERE id <> NEW.id
     AND is_selected = 1;
END;

CREATE TRIGGER IF NOT EXISTS trg_locations_single_selected_update
AFTER UPDATE OF is_selected ON locations
WHEN NEW.is_selected = 1
BEGIN
  UPDATE locations
     SET is_selected = 0
   WHERE id <> NEW.id
     AND is_selected = 1;
END;

-- ============================================================================
--  OPTIONAL: strict CHECK constraints
--  The Flutter schema intentionally keeps enum validation in Dart. If this
--  database is used by other clients, enable the constraints below by copying
--  them into the table definitions above (SQLite cannot add CHECK via ALTER).
-- ============================================================================
-- disasters.type      CHECK (type IN ('earthquake','flood','cyclone','tsunami',
--                                    'landslide','wildfire','heavy_rain','lightning',
--                                    'storm','extreme_heat','volcano'))
-- disasters.severity  CHECK (severity IN ('info','minor','moderate','severe','extreme'))
-- disasters.status    CHECK (status IN ('active','resolved','expired'))
-- disasters.provider  CHECK (provider IN ('server','simulator','local'))
-- alert_history.new_level           CHECK (new_level IN ('safe','warning','danger','critical'))
-- alert_history.notification_status CHECK (notification_status IN ('none','scheduled','sent','failed','suppressed'))
-- sos_events.status   CHECK (status IN ('pending','queued','sent','delivered','failed'))
-- shelters.type       CHECK (type IN ('shelter','hospital','police_station','relief_camp','safe_zone'))
-- locations.mode      CHECK (mode IN ('gps','manual'))
-- sync_queue.status   CHECK (status IN ('pending','synced','failed'))
