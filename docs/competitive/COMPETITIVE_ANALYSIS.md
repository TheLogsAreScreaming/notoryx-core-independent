# NOTORYX Independent: competitive intelligence report

Researched 2026-11-07 against `main` 0d324fe (0.1.0+10, published as v0.1.0-test.10). This is a research document: no app code was changed.

Companion files: [FEATURE_MATRIX.md](FEATURE_MATRIX.md) / [feature_matrix.json](feature_matrix.json) (51 rows) and [COMPETITIVE_ROADMAP.md](COMPETITIVE_ROADMAP.md).

## 0. Method and limits

- **This app:** read from source (`lib/`, ~8.5k hand-written lines, 21 test files with ~150 tests).
- **Competitors:** NOTORYX Independent competes in the same MeshCore market as NOTORYX Core. The full ecosystem research (about 60 clients, 11 profiled, weaknesses with linked issues) is in notoryx-core PR 217 (`docs/competitive/` there) and was done on the same day. It is summarised here, not repeated. Competitor cells in the matrix come from it.
- **The most important benchmark is the old NOTORYX Core app**, because Independent exists to replace it without meshcore-open code.
- **Not done:** no hands-on competitor testing. Reddit and app-store reviews weren't retrieved.
- **Clean-room rule:** recommendations below describe *what* to build. They never point at meshcore-open or old-Core code to adapt. `tools/check_independence.py` keeps enforcing that.

## 1. Ecosystem summary (MeshCore)

| App | Platforms | License | Latest verified | Position |
|---|---|---|---|---|
| **MeshCore official** (Liam Cottle) | Android, iOS, web, desktop | Proprietary, freemium | v1.51.0 (2026-11-04) | Strongest competitor; paid wait timer on remote admin |
| **MeshCore One** (Avi0n) | iOS, iPadOS, Mac | GPL-3.0 | v1.6.2 (2026-11-01) | Deepest diagnostics on Apple; English only |
| **MeshCore Open** (zjs81) | All (Flutter) | MIT | BETA-99.0.1 (2026-10-31) | The base most forks (and old Core) came from; SharedPreferences storage |
| **MeshOS** (Andy Kirby) | Android + T-Deck firmware | Proprietary | v0.4.3 (reported) | Signal bars, path viewer |
| **NOTORYX Core** (old app) | Android, macOS | — | rc.33 (2026-11-07) | Broadest feature set of all; ~68% meshcore-open by blame |

Ecosystem-wide problems that matter most for Independent (from PR 217 §3):
1. Bluetooth fragility.
2. Users can't tell why a DM failed.
3. SharedPreferences used as a database.
4. Distribution gaps (F-Droid, Play, TestFlight).
5. Multi-byte path confusion.
6. Slow or paywalled repeater admin.
7. The app and the radio disagreeing about the contact table.

## 2. Where Independent already stands out

| Strength | Evidence | Who else |
|---|---|---|
| **SQLite (drift) store with tested schema upgrades** | Schema v5; real user DB copies upgraded cleanly (v1→v5) | Old Core and MeshCore Open use SharedPreferences |
| **Reconnect on every transport** | PR #11: backoff 2/5/15/30 s, BLE fallback scan, saved USB by path | Old Core reconnects on Bluetooth only |
| **Clean-room independence enforced in CI** | `tools/check_independence.py` | Unique |
| **Retry behaviour matching the official app** | PR #10: 4 direct + reset path + 4 flood, attempt numbering, stop/resend | Official v1.51 has the same idea |
| **Per-radio data model** | `Radios` table keys all rows | Partial elsewhere |
| **Connection log** | PR #13 | Rare |

## 3. Where it is behind

Against old Core (the app it must replace), Independent lacks:
- path trace and path graph
- repeater and room-server admin
- telemetry
- RX log and noise floor
- message search, drafts, quick messages, reactions and replies
- signed posts, images
- SOS and check-ins
- MQTT, bots
- offline tiles, GPX, line of sight
- network scan
- encrypted backup
- translations
- an Android foreground service
- iOS

It also has no LICENSE file yet.

## 4. Internal audit (summary)

- **Architecture:** `lib/radio` (protocol codec + links + `RadioSession` command queue) → `lib/data` (drift `MeshStore`, `MeshSync`) → `lib/app` (Riverpod controllers) → `lib/screens`. Small, layered and testable. The largest file is `radio_settings_screen.dart` (722 lines). There is no god object like old Core's 9k-line connector.
- **Tests:** ~150 tests including scripted-radio widget tests; CI runs analyze, tests, build_runner freshness, the independence check, and Android and macOS builds.
- **Real-radio record:**
  - test 3: connect, channels, contacts, send, receive and deliver all confirmed on the user's Mac.
  - test 4: retries confirmed.
  - test 5: Android reconnect **failed**. The connection log in test 6 was added to diagnose it, and no Android log has come back yet.
- **Risks:**
  - The Android reconnect is unconfirmed.
  - No foreground service, so Android may kill the link in the background (NOTORYX Connect saw exactly this, fixed with a foreground service and battery-optimisation guidance).
  - The APK is ~80 MB because of the bundled MLKit for QR scanning.

## 5. Answers in brief

- **Strongest competitor:** the official MeshCore app.
- **Real benchmark:** old NOTORYX Core. Independent wins on foundations (storage, reconnect, independence, code size) and loses on breadth.
- **Strategy:** close the breadth gap in the order users feel it. Start with the Android background link, then diagnostics (trace, path, RX log) and repeater admin, then safety features. Keep the foundations that make Independent better.
