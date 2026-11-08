# Independent vs the current NOTORYX Core

What NOTORYX Independent still needs before it can replace the current NOTORYX Core as the everyday app.

Compared on 2026-11-07:
- **Independent (NX):** `main` at 0.1.0 test 15, plus the About screen (PR 38).
- **Current Core (NC):** `notoryx-core` `dev` at 566e910, 10.0.0-rc.36.

NC features come from its README and its list of screens and services. Its code was not read, and none of it is used here.

Nothing in this document was tested on hardware. NX rows marked "needs a radio test" have only run against the simulated radio.

| Code | Meaning |
|---|---|
| ✅ | Has it |
| 🟡 | Partly: the note says what's missing |
| ❌ | Missing |

**Totals (86 features):** NX has 35 (41%), partly has 12 (14%) and is missing 39 (45%).

The missing features are mostly power tools: MQTT, bots, coverage mapping, network scan. Most of what a hiker or a group chat uses day to day is already there.

## Safety and trips

| Feature | NX | Note |
|---|---|---|
| SOS with position | 🟡 | NX: tap and confirm, sent once. NC: hold 2 s, repeats every 5 min until someone replies or you stop it, and **I'm safe** sends an all-clear |
| Check-ins | 🟡 | NX: one "I'm OK" to one chat. NC: I'm OK / At camp / Delayed / Heading back, shows who each reached, and can resend to anyone it missed |
| Check-in reminder and missed check-in alert | ✅ | NX sends a "Missed check-in" to the chat after a 15-minute grace period |
| Overdue warning when a trip contact goes quiet | ❌ | NC watches *other* people's check-ins |
| Trip planning (up to 6 contacts, brief, Field Log) | ❌ | NX has one target chat |
| Signed SOS and channel posts | ❌ | NC signs posts with the radio's key |
| SOS relay | ❌ | Off by default in NC, and not field-tested there |
| Android home-screen widget (status, check-in, SOS) | ❌ | |

## Messaging

| Feature | NX | Note |
|---|---|---|
| Direct and channel messages, delivery status | ✅ | |
| Retries, flood fallback, stop retrying, resend | ✅ | |
| Delivery details | ✅ | |
| "They need to add you" note in new direct chats | ✅ | |
| Unread counts, mute, notifications that open the chat | ✅ | |
| Message search | ✅ | |
| Drafts | ✅ | |
| Quick messages | ✅ | |
| Reactions | ✅ | |
| Replies | ✅ | NX replies are `@[Name]` mentions |
| Mentions highlighted, and blocking senders | ❌ | NC highlights @mentions and has a blocked-senders list and spam filtering |
| Room servers | ✅ | |
| Hashtag, private and link channels | ✅ | |
| Channel directory and channels heard on air | ❌ | NC lists public hashtag channels (local first), channels heard but not joined, and channels active online |
| Share your position or a contact from the message box | ❌ | |
| Add a contact from the clipboard | 🟡 | NX accepts `meshcore://` links. NC also accepts adverts and bare public keys |
| Add discovered contacts | 🟡 | NX adds one at a time. NC can multi-select or **Add all shown**, up to the room left |
| Images and GIFs | ❌ | |
| Read aloud and on-device translation | ❌ | |
| Region tags on channel posts (📍 ct) | ❌ | |
| Link previews | ❌ | Off by default in NC (fetching one reveals your IP) |
| Auto-delete old channel messages | ❌ | |
| Area-limited channel messages | ❌ | Needs flood-corridor firmware |

## Maps, paths and coverage

| Feature | NX | Note |
|---|---|---|
| Live map, nodes, my position | ✅ | |
| Offline map | 🟡 | NX keeps tiles you've already viewed (500 MB, 30 days). NC has offline map packs. OpenStreetMap's tile policy forbids bulk downloads from its servers, so packs would need another source |
| Track log and GPX export | ❌ | |
| Telemetry badges on the map | ❌ | NX has the readings (telemetry history), but doesn't show them on the map |
| Path trace | ✅ | Needs a radio test |
| Path graph and Route Intelligence | ❌ | |
| Wardrive | ❌ | |
| Network scan across presets | ❌ | |
| Observer reach via a CoreScope analyzer | ❌ | Needs an internet service |
| Coverage hexagons, antenna coverage, line of sight | ❌ | |

## Your radio

