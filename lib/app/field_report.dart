/// Fill-in report templates for the field: SALUTE and 9-Line MEDEVAC.
///
/// The lines are the standard public ones. A radio message holds 160 bytes,
/// so a long report goes out as numbered parts, split between fields.
library;

import 'dart:convert';

import '../data/data.dart';

/// One line of a report.
typedef ReportField = ({String tag, String label, String hint});

/// A kind of report.
final class ReportTemplate {
  const ReportTemplate({
    required this.title,
    required this.heading,
    required this.locationField,
    required this.fields,
  });

  final String title;

  /// What the message starts with.
  final String heading;

  /// The index in [fields] that takes a position.
  final int locationField;

  final List<ReportField> fields;
}

const saluteReport = ReportTemplate(
  title: 'SALUTE report',
  heading: 'SALUTE',
  locationField: 2,
  fields: [
    (tag: 'S', label: 'Size', hint: 'How many people or vehicles'),
    (tag: 'A', label: 'Activity', hint: 'What they are doing'),
    (tag: 'L', label: 'Location', hint: 'Where'),
    (tag: 'U', label: 'Unit', hint: 'Who: uniform, group, markings'),
    (tag: 'T', label: 'Time', hint: 'When you saw it'),
    (tag: 'E', label: 'Equipment', hint: 'What they have with them'),
  ],
);

const nineLineReport = ReportTemplate(
  title: '9-Line MEDEVAC',
  heading: '9-LINE',
  locationField: 0,
  fields: [
    (tag: '1', label: '1. Pickup location', hint: 'Grid or coordinates'),
    (tag: '2', label: '2. Frequency and call sign', hint: '#ops, Base 1'),
    (tag: '3', label: '3. Patients by precedence', hint: '1 urgent, 2 routine'),
    (tag: '4', label: '4. Special equipment', hint: 'None, hoist, ventilator'),
    (tag: '5', label: '5. Patients by type', hint: '1 litter, 2 walking'),
    (tag: '6', label: '6. Security at pickup', hint: 'No danger, possible'),
    (tag: '7', label: '7. Marking of pickup site', hint: 'Panel, smoke, light'),
    (tag: '8', label: '8. Patient status', hint: 'Civilian, team member'),
    (tag: '9', label: '9. Terrain and hazards', hint: 'Flat, wires, trees'),
  ],
);

/// The filled-in fields as `tag:value` parts. Empty fields are left out.
List<String> reportParts(ReportTemplate template, List<String> values) => [
  for (var i = 0; i < template.fields.length; i++)
    if (values[i].trim().isNotEmpty)
      '${template.fields[i].tag}:${values[i].trim()}',
];

/// The messages for a report, or null when one field is too long to fit in
/// a message. Empty when nothing is filled in.
List<String>? reportMessages(ReportTemplate template, List<String> values) {
  final parts = reportParts(template, values);
  if (parts.isEmpty) return const [];
  int size(String s) => utf8.encode(s).length;
  // Room for "9-LINE 10/10 " on every message, so numbering can't overflow.
  final room = maxDirectTextBytes - size('${template.heading} 10/10 ');
  final chunks = <String>[];
  var current = '';
  for (final part in parts) {
    if (size(part) > room) return null;
    final joined = current.isEmpty ? part : '$current | $part';
    if (size(joined) > room) {
      chunks.add(current);
      current = part;
    } else {
      current = joined;
    }
  }
  chunks.add(current);
  return [
    for (var i = 0; i < chunks.length; i++)
      chunks.length == 1
          ? '${template.heading} ${chunks[i]}'
          : '${template.heading} ${i + 1}/${chunks.length} ${chunks[i]}',
  ];
}
