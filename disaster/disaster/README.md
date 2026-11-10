# Disaster Alert (Offline-First)

A real-time disaster alert Flutter app built with an **offline-first** architecture:
SQLite cache, WebSocket + REST realtime feeds, GPS/Haversine proximity alerts,
local notifications, SOS with contacts, a live map and a dev data simulator.

## Features

- **Live alerts** — server feeds are pushed over WebSocket with REST catch-up
  and periodic polling; everything lands in SQLite first.
- **Offline-first** — all data reads hit the local SQLite cache. A sync outbox
  (`sync_queue` table) queues SOS acknowledgements and recoveries are automatic
  when connectivity returns.
- **GPS proximity ratings** — every event is rated as `safe / warning / danger /
  critical` from the Haversine distance to the user plus the event's severity.
- **Notifications** — `flutter_local_notifications` with per-level alert
  messages; notification delivery status is recorded per alert.
- **SOS** — one-tap emergency flow shares live location with primary contacts
  and queues the event for retry while offline.
- **Live map** — keyless OpenStreetMap tiles (`flutter_map`), user marker,
  disaster markers + radius circles and nearby shelters.
- **Dev simulator** — generates realistic events (single / burst / critical)
  through the exact same `AlertPipeline` as production feeds, clearly tagged
  `provider = simulator` and isolated from server data. Purgable from Settings.
- **Weather** — current conditions + hourly + 3-day forecast for your active
  location from the keyless Open-Meteo forecast API (`WeatherScreen`).
- **Survival Guide** — offline hazard-by-hazard Before / During / After
  instructions via `SurvivalGuideScreen` (per disaster type).
- **Quick actions & deep links** — Home tiles and the More menu link straight
  into Weather, the Survival Guide, a "Recent Earthquakes" view (alerts list
  scoped to earthquake type) and an emergency helpline mini-dialler.

## Getting started

```sh
flutter pub get
flutter run
```

Use a real device or emulator for GPS/notifications. On Linux desktop you may
need `sudo apt install libsqlite3-dev` for the FFI test database.

### Real incident feeds (keyless, official)

Live alerts come from real, authoritative, **keyless** feeds that are polled
and cached offline-first (see `assets/config/data_sources.json`):

- **USGS** — earthquake GeoJSON feed (`USGS_BASE_URL`).
- **UN GDACS** — RSS feed of cyclone / flood / tsunami / volcano watch alerts
  (`GDACS_BASE_URL`). Fields use `gdacs:`/`geo:` namespaces and are parsed
  accordingly.
- **Open-Meteo** — severe weather derived from the WMO `weather_code` +
  temperature forecast, scoped to your active location (`OPEN_METEO_BASE_URL`);
  place search uses the keyless Open-Meteo geocoder (`GEOCODING_BASE_URL`).
  The Weather screen uses the same keyless forecast API for `current` +
  `hourly` + `daily` conditions.

These replace the placeholder backend below by default and require no API keys.

### Regional scope (near me by default)

USGS and GDACS are **worldwide** feeds. To stop a user in India from seeing
European disasters, both sources are scoped to a ~2000 km region around the
**active location** (GPS or manual place):

- **USGS** is narrowed server-side with the official
  `minlatitude/maxlatitude/minlongitude/maxlongitude` query parameters.
- **GDACS** RSS has no bounding-box support, so its parsed incidents are
  filtered client-side to the same region.

The radius is tunable per source via the `geoRadiusKm` param in
`assets/config/data_sources.json` (`SourceConfig.defaults` fallback is 2000);
set it to `0` to fetch the full global feed. When no location is known the
feeds fall back to global — behaviour is otherwise unchanged.

### Pointing at a real backend

The optional REST/WebSocket backend is still supported; override at build time:

```sh
flutter run \
  --dart-define=APP_ENV=dev \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=WS_URL=wss://api.example.com/ws \
  --dart-define=POLL_INTERVAL_SECONDS=30
```

Source polling cadence and transport are also tunable:

