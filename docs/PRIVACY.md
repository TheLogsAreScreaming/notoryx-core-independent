# NOTORYX Independent privacy policy

NOTORYX Independent is a client for MeshCore LoRa radios. It has no accounts. Its developer receives data only if you turn on the optional Community moderation feature and send a report or appeal. It contains no advertising, analytics or crash-reporting SDK.

## Stored on your phone
Messages, contacts, channels, telemetry, recorded tracks and settings are kept in the app's private storage. Android's own device backup may include this data if you have backup turned on; your Android and Google settings control that. Encrypted backup files are created only when you make one, and are saved where you choose.

## What leaves your phone, and when
- **Over your radio:** messages, node information and any position you choose to share are sent over the air through your radio. Other mesh users and anyone listening can receive them. Channels and direct messages are protected only as far as the mesh protocol and your channel settings provide.
- **Map tiles:** when you view the map, the app downloads tiles from OpenStreetMap's servers, which receive your IP address and the areas requested.
- **Area presets:** the app can download a list of regional radio settings from GitHub, which receives your IP address.
- **Radio over Wi-Fi:** if you connect to a radio by address, the app talks directly to that address.
- **Community moderation:** off unless you turn it on (Radio settings → Community moderation). While it is on, the app downloads the moderators' advisory ban list (node IDs and case numbers only) from sentinel-relay.meshmayhem.org every few hours. When you report a node, it sends that node's public key or channel name, its name, the reason you pick, your optional note and, if you leave it ticked, the one message you reported (at most 280 characters). An appeal sends the case number, your statement and any contact you give. NOTORYX moderators read reports and appeals; your own name, key and location are not sent with a report, but the relay receives your IP address. Turning it off deletes the downloaded list and any unsent reports.
- **Sharing and export:** files and text leave the app only when you share or save them yourself.

## Permissions
- **Bluetooth:** to find and connect to your radio.
- **Location:** to show you on the map, to fill in a position you choose to share, and to record a track when you start one. While a track is recording, a notification stays on screen and location is used even with the screen off. Android versions before 12 also require location for Bluetooth scanning.
- **Camera:** to scan QR codes, only while the scanner is open.
- **Biometrics:** to unlock the app if you turn on app lock. Your fingerprint or face data stays with Android and is never given to the app.
- **Foreground service:** to keep the radio connected in the background when you turn that on.

QR codes are read on your phone by Google's ML Kit barcode component, which may send Google device and usage diagnostics. It does not send camera images.

## Children
The app is not directed at children under 13.

Questions or requests: bastionappsupport@gmail.com

Effective date: November 9, 2026
