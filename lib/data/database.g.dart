// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RadiosTable extends Radios with TableInfo<$RadiosTable, Radio> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RadiosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _publicKeyMeta = const VerificationMeta(
    'publicKey',
  );
  @override
  late final GeneratedColumn<String> publicKey = GeneratedColumn<String>(
    'public_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastConnectedAtMeta = const VerificationMeta(
    'lastConnectedAt',
  );
  @override
  late final GeneratedColumn<int> lastConnectedAt = GeneratedColumn<int>(
    'last_connected_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contactsSinceMeta = const VerificationMeta(
    'contactsSince',
  );
  @override
  late final GeneratedColumn<int> contactsSince = GeneratedColumn<int>(
    'contacts_since',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    publicKey,
    name,
    lastConnectedAt,
    contactsSince,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'radios';
  @override
  VerificationContext validateIntegrity(
    Insertable<Radio> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('public_key')) {
      context.handle(
        _publicKeyMeta,
        publicKey.isAcceptableOrUnknown(data['public_key']!, _publicKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_publicKeyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('last_connected_at')) {
      context.handle(
        _lastConnectedAtMeta,
        lastConnectedAt.isAcceptableOrUnknown(
          data['last_connected_at']!,
          _lastConnectedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastConnectedAtMeta);
    }
    if (data.containsKey('contacts_since')) {
      context.handle(
        _contactsSinceMeta,
        contactsSince.isAcceptableOrUnknown(
          data['contacts_since']!,
          _contactsSinceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {publicKey};
  @override
  Radio map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Radio(
      publicKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}public_key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      lastConnectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_connected_at'],
      )!,
      contactsSince: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}contacts_since'],
      )!,
    );
  }

  @override
  $RadiosTable createAlias(String alias) {
    return $RadiosTable(attachedDatabase, alias);
  }
}

class Radio extends DataClass implements Insertable<Radio> {
  /// The radio's public key, hex.
  final String publicKey;
  final String name;
  final int lastConnectedAt;

  /// Newest contact `lastModified` seen, so the next sync only fetches
  /// changes. Zero means fetch everything.
  final int contactsSince;
  const Radio({
    required this.publicKey,
    required this.name,
    required this.lastConnectedAt,
    required this.contactsSince,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['public_key'] = Variable<String>(publicKey);
    map['name'] = Variable<String>(name);
    map['last_connected_at'] = Variable<int>(lastConnectedAt);
    map['contacts_since'] = Variable<int>(contactsSince);
    return map;
  }

  RadiosCompanion toCompanion(bool nullToAbsent) {
    return RadiosCompanion(
      publicKey: Value(publicKey),
      name: Value(name),
      lastConnectedAt: Value(lastConnectedAt),
      contactsSince: Value(contactsSince),
    );
  }

  factory Radio.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Radio(
      publicKey: serializer.fromJson<String>(json['publicKey']),
      name: serializer.fromJson<String>(json['name']),
      lastConnectedAt: serializer.fromJson<int>(json['lastConnectedAt']),
      contactsSince: serializer.fromJson<int>(json['contactsSince']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'publicKey': serializer.toJson<String>(publicKey),
      'name': serializer.toJson<String>(name),
      'lastConnectedAt': serializer.toJson<int>(lastConnectedAt),
      'contactsSince': serializer.toJson<int>(contactsSince),
    };
  }

  Radio copyWith({
    String? publicKey,
    String? name,
    int? lastConnectedAt,
    int? contactsSince,
  }) => Radio(
    publicKey: publicKey ?? this.publicKey,
    name: name ?? this.name,
    lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    contactsSince: contactsSince ?? this.contactsSince,
  );
  Radio copyWithCompanion(RadiosCompanion data) {
    return Radio(
      publicKey: data.publicKey.present ? data.publicKey.value : this.publicKey,
      name: data.name.present ? data.name.value : this.name,
      lastConnectedAt: data.lastConnectedAt.present
          ? data.lastConnectedAt.value
          : this.lastConnectedAt,
      contactsSince: data.contactsSince.present
          ? data.contactsSince.value
          : this.contactsSince,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Radio(')
          ..write('publicKey: $publicKey, ')
          ..write('name: $name, ')
          ..write('lastConnectedAt: $lastConnectedAt, ')
          ..write('contactsSince: $contactsSince')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(publicKey, name, lastConnectedAt, contactsSince);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Radio &&
          other.publicKey == this.publicKey &&
          other.name == this.name &&
          other.lastConnectedAt == this.lastConnectedAt &&
          other.contactsSince == this.contactsSince);
}

class RadiosCompanion extends UpdateCompanion<Radio> {
  final Value<String> publicKey;
  final Value<String> name;
  final Value<int> lastConnectedAt;
  final Value<int> contactsSince;
  final Value<int> rowid;
  const RadiosCompanion({
    this.publicKey = const Value.absent(),
    this.name = const Value.absent(),
    this.lastConnectedAt = const Value.absent(),
    this.contactsSince = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RadiosCompanion.insert({
    required String publicKey,
    required String name,
    required int lastConnectedAt,
    this.contactsSince = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : publicKey = Value(publicKey),
       name = Value(name),
       lastConnectedAt = Value(lastConnectedAt);
  static Insertable<Radio> custom({
    Expression<String>? publicKey,
    Expression<String>? name,
    Expression<int>? lastConnectedAt,
    Expression<int>? contactsSince,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (publicKey != null) 'public_key': publicKey,
      if (name != null) 'name': name,
      if (lastConnectedAt != null) 'last_connected_at': lastConnectedAt,
      if (contactsSince != null) 'contacts_since': contactsSince,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RadiosCompanion copyWith({
    Value<String>? publicKey,
    Value<String>? name,
    Value<int>? lastConnectedAt,
    Value<int>? contactsSince,
    Value<int>? rowid,
  }) {
    return RadiosCompanion(
      publicKey: publicKey ?? this.publicKey,
      name: name ?? this.name,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      contactsSince: contactsSince ?? this.contactsSince,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (publicKey.present) {
      map['public_key'] = Variable<String>(publicKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lastConnectedAt.present) {
      map['last_connected_at'] = Variable<int>(lastConnectedAt.value);
    }
    if (contactsSince.present) {
      map['contacts_since'] = Variable<int>(contactsSince.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RadiosCompanion(')
          ..write('publicKey: $publicKey, ')
          ..write('name: $name, ')
          ..write('lastConnectedAt: $lastConnectedAt, ')
          ..write('contactsSince: $contactsSince, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContactsTable extends Contacts with TableInfo<$ContactsTable, Contact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _radioKeyMeta = const VerificationMeta(
    'radioKey',
  );
  @override
  late final GeneratedColumn<String> radioKey = GeneratedColumn<String>(
    'radio_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES radios (public_key)',
    ),
  );
  static const VerificationMeta _publicKeyMeta = const VerificationMeta(
    'publicKey',
  );
  @override
  late final GeneratedColumn<String> publicKey = GeneratedColumn<String>(
    'public_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _flagsMeta = const VerificationMeta('flags');
  @override
  late final GeneratedColumn<int> flags = GeneratedColumn<int>(
    'flags',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outPathLengthMeta = const VerificationMeta(
    'outPathLength',
  );
  @override
  late final GeneratedColumn<int> outPathLength = GeneratedColumn<int>(
    'out_path_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outPathMeta = const VerificationMeta(
    'outPath',
  );
  @override
  late final GeneratedColumn<Uint8List> outPath = GeneratedColumn<Uint8List>(
    'out_path',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAdvertMeta = const VerificationMeta(
    'lastAdvert',
  );
  @override
  late final GeneratedColumn<int> lastAdvert = GeneratedColumn<int>(
    'last_advert',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  @override
  late final GeneratedColumn<int> lastModified = GeneratedColumn<int>(
    'last_modified',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    radioKey,
    publicKey,
    name,
    type,
    flags,
    outPathLength,
    outPath,
    lastAdvert,
    latitude,
    longitude,
    lastModified,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Contact> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('radio_key')) {
      context.handle(
        _radioKeyMeta,
        radioKey.isAcceptableOrUnknown(data['radio_key']!, _radioKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_radioKeyMeta);
    }
    if (data.containsKey('public_key')) {
      context.handle(
        _publicKeyMeta,
        publicKey.isAcceptableOrUnknown(data['public_key']!, _publicKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_publicKeyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('flags')) {
      context.handle(
        _flagsMeta,
        flags.isAcceptableOrUnknown(data['flags']!, _flagsMeta),
      );
    } else if (isInserting) {
      context.missing(_flagsMeta);
    }
    if (data.containsKey('out_path_length')) {
      context.handle(
        _outPathLengthMeta,
        outPathLength.isAcceptableOrUnknown(
          data['out_path_length']!,
          _outPathLengthMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_outPathLengthMeta);
    }
    if (data.containsKey('out_path')) {
      context.handle(
        _outPathMeta,
        outPath.isAcceptableOrUnknown(data['out_path']!, _outPathMeta),
      );
    } else if (isInserting) {
      context.missing(_outPathMeta);
    }
    if (data.containsKey('last_advert')) {
      context.handle(
        _lastAdvertMeta,
        lastAdvert.isAcceptableOrUnknown(data['last_advert']!, _lastAdvertMeta),
      );
    } else if (isInserting) {
      context.missing(_lastAdvertMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastModifiedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {radioKey, publicKey};
  @override
  Contact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Contact(
      radioKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}radio_key'],
      )!,
      publicKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}public_key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      flags: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}flags'],
      )!,
      outPathLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}out_path_length'],
      )!,
      outPath: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}out_path'],
      )!,
      lastAdvert: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_advert'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_modified'],
      )!,
    );
  }

  @override
  $ContactsTable createAlias(String alias) {
    return $ContactsTable(attachedDatabase, alias);
  }
}

class Contact extends DataClass implements Insertable<Contact> {
  final String radioKey;
  final String publicKey;
  final String name;

  /// `NodeType.value`: chat, repeater, room or sensor.
  final int type;
  final int flags;

  /// Encoded route length, 0xFF for none.
  final int outPathLength;
  final Uint8List outPath;
  final int lastAdvert;
  final double? latitude;
  final double? longitude;
  final int lastModified;
  const Contact({
    required this.radioKey,
    required this.publicKey,
    required this.name,
    required this.type,
    required this.flags,
    required this.outPathLength,
    required this.outPath,
    required this.lastAdvert,
    this.latitude,
    this.longitude,
    required this.lastModified,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['radio_key'] = Variable<String>(radioKey);
    map['public_key'] = Variable<String>(publicKey);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<int>(type);
    map['flags'] = Variable<int>(flags);
    map['out_path_length'] = Variable<int>(outPathLength);
    map['out_path'] = Variable<Uint8List>(outPath);
    map['last_advert'] = Variable<int>(lastAdvert);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    map['last_modified'] = Variable<int>(lastModified);
    return map;
  }

  ContactsCompanion toCompanion(bool nullToAbsent) {
    return ContactsCompanion(
      radioKey: Value(radioKey),
      publicKey: Value(publicKey),
      name: Value(name),
      type: Value(type),
      flags: Value(flags),
      outPathLength: Value(outPathLength),
      outPath: Value(outPath),
      lastAdvert: Value(lastAdvert),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      lastModified: Value(lastModified),
    );
  }

  factory Contact.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Contact(
      radioKey: serializer.fromJson<String>(json['radioKey']),
      publicKey: serializer.fromJson<String>(json['publicKey']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<int>(json['type']),
      flags: serializer.fromJson<int>(json['flags']),
      outPathLength: serializer.fromJson<int>(json['outPathLength']),
      outPath: serializer.fromJson<Uint8List>(json['outPath']),
      lastAdvert: serializer.fromJson<int>(json['lastAdvert']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      lastModified: serializer.fromJson<int>(json['lastModified']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'radioKey': serializer.toJson<String>(radioKey),
      'publicKey': serializer.toJson<String>(publicKey),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<int>(type),
      'flags': serializer.toJson<int>(flags),
      'outPathLength': serializer.toJson<int>(outPathLength),
      'outPath': serializer.toJson<Uint8List>(outPath),
      'lastAdvert': serializer.toJson<int>(lastAdvert),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'lastModified': serializer.toJson<int>(lastModified),
    };
  }

  Contact copyWith({
    String? radioKey,
    String? publicKey,
    String? name,
    int? type,
    int? flags,
    int? outPathLength,
    Uint8List? outPath,
    int? lastAdvert,
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    int? lastModified,
  }) => Contact(
    radioKey: radioKey ?? this.radioKey,
    publicKey: publicKey ?? this.publicKey,
    name: name ?? this.name,
    type: type ?? this.type,
    flags: flags ?? this.flags,
    outPathLength: outPathLength ?? this.outPathLength,
    outPath: outPath ?? this.outPath,
    lastAdvert: lastAdvert ?? this.lastAdvert,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    lastModified: lastModified ?? this.lastModified,
  );
  Contact copyWithCompanion(ContactsCompanion data) {
    return Contact(
      radioKey: data.radioKey.present ? data.radioKey.value : this.radioKey,
      publicKey: data.publicKey.present ? data.publicKey.value : this.publicKey,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      flags: data.flags.present ? data.flags.value : this.flags,
      outPathLength: data.outPathLength.present
          ? data.outPathLength.value
          : this.outPathLength,
      outPath: data.outPath.present ? data.outPath.value : this.outPath,
      lastAdvert: data.lastAdvert.present
          ? data.lastAdvert.value
          : this.lastAdvert,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Contact(')
          ..write('radioKey: $radioKey, ')
          ..write('publicKey: $publicKey, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('flags: $flags, ')
          ..write('outPathLength: $outPathLength, ')
          ..write('outPath: $outPath, ')
          ..write('lastAdvert: $lastAdvert, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('lastModified: $lastModified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    radioKey,
    publicKey,
    name,
    type,
    flags,
    outPathLength,
    $driftBlobEquality.hash(outPath),
    lastAdvert,
    latitude,
    longitude,
    lastModified,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Contact &&
          other.radioKey == this.radioKey &&
          other.publicKey == this.publicKey &&
          other.name == this.name &&
          other.type == this.type &&
          other.flags == this.flags &&
          other.outPathLength == this.outPathLength &&
          $driftBlobEquality.equals(other.outPath, this.outPath) &&
          other.lastAdvert == this.lastAdvert &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.lastModified == this.lastModified);
}

class ContactsCompanion extends UpdateCompanion<Contact> {
  final Value<String> radioKey;
  final Value<String> publicKey;
  final Value<String> name;
  final Value<int> type;
  final Value<int> flags;
  final Value<int> outPathLength;
  final Value<Uint8List> outPath;
  final Value<int> lastAdvert;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<int> lastModified;
  final Value<int> rowid;
  const ContactsCompanion({
    this.radioKey = const Value.absent(),
    this.publicKey = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.flags = const Value.absent(),
    this.outPathLength = const Value.absent(),
    this.outPath = const Value.absent(),
    this.lastAdvert = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactsCompanion.insert({
    required String radioKey,
    required String publicKey,
    required String name,
    required int type,
    required int flags,
    required int outPathLength,
    required Uint8List outPath,
    required int lastAdvert,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    required int lastModified,
    this.rowid = const Value.absent(),
  }) : radioKey = Value(radioKey),
       publicKey = Value(publicKey),
       name = Value(name),
       type = Value(type),
       flags = Value(flags),
       outPathLength = Value(outPathLength),
       outPath = Value(outPath),
       lastAdvert = Value(lastAdvert),
       lastModified = Value(lastModified);
  static Insertable<Contact> custom({
    Expression<String>? radioKey,
    Expression<String>? publicKey,
    Expression<String>? name,
    Expression<int>? type,
    Expression<int>? flags,
    Expression<int>? outPathLength,
    Expression<Uint8List>? outPath,
    Expression<int>? lastAdvert,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? lastModified,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (radioKey != null) 'radio_key': radioKey,
      if (publicKey != null) 'public_key': publicKey,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (flags != null) 'flags': flags,
      if (outPathLength != null) 'out_path_length': outPathLength,
      if (outPath != null) 'out_path': outPath,
      if (lastAdvert != null) 'last_advert': lastAdvert,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (lastModified != null) 'last_modified': lastModified,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactsCompanion copyWith({
    Value<String>? radioKey,
    Value<String>? publicKey,
    Value<String>? name,
    Value<int>? type,
    Value<int>? flags,
    Value<int>? outPathLength,
    Value<Uint8List>? outPath,
    Value<int>? lastAdvert,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<int>? lastModified,
    Value<int>? rowid,
  }) {
    return ContactsCompanion(
      radioKey: radioKey ?? this.radioKey,
      publicKey: publicKey ?? this.publicKey,
      name: name ?? this.name,
      type: type ?? this.type,
      flags: flags ?? this.flags,
      outPathLength: outPathLength ?? this.outPathLength,
      outPath: outPath ?? this.outPath,
      lastAdvert: lastAdvert ?? this.lastAdvert,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastModified: lastModified ?? this.lastModified,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (radioKey.present) {
      map['radio_key'] = Variable<String>(radioKey.value);
    }
    if (publicKey.present) {
      map['public_key'] = Variable<String>(publicKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (flags.present) {
      map['flags'] = Variable<int>(flags.value);
    }
    if (outPathLength.present) {
      map['out_path_length'] = Variable<int>(outPathLength.value);
    }
    if (outPath.present) {
      map['out_path'] = Variable<Uint8List>(outPath.value);
    }
    if (lastAdvert.present) {
      map['last_advert'] = Variable<int>(lastAdvert.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<int>(lastModified.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactsCompanion(')
          ..write('radioKey: $radioKey, ')
          ..write('publicKey: $publicKey, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('flags: $flags, ')
          ..write('outPathLength: $outPathLength, ')
          ..write('outPath: $outPath, ')
          ..write('lastAdvert: $lastAdvert, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('lastModified: $lastModified, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChannelsTable extends Channels with TableInfo<$ChannelsTable, Channel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _radioKeyMeta = const VerificationMeta(
    'radioKey',
  );
  @override
  late final GeneratedColumn<String> radioKey = GeneratedColumn<String>(
    'radio_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES radios (public_key)',
    ),
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<int> slot = GeneratedColumn<int>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _secretMeta = const VerificationMeta('secret');
  @override
  late final GeneratedColumn<Uint8List> secret = GeneratedColumn<Uint8List>(
    'secret',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [radioKey, slot, name, secret];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<Channel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('radio_key')) {
      context.handle(
        _radioKeyMeta,
        radioKey.isAcceptableOrUnknown(data['radio_key']!, _radioKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_radioKeyMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('secret')) {
      context.handle(
        _secretMeta,
        secret.isAcceptableOrUnknown(data['secret']!, _secretMeta),
      );
    } else if (isInserting) {
      context.missing(_secretMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {radioKey, slot};
  @override
  Channel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Channel(
      radioKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}radio_key'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      secret: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}secret'],
      )!,
    );
  }

  @override
  $ChannelsTable createAlias(String alias) {
    return $ChannelsTable(attachedDatabase, alias);
  }
}

class Channel extends DataClass implements Insertable<Channel> {
  final String radioKey;
  final int slot;
  final String name;
  final Uint8List secret;
  const Channel({
    required this.radioKey,
    required this.slot,
    required this.name,
    required this.secret,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['radio_key'] = Variable<String>(radioKey);
    map['slot'] = Variable<int>(slot);
    map['name'] = Variable<String>(name);
    map['secret'] = Variable<Uint8List>(secret);
    return map;
  }

  ChannelsCompanion toCompanion(bool nullToAbsent) {
    return ChannelsCompanion(
      radioKey: Value(radioKey),
      slot: Value(slot),
      name: Value(name),
      secret: Value(secret),
    );
  }

  factory Channel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Channel(
      radioKey: serializer.fromJson<String>(json['radioKey']),
      slot: serializer.fromJson<int>(json['slot']),
      name: serializer.fromJson<String>(json['name']),
      secret: serializer.fromJson<Uint8List>(json['secret']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'radioKey': serializer.toJson<String>(radioKey),
      'slot': serializer.toJson<int>(slot),
      'name': serializer.toJson<String>(name),
      'secret': serializer.toJson<Uint8List>(secret),
    };
  }

  Channel copyWith({
    String? radioKey,
    int? slot,
    String? name,
    Uint8List? secret,
  }) => Channel(
    radioKey: radioKey ?? this.radioKey,
    slot: slot ?? this.slot,
    name: name ?? this.name,
    secret: secret ?? this.secret,
  );
  Channel copyWithCompanion(ChannelsCompanion data) {
    return Channel(
      radioKey: data.radioKey.present ? data.radioKey.value : this.radioKey,
      slot: data.slot.present ? data.slot.value : this.slot,
      name: data.name.present ? data.name.value : this.name,
      secret: data.secret.present ? data.secret.value : this.secret,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Channel(')
          ..write('radioKey: $radioKey, ')
          ..write('slot: $slot, ')
          ..write('name: $name, ')
          ..write('secret: $secret')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(radioKey, slot, name, $driftBlobEquality.hash(secret));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Channel &&
          other.radioKey == this.radioKey &&
          other.slot == this.slot &&
          other.name == this.name &&
          $driftBlobEquality.equals(other.secret, this.secret));
}

class ChannelsCompanion extends UpdateCompanion<Channel> {
  final Value<String> radioKey;
  final Value<int> slot;
  final Value<String> name;
  final Value<Uint8List> secret;
  final Value<int> rowid;
  const ChannelsCompanion({
    this.radioKey = const Value.absent(),
    this.slot = const Value.absent(),
    this.name = const Value.absent(),
    this.secret = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChannelsCompanion.insert({
    required String radioKey,
    required int slot,
    required String name,
    required Uint8List secret,
    this.rowid = const Value.absent(),
  }) : radioKey = Value(radioKey),
       slot = Value(slot),
       name = Value(name),
       secret = Value(secret);
  static Insertable<Channel> custom({
    Expression<String>? radioKey,
    Expression<int>? slot,
    Expression<String>? name,
    Expression<Uint8List>? secret,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (radioKey != null) 'radio_key': radioKey,
      if (slot != null) 'slot': slot,
      if (name != null) 'name': name,
      if (secret != null) 'secret': secret,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChannelsCompanion copyWith({
    Value<String>? radioKey,
    Value<int>? slot,
    Value<String>? name,
    Value<Uint8List>? secret,
    Value<int>? rowid,
  }) {
    return ChannelsCompanion(
      radioKey: radioKey ?? this.radioKey,
      slot: slot ?? this.slot,
      name: name ?? this.name,
      secret: secret ?? this.secret,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (radioKey.present) {
      map['radio_key'] = Variable<String>(radioKey.value);
    }
    if (slot.present) {
      map['slot'] = Variable<int>(slot.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (secret.present) {
      map['secret'] = Variable<Uint8List>(secret.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChannelsCompanion(')
          ..write('radioKey: $radioKey, ')
          ..write('slot: $slot, ')
          ..write('name: $name, ')
          ..write('secret: $secret, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _radioKeyMeta = const VerificationMeta(
    'radioKey',
  );
  @override
  late final GeneratedColumn<String> radioKey = GeneratedColumn<String>(
    'radio_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES radios (public_key)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<MessageKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<MessageKind>($MessagesTable.$converterkind);
  static const VerificationMeta _threadMeta = const VerificationMeta('thread');
  @override
  late final GeneratedColumn<String> thread = GeneratedColumn<String>(
    'thread',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outgoingMeta = const VerificationMeta(
    'outgoing',
  );
  @override
  late final GeneratedColumn<bool> outgoing = GeneratedColumn<bool>(
    'outgoing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("outgoing" IN (0, 1))',
    ),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderNameMeta = const VerificationMeta(
    'senderName',
  );
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
    'sender_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<int> sentAt = GeneratedColumn<int>(
    'sent_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storedAtMeta = const VerificationMeta(
    'storedAt',
  );
  @override
  late final GeneratedColumn<int> storedAt = GeneratedColumn<int>(
    'stored_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MessageStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<MessageStatus>($MessagesTable.$converterstatus);
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ackCodeMeta = const VerificationMeta(
    'ackCode',
  );
  @override
  late final GeneratedColumn<int> ackCode = GeneratedColumn<int>(
    'ack_code',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _floodedMeta = const VerificationMeta(
    'flooded',
  );
  @override
  late final GeneratedColumn<bool> flooded = GeneratedColumn<bool>(
    'flooded',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("flooded" IN (0, 1))',
    ),
  );
  static const VerificationMeta _pathLengthMeta = const VerificationMeta(
    'pathLength',
  );
  @override
  late final GeneratedColumn<int> pathLength = GeneratedColumn<int>(
    'path_length',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snrMeta = const VerificationMeta('snr');
  @override
  late final GeneratedColumn<double> snr = GeneratedColumn<double>(
    'snr',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textTypeMeta = const VerificationMeta(
    'textType',
  );
  @override
  late final GeneratedColumn<int> textType = GeneratedColumn<int>(
    'text_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _authorPrefixMeta = const VerificationMeta(
    'authorPrefix',
  );
  @override
  late final GeneratedColumn<String> authorPrefix = GeneratedColumn<String>(
    'author_prefix',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dedupeKeyMeta = const VerificationMeta(
    'dedupeKey',
  );
  @override
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
    'dedupe_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    radioKey,
    kind,
    thread,
    outgoing,
    body,
    senderName,
    sentAt,
    storedAt,
    status,
    attempts,
    ackCode,
    flooded,
    pathLength,
    snr,
    textType,
    authorPrefix,
    dedupeKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('radio_key')) {
      context.handle(
        _radioKeyMeta,
        radioKey.isAcceptableOrUnknown(data['radio_key']!, _radioKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_radioKeyMeta);
    }
    if (data.containsKey('thread')) {
      context.handle(
        _threadMeta,
        thread.isAcceptableOrUnknown(data['thread']!, _threadMeta),
      );
    } else if (isInserting) {
      context.missing(_threadMeta);
    }
    if (data.containsKey('outgoing')) {
      context.handle(
        _outgoingMeta,
        outgoing.isAcceptableOrUnknown(data['outgoing']!, _outgoingMeta),
      );
    } else if (isInserting) {
      context.missing(_outgoingMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('sender_name')) {
      context.handle(
        _senderNameMeta,
        senderName.isAcceptableOrUnknown(data['sender_name']!, _senderNameMeta),
      );
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    } else if (isInserting) {
      context.missing(_sentAtMeta);
    }
    if (data.containsKey('stored_at')) {
      context.handle(
        _storedAtMeta,
        storedAt.isAcceptableOrUnknown(data['stored_at']!, _storedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_storedAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('ack_code')) {
      context.handle(
        _ackCodeMeta,
        ackCode.isAcceptableOrUnknown(data['ack_code']!, _ackCodeMeta),
      );
    }
    if (data.containsKey('flooded')) {
      context.handle(
        _floodedMeta,
        flooded.isAcceptableOrUnknown(data['flooded']!, _floodedMeta),
      );
    }
    if (data.containsKey('path_length')) {
      context.handle(
        _pathLengthMeta,
        pathLength.isAcceptableOrUnknown(data['path_length']!, _pathLengthMeta),
      );
    }
    if (data.containsKey('snr')) {
      context.handle(
        _snrMeta,
        snr.isAcceptableOrUnknown(data['snr']!, _snrMeta),
      );
    }
    if (data.containsKey('text_type')) {
      context.handle(
        _textTypeMeta,
        textType.isAcceptableOrUnknown(data['text_type']!, _textTypeMeta),
      );
    }
    if (data.containsKey('author_prefix')) {
      context.handle(
        _authorPrefixMeta,
        authorPrefix.isAcceptableOrUnknown(
          data['author_prefix']!,
          _authorPrefixMeta,
        ),
      );
    }
    if (data.containsKey('dedupe_key')) {
      context.handle(
        _dedupeKeyMeta,
        dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      radioKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}radio_key'],
      )!,
      kind: $MessagesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      thread: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread'],
      )!,
      outgoing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}outgoing'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      senderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_name'],
      ),
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sent_at'],
      )!,
      storedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stored_at'],
      )!,
      status: $MessagesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      ackCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ack_code'],
      ),
      flooded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}flooded'],
      ),
      pathLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}path_length'],
      ),
      snr: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}snr'],
      ),
      textType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}text_type'],
      )!,
      authorPrefix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_prefix'],
      ),
      dedupeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupe_key'],
      ),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MessageKind, int, int> $converterkind =
      const EnumIndexConverter<MessageKind>(MessageKind.values);
  static JsonTypeConverter2<MessageStatus, int, int> $converterstatus =
      const EnumIndexConverter<MessageStatus>(MessageStatus.values);
}

class Message extends DataClass implements Insertable<Message> {
  final int id;
  final String radioKey;
  final MessageKind kind;

  /// The conversation, built by `Threads`: `d:` plus the contact key (or key
  /// prefix) in hex, or `c:` plus the channel slot.
  final String thread;
  final bool outgoing;
  final String body;

  /// Channel messages: the name the sender put before the text.
  final String? senderName;

  /// Sender's clock, Unix seconds.
  final int sentAt;

  /// This phone's clock when stored, Unix milliseconds.
  final int storedAt;
  final MessageStatus status;

  /// Outgoing direct messages: how many times it has been sent so far.
  final int attempts;

  /// Outgoing direct messages: the code the delivery ack will carry.
  final int? ackCode;
  final bool? flooded;
  final int? pathLength;
  final double? snr;

  /// `TextType.value`: plain chat, or command text exchanged with a
  /// repeater or room server's console.
  final int textType;

  /// Room posts: the first 4 bytes of the writer's key, in hex.
  final String? authorPrefix;

  /// Incoming only: identifies a message so a repeat delivery is dropped.
  final String? dedupeKey;
  const Message({
    required this.id,
    required this.radioKey,
    required this.kind,
    required this.thread,
    required this.outgoing,
    required this.body,
    this.senderName,
    required this.sentAt,
    required this.storedAt,
    required this.status,
    required this.attempts,
    this.ackCode,
    this.flooded,
    this.pathLength,
    this.snr,
    required this.textType,
    this.authorPrefix,
    this.dedupeKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['radio_key'] = Variable<String>(radioKey);
    {
      map['kind'] = Variable<int>($MessagesTable.$converterkind.toSql(kind));
    }
    map['thread'] = Variable<String>(thread);
    map['outgoing'] = Variable<bool>(outgoing);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || senderName != null) {
      map['sender_name'] = Variable<String>(senderName);
    }
    map['sent_at'] = Variable<int>(sentAt);
    map['stored_at'] = Variable<int>(storedAt);
    {
      map['status'] = Variable<int>(
        $MessagesTable.$converterstatus.toSql(status),
      );
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || ackCode != null) {
      map['ack_code'] = Variable<int>(ackCode);
    }
    if (!nullToAbsent || flooded != null) {
      map['flooded'] = Variable<bool>(flooded);
    }
    if (!nullToAbsent || pathLength != null) {
      map['path_length'] = Variable<int>(pathLength);
    }
    if (!nullToAbsent || snr != null) {
      map['snr'] = Variable<double>(snr);
    }
    map['text_type'] = Variable<int>(textType);
    if (!nullToAbsent || authorPrefix != null) {
      map['author_prefix'] = Variable<String>(authorPrefix);
    }
    if (!nullToAbsent || dedupeKey != null) {
      map['dedupe_key'] = Variable<String>(dedupeKey);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      radioKey: Value(radioKey),
      kind: Value(kind),
      thread: Value(thread),
      outgoing: Value(outgoing),
      body: Value(body),
      senderName: senderName == null && nullToAbsent
          ? const Value.absent()
          : Value(senderName),
      sentAt: Value(sentAt),
      storedAt: Value(storedAt),
      status: Value(status),
      attempts: Value(attempts),
      ackCode: ackCode == null && nullToAbsent
          ? const Value.absent()
          : Value(ackCode),
      flooded: flooded == null && nullToAbsent
          ? const Value.absent()
          : Value(flooded),
      pathLength: pathLength == null && nullToAbsent
          ? const Value.absent()
          : Value(pathLength),
      snr: snr == null && nullToAbsent ? const Value.absent() : Value(snr),
      textType: Value(textType),
      authorPrefix: authorPrefix == null && nullToAbsent
          ? const Value.absent()
          : Value(authorPrefix),
      dedupeKey: dedupeKey == null && nullToAbsent
          ? const Value.absent()
          : Value(dedupeKey),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<int>(json['id']),
      radioKey: serializer.fromJson<String>(json['radioKey']),
      kind: $MessagesTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      thread: serializer.fromJson<String>(json['thread']),
      outgoing: serializer.fromJson<bool>(json['outgoing']),
      body: serializer.fromJson<String>(json['body']),
      senderName: serializer.fromJson<String?>(json['senderName']),
      sentAt: serializer.fromJson<int>(json['sentAt']),
      storedAt: serializer.fromJson<int>(json['storedAt']),
      status: $MessagesTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      attempts: serializer.fromJson<int>(json['attempts']),
      ackCode: serializer.fromJson<int?>(json['ackCode']),
      flooded: serializer.fromJson<bool?>(json['flooded']),
      pathLength: serializer.fromJson<int?>(json['pathLength']),
      snr: serializer.fromJson<double?>(json['snr']),
      textType: serializer.fromJson<int>(json['textType']),
      authorPrefix: serializer.fromJson<String?>(json['authorPrefix']),
      dedupeKey: serializer.fromJson<String?>(json['dedupeKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'radioKey': serializer.toJson<String>(radioKey),
      'kind': serializer.toJson<int>(
        $MessagesTable.$converterkind.toJson(kind),
      ),
      'thread': serializer.toJson<String>(thread),
      'outgoing': serializer.toJson<bool>(outgoing),
      'body': serializer.toJson<String>(body),
      'senderName': serializer.toJson<String?>(senderName),
      'sentAt': serializer.toJson<int>(sentAt),
      'storedAt': serializer.toJson<int>(storedAt),
      'status': serializer.toJson<int>(
        $MessagesTable.$converterstatus.toJson(status),
      ),
      'attempts': serializer.toJson<int>(attempts),
      'ackCode': serializer.toJson<int?>(ackCode),
      'flooded': serializer.toJson<bool?>(flooded),
      'pathLength': serializer.toJson<int?>(pathLength),
      'snr': serializer.toJson<double?>(snr),
      'textType': serializer.toJson<int>(textType),
      'authorPrefix': serializer.toJson<String?>(authorPrefix),
      'dedupeKey': serializer.toJson<String?>(dedupeKey),
    };
  }

  Message copyWith({
    int? id,
    String? radioKey,
    MessageKind? kind,
    String? thread,
    bool? outgoing,
    String? body,
    Value<String?> senderName = const Value.absent(),
    int? sentAt,
    int? storedAt,
    MessageStatus? status,
    int? attempts,
    Value<int?> ackCode = const Value.absent(),
    Value<bool?> flooded = const Value.absent(),
    Value<int?> pathLength = const Value.absent(),
    Value<double?> snr = const Value.absent(),
    int? textType,
    Value<String?> authorPrefix = const Value.absent(),
    Value<String?> dedupeKey = const Value.absent(),
  }) => Message(
    id: id ?? this.id,
    radioKey: radioKey ?? this.radioKey,
    kind: kind ?? this.kind,
    thread: thread ?? this.thread,
    outgoing: outgoing ?? this.outgoing,
    body: body ?? this.body,
    senderName: senderName.present ? senderName.value : this.senderName,
    sentAt: sentAt ?? this.sentAt,
    storedAt: storedAt ?? this.storedAt,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    ackCode: ackCode.present ? ackCode.value : this.ackCode,
    flooded: flooded.present ? flooded.value : this.flooded,
    pathLength: pathLength.present ? pathLength.value : this.pathLength,
    snr: snr.present ? snr.value : this.snr,
    textType: textType ?? this.textType,
    authorPrefix: authorPrefix.present ? authorPrefix.value : this.authorPrefix,
    dedupeKey: dedupeKey.present ? dedupeKey.value : this.dedupeKey,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      radioKey: data.radioKey.present ? data.radioKey.value : this.radioKey,
      kind: data.kind.present ? data.kind.value : this.kind,
      thread: data.thread.present ? data.thread.value : this.thread,
      outgoing: data.outgoing.present ? data.outgoing.value : this.outgoing,
      body: data.body.present ? data.body.value : this.body,
      senderName: data.senderName.present
          ? data.senderName.value
          : this.senderName,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      storedAt: data.storedAt.present ? data.storedAt.value : this.storedAt,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      ackCode: data.ackCode.present ? data.ackCode.value : this.ackCode,
      flooded: data.flooded.present ? data.flooded.value : this.flooded,
      pathLength: data.pathLength.present
          ? data.pathLength.value
          : this.pathLength,
      snr: data.snr.present ? data.snr.value : this.snr,
      textType: data.textType.present ? data.textType.value : this.textType,
      authorPrefix: data.authorPrefix.present
          ? data.authorPrefix.value
          : this.authorPrefix,
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('radioKey: $radioKey, ')
          ..write('kind: $kind, ')
          ..write('thread: $thread, ')
          ..write('outgoing: $outgoing, ')
          ..write('body: $body, ')
          ..write('senderName: $senderName, ')
          ..write('sentAt: $sentAt, ')
          ..write('storedAt: $storedAt, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('ackCode: $ackCode, ')
          ..write('flooded: $flooded, ')
          ..write('pathLength: $pathLength, ')
          ..write('snr: $snr, ')
          ..write('textType: $textType, ')
          ..write('authorPrefix: $authorPrefix, ')
          ..write('dedupeKey: $dedupeKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    radioKey,
    kind,
    thread,
    outgoing,
    body,
    senderName,
    sentAt,
    storedAt,
    status,
    attempts,
    ackCode,
    flooded,
    pathLength,
    snr,
    textType,
    authorPrefix,
    dedupeKey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.radioKey == this.radioKey &&
          other.kind == this.kind &&
          other.thread == this.thread &&
          other.outgoing == this.outgoing &&
          other.body == this.body &&
          other.senderName == this.senderName &&
          other.sentAt == this.sentAt &&
          other.storedAt == this.storedAt &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.ackCode == this.ackCode &&
          other.flooded == this.flooded &&
          other.pathLength == this.pathLength &&
          other.snr == this.snr &&
          other.textType == this.textType &&
          other.authorPrefix == this.authorPrefix &&
          other.dedupeKey == this.dedupeKey);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<int> id;
  final Value<String> radioKey;
  final Value<MessageKind> kind;
  final Value<String> thread;
  final Value<bool> outgoing;
  final Value<String> body;
  final Value<String?> senderName;
  final Value<int> sentAt;
  final Value<int> storedAt;
  final Value<MessageStatus> status;
  final Value<int> attempts;
  final Value<int?> ackCode;
  final Value<bool?> flooded;
  final Value<int?> pathLength;
  final Value<double?> snr;
  final Value<int> textType;
  final Value<String?> authorPrefix;
  final Value<String?> dedupeKey;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.radioKey = const Value.absent(),
    this.kind = const Value.absent(),
    this.thread = const Value.absent(),
    this.outgoing = const Value.absent(),
    this.body = const Value.absent(),
    this.senderName = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.storedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.ackCode = const Value.absent(),
    this.flooded = const Value.absent(),
    this.pathLength = const Value.absent(),
    this.snr = const Value.absent(),
    this.textType = const Value.absent(),
    this.authorPrefix = const Value.absent(),
    this.dedupeKey = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required String radioKey,
    required MessageKind kind,
    required String thread,
    required bool outgoing,
    required String body,
    this.senderName = const Value.absent(),
    required int sentAt,
    required int storedAt,
    required MessageStatus status,
    this.attempts = const Value.absent(),
    this.ackCode = const Value.absent(),
    this.flooded = const Value.absent(),
    this.pathLength = const Value.absent(),
    this.snr = const Value.absent(),
    this.textType = const Value.absent(),
    this.authorPrefix = const Value.absent(),
    this.dedupeKey = const Value.absent(),
  }) : radioKey = Value(radioKey),
       kind = Value(kind),
       thread = Value(thread),
       outgoing = Value(outgoing),
       body = Value(body),
       sentAt = Value(sentAt),
       storedAt = Value(storedAt),
       status = Value(status);
  static Insertable<Message> custom({
    Expression<int>? id,
    Expression<String>? radioKey,
    Expression<int>? kind,
    Expression<String>? thread,
    Expression<bool>? outgoing,
    Expression<String>? body,
    Expression<String>? senderName,
    Expression<int>? sentAt,
    Expression<int>? storedAt,
    Expression<int>? status,
    Expression<int>? attempts,
    Expression<int>? ackCode,
    Expression<bool>? flooded,
    Expression<int>? pathLength,
    Expression<double>? snr,
    Expression<int>? textType,
    Expression<String>? authorPrefix,
    Expression<String>? dedupeKey,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (radioKey != null) 'radio_key': radioKey,
      if (kind != null) 'kind': kind,
      if (thread != null) 'thread': thread,
      if (outgoing != null) 'outgoing': outgoing,
      if (body != null) 'body': body,
      if (senderName != null) 'sender_name': senderName,
      if (sentAt != null) 'sent_at': sentAt,
      if (storedAt != null) 'stored_at': storedAt,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (ackCode != null) 'ack_code': ackCode,
      if (flooded != null) 'flooded': flooded,
      if (pathLength != null) 'path_length': pathLength,
      if (snr != null) 'snr': snr,
      if (textType != null) 'text_type': textType,
      if (authorPrefix != null) 'author_prefix': authorPrefix,
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
    });
  }

  MessagesCompanion copyWith({
    Value<int>? id,
    Value<String>? radioKey,
    Value<MessageKind>? kind,
    Value<String>? thread,
    Value<bool>? outgoing,
    Value<String>? body,
    Value<String?>? senderName,
    Value<int>? sentAt,
    Value<int>? storedAt,
    Value<MessageStatus>? status,
    Value<int>? attempts,
    Value<int?>? ackCode,
    Value<bool?>? flooded,
    Value<int?>? pathLength,
    Value<double?>? snr,
    Value<int>? textType,
    Value<String?>? authorPrefix,
    Value<String?>? dedupeKey,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      radioKey: radioKey ?? this.radioKey,
      kind: kind ?? this.kind,
      thread: thread ?? this.thread,
      outgoing: outgoing ?? this.outgoing,
      body: body ?? this.body,
      senderName: senderName ?? this.senderName,
      sentAt: sentAt ?? this.sentAt,
      storedAt: storedAt ?? this.storedAt,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      ackCode: ackCode ?? this.ackCode,
      flooded: flooded ?? this.flooded,
      pathLength: pathLength ?? this.pathLength,
      snr: snr ?? this.snr,
      textType: textType ?? this.textType,
      authorPrefix: authorPrefix ?? this.authorPrefix,
      dedupeKey: dedupeKey ?? this.dedupeKey,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (radioKey.present) {
      map['radio_key'] = Variable<String>(radioKey.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $MessagesTable.$converterkind.toSql(kind.value),
      );
    }
    if (thread.present) {
      map['thread'] = Variable<String>(thread.value);
    }
    if (outgoing.present) {
      map['outgoing'] = Variable<bool>(outgoing.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (senderName.present) {
      map['sender_name'] = Variable<String>(senderName.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<int>(sentAt.value);
    }
    if (storedAt.present) {
      map['stored_at'] = Variable<int>(storedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $MessagesTable.$converterstatus.toSql(status.value),
      );
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (ackCode.present) {
      map['ack_code'] = Variable<int>(ackCode.value);
    }
    if (flooded.present) {
      map['flooded'] = Variable<bool>(flooded.value);
    }
    if (pathLength.present) {
      map['path_length'] = Variable<int>(pathLength.value);
    }
    if (snr.present) {
      map['snr'] = Variable<double>(snr.value);
    }
    if (textType.present) {
      map['text_type'] = Variable<int>(textType.value);
    }
    if (authorPrefix.present) {
      map['author_prefix'] = Variable<String>(authorPrefix.value);
    }
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('radioKey: $radioKey, ')
          ..write('kind: $kind, ')
          ..write('thread: $thread, ')
          ..write('outgoing: $outgoing, ')
          ..write('body: $body, ')
          ..write('senderName: $senderName, ')
          ..write('sentAt: $sentAt, ')
          ..write('storedAt: $storedAt, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('ackCode: $ackCode, ')
          ..write('flooded: $flooded, ')
          ..write('pathLength: $pathLength, ')
          ..write('snr: $snr, ')
          ..write('textType: $textType, ')
          ..write('authorPrefix: $authorPrefix, ')
          ..write('dedupeKey: $dedupeKey')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ThreadStatesTable extends ThreadStates
    with TableInfo<$ThreadStatesTable, ThreadState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ThreadStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _radioKeyMeta = const VerificationMeta(
    'radioKey',
  );
  @override
  late final GeneratedColumn<String> radioKey = GeneratedColumn<String>(
    'radio_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES radios (public_key)',
    ),
  );
  static const VerificationMeta _threadMeta = const VerificationMeta('thread');
  @override
  late final GeneratedColumn<String> thread = GeneratedColumn<String>(
    'thread',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastReadIdMeta = const VerificationMeta(
    'lastReadId',
  );
  @override
  late final GeneratedColumn<int> lastReadId = GeneratedColumn<int>(
    'last_read_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mutedMeta = const VerificationMeta('muted');
  @override
  late final GeneratedColumn<bool> muted = GeneratedColumn<bool>(
    'muted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("muted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [radioKey, thread, lastReadId, muted];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'thread_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<ThreadState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('radio_key')) {
      context.handle(
        _radioKeyMeta,
        radioKey.isAcceptableOrUnknown(data['radio_key']!, _radioKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_radioKeyMeta);
    }
    if (data.containsKey('thread')) {
      context.handle(
        _threadMeta,
        thread.isAcceptableOrUnknown(data['thread']!, _threadMeta),
      );
    } else if (isInserting) {
      context.missing(_threadMeta);
    }
    if (data.containsKey('last_read_id')) {
      context.handle(
        _lastReadIdMeta,
        lastReadId.isAcceptableOrUnknown(
          data['last_read_id']!,
          _lastReadIdMeta,
        ),
      );
    }
    if (data.containsKey('muted')) {
      context.handle(
        _mutedMeta,
        muted.isAcceptableOrUnknown(data['muted']!, _mutedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {radioKey, thread};
  @override
  ThreadState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ThreadState(
      radioKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}radio_key'],
      )!,
      thread: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread'],
      )!,
      lastReadId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_read_id'],
      )!,
      muted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}muted'],
      )!,
    );
  }

  @override
  $ThreadStatesTable createAlias(String alias) {
    return $ThreadStatesTable(attachedDatabase, alias);
  }
}

class ThreadState extends DataClass implements Insertable<ThreadState> {
  final String radioKey;
  final String thread;

  /// Newest message id seen; incoming messages above it are unread.
  final int lastReadId;
  final bool muted;
  const ThreadState({
    required this.radioKey,
    required this.thread,
    required this.lastReadId,
    required this.muted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['radio_key'] = Variable<String>(radioKey);
    map['thread'] = Variable<String>(thread);
    map['last_read_id'] = Variable<int>(lastReadId);
    map['muted'] = Variable<bool>(muted);
    return map;
  }

  ThreadStatesCompanion toCompanion(bool nullToAbsent) {
    return ThreadStatesCompanion(
      radioKey: Value(radioKey),
      thread: Value(thread),
      lastReadId: Value(lastReadId),
      muted: Value(muted),
    );
  }

  factory ThreadState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ThreadState(
      radioKey: serializer.fromJson<String>(json['radioKey']),
      thread: serializer.fromJson<String>(json['thread']),
      lastReadId: serializer.fromJson<int>(json['lastReadId']),
      muted: serializer.fromJson<bool>(json['muted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'radioKey': serializer.toJson<String>(radioKey),
      'thread': serializer.toJson<String>(thread),
      'lastReadId': serializer.toJson<int>(lastReadId),
      'muted': serializer.toJson<bool>(muted),
    };
  }

  ThreadState copyWith({
    String? radioKey,
    String? thread,
    int? lastReadId,
    bool? muted,
  }) => ThreadState(
    radioKey: radioKey ?? this.radioKey,
    thread: thread ?? this.thread,
    lastReadId: lastReadId ?? this.lastReadId,
    muted: muted ?? this.muted,
  );
  ThreadState copyWithCompanion(ThreadStatesCompanion data) {
    return ThreadState(
      radioKey: data.radioKey.present ? data.radioKey.value : this.radioKey,
      thread: data.thread.present ? data.thread.value : this.thread,
      lastReadId: data.lastReadId.present
          ? data.lastReadId.value
          : this.lastReadId,
      muted: data.muted.present ? data.muted.value : this.muted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ThreadState(')
          ..write('radioKey: $radioKey, ')
          ..write('thread: $thread, ')
          ..write('lastReadId: $lastReadId, ')
          ..write('muted: $muted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(radioKey, thread, lastReadId, muted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ThreadState &&
          other.radioKey == this.radioKey &&
          other.thread == this.thread &&
          other.lastReadId == this.lastReadId &&
          other.muted == this.muted);
}

class ThreadStatesCompanion extends UpdateCompanion<ThreadState> {
  final Value<String> radioKey;
  final Value<String> thread;
  final Value<int> lastReadId;
  final Value<bool> muted;
  final Value<int> rowid;
  const ThreadStatesCompanion({
    this.radioKey = const Value.absent(),
    this.thread = const Value.absent(),
    this.lastReadId = const Value.absent(),
    this.muted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ThreadStatesCompanion.insert({
    required String radioKey,
    required String thread,
    this.lastReadId = const Value.absent(),
    this.muted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : radioKey = Value(radioKey),
       thread = Value(thread);
  static Insertable<ThreadState> custom({
    Expression<String>? radioKey,
    Expression<String>? thread,
    Expression<int>? lastReadId,
    Expression<bool>? muted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (radioKey != null) 'radio_key': radioKey,
      if (thread != null) 'thread': thread,
      if (lastReadId != null) 'last_read_id': lastReadId,
      if (muted != null) 'muted': muted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ThreadStatesCompanion copyWith({
    Value<String>? radioKey,
    Value<String>? thread,
    Value<int>? lastReadId,
    Value<bool>? muted,
    Value<int>? rowid,
  }) {
    return ThreadStatesCompanion(
      radioKey: radioKey ?? this.radioKey,
      thread: thread ?? this.thread,
      lastReadId: lastReadId ?? this.lastReadId,
      muted: muted ?? this.muted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (radioKey.present) {
      map['radio_key'] = Variable<String>(radioKey.value);
    }
    if (thread.present) {
      map['thread'] = Variable<String>(thread.value);
    }
    if (lastReadId.present) {
      map['last_read_id'] = Variable<int>(lastReadId.value);
    }
    if (muted.present) {
      map['muted'] = Variable<bool>(muted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ThreadStatesCompanion(')
          ..write('radioKey: $radioKey, ')
          ..write('thread: $thread, ')
          ..write('lastReadId: $lastReadId, ')
          ..write('muted: $muted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiscoveredTable extends Discovered
    with TableInfo<$DiscoveredTable, DiscoveredData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiscoveredTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _radioKeyMeta = const VerificationMeta(
    'radioKey',
  );
  @override
  late final GeneratedColumn<String> radioKey = GeneratedColumn<String>(
    'radio_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES radios (public_key)',
    ),
  );
  static const VerificationMeta _publicKeyMeta = const VerificationMeta(
    'publicKey',
  );
  @override
  late final GeneratedColumn<String> publicKey = GeneratedColumn<String>(
    'public_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAdvertMeta = const VerificationMeta(
    'lastAdvert',
  );
  @override
  late final GeneratedColumn<int> lastAdvert = GeneratedColumn<int>(
    'last_advert',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heardAtMeta = const VerificationMeta(
    'heardAt',
  );
  @override
  late final GeneratedColumn<int> heardAt = GeneratedColumn<int>(
    'heard_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    radioKey,
    publicKey,
    name,
    type,
    latitude,
    longitude,
    lastAdvert,
    heardAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'discovered';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiscoveredData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('radio_key')) {
      context.handle(
        _radioKeyMeta,
        radioKey.isAcceptableOrUnknown(data['radio_key']!, _radioKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_radioKeyMeta);
    }
    if (data.containsKey('public_key')) {
      context.handle(
        _publicKeyMeta,
        publicKey.isAcceptableOrUnknown(data['public_key']!, _publicKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_publicKeyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('last_advert')) {
      context.handle(
        _lastAdvertMeta,
        lastAdvert.isAcceptableOrUnknown(data['last_advert']!, _lastAdvertMeta),
      );
    } else if (isInserting) {
      context.missing(_lastAdvertMeta);
    }
    if (data.containsKey('heard_at')) {
      context.handle(
        _heardAtMeta,
        heardAt.isAcceptableOrUnknown(data['heard_at']!, _heardAtMeta),
      );
    } else if (isInserting) {
      context.missing(_heardAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {radioKey, publicKey};
  @override
  DiscoveredData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiscoveredData(
      radioKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}radio_key'],
      )!,
      publicKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}public_key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      lastAdvert: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_advert'],
      )!,
      heardAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}heard_at'],
      )!,
    );
  }

  @override
  $DiscoveredTable createAlias(String alias) {
    return $DiscoveredTable(attachedDatabase, alias);
  }
}

class DiscoveredData extends DataClass implements Insertable<DiscoveredData> {
  final String radioKey;
  final String publicKey;
  final String name;
  final int type;
  final double? latitude;
  final double? longitude;

  /// When the node last advertised, by its own clock.
  final int lastAdvert;

  /// When this phone heard it, Unix milliseconds.
  final int heardAt;
  const DiscoveredData({
    required this.radioKey,
    required this.publicKey,
    required this.name,
    required this.type,
    this.latitude,
    this.longitude,
    required this.lastAdvert,
    required this.heardAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['radio_key'] = Variable<String>(radioKey);
    map['public_key'] = Variable<String>(publicKey);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<int>(type);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    map['last_advert'] = Variable<int>(lastAdvert);
    map['heard_at'] = Variable<int>(heardAt);
    return map;
  }

  DiscoveredCompanion toCompanion(bool nullToAbsent) {
    return DiscoveredCompanion(
      radioKey: Value(radioKey),
      publicKey: Value(publicKey),
      name: Value(name),
      type: Value(type),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      lastAdvert: Value(lastAdvert),
      heardAt: Value(heardAt),
    );
  }

  factory DiscoveredData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiscoveredData(
      radioKey: serializer.fromJson<String>(json['radioKey']),
      publicKey: serializer.fromJson<String>(json['publicKey']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<int>(json['type']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      lastAdvert: serializer.fromJson<int>(json['lastAdvert']),
      heardAt: serializer.fromJson<int>(json['heardAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'radioKey': serializer.toJson<String>(radioKey),
      'publicKey': serializer.toJson<String>(publicKey),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<int>(type),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'lastAdvert': serializer.toJson<int>(lastAdvert),
      'heardAt': serializer.toJson<int>(heardAt),
    };
  }

  DiscoveredData copyWith({
    String? radioKey,
    String? publicKey,
    String? name,
    int? type,
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    int? lastAdvert,
    int? heardAt,
  }) => DiscoveredData(
    radioKey: radioKey ?? this.radioKey,
    publicKey: publicKey ?? this.publicKey,
    name: name ?? this.name,
    type: type ?? this.type,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    lastAdvert: lastAdvert ?? this.lastAdvert,
    heardAt: heardAt ?? this.heardAt,
  );
  DiscoveredData copyWithCompanion(DiscoveredCompanion data) {
    return DiscoveredData(
      radioKey: data.radioKey.present ? data.radioKey.value : this.radioKey,
      publicKey: data.publicKey.present ? data.publicKey.value : this.publicKey,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      lastAdvert: data.lastAdvert.present
          ? data.lastAdvert.value
          : this.lastAdvert,
      heardAt: data.heardAt.present ? data.heardAt.value : this.heardAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveredData(')
          ..write('radioKey: $radioKey, ')
          ..write('publicKey: $publicKey, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('lastAdvert: $lastAdvert, ')
          ..write('heardAt: $heardAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    radioKey,
    publicKey,
    name,
    type,
    latitude,
    longitude,
    lastAdvert,
    heardAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiscoveredData &&
          other.radioKey == this.radioKey &&
          other.publicKey == this.publicKey &&
          other.name == this.name &&
          other.type == this.type &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.lastAdvert == this.lastAdvert &&
          other.heardAt == this.heardAt);
}

class DiscoveredCompanion extends UpdateCompanion<DiscoveredData> {
  final Value<String> radioKey;
  final Value<String> publicKey;
  final Value<String> name;
  final Value<int> type;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<int> lastAdvert;
  final Value<int> heardAt;
  final Value<int> rowid;
  const DiscoveredCompanion({
    this.radioKey = const Value.absent(),
    this.publicKey = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.lastAdvert = const Value.absent(),
    this.heardAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiscoveredCompanion.insert({
    required String radioKey,
    required String publicKey,
    required String name,
    required int type,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    required int lastAdvert,
    required int heardAt,
    this.rowid = const Value.absent(),
  }) : radioKey = Value(radioKey),
       publicKey = Value(publicKey),
       name = Value(name),
       type = Value(type),
       lastAdvert = Value(lastAdvert),
       heardAt = Value(heardAt);
  static Insertable<DiscoveredData> custom({
    Expression<String>? radioKey,
    Expression<String>? publicKey,
    Expression<String>? name,
    Expression<int>? type,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? lastAdvert,
    Expression<int>? heardAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (radioKey != null) 'radio_key': radioKey,
      if (publicKey != null) 'public_key': publicKey,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (lastAdvert != null) 'last_advert': lastAdvert,
      if (heardAt != null) 'heard_at': heardAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiscoveredCompanion copyWith({
    Value<String>? radioKey,
    Value<String>? publicKey,
    Value<String>? name,
    Value<int>? type,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<int>? lastAdvert,
    Value<int>? heardAt,
    Value<int>? rowid,
  }) {
    return DiscoveredCompanion(
      radioKey: radioKey ?? this.radioKey,
      publicKey: publicKey ?? this.publicKey,
      name: name ?? this.name,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastAdvert: lastAdvert ?? this.lastAdvert,
      heardAt: heardAt ?? this.heardAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (radioKey.present) {
      map['radio_key'] = Variable<String>(radioKey.value);
    }
    if (publicKey.present) {
      map['public_key'] = Variable<String>(publicKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (lastAdvert.present) {
      map['last_advert'] = Variable<int>(lastAdvert.value);
    }
    if (heardAt.present) {
      map['heard_at'] = Variable<int>(heardAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveredCompanion(')
          ..write('radioKey: $radioKey, ')
          ..write('publicKey: $publicKey, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('lastAdvert: $lastAdvert, ')
          ..write('heardAt: $heardAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TelemetrySamplesTable extends TelemetrySamples
    with TableInfo<$TelemetrySamplesTable, TelemetrySample> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TelemetrySamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _radioKeyMeta = const VerificationMeta(
    'radioKey',
  );
  @override
  late final GeneratedColumn<String> radioKey = GeneratedColumn<String>(
    'radio_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES radios (public_key)',
    ),
  );
  static const VerificationMeta _nodeKeyMeta = const VerificationMeta(
    'nodeKey',
  );
  @override
  late final GeneratedColumn<String> nodeKey = GeneratedColumn<String>(
    'node_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<Uint8List> data = GeneratedColumn<Uint8List>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, radioKey, nodeKey, at, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'telemetry_samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<TelemetrySample> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('radio_key')) {
      context.handle(
        _radioKeyMeta,
        radioKey.isAcceptableOrUnknown(data['radio_key']!, _radioKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_radioKeyMeta);
    }
    if (data.containsKey('node_key')) {
      context.handle(
        _nodeKeyMeta,
        nodeKey.isAcceptableOrUnknown(data['node_key']!, _nodeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeKeyMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TelemetrySample map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TelemetrySample(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      radioKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}radio_key'],
      )!,
      nodeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_key'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}data'],
      )!,
    );
  }

  @override
  $TelemetrySamplesTable createAlias(String alias) {
    return $TelemetrySamplesTable(attachedDatabase, alias);
  }
}

class TelemetrySample extends DataClass implements Insertable<TelemetrySample> {
  final int id;
  final String radioKey;

  /// The node's public key, hex.
  final String nodeKey;

  /// When it arrived, Unix milliseconds.
  final int at;
  final Uint8List data;
  const TelemetrySample({
    required this.id,
    required this.radioKey,
    required this.nodeKey,
    required this.at,
    required this.data,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['radio_key'] = Variable<String>(radioKey);
    map['node_key'] = Variable<String>(nodeKey);
    map['at'] = Variable<int>(at);
    map['data'] = Variable<Uint8List>(data);
    return map;
  }

  TelemetrySamplesCompanion toCompanion(bool nullToAbsent) {
    return TelemetrySamplesCompanion(
      id: Value(id),
      radioKey: Value(radioKey),
      nodeKey: Value(nodeKey),
      at: Value(at),
      data: Value(data),
    );
  }

  factory TelemetrySample.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TelemetrySample(
      id: serializer.fromJson<int>(json['id']),
      radioKey: serializer.fromJson<String>(json['radioKey']),
      nodeKey: serializer.fromJson<String>(json['nodeKey']),
      at: serializer.fromJson<int>(json['at']),
      data: serializer.fromJson<Uint8List>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'radioKey': serializer.toJson<String>(radioKey),
      'nodeKey': serializer.toJson<String>(nodeKey),
      'at': serializer.toJson<int>(at),
      'data': serializer.toJson<Uint8List>(data),
    };
  }

  TelemetrySample copyWith({
    int? id,
    String? radioKey,
    String? nodeKey,
    int? at,
    Uint8List? data,
  }) => TelemetrySample(
    id: id ?? this.id,
    radioKey: radioKey ?? this.radioKey,
    nodeKey: nodeKey ?? this.nodeKey,
    at: at ?? this.at,
    data: data ?? this.data,
  );
  TelemetrySample copyWithCompanion(TelemetrySamplesCompanion data) {
    return TelemetrySample(
      id: data.id.present ? data.id.value : this.id,
      radioKey: data.radioKey.present ? data.radioKey.value : this.radioKey,
      nodeKey: data.nodeKey.present ? data.nodeKey.value : this.nodeKey,
      at: data.at.present ? data.at.value : this.at,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TelemetrySample(')
          ..write('id: $id, ')
          ..write('radioKey: $radioKey, ')
          ..write('nodeKey: $nodeKey, ')
          ..write('at: $at, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, radioKey, nodeKey, at, $driftBlobEquality.hash(data));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TelemetrySample &&
          other.id == this.id &&
          other.radioKey == this.radioKey &&
          other.nodeKey == this.nodeKey &&
          other.at == this.at &&
          $driftBlobEquality.equals(other.data, this.data));
}

class TelemetrySamplesCompanion extends UpdateCompanion<TelemetrySample> {
  final Value<int> id;
  final Value<String> radioKey;
  final Value<String> nodeKey;
  final Value<int> at;
  final Value<Uint8List> data;
  const TelemetrySamplesCompanion({
    this.id = const Value.absent(),
    this.radioKey = const Value.absent(),
    this.nodeKey = const Value.absent(),
    this.at = const Value.absent(),
    this.data = const Value.absent(),
  });
  TelemetrySamplesCompanion.insert({
    this.id = const Value.absent(),
    required String radioKey,
    required String nodeKey,
    required int at,
    required Uint8List data,
  }) : radioKey = Value(radioKey),
       nodeKey = Value(nodeKey),
       at = Value(at),
       data = Value(data);
  static Insertable<TelemetrySample> custom({
    Expression<int>? id,
    Expression<String>? radioKey,
    Expression<String>? nodeKey,
    Expression<int>? at,
    Expression<Uint8List>? data,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (radioKey != null) 'radio_key': radioKey,
      if (nodeKey != null) 'node_key': nodeKey,
      if (at != null) 'at': at,
      if (data != null) 'data': data,
    });
  }

  TelemetrySamplesCompanion copyWith({
    Value<int>? id,
    Value<String>? radioKey,
    Value<String>? nodeKey,
    Value<int>? at,
    Value<Uint8List>? data,
  }) {
    return TelemetrySamplesCompanion(
      id: id ?? this.id,
      radioKey: radioKey ?? this.radioKey,
      nodeKey: nodeKey ?? this.nodeKey,
      at: at ?? this.at,
      data: data ?? this.data,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (radioKey.present) {
      map['radio_key'] = Variable<String>(radioKey.value);
    }
    if (nodeKey.present) {
      map['node_key'] = Variable<String>(nodeKey.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (data.present) {
      map['data'] = Variable<Uint8List>(data.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TelemetrySamplesCompanion(')
          ..write('id: $id, ')
          ..write('radioKey: $radioKey, ')
          ..write('nodeKey: $nodeKey, ')
          ..write('at: $at, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }
}

class $RadioStatsSamplesTable extends RadioStatsSamples
    with TableInfo<$RadioStatsSamplesTable, RadioStatsSample> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RadioStatsSamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _radioKeyMeta = const VerificationMeta(
    'radioKey',
  );
  @override
  late final GeneratedColumn<String> radioKey = GeneratedColumn<String>(
    'radio_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES radios (public_key)',
    ),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noiseFloorMeta = const VerificationMeta(
    'noiseFloor',
  );
  @override
  late final GeneratedColumn<int> noiseFloor = GeneratedColumn<int>(
    'noise_floor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastRssiMeta = const VerificationMeta(
    'lastRssi',
  );
  @override
  late final GeneratedColumn<int> lastRssi = GeneratedColumn<int>(
    'last_rssi',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSnrMeta = const VerificationMeta(
    'lastSnr',
  );
  @override
  late final GeneratedColumn<double> lastSnr = GeneratedColumn<double>(
    'last_snr',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _txAirSecondsMeta = const VerificationMeta(
    'txAirSeconds',
  );
  @override
  late final GeneratedColumn<int> txAirSeconds = GeneratedColumn<int>(
    'tx_air_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rxAirSecondsMeta = const VerificationMeta(
    'rxAirSeconds',
  );
  @override
  late final GeneratedColumn<int> rxAirSeconds = GeneratedColumn<int>(
    'rx_air_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    radioKey,
    at,
    noiseFloor,
    lastRssi,
    lastSnr,
    txAirSeconds,
    rxAirSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'radio_stats_samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<RadioStatsSample> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('radio_key')) {
      context.handle(
        _radioKeyMeta,
        radioKey.isAcceptableOrUnknown(data['radio_key']!, _radioKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_radioKeyMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('noise_floor')) {
      context.handle(
        _noiseFloorMeta,
        noiseFloor.isAcceptableOrUnknown(data['noise_floor']!, _noiseFloorMeta),
      );
    } else if (isInserting) {
      context.missing(_noiseFloorMeta);
    }
    if (data.containsKey('last_rssi')) {
      context.handle(
        _lastRssiMeta,
        lastRssi.isAcceptableOrUnknown(data['last_rssi']!, _lastRssiMeta),
      );
    } else if (isInserting) {
      context.missing(_lastRssiMeta);
    }
    if (data.containsKey('last_snr')) {
      context.handle(
        _lastSnrMeta,
        lastSnr.isAcceptableOrUnknown(data['last_snr']!, _lastSnrMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSnrMeta);
    }
    if (data.containsKey('tx_air_seconds')) {
      context.handle(
        _txAirSecondsMeta,
        txAirSeconds.isAcceptableOrUnknown(
          data['tx_air_seconds']!,
          _txAirSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_txAirSecondsMeta);
    }
    if (data.containsKey('rx_air_seconds')) {
      context.handle(
        _rxAirSecondsMeta,
        rxAirSeconds.isAcceptableOrUnknown(
          data['rx_air_seconds']!,
          _rxAirSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rxAirSecondsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RadioStatsSample map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RadioStatsSample(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      radioKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}radio_key'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      noiseFloor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}noise_floor'],
      )!,
      lastRssi: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_rssi'],
      )!,
      lastSnr: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_snr'],
      )!,
      txAirSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tx_air_seconds'],
      )!,
      rxAirSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rx_air_seconds'],
      )!,
    );
  }

  @override
  $RadioStatsSamplesTable createAlias(String alias) {
    return $RadioStatsSamplesTable(attachedDatabase, alias);
  }
}

class RadioStatsSample extends DataClass
    implements Insertable<RadioStatsSample> {
  final int id;
  final String radioKey;

  /// When it was read, Unix milliseconds.
  final int at;

  /// dBm.
  final int noiseFloor;
  final int lastRssi;
  final double lastSnr;
  final int txAirSeconds;
  final int rxAirSeconds;
  const RadioStatsSample({
    required this.id,
    required this.radioKey,
    required this.at,
    required this.noiseFloor,
    required this.lastRssi,
    required this.lastSnr,
    required this.txAirSeconds,
    required this.rxAirSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['radio_key'] = Variable<String>(radioKey);
    map['at'] = Variable<int>(at);
    map['noise_floor'] = Variable<int>(noiseFloor);
    map['last_rssi'] = Variable<int>(lastRssi);
    map['last_snr'] = Variable<double>(lastSnr);
    map['tx_air_seconds'] = Variable<int>(txAirSeconds);
    map['rx_air_seconds'] = Variable<int>(rxAirSeconds);
    return map;
  }

  RadioStatsSamplesCompanion toCompanion(bool nullToAbsent) {
    return RadioStatsSamplesCompanion(
      id: Value(id),
      radioKey: Value(radioKey),
      at: Value(at),
      noiseFloor: Value(noiseFloor),
      lastRssi: Value(lastRssi),
      lastSnr: Value(lastSnr),
      txAirSeconds: Value(txAirSeconds),
      rxAirSeconds: Value(rxAirSeconds),
    );
  }

  factory RadioStatsSample.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RadioStatsSample(
      id: serializer.fromJson<int>(json['id']),
      radioKey: serializer.fromJson<String>(json['radioKey']),
      at: serializer.fromJson<int>(json['at']),
      noiseFloor: serializer.fromJson<int>(json['noiseFloor']),
      lastRssi: serializer.fromJson<int>(json['lastRssi']),
      lastSnr: serializer.fromJson<double>(json['lastSnr']),
      txAirSeconds: serializer.fromJson<int>(json['txAirSeconds']),
      rxAirSeconds: serializer.fromJson<int>(json['rxAirSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'radioKey': serializer.toJson<String>(radioKey),
      'at': serializer.toJson<int>(at),
      'noiseFloor': serializer.toJson<int>(noiseFloor),
      'lastRssi': serializer.toJson<int>(lastRssi),
      'lastSnr': serializer.toJson<double>(lastSnr),
      'txAirSeconds': serializer.toJson<int>(txAirSeconds),
      'rxAirSeconds': serializer.toJson<int>(rxAirSeconds),
    };
  }

  RadioStatsSample copyWith({
    int? id,
    String? radioKey,
    int? at,
    int? noiseFloor,
    int? lastRssi,
    double? lastSnr,
    int? txAirSeconds,
    int? rxAirSeconds,
  }) => RadioStatsSample(
    id: id ?? this.id,
    radioKey: radioKey ?? this.radioKey,
    at: at ?? this.at,
    noiseFloor: noiseFloor ?? this.noiseFloor,
    lastRssi: lastRssi ?? this.lastRssi,
    lastSnr: lastSnr ?? this.lastSnr,
    txAirSeconds: txAirSeconds ?? this.txAirSeconds,
    rxAirSeconds: rxAirSeconds ?? this.rxAirSeconds,
  );
  RadioStatsSample copyWithCompanion(RadioStatsSamplesCompanion data) {
    return RadioStatsSample(
      id: data.id.present ? data.id.value : this.id,
      radioKey: data.radioKey.present ? data.radioKey.value : this.radioKey,
      at: data.at.present ? data.at.value : this.at,
      noiseFloor: data.noiseFloor.present
          ? data.noiseFloor.value
          : this.noiseFloor,
      lastRssi: data.lastRssi.present ? data.lastRssi.value : this.lastRssi,
      lastSnr: data.lastSnr.present ? data.lastSnr.value : this.lastSnr,
      txAirSeconds: data.txAirSeconds.present
          ? data.txAirSeconds.value
          : this.txAirSeconds,
      rxAirSeconds: data.rxAirSeconds.present
          ? data.rxAirSeconds.value
          : this.rxAirSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RadioStatsSample(')
          ..write('id: $id, ')
          ..write('radioKey: $radioKey, ')
          ..write('at: $at, ')
          ..write('noiseFloor: $noiseFloor, ')
          ..write('lastRssi: $lastRssi, ')
          ..write('lastSnr: $lastSnr, ')
          ..write('txAirSeconds: $txAirSeconds, ')
          ..write('rxAirSeconds: $rxAirSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    radioKey,
    at,
    noiseFloor,
    lastRssi,
    lastSnr,
    txAirSeconds,
    rxAirSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RadioStatsSample &&
          other.id == this.id &&
          other.radioKey == this.radioKey &&
          other.at == this.at &&
          other.noiseFloor == this.noiseFloor &&
          other.lastRssi == this.lastRssi &&
          other.lastSnr == this.lastSnr &&
          other.txAirSeconds == this.txAirSeconds &&
          other.rxAirSeconds == this.rxAirSeconds);
}

class RadioStatsSamplesCompanion extends UpdateCompanion<RadioStatsSample> {
  final Value<int> id;
  final Value<String> radioKey;
  final Value<int> at;
  final Value<int> noiseFloor;
  final Value<int> lastRssi;
  final Value<double> lastSnr;
  final Value<int> txAirSeconds;
  final Value<int> rxAirSeconds;
  const RadioStatsSamplesCompanion({
    this.id = const Value.absent(),
    this.radioKey = const Value.absent(),
    this.at = const Value.absent(),
    this.noiseFloor = const Value.absent(),
    this.lastRssi = const Value.absent(),
    this.lastSnr = const Value.absent(),
    this.txAirSeconds = const Value.absent(),
    this.rxAirSeconds = const Value.absent(),
  });
  RadioStatsSamplesCompanion.insert({
    this.id = const Value.absent(),
    required String radioKey,
    required int at,
    required int noiseFloor,
    required int lastRssi,
    required double lastSnr,
    required int txAirSeconds,
    required int rxAirSeconds,
  }) : radioKey = Value(radioKey),
       at = Value(at),
       noiseFloor = Value(noiseFloor),
       lastRssi = Value(lastRssi),
       lastSnr = Value(lastSnr),
       txAirSeconds = Value(txAirSeconds),
       rxAirSeconds = Value(rxAirSeconds);
  static Insertable<RadioStatsSample> custom({
    Expression<int>? id,
    Expression<String>? radioKey,
    Expression<int>? at,
    Expression<int>? noiseFloor,
    Expression<int>? lastRssi,
    Expression<double>? lastSnr,
    Expression<int>? txAirSeconds,
    Expression<int>? rxAirSeconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (radioKey != null) 'radio_key': radioKey,
      if (at != null) 'at': at,
      if (noiseFloor != null) 'noise_floor': noiseFloor,
      if (lastRssi != null) 'last_rssi': lastRssi,
      if (lastSnr != null) 'last_snr': lastSnr,
      if (txAirSeconds != null) 'tx_air_seconds': txAirSeconds,
      if (rxAirSeconds != null) 'rx_air_seconds': rxAirSeconds,
    });
  }

  RadioStatsSamplesCompanion copyWith({
    Value<int>? id,
    Value<String>? radioKey,
    Value<int>? at,
    Value<int>? noiseFloor,
    Value<int>? lastRssi,
    Value<double>? lastSnr,
    Value<int>? txAirSeconds,
    Value<int>? rxAirSeconds,
  }) {
    return RadioStatsSamplesCompanion(
      id: id ?? this.id,
      radioKey: radioKey ?? this.radioKey,
      at: at ?? this.at,
      noiseFloor: noiseFloor ?? this.noiseFloor,
      lastRssi: lastRssi ?? this.lastRssi,
      lastSnr: lastSnr ?? this.lastSnr,
      txAirSeconds: txAirSeconds ?? this.txAirSeconds,
      rxAirSeconds: rxAirSeconds ?? this.rxAirSeconds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (radioKey.present) {
      map['radio_key'] = Variable<String>(radioKey.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (noiseFloor.present) {
      map['noise_floor'] = Variable<int>(noiseFloor.value);
    }
    if (lastRssi.present) {
      map['last_rssi'] = Variable<int>(lastRssi.value);
    }
    if (lastSnr.present) {
      map['last_snr'] = Variable<double>(lastSnr.value);
    }
    if (txAirSeconds.present) {
      map['tx_air_seconds'] = Variable<int>(txAirSeconds.value);
    }
    if (rxAirSeconds.present) {
      map['rx_air_seconds'] = Variable<int>(rxAirSeconds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RadioStatsSamplesCompanion(')
          ..write('id: $id, ')
          ..write('radioKey: $radioKey, ')
          ..write('at: $at, ')
          ..write('noiseFloor: $noiseFloor, ')
          ..write('lastRssi: $lastRssi, ')
          ..write('lastSnr: $lastSnr, ')
          ..write('txAirSeconds: $txAirSeconds, ')
          ..write('rxAirSeconds: $rxAirSeconds')
          ..write(')'))
        .toString();
  }
}

abstract class _$MeshDatabase extends GeneratedDatabase {
  _$MeshDatabase(QueryExecutor e) : super(e);
  $MeshDatabaseManager get managers => $MeshDatabaseManager(this);
  late final $RadiosTable radios = $RadiosTable(this);
  late final $ContactsTable contacts = $ContactsTable(this);
  late final $ChannelsTable channels = $ChannelsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $ThreadStatesTable threadStates = $ThreadStatesTable(this);
  late final $DiscoveredTable discovered = $DiscoveredTable(this);
  late final $TelemetrySamplesTable telemetrySamples = $TelemetrySamplesTable(
    this,
  );
  late final $RadioStatsSamplesTable radioStatsSamples =
      $RadioStatsSamplesTable(this);
  late final Index messagesByThread = Index(
    'messages_by_thread',
    'CREATE INDEX messages_by_thread ON messages (radio_key, thread, id)',
  );
  late final Index messagesByAck = Index(
    'messages_by_ack',
    'CREATE INDEX messages_by_ack ON messages (radio_key, ack_code)',
  );
  late final Index telemetryByNode = Index(
    'telemetry_by_node',
    'CREATE INDEX telemetry_by_node ON telemetry_samples (radio_key, node_key, at)',
  );
  late final Index radioStatsByRadio = Index(
    'radio_stats_by_radio',
    'CREATE INDEX radio_stats_by_radio ON radio_stats_samples (radio_key, at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    radios,
    contacts,
    channels,
    messages,
    settings,
    threadStates,
    discovered,
    telemetrySamples,
    radioStatsSamples,
    messagesByThread,
    messagesByAck,
    telemetryByNode,
    radioStatsByRadio,
  ];
}

typedef $$RadiosTableCreateCompanionBuilder = RadiosCompanion Function({
  required String publicKey,
  required String name,
  required int lastConnectedAt,
  Value<int> contactsSince,
  Value<int> rowid,
});
typedef $$RadiosTableUpdateCompanionBuilder = RadiosCompanion Function({
  Value<String> publicKey,
  Value<String> name,
  Value<int> lastConnectedAt,
  Value<int> contactsSince,
  Value<int> rowid,
});

final class $$RadiosTableReferences
    extends BaseReferences<_$MeshDatabase, $RadiosTable, Radio> {
  $$RadiosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ContactsTable, List<Contact>> _contactsRefsTable(
    _$MeshDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.contacts,
    aliasName: 'radios__public_key__contacts__radio_key',
  );

  $$ContactsTableProcessedTableManager get contactsRefs {
    final manager = $$ContactsTableTableManager($_db, $_db.contacts).filter(
      (f) =>
          f.radioKey.publicKey.sqlEquals($_itemColumn<String>('public_key')!),
    );

    final cache = $_typedResult.readTableOrNull(_contactsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ChannelsTable, List<Channel>> _channelsRefsTable(
    _$MeshDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.channels,
    aliasName: 'radios__public_key__channels__radio_key',
  );

  $$ChannelsTableProcessedTableManager get channelsRefs {
    final manager = $$ChannelsTableTableManager($_db, $_db.channels).filter(
      (f) =>
          f.radioKey.publicKey.sqlEquals($_itemColumn<String>('public_key')!),
    );

    final cache = $_typedResult.readTableOrNull(_channelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MessagesTable, List<Message>> _messagesRefsTable(
    _$MeshDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: 'radios__public_key__messages__radio_key',
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager($_db, $_db.messages).filter(
      (f) =>
          f.radioKey.publicKey.sqlEquals($_itemColumn<String>('public_key')!),
    );

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ThreadStatesTable, List<ThreadState>>
  _threadStatesRefsTable(_$MeshDatabase db) => MultiTypedResultKey.fromTable(
    db.threadStates,
    aliasName: 'radios__public_key__thread_states__radio_key',
  );

  $$ThreadStatesTableProcessedTableManager get threadStatesRefs {
    final manager = $$ThreadStatesTableTableManager($_db, $_db.threadStates)
        .filter(
          (f) => f.radioKey.publicKey.sqlEquals(
            $_itemColumn<String>('public_key')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_threadStatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DiscoveredTable, List<DiscoveredData>>
  _discoveredRefsTable(_$MeshDatabase db) => MultiTypedResultKey.fromTable(
    db.discovered,
    aliasName: 'radios__public_key__discovered__radio_key',
  );

  $$DiscoveredTableProcessedTableManager get discoveredRefs {
    final manager = $$DiscoveredTableTableManager($_db, $_db.discovered).filter(
      (f) =>
          f.radioKey.publicKey.sqlEquals($_itemColumn<String>('public_key')!),
    );

    final cache = $_typedResult.readTableOrNull(_discoveredRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TelemetrySamplesTable, List<TelemetrySample>>
  _telemetrySamplesRefsTable(_$MeshDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.telemetrySamples,
        aliasName: 'radios__public_key__telemetry_samples__radio_key',
      );

  $$TelemetrySamplesTableProcessedTableManager get telemetrySamplesRefs {
    final manager =
        $$TelemetrySamplesTableTableManager($_db, $_db.telemetrySamples).filter(
          (f) => f.radioKey.publicKey.sqlEquals(
            $_itemColumn<String>('public_key')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _telemetrySamplesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RadioStatsSamplesTable, List<RadioStatsSample>>
  _radioStatsSamplesRefsTable(_$MeshDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.radioStatsSamples,
        aliasName: 'radios__public_key__radio_stats_samples__radio_key',
      );

  $$RadioStatsSamplesTableProcessedTableManager get radioStatsSamplesRefs {
    final manager =
        $$RadioStatsSamplesTableTableManager(
          $_db,
          $_db.radioStatsSamples,
        ).filter(
          (f) => f.radioKey.publicKey.sqlEquals(
            $_itemColumn<String>('public_key')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _radioStatsSamplesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RadiosTableFilterComposer
    extends Composer<_$MeshDatabase, $RadiosTable> {
  $$RadiosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contactsSince => $composableBuilder(
    column: $table.contactsSince,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> contactsRefs(
    Expression<bool> Function($$ContactsTableFilterComposer f) f,
  ) {
    final $$ContactsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publicKey,
      referencedTable: $db.contacts,
      getReferencedColumn: (t) => t.radioKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContactsTableFilterComposer(
            $db: $db,
            $table: $db.contacts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> channelsRefs(
    Expression<bool> Function($$ChannelsTableFilterComposer f) f,
  ) {
    final $$ChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publicKey,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.radioKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableFilterComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publicKey,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.radioKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> threadStatesRefs(
    Expression<bool> Function($$ThreadStatesTableFilterComposer f) f,
  ) {
    final $$ThreadStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publicKey,
      referencedTable: $db.threadStates,
      getReferencedColumn: (t) => t.radioKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ThreadStatesTableFilterComposer(
            $db: $db,
            $table: $db.threadStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> discoveredRefs(
    Expression<bool> Function($$DiscoveredTableFilterComposer f) f,
  ) {
    final $$DiscoveredTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publicKey,
      referencedTable: $db.discovered,
      getReferencedColumn: (t) => t.radioKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiscoveredTableFilterComposer(
            $db: $db,
            $table: $db.discovered,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> telemetrySamplesRefs(
    Expression<bool> Function($$TelemetrySamplesTableFilterComposer f) f,
  ) {
    final $$TelemetrySamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publicKey,
      referencedTable: $db.telemetrySamples,
      getReferencedColumn: (t) => t.radioKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TelemetrySamplesTableFilterComposer(
            $db: $db,
            $table: $db.telemetrySamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> radioStatsSamplesRefs(
    Expression<bool> Function($$RadioStatsSamplesTableFilterComposer f) f,
  ) {
    final $$RadioStatsSamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publicKey,
      referencedTable: $db.radioStatsSamples,
      getReferencedColumn: (t) => t.radioKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadioStatsSamplesTableFilterComposer(
            $db: $db,
            $table: $db.radioStatsSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RadiosTableOrderingComposer
    extends Composer<_$MeshDatabase, $RadiosTable> {
  $$RadiosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contactsSince => $composableBuilder(
    column: $table.contactsSince,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RadiosTableAnnotationComposer
    extends Composer<_$MeshDatabase, $RadiosTable> {
  $$RadiosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get publicKey =>
      $composableBuilder(column: $table.publicKey, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contactsSince => $composableBuilder(
    column: $table.contactsSince,
    builder: (column) => column,
  );

  Expression<T> contactsRefs<T extends Object>(
    Expression<T> Function($$ContactsTableAnnotationComposer a) f,
  ) {
    final $$ContactsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publicKey,
      referencedTable: $db.contacts,
      getReferencedColumn: (t) => t.radioKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContactsTableAnnotationComposer(
            $db: $db,
            $table: $db.contacts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> channelsRefs<T extends Object>(
    Expression<T> Function($$ChannelsTableAnnotationComposer a) f,
  ) {
    final $$ChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publicKey,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.radioKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publicKey,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.radioKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> threadStatesRefs<T extends Object>(
    Expression<T> Function($$ThreadStatesTableAnnotationComposer a) f,
  ) {
    final $$ThreadStatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publicKey,
      referencedTable: $db.threadStates,
      getReferencedColumn: (t) => t.radioKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ThreadStatesTableAnnotationComposer(
            $db: $db,
            $table: $db.threadStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> discoveredRefs<T extends Object>(
    Expression<T> Function($$DiscoveredTableAnnotationComposer a) f,
  ) {
    final $$DiscoveredTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publicKey,
      referencedTable: $db.discovered,
      getReferencedColumn: (t) => t.radioKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiscoveredTableAnnotationComposer(
            $db: $db,
            $table: $db.discovered,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> telemetrySamplesRefs<T extends Object>(
    Expression<T> Function($$TelemetrySamplesTableAnnotationComposer a) f,
  ) {
    final $$TelemetrySamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publicKey,
      referencedTable: $db.telemetrySamples,
      getReferencedColumn: (t) => t.radioKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TelemetrySamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.telemetrySamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> radioStatsSamplesRefs<T extends Object>(
    Expression<T> Function($$RadioStatsSamplesTableAnnotationComposer a) f,
  ) {
    final $$RadioStatsSamplesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.publicKey,
          referencedTable: $db.radioStatsSamples,
          getReferencedColumn: (t) => t.radioKey,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RadioStatsSamplesTableAnnotationComposer(
                $db: $db,
                $table: $db.radioStatsSamples,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$RadiosTableTableManager
    extends
        RootTableManager<
          _$MeshDatabase,
          $RadiosTable,
          Radio,
          $$RadiosTableFilterComposer,
          $$RadiosTableOrderingComposer,
          $$RadiosTableAnnotationComposer,
          $$RadiosTableCreateCompanionBuilder,
          $$RadiosTableUpdateCompanionBuilder,
          (Radio, $$RadiosTableReferences),
          Radio,
          PrefetchHooks Function({
            bool contactsRefs,
            bool channelsRefs,
            bool messagesRefs,
            bool threadStatesRefs,
            bool discoveredRefs,
            bool telemetrySamplesRefs,
            bool radioStatsSamplesRefs,
          })
        > {
  $$RadiosTableTableManager(_$MeshDatabase db, $RadiosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RadiosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RadiosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RadiosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> publicKey = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> lastConnectedAt = const Value.absent(),
                Value<int> contactsSince = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RadiosCompanion(
                publicKey: publicKey,
                name: name,
                lastConnectedAt: lastConnectedAt,
                contactsSince: contactsSince,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String publicKey,
                required String name,
                required int lastConnectedAt,
                Value<int> contactsSince = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RadiosCompanion.insert(
                publicKey: publicKey,
                name: name,
                lastConnectedAt: lastConnectedAt,
                contactsSince: contactsSince,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RadiosTable, Radio>(table),
                  $$RadiosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                contactsRefs = false,
                channelsRefs = false,
                messagesRefs = false,
                threadStatesRefs = false,
                discoveredRefs = false,
                telemetrySamplesRefs = false,
                radioStatsSamplesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (contactsRefs) db.contacts,
                    if (channelsRefs) db.channels,
                    if (messagesRefs) db.messages,
                    if (threadStatesRefs) db.threadStates,
                    if (discoveredRefs) db.discovered,
                    if (telemetrySamplesRefs) db.telemetrySamples,
                    if (radioStatsSamplesRefs) db.radioStatsSamples,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (contactsRefs)
                        await $_getPrefetchedDataByColumns<
                          Radio,
                          $RadiosTable,
                          Contact,
                          $ContactsTable
                        >(
                          currentTable: table,
                          referencedTable: $$RadiosTableReferences
                              ._contactsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RadiosTableReferences(
                                db,
                                table,
                                p0,
                              ).contactsRefs,
                          currentColumn: 'public_key',
                          referencedColumn: 'radio_key',
                          typedResults: items,
                        ),
                      if (channelsRefs)
                        await $_getPrefetchedDataByColumns<
                          Radio,
                          $RadiosTable,
                          Channel,
                          $ChannelsTable
                        >(
                          currentTable: table,
                          referencedTable: $$RadiosTableReferences
                              ._channelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RadiosTableReferences(
                                db,
                                table,
                                p0,
                              ).channelsRefs,
                          currentColumn: 'public_key',
                          referencedColumn: 'radio_key',
                          typedResults: items,
                        ),
                      if (messagesRefs)
                        await $_getPrefetchedDataByColumns<
                          Radio,
                          $RadiosTable,
                          Message,
                          $MessagesTable
                        >(
                          currentTable: table,
                          referencedTable: $$RadiosTableReferences
                              ._messagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RadiosTableReferences(
                                db,
                                table,
                                p0,
                              ).messagesRefs,
                          currentColumn: 'public_key',
                          referencedColumn: 'radio_key',
                          typedResults: items,
                        ),
                      if (threadStatesRefs)
                        await $_getPrefetchedDataByColumns<
                          Radio,
                          $RadiosTable,
                          ThreadState,
                          $ThreadStatesTable
                        >(
                          currentTable: table,
                          referencedTable: $$RadiosTableReferences
                              ._threadStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RadiosTableReferences(
                                db,
                                table,
                                p0,
                              ).threadStatesRefs,
                          currentColumn: 'public_key',
                          referencedColumn: 'radio_key',
                          typedResults: items,
                        ),
                      if (discoveredRefs)
                        await $_getPrefetchedDataByColumns<
                          Radio,
                          $RadiosTable,
                          DiscoveredData,
                          $DiscoveredTable
                        >(
                          currentTable: table,
                          referencedTable: $$RadiosTableReferences
                              ._discoveredRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RadiosTableReferences(
                                db,
                                table,
                                p0,
                              ).discoveredRefs,
                          currentColumn: 'public_key',
                          referencedColumn: 'radio_key',
                          typedResults: items,
                        ),
                      if (telemetrySamplesRefs)
                        await $_getPrefetchedDataByColumns<
                          Radio,
                          $RadiosTable,
                          TelemetrySample,
                          $TelemetrySamplesTable
                        >(
                          currentTable: table,
                          referencedTable: $$RadiosTableReferences
                              ._telemetrySamplesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RadiosTableReferences(
                                db,
                                table,
                                p0,
                              ).telemetrySamplesRefs,
                          currentColumn: 'public_key',
                          referencedColumn: 'radio_key',
                          typedResults: items,
                        ),
                      if (radioStatsSamplesRefs)
                        await $_getPrefetchedDataByColumns<
                          Radio,
                          $RadiosTable,
                          RadioStatsSample,
                          $RadioStatsSamplesTable
                        >(
                          currentTable: table,
                          referencedTable: $$RadiosTableReferences
                              ._radioStatsSamplesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RadiosTableReferences(
                                db,
                                table,
                                p0,
                              ).radioStatsSamplesRefs,
                          currentColumn: 'public_key',
                          referencedColumn: 'radio_key',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RadiosTableProcessedTableManager =
    ProcessedTableManager<
      _$MeshDatabase,
      $RadiosTable,
      Radio,
      $$RadiosTableFilterComposer,
      $$RadiosTableOrderingComposer,
      $$RadiosTableAnnotationComposer,
      $$RadiosTableCreateCompanionBuilder,
      $$RadiosTableUpdateCompanionBuilder,
      (Radio, $$RadiosTableReferences),
      Radio,
      PrefetchHooks Function({
        bool contactsRefs,
        bool channelsRefs,
        bool messagesRefs,
        bool threadStatesRefs,
        bool discoveredRefs,
        bool telemetrySamplesRefs,
        bool radioStatsSamplesRefs,
      })
    >;
typedef $$ContactsTableCreateCompanionBuilder = ContactsCompanion Function({
  required String radioKey,
  required String publicKey,
  required String name,
  required int type,
  required int flags,
  required int outPathLength,
  required Uint8List outPath,
  required int lastAdvert,
  Value<double?> latitude,
  Value<double?> longitude,
  required int lastModified,
  Value<int> rowid,
});
typedef $$ContactsTableUpdateCompanionBuilder = ContactsCompanion Function({
  Value<String> radioKey,
  Value<String> publicKey,
  Value<String> name,
  Value<int> type,
  Value<int> flags,
  Value<int> outPathLength,
  Value<Uint8List> outPath,
  Value<int> lastAdvert,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<int> lastModified,
  Value<int> rowid,
});

final class $$ContactsTableReferences
    extends BaseReferences<_$MeshDatabase, $ContactsTable, Contact> {
  $$ContactsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RadiosTable _radioKeyTable(_$MeshDatabase db) =>
      db.radios.createAlias('contacts__radio_key__radios__public_key');

  $$RadiosTableProcessedTableManager get radioKey {
    final $_column = $_itemColumn<String>('radio_key')!;

    final manager = $$RadiosTableTableManager(
      $_db,
      $_db.radios,
    ).filter((f) => f.publicKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_radioKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ContactsTableFilterComposer
    extends Composer<_$MeshDatabase, $ContactsTable> {
  $$ContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get flags => $composableBuilder(
    column: $table.flags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outPathLength => $composableBuilder(
    column: $table.outPathLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get outPath => $composableBuilder(
    column: $table.outPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAdvert => $composableBuilder(
    column: $table.lastAdvert,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );

  $$RadiosTableFilterComposer get radioKey {
    final $$RadiosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableFilterComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ContactsTableOrderingComposer
    extends Composer<_$MeshDatabase, $ContactsTable> {
  $$ContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get flags => $composableBuilder(
    column: $table.flags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outPathLength => $composableBuilder(
    column: $table.outPathLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get outPath => $composableBuilder(
    column: $table.outPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAdvert => $composableBuilder(
    column: $table.lastAdvert,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );

  $$RadiosTableOrderingComposer get radioKey {
    final $$RadiosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableOrderingComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ContactsTableAnnotationComposer
    extends Composer<_$MeshDatabase, $ContactsTable> {
  $$ContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get publicKey =>
      $composableBuilder(column: $table.publicKey, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get flags =>
      $composableBuilder(column: $table.flags, builder: (column) => column);

  GeneratedColumn<int> get outPathLength => $composableBuilder(
    column: $table.outPathLength,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get outPath =>
      $composableBuilder(column: $table.outPath, builder: (column) => column);

  GeneratedColumn<int> get lastAdvert => $composableBuilder(
    column: $table.lastAdvert,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<int> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );

  $$RadiosTableAnnotationComposer get radioKey {
    final $$RadiosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableAnnotationComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ContactsTableTableManager
    extends
        RootTableManager<
          _$MeshDatabase,
          $ContactsTable,
          Contact,
          $$ContactsTableFilterComposer,
          $$ContactsTableOrderingComposer,
          $$ContactsTableAnnotationComposer,
          $$ContactsTableCreateCompanionBuilder,
          $$ContactsTableUpdateCompanionBuilder,
          (Contact, $$ContactsTableReferences),
          Contact,
          PrefetchHooks Function({bool radioKey})
        > {
  $$ContactsTableTableManager(_$MeshDatabase db, $ContactsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> radioKey = const Value.absent(),
                Value<String> publicKey = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<int> flags = const Value.absent(),
                Value<int> outPathLength = const Value.absent(),
                Value<Uint8List> outPath = const Value.absent(),
                Value<int> lastAdvert = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<int> lastModified = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion(
                radioKey: radioKey,
                publicKey: publicKey,
                name: name,
                type: type,
                flags: flags,
                outPathLength: outPathLength,
                outPath: outPath,
                lastAdvert: lastAdvert,
                latitude: latitude,
                longitude: longitude,
                lastModified: lastModified,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String radioKey,
                required String publicKey,
                required String name,
                required int type,
                required int flags,
                required int outPathLength,
                required Uint8List outPath,
                required int lastAdvert,
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                required int lastModified,
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion.insert(
                radioKey: radioKey,
                publicKey: publicKey,
                name: name,
                type: type,
                flags: flags,
                outPathLength: outPathLength,
                outPath: outPath,
                lastAdvert: lastAdvert,
                latitude: latitude,
                longitude: longitude,
                lastModified: lastModified,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContactsTable, Contact>(table),
                  $$ContactsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({radioKey = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (radioKey) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.radioKey,
                        referencedTable: $$ContactsTableReferences
                            ._radioKeyTable(db),
                        referencedColumn: $$ContactsTableReferences
                            ._radioKeyTable(db)
                            .publicKey,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ContactsTableProcessedTableManager =
    ProcessedTableManager<
      _$MeshDatabase,
      $ContactsTable,
      Contact,
      $$ContactsTableFilterComposer,
      $$ContactsTableOrderingComposer,
      $$ContactsTableAnnotationComposer,
      $$ContactsTableCreateCompanionBuilder,
      $$ContactsTableUpdateCompanionBuilder,
      (Contact, $$ContactsTableReferences),
      Contact,
      PrefetchHooks Function({bool radioKey})
    >;
typedef $$ChannelsTableCreateCompanionBuilder = ChannelsCompanion Function({
  required String radioKey,
  required int slot,
  required String name,
  required Uint8List secret,
  Value<int> rowid,
});
typedef $$ChannelsTableUpdateCompanionBuilder = ChannelsCompanion Function({
  Value<String> radioKey,
  Value<int> slot,
  Value<String> name,
  Value<Uint8List> secret,
  Value<int> rowid,
});

final class $$ChannelsTableReferences
    extends BaseReferences<_$MeshDatabase, $ChannelsTable, Channel> {
  $$ChannelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RadiosTable _radioKeyTable(_$MeshDatabase db) =>
      db.radios.createAlias('channels__radio_key__radios__public_key');

  $$RadiosTableProcessedTableManager get radioKey {
    final $_column = $_itemColumn<String>('radio_key')!;

    final manager = $$RadiosTableTableManager(
      $_db,
      $_db.radios,
    ).filter((f) => f.publicKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_radioKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChannelsTableFilterComposer
    extends Composer<_$MeshDatabase, $ChannelsTable> {
  $$ChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get secret => $composableBuilder(
    column: $table.secret,
    builder: (column) => ColumnFilters(column),
  );

  $$RadiosTableFilterComposer get radioKey {
    final $$RadiosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableFilterComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChannelsTableOrderingComposer
    extends Composer<_$MeshDatabase, $ChannelsTable> {
  $$ChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get secret => $composableBuilder(
    column: $table.secret,
    builder: (column) => ColumnOrderings(column),
  );

  $$RadiosTableOrderingComposer get radioKey {
    final $$RadiosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableOrderingComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChannelsTableAnnotationComposer
    extends Composer<_$MeshDatabase, $ChannelsTable> {
  $$ChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<Uint8List> get secret =>
      $composableBuilder(column: $table.secret, builder: (column) => column);

  $$RadiosTableAnnotationComposer get radioKey {
    final $$RadiosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableAnnotationComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChannelsTableTableManager
    extends
        RootTableManager<
          _$MeshDatabase,
          $ChannelsTable,
          Channel,
          $$ChannelsTableFilterComposer,
          $$ChannelsTableOrderingComposer,
          $$ChannelsTableAnnotationComposer,
          $$ChannelsTableCreateCompanionBuilder,
          $$ChannelsTableUpdateCompanionBuilder,
          (Channel, $$ChannelsTableReferences),
          Channel,
          PrefetchHooks Function({bool radioKey})
        > {
  $$ChannelsTableTableManager(_$MeshDatabase db, $ChannelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> radioKey = const Value.absent(),
                Value<int> slot = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<Uint8List> secret = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChannelsCompanion(
                radioKey: radioKey,
                slot: slot,
                name: name,
                secret: secret,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String radioKey,
                required int slot,
                required String name,
                required Uint8List secret,
                Value<int> rowid = const Value.absent(),
              }) => ChannelsCompanion.insert(
                radioKey: radioKey,
                slot: slot,
                name: name,
                secret: secret,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChannelsTable, Channel>(table),
                  $$ChannelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({radioKey = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (radioKey) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.radioKey,
                        referencedTable: $$ChannelsTableReferences
                            ._radioKeyTable(db),
                        referencedColumn: $$ChannelsTableReferences
                            ._radioKeyTable(db)
                            .publicKey,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$MeshDatabase,
      $ChannelsTable,
      Channel,
      $$ChannelsTableFilterComposer,
      $$ChannelsTableOrderingComposer,
      $$ChannelsTableAnnotationComposer,
      $$ChannelsTableCreateCompanionBuilder,
      $$ChannelsTableUpdateCompanionBuilder,
      (Channel, $$ChannelsTableReferences),
      Channel,
      PrefetchHooks Function({bool radioKey})
    >;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  required String radioKey,
  required MessageKind kind,
  required String thread,
  required bool outgoing,
  required String body,
  Value<String?> senderName,
  required int sentAt,
  required int storedAt,
  required MessageStatus status,
  Value<int> attempts,
  Value<int?> ackCode,
  Value<bool?> flooded,
  Value<int?> pathLength,
  Value<double?> snr,
  Value<int> textType,
  Value<String?> authorPrefix,
  Value<String?> dedupeKey,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  Value<String> radioKey,
  Value<MessageKind> kind,
  Value<String> thread,
  Value<bool> outgoing,
  Value<String> body,
  Value<String?> senderName,
  Value<int> sentAt,
  Value<int> storedAt,
  Value<MessageStatus> status,
  Value<int> attempts,
  Value<int?> ackCode,
  Value<bool?> flooded,
  Value<int?> pathLength,
  Value<double?> snr,
  Value<int> textType,
  Value<String?> authorPrefix,
  Value<String?> dedupeKey,
});

final class $$MessagesTableReferences
    extends BaseReferences<_$MeshDatabase, $MessagesTable, Message> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RadiosTable _radioKeyTable(_$MeshDatabase db) =>
      db.radios.createAlias('messages__radio_key__radios__public_key');

  $$RadiosTableProcessedTableManager get radioKey {
    final $_column = $_itemColumn<String>('radio_key')!;

    final manager = $$RadiosTableTableManager(
      $_db,
      $_db.radios,
    ).filter((f) => f.publicKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_radioKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$MeshDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MessageKind, MessageKind, int> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get thread => $composableBuilder(
    column: $table.thread,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get outgoing => $composableBuilder(
    column: $table.outgoing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storedAt => $composableBuilder(
    column: $table.storedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MessageStatus, MessageStatus, int>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ackCode => $composableBuilder(
    column: $table.ackCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get flooded => $composableBuilder(
    column: $table.flooded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pathLength => $composableBuilder(
    column: $table.pathLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get snr => $composableBuilder(
    column: $table.snr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get textType => $composableBuilder(
    column: $table.textType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorPrefix => $composableBuilder(
    column: $table.authorPrefix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnFilters(column),
  );

  $$RadiosTableFilterComposer get radioKey {
    final $$RadiosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableFilterComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$MeshDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thread => $composableBuilder(
    column: $table.thread,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get outgoing => $composableBuilder(
    column: $table.outgoing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storedAt => $composableBuilder(
    column: $table.storedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ackCode => $composableBuilder(
    column: $table.ackCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get flooded => $composableBuilder(
    column: $table.flooded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pathLength => $composableBuilder(
    column: $table.pathLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get snr => $composableBuilder(
    column: $table.snr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get textType => $composableBuilder(
    column: $table.textType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorPrefix => $composableBuilder(
    column: $table.authorPrefix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnOrderings(column),
  );

  $$RadiosTableOrderingComposer get radioKey {
    final $$RadiosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableOrderingComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$MeshDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MessageKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get thread =>
      $composableBuilder(column: $table.thread, builder: (column) => column);

  GeneratedColumn<bool> get outgoing =>
      $composableBuilder(column: $table.outgoing, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumn<int> get storedAt =>
      $composableBuilder(column: $table.storedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MessageStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get ackCode =>
      $composableBuilder(column: $table.ackCode, builder: (column) => column);

  GeneratedColumn<bool> get flooded =>
      $composableBuilder(column: $table.flooded, builder: (column) => column);

  GeneratedColumn<int> get pathLength => $composableBuilder(
    column: $table.pathLength,
    builder: (column) => column,
  );

  GeneratedColumn<double> get snr =>
      $composableBuilder(column: $table.snr, builder: (column) => column);

  GeneratedColumn<int> get textType =>
      $composableBuilder(column: $table.textType, builder: (column) => column);

  GeneratedColumn<String> get authorPrefix => $composableBuilder(
    column: $table.authorPrefix,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dedupeKey =>
      $composableBuilder(column: $table.dedupeKey, builder: (column) => column);

  $$RadiosTableAnnotationComposer get radioKey {
    final $$RadiosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableAnnotationComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$MeshDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, $$MessagesTableReferences),
          Message,
          PrefetchHooks Function({bool radioKey})
        > {
  $$MessagesTableTableManager(_$MeshDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> radioKey = const Value.absent(),
                Value<MessageKind> kind = const Value.absent(),
                Value<String> thread = const Value.absent(),
                Value<bool> outgoing = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> senderName = const Value.absent(),
                Value<int> sentAt = const Value.absent(),
                Value<int> storedAt = const Value.absent(),
                Value<MessageStatus> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int?> ackCode = const Value.absent(),
                Value<bool?> flooded = const Value.absent(),
                Value<int?> pathLength = const Value.absent(),
                Value<double?> snr = const Value.absent(),
                Value<int> textType = const Value.absent(),
                Value<String?> authorPrefix = const Value.absent(),
                Value<String?> dedupeKey = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                radioKey: radioKey,
                kind: kind,
                thread: thread,
                outgoing: outgoing,
                body: body,
                senderName: senderName,
                sentAt: sentAt,
                storedAt: storedAt,
                status: status,
                attempts: attempts,
                ackCode: ackCode,
                flooded: flooded,
                pathLength: pathLength,
                snr: snr,
                textType: textType,
                authorPrefix: authorPrefix,
                dedupeKey: dedupeKey,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String radioKey,
                required MessageKind kind,
                required String thread,
                required bool outgoing,
                required String body,
                Value<String?> senderName = const Value.absent(),
                required int sentAt,
                required int storedAt,
                required MessageStatus status,
                Value<int> attempts = const Value.absent(),
                Value<int?> ackCode = const Value.absent(),
                Value<bool?> flooded = const Value.absent(),
                Value<int?> pathLength = const Value.absent(),
                Value<double?> snr = const Value.absent(),
                Value<int> textType = const Value.absent(),
                Value<String?> authorPrefix = const Value.absent(),
                Value<String?> dedupeKey = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                radioKey: radioKey,
                kind: kind,
                thread: thread,
                outgoing: outgoing,
                body: body,
                senderName: senderName,
                sentAt: sentAt,
                storedAt: storedAt,
                status: status,
                attempts: attempts,
                ackCode: ackCode,
                flooded: flooded,
                pathLength: pathLength,
                snr: snr,
                textType: textType,
                authorPrefix: authorPrefix,
                dedupeKey: dedupeKey,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MessagesTable, Message>(table),
                  $$MessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({radioKey = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (radioKey) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.radioKey,
                        referencedTable: $$MessagesTableReferences
                            ._radioKeyTable(db),
                        referencedColumn: $$MessagesTableReferences
                            ._radioKeyTable(db)
                            .publicKey,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$MeshDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, $$MessagesTableReferences),
      Message,
      PrefetchHooks Function({bool radioKey})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$MeshDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$MeshDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$MeshDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$MeshDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$MeshDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$MeshDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$MeshDatabase, $SettingsTable, Setting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$MeshDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$MeshDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$ThreadStatesTableCreateCompanionBuilder =
    ThreadStatesCompanion Function({
      required String radioKey,
      required String thread,
      Value<int> lastReadId,
      Value<bool> muted,
      Value<int> rowid,
    });
typedef $$ThreadStatesTableUpdateCompanionBuilder =
    ThreadStatesCompanion Function({
      Value<String> radioKey,
      Value<String> thread,
      Value<int> lastReadId,
      Value<bool> muted,
      Value<int> rowid,
    });

final class $$ThreadStatesTableReferences
    extends BaseReferences<_$MeshDatabase, $ThreadStatesTable, ThreadState> {
  $$ThreadStatesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RadiosTable _radioKeyTable(_$MeshDatabase db) =>
      db.radios.createAlias('thread_states__radio_key__radios__public_key');

  $$RadiosTableProcessedTableManager get radioKey {
    final $_column = $_itemColumn<String>('radio_key')!;

    final manager = $$RadiosTableTableManager(
      $_db,
      $_db.radios,
    ).filter((f) => f.publicKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_radioKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ThreadStatesTableFilterComposer
    extends Composer<_$MeshDatabase, $ThreadStatesTable> {
  $$ThreadStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get thread => $composableBuilder(
    column: $table.thread,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReadId => $composableBuilder(
    column: $table.lastReadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get muted => $composableBuilder(
    column: $table.muted,
    builder: (column) => ColumnFilters(column),
  );

  $$RadiosTableFilterComposer get radioKey {
    final $$RadiosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableFilterComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ThreadStatesTableOrderingComposer
    extends Composer<_$MeshDatabase, $ThreadStatesTable> {
  $$ThreadStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get thread => $composableBuilder(
    column: $table.thread,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReadId => $composableBuilder(
    column: $table.lastReadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get muted => $composableBuilder(
    column: $table.muted,
    builder: (column) => ColumnOrderings(column),
  );

  $$RadiosTableOrderingComposer get radioKey {
    final $$RadiosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableOrderingComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ThreadStatesTableAnnotationComposer
    extends Composer<_$MeshDatabase, $ThreadStatesTable> {
  $$ThreadStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get thread =>
      $composableBuilder(column: $table.thread, builder: (column) => column);

  GeneratedColumn<int> get lastReadId => $composableBuilder(
    column: $table.lastReadId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get muted =>
      $composableBuilder(column: $table.muted, builder: (column) => column);

  $$RadiosTableAnnotationComposer get radioKey {
    final $$RadiosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableAnnotationComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ThreadStatesTableTableManager
    extends
        RootTableManager<
          _$MeshDatabase,
          $ThreadStatesTable,
          ThreadState,
          $$ThreadStatesTableFilterComposer,
          $$ThreadStatesTableOrderingComposer,
          $$ThreadStatesTableAnnotationComposer,
          $$ThreadStatesTableCreateCompanionBuilder,
          $$ThreadStatesTableUpdateCompanionBuilder,
          (ThreadState, $$ThreadStatesTableReferences),
          ThreadState,
          PrefetchHooks Function({bool radioKey})
        > {
  $$ThreadStatesTableTableManager(_$MeshDatabase db, $ThreadStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ThreadStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ThreadStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ThreadStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> radioKey = const Value.absent(),
                Value<String> thread = const Value.absent(),
                Value<int> lastReadId = const Value.absent(),
                Value<bool> muted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ThreadStatesCompanion(
                radioKey: radioKey,
                thread: thread,
                lastReadId: lastReadId,
                muted: muted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String radioKey,
                required String thread,
                Value<int> lastReadId = const Value.absent(),
                Value<bool> muted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ThreadStatesCompanion.insert(
                radioKey: radioKey,
                thread: thread,
                lastReadId: lastReadId,
                muted: muted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ThreadStatesTable, ThreadState>(table),
                  $$ThreadStatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({radioKey = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (radioKey) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.radioKey,
                        referencedTable: $$ThreadStatesTableReferences
                            ._radioKeyTable(db),
                        referencedColumn: $$ThreadStatesTableReferences
                            ._radioKeyTable(db)
                            .publicKey,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ThreadStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$MeshDatabase,
      $ThreadStatesTable,
      ThreadState,
      $$ThreadStatesTableFilterComposer,
      $$ThreadStatesTableOrderingComposer,
      $$ThreadStatesTableAnnotationComposer,
      $$ThreadStatesTableCreateCompanionBuilder,
      $$ThreadStatesTableUpdateCompanionBuilder,
      (ThreadState, $$ThreadStatesTableReferences),
      ThreadState,
      PrefetchHooks Function({bool radioKey})
    >;
typedef $$DiscoveredTableCreateCompanionBuilder = DiscoveredCompanion Function({
  required String radioKey,
  required String publicKey,
  required String name,
  required int type,
  Value<double?> latitude,
  Value<double?> longitude,
  required int lastAdvert,
  required int heardAt,
  Value<int> rowid,
});
typedef $$DiscoveredTableUpdateCompanionBuilder = DiscoveredCompanion Function({
  Value<String> radioKey,
  Value<String> publicKey,
  Value<String> name,
  Value<int> type,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<int> lastAdvert,
  Value<int> heardAt,
  Value<int> rowid,
});

final class $$DiscoveredTableReferences
    extends BaseReferences<_$MeshDatabase, $DiscoveredTable, DiscoveredData> {
  $$DiscoveredTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RadiosTable _radioKeyTable(_$MeshDatabase db) =>
      db.radios.createAlias('discovered__radio_key__radios__public_key');

  $$RadiosTableProcessedTableManager get radioKey {
    final $_column = $_itemColumn<String>('radio_key')!;

    final manager = $$RadiosTableTableManager(
      $_db,
      $_db.radios,
    ).filter((f) => f.publicKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_radioKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DiscoveredTableFilterComposer
    extends Composer<_$MeshDatabase, $DiscoveredTable> {
  $$DiscoveredTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAdvert => $composableBuilder(
    column: $table.lastAdvert,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get heardAt => $composableBuilder(
    column: $table.heardAt,
    builder: (column) => ColumnFilters(column),
  );

  $$RadiosTableFilterComposer get radioKey {
    final $$RadiosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableFilterComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DiscoveredTableOrderingComposer
    extends Composer<_$MeshDatabase, $DiscoveredTable> {
  $$DiscoveredTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAdvert => $composableBuilder(
    column: $table.lastAdvert,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heardAt => $composableBuilder(
    column: $table.heardAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RadiosTableOrderingComposer get radioKey {
    final $$RadiosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableOrderingComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DiscoveredTableAnnotationComposer
    extends Composer<_$MeshDatabase, $DiscoveredTable> {
  $$DiscoveredTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get publicKey =>
      $composableBuilder(column: $table.publicKey, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<int> get lastAdvert => $composableBuilder(
    column: $table.lastAdvert,
    builder: (column) => column,
  );

  GeneratedColumn<int> get heardAt =>
      $composableBuilder(column: $table.heardAt, builder: (column) => column);

  $$RadiosTableAnnotationComposer get radioKey {
    final $$RadiosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableAnnotationComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DiscoveredTableTableManager
    extends
        RootTableManager<
          _$MeshDatabase,
          $DiscoveredTable,
          DiscoveredData,
          $$DiscoveredTableFilterComposer,
          $$DiscoveredTableOrderingComposer,
          $$DiscoveredTableAnnotationComposer,
          $$DiscoveredTableCreateCompanionBuilder,
          $$DiscoveredTableUpdateCompanionBuilder,
          (DiscoveredData, $$DiscoveredTableReferences),
          DiscoveredData,
          PrefetchHooks Function({bool radioKey})
        > {
  $$DiscoveredTableTableManager(_$MeshDatabase db, $DiscoveredTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiscoveredTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiscoveredTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiscoveredTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> radioKey = const Value.absent(),
                Value<String> publicKey = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<int> lastAdvert = const Value.absent(),
                Value<int> heardAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiscoveredCompanion(
                radioKey: radioKey,
                publicKey: publicKey,
                name: name,
                type: type,
                latitude: latitude,
                longitude: longitude,
                lastAdvert: lastAdvert,
                heardAt: heardAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String radioKey,
                required String publicKey,
                required String name,
                required int type,
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                required int lastAdvert,
                required int heardAt,
                Value<int> rowid = const Value.absent(),
              }) => DiscoveredCompanion.insert(
                radioKey: radioKey,
                publicKey: publicKey,
                name: name,
                type: type,
                latitude: latitude,
                longitude: longitude,
                lastAdvert: lastAdvert,
                heardAt: heardAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiscoveredTable, DiscoveredData>(table),
                  $$DiscoveredTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({radioKey = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (radioKey) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.radioKey,
                        referencedTable: $$DiscoveredTableReferences
                            ._radioKeyTable(db),
                        referencedColumn: $$DiscoveredTableReferences
                            ._radioKeyTable(db)
                            .publicKey,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DiscoveredTableProcessedTableManager =
    ProcessedTableManager<
      _$MeshDatabase,
      $DiscoveredTable,
      DiscoveredData,
      $$DiscoveredTableFilterComposer,
      $$DiscoveredTableOrderingComposer,
      $$DiscoveredTableAnnotationComposer,
      $$DiscoveredTableCreateCompanionBuilder,
      $$DiscoveredTableUpdateCompanionBuilder,
      (DiscoveredData, $$DiscoveredTableReferences),
      DiscoveredData,
      PrefetchHooks Function({bool radioKey})
    >;
typedef $$TelemetrySamplesTableCreateCompanionBuilder =
    TelemetrySamplesCompanion Function({
      Value<int> id,
      required String radioKey,
      required String nodeKey,
      required int at,
      required Uint8List data,
    });
typedef $$TelemetrySamplesTableUpdateCompanionBuilder =
    TelemetrySamplesCompanion Function({
      Value<int> id,
      Value<String> radioKey,
      Value<String> nodeKey,
      Value<int> at,
      Value<Uint8List> data,
    });

final class $$TelemetrySamplesTableReferences
    extends
        BaseReferences<
          _$MeshDatabase,
          $TelemetrySamplesTable,
          TelemetrySample
        > {
  $$TelemetrySamplesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RadiosTable _radioKeyTable(_$MeshDatabase db) =>
      db.radios.createAlias('telemetry_samples__radio_key__radios__public_key');

  $$RadiosTableProcessedTableManager get radioKey {
    final $_column = $_itemColumn<String>('radio_key')!;

    final manager = $$RadiosTableTableManager(
      $_db,
      $_db.radios,
    ).filter((f) => f.publicKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_radioKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TelemetrySamplesTableFilterComposer
    extends Composer<_$MeshDatabase, $TelemetrySamplesTable> {
  $$TelemetrySamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nodeKey => $composableBuilder(
    column: $table.nodeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  $$RadiosTableFilterComposer get radioKey {
    final $$RadiosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableFilterComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TelemetrySamplesTableOrderingComposer
    extends Composer<_$MeshDatabase, $TelemetrySamplesTable> {
  $$TelemetrySamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nodeKey => $composableBuilder(
    column: $table.nodeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  $$RadiosTableOrderingComposer get radioKey {
    final $$RadiosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableOrderingComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TelemetrySamplesTableAnnotationComposer
    extends Composer<_$MeshDatabase, $TelemetrySamplesTable> {
  $$TelemetrySamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nodeKey =>
      $composableBuilder(column: $table.nodeKey, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<Uint8List> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  $$RadiosTableAnnotationComposer get radioKey {
    final $$RadiosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableAnnotationComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TelemetrySamplesTableTableManager
    extends
        RootTableManager<
          _$MeshDatabase,
          $TelemetrySamplesTable,
          TelemetrySample,
          $$TelemetrySamplesTableFilterComposer,
          $$TelemetrySamplesTableOrderingComposer,
          $$TelemetrySamplesTableAnnotationComposer,
          $$TelemetrySamplesTableCreateCompanionBuilder,
          $$TelemetrySamplesTableUpdateCompanionBuilder,
          (TelemetrySample, $$TelemetrySamplesTableReferences),
          TelemetrySample,
          PrefetchHooks Function({bool radioKey})
        > {
  $$TelemetrySamplesTableTableManager(
    _$MeshDatabase db,
    $TelemetrySamplesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TelemetrySamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TelemetrySamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TelemetrySamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> radioKey = const Value.absent(),
                Value<String> nodeKey = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<Uint8List> data = const Value.absent(),
              }) => TelemetrySamplesCompanion(
                id: id,
                radioKey: radioKey,
                nodeKey: nodeKey,
                at: at,
                data: data,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String radioKey,
                required String nodeKey,
                required int at,
                required Uint8List data,
              }) => TelemetrySamplesCompanion.insert(
                id: id,
                radioKey: radioKey,
                nodeKey: nodeKey,
                at: at,
                data: data,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TelemetrySamplesTable, TelemetrySample>(table),
                  $$TelemetrySamplesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({radioKey = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (radioKey) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.radioKey,
                        referencedTable: $$TelemetrySamplesTableReferences
                            ._radioKeyTable(db),
                        referencedColumn: $$TelemetrySamplesTableReferences
                            ._radioKeyTable(db)
                            .publicKey,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TelemetrySamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$MeshDatabase,
      $TelemetrySamplesTable,
      TelemetrySample,
      $$TelemetrySamplesTableFilterComposer,
      $$TelemetrySamplesTableOrderingComposer,
      $$TelemetrySamplesTableAnnotationComposer,
      $$TelemetrySamplesTableCreateCompanionBuilder,
      $$TelemetrySamplesTableUpdateCompanionBuilder,
      (TelemetrySample, $$TelemetrySamplesTableReferences),
      TelemetrySample,
      PrefetchHooks Function({bool radioKey})
    >;
typedef $$RadioStatsSamplesTableCreateCompanionBuilder =
    RadioStatsSamplesCompanion Function({
      Value<int> id,
      required String radioKey,
      required int at,
      required int noiseFloor,
      required int lastRssi,
      required double lastSnr,
      required int txAirSeconds,
      required int rxAirSeconds,
    });
typedef $$RadioStatsSamplesTableUpdateCompanionBuilder =
    RadioStatsSamplesCompanion Function({
      Value<int> id,
      Value<String> radioKey,
      Value<int> at,
      Value<int> noiseFloor,
      Value<int> lastRssi,
      Value<double> lastSnr,
      Value<int> txAirSeconds,
      Value<int> rxAirSeconds,
    });

final class $$RadioStatsSamplesTableReferences
    extends
        BaseReferences<
          _$MeshDatabase,
          $RadioStatsSamplesTable,
          RadioStatsSample
        > {
  $$RadioStatsSamplesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RadiosTable _radioKeyTable(_$MeshDatabase db) => db.radios
      .createAlias('radio_stats_samples__radio_key__radios__public_key');

  $$RadiosTableProcessedTableManager get radioKey {
    final $_column = $_itemColumn<String>('radio_key')!;

    final manager = $$RadiosTableTableManager(
      $_db,
      $_db.radios,
    ).filter((f) => f.publicKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_radioKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RadioStatsSamplesTableFilterComposer
    extends Composer<_$MeshDatabase, $RadioStatsSamplesTable> {
  $$RadioStatsSamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get noiseFloor => $composableBuilder(
    column: $table.noiseFloor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastRssi => $composableBuilder(
    column: $table.lastRssi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastSnr => $composableBuilder(
    column: $table.lastSnr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get txAirSeconds => $composableBuilder(
    column: $table.txAirSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rxAirSeconds => $composableBuilder(
    column: $table.rxAirSeconds,
    builder: (column) => ColumnFilters(column),
  );

  $$RadiosTableFilterComposer get radioKey {
    final $$RadiosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableFilterComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RadioStatsSamplesTableOrderingComposer
    extends Composer<_$MeshDatabase, $RadioStatsSamplesTable> {
  $$RadioStatsSamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get noiseFloor => $composableBuilder(
    column: $table.noiseFloor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastRssi => $composableBuilder(
    column: $table.lastRssi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastSnr => $composableBuilder(
    column: $table.lastSnr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get txAirSeconds => $composableBuilder(
    column: $table.txAirSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rxAirSeconds => $composableBuilder(
    column: $table.rxAirSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  $$RadiosTableOrderingComposer get radioKey {
    final $$RadiosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableOrderingComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RadioStatsSamplesTableAnnotationComposer
    extends Composer<_$MeshDatabase, $RadioStatsSamplesTable> {
  $$RadioStatsSamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<int> get noiseFloor => $composableBuilder(
    column: $table.noiseFloor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastRssi =>
      $composableBuilder(column: $table.lastRssi, builder: (column) => column);

  GeneratedColumn<double> get lastSnr =>
      $composableBuilder(column: $table.lastSnr, builder: (column) => column);

  GeneratedColumn<int> get txAirSeconds => $composableBuilder(
    column: $table.txAirSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rxAirSeconds => $composableBuilder(
    column: $table.rxAirSeconds,
    builder: (column) => column,
  );

  $$RadiosTableAnnotationComposer get radioKey {
    final $$RadiosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.radioKey,
      referencedTable: $db.radios,
      getReferencedColumn: (t) => t.publicKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RadiosTableAnnotationComposer(
            $db: $db,
            $table: $db.radios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RadioStatsSamplesTableTableManager
    extends
        RootTableManager<
          _$MeshDatabase,
          $RadioStatsSamplesTable,
          RadioStatsSample,
          $$RadioStatsSamplesTableFilterComposer,
          $$RadioStatsSamplesTableOrderingComposer,
          $$RadioStatsSamplesTableAnnotationComposer,
          $$RadioStatsSamplesTableCreateCompanionBuilder,
          $$RadioStatsSamplesTableUpdateCompanionBuilder,
          (RadioStatsSample, $$RadioStatsSamplesTableReferences),
          RadioStatsSample,
          PrefetchHooks Function({bool radioKey})
        > {
  $$RadioStatsSamplesTableTableManager(
    _$MeshDatabase db,
    $RadioStatsSamplesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RadioStatsSamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RadioStatsSamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RadioStatsSamplesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> radioKey = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<int> noiseFloor = const Value.absent(),
                Value<int> lastRssi = const Value.absent(),
                Value<double> lastSnr = const Value.absent(),
                Value<int> txAirSeconds = const Value.absent(),
                Value<int> rxAirSeconds = const Value.absent(),
              }) => RadioStatsSamplesCompanion(
                id: id,
                radioKey: radioKey,
                at: at,
                noiseFloor: noiseFloor,
                lastRssi: lastRssi,
                lastSnr: lastSnr,
                txAirSeconds: txAirSeconds,
                rxAirSeconds: rxAirSeconds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String radioKey,
                required int at,
                required int noiseFloor,
                required int lastRssi,
                required double lastSnr,
                required int txAirSeconds,
                required int rxAirSeconds,
              }) => RadioStatsSamplesCompanion.insert(
                id: id,
                radioKey: radioKey,
                at: at,
                noiseFloor: noiseFloor,
                lastRssi: lastRssi,
                lastSnr: lastSnr,
                txAirSeconds: txAirSeconds,
                rxAirSeconds: rxAirSeconds,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RadioStatsSamplesTable, RadioStatsSample>(table),
                  $$RadioStatsSamplesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({radioKey = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (radioKey) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.radioKey,
                        referencedTable: $$RadioStatsSamplesTableReferences
                            ._radioKeyTable(db),
                        referencedColumn: $$RadioStatsSamplesTableReferences
                            ._radioKeyTable(db)
                            .publicKey,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RadioStatsSamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$MeshDatabase,
      $RadioStatsSamplesTable,
      RadioStatsSample,
      $$RadioStatsSamplesTableFilterComposer,
      $$RadioStatsSamplesTableOrderingComposer,
      $$RadioStatsSamplesTableAnnotationComposer,
      $$RadioStatsSamplesTableCreateCompanionBuilder,
      $$RadioStatsSamplesTableUpdateCompanionBuilder,
      (RadioStatsSample, $$RadioStatsSamplesTableReferences),
      RadioStatsSample,
      PrefetchHooks Function({bool radioKey})
    >;

class $MeshDatabaseManager {
  final _$MeshDatabase _db;
  $MeshDatabaseManager(this._db);
  $$RadiosTableTableManager get radios =>
      $$RadiosTableTableManager(_db, _db.radios);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db, _db.contacts);
  $$ChannelsTableTableManager get channels =>
      $$ChannelsTableTableManager(_db, _db.channels);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$ThreadStatesTableTableManager get threadStates =>
      $$ThreadStatesTableTableManager(_db, _db.threadStates);
  $$DiscoveredTableTableManager get discovered =>
      $$DiscoveredTableTableManager(_db, _db.discovered);
  $$TelemetrySamplesTableTableManager get telemetrySamples =>
      $$TelemetrySamplesTableTableManager(_db, _db.telemetrySamples);
  $$RadioStatsSamplesTableTableManager get radioStatsSamples =>
      $$RadioStatsSamplesTableTableManager(_db, _db.radioStatsSamples);
}
