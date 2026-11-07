# NOTORYX Independent: competitive strategy and roadmap

Researched 2026-11-07 against `main` 0d324fe (0.1.0+10). Evidence: [COMPETITIVE_ANALYSIS.md](COMPETITIVE_ANALYSIS.md), [FEATURE_MATRIX.md](FEATURE_MATRIX.md), and notoryx-core PR 217 for the wider MeshCore ecosystem. Everything is a proposal; nothing in this PR changes code. Every item is to be built clean-room from the MeshCore companion protocol docs and firmware behaviour, never by adapting meshcore-open or old-Core code.

## 1. Competitive advantage opportunities

| Opportunity | Why it is open | Head start |
|---|---|---|
| **The MeshCore app that doesn't lose your chats** | SharedPreferences in old Core and MeshCore Open | drift store, tested migrations |
| **Reconnect that works on every link** | Old Core: Bluetooth only; MeshCore Open: no auto-connect | PR #11, connection log |
| **"Why did my DM fail?"** | PR 217 weakness #2, across all MeshCore apps | Per-attempt ack codes already stored (`messages.attempts`) |
| **Free repeater admin** | The official app puts a wait timer on remote admin | Login codes parsed |
| **A small, clean, licensable codebase** | Old Core is ~68% upstream code | 8.5k lines, independence CI |

## 2. Weakness report (MeshCore ecosystem, applied to Independent)

| # | Weakness | Affected (PR 217) | Independent today | Better answer | Difficulty | Priority |
|---|---|---|---|---|---|---|
| W1 | Bluetooth drops, especially in the background | official iOS, mesh-client, Offband | Reconnect yes; **no foreground service**; Android reconnect failed in test 5 | Foreground service + battery-optimisation card + confirm with the connection log | M | P0 |
| W2 | DM failure unexplained | All | Data stored, not shown | Delivery diagnosis sheet: each attempt, route, ack seen or not, what to try | M | P1 |
| W3 | SharedPreferences as DB | Old Core, MCO, Offband | **Solved** | Keep; add a size/retention setting | S | P3 |
| W4 | Repeater admin slow/paywalled | official, Offband | Missing | Login + status + CLI screen, free | M | P1 |
| W5 | Contact table full / app vs radio disagree | Offband | Partial: auto-add settings, `Discovered` table | "Radio has N/M contacts" meter and swap-out flow | M | P2 |
| W6 | Multi-byte path confusion | MCO, Offband, official | Unverified | Show path hash size explicitly in trace and path views | S | P2 |
| W7 | Distribution gaps | MCO, wardrive | -releases repo only | Obtainium config, then F-Droid once licensed | S | P2 |

## 3. Innovation research

| Concept | Elsewhere? | Firmware support | Effort | Notes |
|---|---|---|---|---|
| Delivery diagnosis sheet | Partly (MC1, old Core) | ACK codes, path return, trace | M | Built on stored attempts |
| Route health per contact | Old Core Route Intelligence | Path return + trace | M | Simple version: last good path, age, success rate |
| Repeater ranking from heard repeats | Old Core (P) | `LOG_RX_DATA` | M | Needs RX log first |
| Contacts beyond the radio limit | KIEKR (PR 217 ideas) | Add/remove contact commands | M | Keep everyone in the DB; sync favourites to the radio |
| Readiness check | Old Core (P) | Self info, battery, presets | S | Before a trip: battery, area preset, time synced, reachable repeaters |
| SOS with repeat and all-clear | Old Core | Channel/DM send | M | Build own tag format compatible with `[NOTORYX SOS]` text so both apps interoperate |

## 4. Internal audit

### 4.1 Architecture
Layered `radio → data → app → screens` with Riverpod; links behind `RadioLink`; one command at a time through `RadioSession`. Good for testing (scripted radio fakes in `test/support`).

### 4.2 Ahead (protect)
drift store with upgrade tests; reconnect on all links; connection log; independence CI; retries parity with the official app; per-radio data.

### 4.3 Behind (verified in source)
1. No Android foreground service; Android reconnect unconfirmed.
2. No path trace, path view, RX log, noise floor, telemetry.
3. No repeater/room admin UI.
4. No search, drafts, reactions, replies, images, signed posts.
5. No SOS, check-ins, MQTT, bots.
6. No offline tiles, GPX, line of sight.
7. No translations; `Semantics(` in 2 files.
8. No LICENSE; no iOS build; USB on Android only.

### 4.4 Most improvement for least effort
Foreground service (W1), message search (data is in SQLite already), delivery diagnosis sheet (data stored), path trace.

## 5. Prioritised roadmap

### P0: critical
**P0-1 Android background link.** *Problem:* test 5 reconnect failed on Android; no foreground service. *Solution:* foreground service while connected; battery-optimisation guidance; verify with the connection log. *Code:* Android manifest + service plugin, `lib/app/connection.dart`. *Accept:* the link survives 30 min screen-off on a Samsung phone; a drop reconnects within 30 s; log shows the sequence. *Tests:* connection controller tests with scripted drops; manual device test recorded. **M**

**P0-2 Choose a license.** Needed before F-Droid, before outside contributions, and to make "independent" meaningful. **S**

