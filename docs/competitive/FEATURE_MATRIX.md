# NOTORYX Independent: master feature comparison matrix

Researched 2026-11-07 (notoryx-core-independent `main` 0d324fe, 0.1.0+10 / test.10). Machine-readable copy: [`feature_matrix.json`](feature_matrix.json).

## How to read this

- NX cells come from reading `lib/` on `main`. NC, OFF, MCO and MC1 cells are carried over from notoryx-core PR 217 (same research date), where "?" became U.
- NC is the old NOTORYX Core app. It is the most useful benchmark, because Independent is meant to replace it without its meshcore-open code.
- No competitor app was installed and tested hands-on for this report.

| Code | Meaning |
|---|---|
| I | Implemented |
| P | Partial |
| M | Missing |
| S | Superior |
| F | Inferior |
| U | Unverified |
| NA | Not applicable |
| O | In open PR |

**Apps:** **NX** = NOTORYX Independent 0.1.0+10; **NC** = NOTORYX Core 10.0.0-rc.33 (old app); **OFF** = MeshCore official v1.51.0; **MCO** = MeshCore Open BETA-99.0.1; **MC1** = MeshCore One v1.6.2

**NOTORYX Independent 0.1.0+10 totals (51 rows):** 24 missing, 21 implemented, 3 partial, 3 superior

## Messaging

| Feature | NX | NC | OFF | MCO | MC1 | Evidence / note |
|---|---|---|---|---|---|---|
| Direct messages | I | I | I | I | I | `lib/data/mesh_sync.dart` |
| Channels (public / hashtag / private) | I | I | I | I | I | PR #16 |
| Delivery ticks | I | I | I | I | I | Messages pending → sent → delivered/failed |
| Direct retries, reset path, flood fallback | I | I | I | P | I | PR #10: 4 direct + reset + 4 flood |
| Stop retrying / resend | I | I | I | U | U | PR #10 |
| Fail cleanly on disconnect | I | I | I | U | U | PR #10 |
| Failed-DM diagnosis (which stage) | M | P | U | U | P | Attempts are stored per message (`messages.attempts`), so the data exists |
| Message search | M | I | I | U | U | No message search in `lib/` |
| Drafts, quick messages | M | I | I | U | U | — |
| Reactions, replies | M | P | U | I | I | — |
| Signed channel posts | M | I | U | U | U | — |
| Images over mesh | M | I | U | I | I | — |
| Unread counts, mute, notifications | I | I | I | I | I | PR #15 |
| Room servers | M | I | I | I | I | Login codes exist (`codes.dart:25`); no UI |

## Mesh and diagnostics

| Feature | NX | NC | OFF | MCO | MC1 | Evidence / note |
|---|---|---|---|---|---|---|
| Heard-nearby / discovered contacts | I | I | I | I | I | PR #16 `Discovered` table |
| Hop count shown | I | I | I | U | U | `conversation_screen.dart`, `node_details.dart` |
| Path trace / ping | M | I | I | I | I | — |
| Path graph / route visualisation | M | S | I | I | I | — |
| Noise floor, RX log | M | P | P | U | I | RX frame type decoded in `frames.dart`; no screen |
| Repeater remote admin | M | S | P | I | I | — |
| Telemetry | M | P | I | U | I | Telemetry modes are parsed (`frames.dart:91`); no requests or charts |
| Network scan across presets | M | S | U | U | U | — |
| Area / regional presets | I | I | I | I | I | PR #12/#17; same `regional_presets.json` v2 source as Core |
| Radio settings (name, position, power, LoRa, auto-add) | I | I | I | I | I | PR #18 |

## Map and location

| Feature | NX | NC | OFF | MCO | MC1 | Evidence / note |
|---|---|---|---|---|---|---|
| Interactive map | I | I | I | I | I | PR #20 (flutter_map) |
| Offline tiles | M | I | U | I | I | OSM tiles online only |
| Phone GPS position | I | I | I | U | U | geolocator 14.1.2 |
| Track log, GPX | M | I | U | U | U | — |
| Line of sight | M | I | I | U | I | — |

## Connectivity

| Feature | NX | NC | OFF | MCO | MC1 | Evidence / note |
|---|---|---|---|---|---|---|
| Bluetooth LE | I | I | I | I | I | `ble_radio_link.dart` (universal_ble) |
| USB serial | P | I | I | I | U | Android only (vendored `usb_serial`); no Mac USB |
| TCP / Wi-Fi | I | I | I | I | I | `TcpRadioLink`, port 5000 |
| Auto-connect at launch | I | I | I | M | U | PR #11, saved `last_radio` |
| Auto-reconnect on every transport | S | P | I | U | U | PR #11 backoff 2/5/15/30 s for BLE/USB/TCP; Core's is Bluetooth-only. Android reconnect still unconfirmed on a device |
| Android foreground service | M | I | I | M | NA | No foreground service in the manifest |
| Connection log | I | I | U | U | U | PR #13, copy/clear screen |
| Radio clock sync | I | I | U | U | U | `radio_session.dart:138` `SetDeviceTime` |

## Data, privacy and platform

| Feature | NX | NC | OFF | MCO | MC1 | Evidence / note |
|---|---|---|---|---|---|---|
| SQLite message store with migrations | S | F | U | F | U | drift schema v5 with tested upgrades; Core and MeshCore Open use SharedPreferences |
| Per-radio data separation | I | P | U | U | U | `Radios` table keys every row |
| Encrypted backup / export | M | I | U | U | I | — |
| QR codes for contacts and channels | I | I | I | I | I | PR #19 |
| Safety: SOS, check-ins | M | S | U | U | U | — |
| MQTT bridge | M | S | U | U | U | — |
| Bots | M | S | U | U | U | — |
| Themes | P | S | U | I | I | `ThemeMode` in `main.dart` |
| Translations | M | S | I | I | M | — |
| Screen-reader labels | P | P | U | U | U | `Semantics(` in 2 files |
| Zero meshcore-open code (CI-checked) | S | F | NA | NA | NA | `tools/check_independence.py` in CI; Core is ~68% meshcore-open by blame |
| License chosen | M | U | NA | I | I | No LICENSE file yet; MeshCore Open is MIT, MeshCore One GPL-3.0, the official app proprietary |
| Android, macOS builds | I | I | I | I | P | Test builds test.1–test.10 in the -releases repo |
| iOS build | M | P | I | I | I | Platform folder exists; no iOS build or TestFlight |