```sh
flutter build apk --debug \
  --dart-define=INGEST_INTERVAL_SECONDS=180 \
  --dart-define=SOURCE_TIMEOUT_SECONDS=30 \
  --dart-define=REQUEST_TIMEOUT_SECONDS=10 \
  --dart-define=BACKGROUND_REFRESH_ENABLED=false
```

`SOURCE_TIMEOUT_SECONDS` (default 30) caps each incident-feed poll before the
source is marked unavailable; official feeds like USGS/GDACS are given more
slack than the general API `REQUEST_TIMEOUT_SECONDS` (default 10).

Expected server shape (parsed by `DisasterEventParser` / `ShelterParser`):

```jsonc
// GET /v1/disasters -> {"events": [ {disaster…} ]}
// WS frame        -> {"disaster": {…}, "type": "disaster"}
// GET /v1/shelters-> {"shelters": [ {…} ]}
```

Disaster fields: `id`, `type`, `title`, `latitude`/`lat`, `longitude`/`lng`,
`affected_radius_km`, `severity`, `status`, optional `magnitude`,
`occurred_at`, `expires_at`, `source`.

### Firebase / FCM (push)

Recommended integration point: `LocalNotificationService` (`lib/core/
notifications/local_notification_service.dart`). Add FCM for remote push while
keeping local notifications as the fallback. If you add `firebase_core` +
`firebase_messaging`, regenerate `google-services.json` before building an APK —
a committed stub file will break the Android Gradle build.

## Architecture

```
lib/
├── core/          network (http/ws/connectivity), notifications, geoutils, config
├── data/
│   ├── local/     SQLite schema, models/mappers, repositories, sync outbox
│   ├── remote/    REST API service, WS realtime, DTO parsers
│   └── sync/      SyncService (push outbox -> pull disasters -> pull shelters)
├── domain/        entities, value objects, repository interfaces, services,
│                  AlertPipeline (single processing path for all sources)
└── presentation/  providers (ChangeNotifier), screens, theme, widgets
```

- **Single pipeline**: WebSocket, REST poll and the dev simulator all flow
  through `AlertPipeline.process()`, so rating, history and notifications behave
  identically for every source.
- **Event rating** (`Disaster.levelForDistance`): `≤25%` radius = critical,
  `≤50%` = danger, `≤100%` = warning, beyond = safe, boosted by intrinsic
  severity. A user-configurable `minimumAlertLevel` floors weak events.
- **Up-serts keep history**: disaster writes use `ON CONFLICT(id) DO UPDATE` so
  `alert_history` rows (FK `ON DELETE CASCADE`) survive re-pushes.

## Settings

Allowlist of alert types, safety radius, minimum alert level, notification /
sound / vibration toggles, dark theme and simulator controls.

### Location modes

The app follows either **live GPS** (auto-updating as you move, requires the
location permission) or a **manual place** (searchable via the open-source
Open-Meteo geocoder — useful indoors, travelling, or watching over a distant
area). The active mode is persisted and can be switched from the home
`LocationHeader`, the picker screen, or Settings. Realtime sections
(**Critical / Nearby / Recent**) and filters (severity, max distance, recency)
work on top of the chosen reference point.

## Testing

```sh
flutter test        # 106 tests
flutter analyze
```

SQLite tests run on sqflite_common_ffi with a fresh in-memory database per
test; `GeoDistance`, alert-level maths, USGS/GDACS/Open-Meteo + geocoder JSON
parsers, DB schema + legacy-key migrations, every local repository, the
`AlertPipeline` (dedupe / filters / notifications / history), the offline sync
outbox, the incident ingestion service, the simulator, the Open-Meteo weather
parser + WMO code mapping, Survival Guide data integrity, plus controller-level
integration tests (GPS/manual persistence, section + type filter behaviour) are
all covered.

## Platform notes

- **Android**: `minSdk 24`, Java 8 desugaring enabled (`desugar_jdk_libs`),
  full permission set and `<queries>` entries for `geo:`/`tel:` intents in
  `AndroidManifest.xml`.
- **iOS**: location usage descriptions + background modes in `Info.plist`.

## Repository

`flutter_secure_storage` stores the bearer token; `AppConfig` holds no secrets.

Frontend only — no hard-coded API keys.