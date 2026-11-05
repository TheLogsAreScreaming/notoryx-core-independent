# NOTORYX Core (independent)

A MeshCore LoRa companion app for Android, iOS and macOS, written from
scratch for this repository.

## Status

In development. The current NOTORYX Core releases keep shipping from the
existing app; this one replaces it once it matches its features.

Builds are published to
[notoryx-core-independent-releases](https://github.com/TheLogsAreScreaming/notoryx-core-independent-releases).

Build order:

1. Radio core: frame codec and BLE, USB and TCP links, written from
   MeshCore's [companion protocol](https://github.com/meshcore-dev/MeshCore/blob/main/docs/companion_protocol.md)
   and the firmware source
2. Data layer: contacts, messages, channels and settings
3. Screens: chats, nodes, map, radio and tools
4. Helpers: SMAZ, Cayenne LPP, LoRa airtime, GPX export

## The independence rule

No code from meshcore-open goes into this repository, copied or adapted.
Write from the protocol documentation and the firmware instead.

CI enforces this: `tools/check_independence.py` compares every source file
against the latest meshcore-open and fails on any copied block or leftover
name. Run it locally before pushing:

```bash
git clone --depth 1 https://github.com/zjs81/meshcore-open.git /tmp/meshcore-open
python3 tools/check_independence.py /tmp/meshcore-open .
```

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

App IDs are `com.bastionmesh.notoryx_core` (Android) and
`com.bastionmesh.notoryxCore` (iOS, macOS), so this app installs alongside
the current NOTORYX Core.