| Feature | NX | Note |
|---|---|---|
| Radio settings (name, position, power, LoRa, auto-add) | ✅ | |
| Local mesh (area) settings | ✅ | Same `regional_presets.json` as NC |
| Community preset catalogue by country | 🟡 | NX offers area presets and manual LoRa settings, but not MeshCore's country catalogue |
| Advert, zero-hop or flooded | ✅ | |
| Own sensors and battery | 🟡 | NX: telemetry history in Radio settings. NC also shows them on Home |
| Radio stats and noise-floor chart | ✅ | Needs a radio test |
| Adjustable refresh rate and battery saver | ❌ | |
| Contact meter and making room | ✅ | NC has a contact-table banner |
| Command line for your own radio, Wi-Fi setup | ❌ | |
| A trusted contact's command line | ❌ | |

## Field and repeater tools

| Feature | NX | Note |
|---|---|---|
| Repeater login, status, console | ✅ | |
| Repeater and room telemetry | ✅ | Needs a radio test |
| Repeater neighbors | ❌ | |
| Repeater access control | ❌ | |
| Repeater ping (one hop, signal both ways) | 🟡 | NX's path trace covers it, but there's no one-tap ping |
| Antenna hunt | ❌ | |
| Forget last advert | ❌ | |
| Repeater IDs and region setup | ❌ | |
| Bot Mode | ❌ | |
| Field guide | ❌ | |
| Packet log | ✅ | |
| Connection log | ✅ | NC also has separate Bluetooth and app debug logs |

## Connecting

| Feature | NX | Note |
|---|---|---|
| Bluetooth | ✅ | |
| Wi-Fi (TCP) | ✅ | |
| USB, Android | ✅ | |
| USB, Mac | ❌ | |
| Connect automatically at launch | ✅ | |
| Reconnect after a drop | 🟡 | NX reconnects over every transport on Mac. **Not confirmed on Android** |
| Stay connected in the background (Android) | 🟡 | Built in test 12; needs a phone test |
| Battery optimisation prompt | ✅ | |
| Radio clock sync | ✅ | |

## Data, look and platforms

| Feature | NX | Note |
|---|---|---|
| SQLite store with tested upgrades | ✅ | Both apps have one now (NC since rc.34) |
| Encrypted backup and restore | ❌ | |
| MQTT bridge (brokers, packet feed, observer sharing, LetsMesh sign-in) | ❌ | |
| Themes | 🟡 | NX: system light/dark. NC: eight themes, all at WCAG AA |
| Colour-blind-safe node colours | ❌ | NC uses the Okabe-Ito palette |
| Chat text size | ❌ | |
| Languages | ❌ | NX is English only; NC has 18 languages |
| Screen-reader labels | 🟡 | Newer NX screens have them, but they haven't been checked across the whole app |
| About screen with copyable report details | ✅ | PR 38 |
| App-icon shortcuts | ❌ | |
| Android and macOS builds | ✅ | |
| iOS build | ❌ | |
| Automatic updates (Obtainium) | ✅ | |
| Zero meshcore-open code | ✅ | NX only; CI-checked |

## What to build, in order

Ranked by whether someone could switch to NX for everyday use without missing it.

**1. Blocks switching**
1. **Android reconnect and background confirmed on a phone.** This needs a hardware test, not code: without it, nothing else matters.
2. **SOS parity:** hold to send, repeat until someone answers or you stop, and **I'm safe**.
3. **Check-in kinds and trip contacts:** several contacts, who it reached, resend to the missed ones, and overdue warnings for others.
4. **Encrypted backup and restore**, so a phone change doesn't lose chats.
5. **Block senders and highlight mentions.** Public channels get spam.
6. **Channel directory and channels heard on air**, so people can find their local channels.
7. **Share position or a contact in a chat.**

**2. Expected by regular users**
1. Track log with GPX export, and telemetry badges on the map.
2. Repeater neighbors, access control and one-tap ping.
3. Command line for your own radio.
4. Themes, including a colour-blind-safe one, and chat text size.
5. Getting the app ready for translation: move its text into one place first, then add languages.
6. Clipboard add for adverts and keys, and multi-add from discovered contacts.
7. Auto-delete old channel messages, and the Android home-screen widget.

**3. Power tools (later, or never)**
- MQTT bridge, Bot Mode, wardrive, network scan, path graph and Route Intelligence, coverage and line of sight, observer reach, images and GIFs, signed posts, SOS relay, area-limited messages, link previews, read aloud, translation, USB on Mac, iOS.