**P0-3 Real-radio checklist per test build.** Record connect / send / deliver / retry / reconnect on Mac and Android for each test.N. **S**

### P1: high impact
| ID | Item | Approach | Accept | Effort |
|---|---|---|---|---|
| P1-1 | Path trace + path view | Trace command, hop list with SNR, saved last path per contact | Trace to a 2-hop contact shows both hops | M |
| P1-2 | Delivery diagnosis sheet | From `messages.attempts`: attempt, route, ack, timing; suggest reset path / flood | Every failed DM opens a sheet with a reason | M |
| P1-3 | Repeater / room login and status | Login, status, neighbours, CLI with history; free | Logs into a repeater and reads status | M |
| P1-4 | Message search | SQL `LIKE`/FTS over messages | 10k messages search in <100 ms | S |
| P1-5 | RX log + noise floor | Raw RX push, ring buffer in DB, chart | Live log shows packets with SNR/RSSI | M |
| P1-6 | Telemetry request + history | Request telemetry; store; chart | Battery chart for a repeater | M |

### P2: differentiators
- SOS + check-ins compatible with old Core's text tags. **M**
- Contacts beyond the radio limit (favourites sync). **M**
- Offline tiles (area download) and GPX export. **M**
- Translations via `gen_l10n`. **M**
- Route health per contact. **M**
- Obtainium / F-Droid distribution. **S**

### P3: long-term
- MQTT observer feeds. **M**
- Bots. **M**
- iOS build and TestFlight. **L**
- Mac USB backend. **M**
- Firmware update. **L**

## 6. Top 25 recommended improvements

1. P0-1 Android foreground service + reconnect confirmation
2. P0-2 License
3. P0-3 Real-radio checklist per build
4. P1-2 Delivery diagnosis sheet
5. P1-1 Path trace + path view
6. P1-3 Repeater / room admin (free)
7. P1-4 Message search
8. P1-5 RX log + noise floor
9. P1-6 Telemetry history
10. Drafts and quick messages
11. Reactions and replies
12. SOS + check-ins
13. Contacts beyond the radio limit
14. Offline tiles
15. GPX export
16. Translations
17. Semantics pass on all screens
18. Signed channel posts
19. Route health per contact
20. Path hash size shown explicitly
21. Obtainium config
22. Smaller APK (drop bundled MLKit for the unbundled model, or a lighter scanner)
23. Mac USB backend
24. MQTT observer feeds
25. iOS build

## 7. Quick wins

- Message search (SQL over existing tables).
- "Radio has N of M contacts" meter (self info).
- Show path hash size in node details.
- Commit a LICENSE.
- Battery-optimisation card on Android (Connect proved this helps).

## 8. Innovation backlog

| Concept | Open question |
|---|---|
| Route health scoring | How much history is enough on a quiet mesh? |
| Contacts beyond radio limit | Swap policy that doesn't break pending DMs |
| Repeater ranking | Needs RX log volume to be meaningful |
| Interop with old Core SOS/check-in tags | Keep text formats identical, or version them |

**Do not build:** anything copied or adapted from meshcore-open or old Core; features that need a server account; images before the basics (trace, admin, search) exist.

## 9. Strategic scoring

0–10. Confidence H = source read (Independent, old Core), M = changelog/README (others).

| Area | Independent | Old Core | Official | MeshCore One |
|---|---|---|---|---|
| Ease of use | 7 (H) | 6 (H) | 8 (M) | 7 (M) |
| Messaging | 6 (H) | 9 (H) | 8 (M) | 8 (M) |
| Connectivity reliability | 7 (H) | 6 (H) | 7 (M) | 6 (M) |
| Mapping | 5 (H) | 9 (H) | 7 (M) | 7 (M) |
| Network diagnostics | 3 (H) | 9 (H) | 7 (M) | 9 (M) |
| Advanced features | 3 (H) | 9 (H) | 7 (M) | 7 (M) |
| Performance | 8 (H) | 5 (H) | 7 (M) | ? |
| Accessibility | 4 (H) | 6 (H) | ? | ? |
| Privacy and security | 7 (H) | 8 (H) | 6 (M) | 7 (M) |
| Overall | 5 | 8 | 8 | 7 |

**After P0 + P1:** about 7 overall (reliability 8, diagnostics 7, messaging 7), with better foundations than any MeshCore Open-derived app.

## 10. Executive summary

- **Strongest competitor:** the official MeshCore app. **Benchmark:** old NOTORYX Core.
- **What they do better:** breadth: diagnostics, repeater admin, safety, map tools, translations.
- **What Independent already does better:** durable SQLite history, reconnect on every link, a small layered codebase with independence enforced in CI.
- **Biggest market gaps it can fill:** explaining failed DMs; free repeater admin; an app that never loses history.
- **Build first:** the Android background link (foreground service), confirmed on a device.
- **Don't build:** anything adapted from meshcore-open or old Core; account-based features.
- **Five actions now:**
  1. Add the Android foreground service and confirm reconnect with the connection log.
  2. Choose and commit a license.
  3. Ship message search (quick win on the existing DB).
  4. Build the delivery diagnosis sheet from stored attempts.
  5. Build path trace + repeater login next.
