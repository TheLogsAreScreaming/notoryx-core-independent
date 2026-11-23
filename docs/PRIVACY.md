# NOTORYX Independent privacy policy

NOTORYX Independent is a client for MeshCore LoRa radios. It has no accounts. Its developer receives data only if you turn on the optional Community moderation feature and send a report or appeal. It contains no advertising, analytics or crash-reporting SDK.

## Stored on your phone
Messages, contacts, channels, telemetry, recorded tracks, settings, and any photo or colour you pick for a node are kept in the app's private storage. Node photos are shrunk to a small square and are never sent over the radio. Android's own device backup may include this data if you have backup turned on; your Android and Google settings control that. Encrypted backup files are created only when you make one, and are saved where you choose.

## What leaves your phone, and when
- **Over your radio:** messages, node information and any position you choose to share are sent over the air through your radio. Other mesh users and anyone listening can receive them. Channels and direct messages are protected only as far as the mesh protocol and your channel settings provide.
- **Map tiles:** when you view the map, the app downloads tiles from OpenStreetMap's servers, which receive your IP address and the areas requested.
- **Terrain check:** only when you tap Check terrain on a node, the app sends 64 points along the line between your radio and that node to the free Open-Meteo elevation service (api.open-meteo.com) to get ground heights. Open-Meteo receives those points and your IP address.
- **Area presets:** the app can download a list of regional radio settings from GitHub, which receives your IP address.
- **Radio over Wi-Fi:** if you connect to a radio by address, the app talks directly to that address.
- **Community moderation:** off unless you turn it on (Radio settings → Community moderation). While it is on, the app downloads the moderators' advisory ban list (node IDs and case numbers only) from sentinel-relay.meshmayhem.org every few hours. When you report a node, it sends that node's public key or channel name, its name, the reason you pick, your optional note and, if you leave it ticked, the one message you reported (at most 280 characters). An appeal sends the case number, your statement and any contact you give. NOTORYX moderators read reports and appeals; your own name, key and location are not sent with a report, but the relay receives your IP address. Turning it off deletes the downloaded list and any unsent reports.
- **Coverage map:** off unless you agree to it (Wardrive → Share with the NOTORYX coverage map). While it is on and a wardrive is running, the app notes what your radio hears in each hexagon about 0.9 km across, in 15-minute blocks, and keeps that on your phone for 7 days. It sends coverage.meshmayhem.org, per hexagon: the hexagon, the 15-minute time, how many packets were heard, the best SNR and RSSI, and the short IDs of repeaters heard directly with their SNR. With Live or Delayed privacy (Delayed, the default, waits 3 hours) uploads are signed by a coverage key made on your phone, which is not your radio's identity, so you can erase them later; they also carry your optional mapper name, shown only to coverage map members, and repeaters you know that advertised a position (their key, name, position and advert time). Anonymous sends no key, name or repeater list, rounds times to the day and waits a day; it can't be erased. Your GPS track, exact position, messages and contacts are never sent, and the first and last 2 hexagons of each drive stay on the phone unless you turn that off. Uploads go over Wi-Fi only unless you change that. The server receives your IP address. Stop sharing deletes readings not sent yet; Erase my uploads asks the server to delete everything your coverage key sent.
- **Sharing and export:** files and text leave the app only when you share or save them yourself.

## Permissions
- **Bluetooth:** to find and connect to your radio.
- **Location:** to show you on the map, to fill in a position you choose to share, to record a track when you start one, and to place wardrive and coverage map readings. While a track is recording, a notification stays on screen and location is used even with the screen off. Android versions before 12 also require location for Bluetooth scanning.
- **Camera:** to scan QR codes, only while the scanner is open.
- **Biometrics:** to unlock the app if you turn on app lock. Your fingerprint or face data stays with Android and is never given to the app.
- **Foreground service:** to keep the radio connected in the background when you turn that on.

QR codes are read on your phone by Google's ML Kit barcode component, which may send Google device and usage diagnostics. It does not send camera images.

## Children
The app is not directed at children under 13.

Questions or requests: bastionappsupport@gmail.com

Effective date: November 23, 2026
