/// Tools for repeater owners: which short IDs are taken, and building the
/// commands that set up a repeater's regions.
library;

import '../radio/protocol/region_scope.dart';

/// A node using a short ID.
typedef IdUser = ({String name, String publicKey});

/// Who uses each 1-byte ID (the first byte of a key), by value.
Map<int, List<IdUser>> repeaterIdUsage(Iterable<IdUser> nodes) {
  final used = <int, List<IdUser>>{};
  for (final node in nodes) {
    if (node.publicKey.length < 2) continue;
    final id = int.tryParse(node.publicKey.substring(0, 2), radix: 16);
    if (id == null) continue;
    (used[id] ??= []).add(node);
  }
  return used;
}

/// The IDs nobody heard is using. 00 and FF are left out, since firmware
/// and tools treat them specially.
List<int> freeRepeaterIds(Map<int, List<IdUser>> used) => [
  for (var id = 1; id < 0xFF; id++)
    if (!used.containsKey(id)) id,
];

/// "AB" for an ID.
String idLabel(int id) => id.toRadixString(16).padLeft(2, '0').toUpperCase();

const usRegions = [
  'al', 'ak', 'az', 'ar', 'ca', 'co', 'ct', 'de', 'dc', 'fl', 'ga', 'hi', //
  'id', 'il', 'in', 'ia', 'ks', 'ky', 'la', 'me', 'md', 'ma', 'mi', 'mn', //
  'ms', 'mo', 'mt', 'ne', 'nv', 'nh', 'nj', 'nm', 'ny', 'nc', 'nd', 'oh', //
  'ok', 'or', 'pa', 'ri', 'sc', 'sd', 'tn', 'tx', 'ut', 'vt', 'va', 'wa', //
  'wv', 'wi', 'wy',
];

const canadaRegions = [
  'ab', 'bc', 'mb', 'nb', 'nl', 'ns', 'nt', 'nu', 'on', 'pe', 'qc', 'sk', //
  'yt',
];

/// The commands that add [regions] under [parent], make [home] this
/// repeater's home region, and save. They only add: nothing is removed or
/// blocked. [parent] may be null for a flat list.
List<String> regionSetupCommands({
  required Iterable<String> regions,
  String? parent,
  String? home,
}) {
  final top = cleanRegionName(parent);
  final names = {for (final r in regions) ?cleanRegionName(r)}..remove(top);
  if (names.isEmpty) return const [];
  final homeName = cleanRegionName(home);
  return [
    if (top != null) 'region put $top',
    for (final n in names) top == null ? 'region put $n' : 'region put $n $top',
    if (homeName != null && names.contains(homeName)) 'region home $homeName',
    'region save',
  ];
}
