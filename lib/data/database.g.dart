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
    ackCode,
    flooded,
    pathLength,
    snr,
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

  /// Outgoing direct messages: the code the delivery ack will carry.
  final int? ackCode;
  final bool? flooded;
  final int? pathLength;
  final double? snr;

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
    this.ackCode,
    this.flooded,
    this.pathLength,
    this.snr,
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
      ackCode: serializer.fromJson<int?>(json['ackCode']),
      flooded: serializer.fromJson<bool?>(json['flooded']),
      pathLength: serializer.fromJson<int?>(json['pathLength']),
      snr: serializer.fromJson<double?>(json['snr']),
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
      'ackCode': serializer.toJson<int?>(ackCode),
      'flooded': serializer.toJson<bool?>(flooded),
      'pathLength': serializer.toJson<int?>(pathLength),
      'snr': serializer.toJson<double?>(snr),
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
    Value<int?> ackCode = const Value.absent(),
    Value<bool?> flooded = const Value.absent(),
    Value<int?> pathLength = const Value.absent(),
    Value<double?> snr = const Value.absent(),
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
    ackCode: ackCode.present ? ackCode.value : this.ackCode,
    flooded: flooded.present ? flooded.value : this.flooded,
    pathLength: pathLength.present ? pathLength.value : this.pathLength,
    snr: snr.present ? snr.value : this.snr,
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
      ackCode: data.ackCode.present ? data.ackCode.value : this.ackCode,
      flooded: data.flooded.present ? data.flooded.value : this.flooded,
      pathLength: data.pathLength.present
          ? data.pathLength.value
          : this.pathLength,
      snr: data.snr.present ? data.snr.value : this.snr,
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
          ..write('ackCode: $ackCode, ')
          ..write('flooded: $flooded, ')
          ..write('pathLength: $pathLength, ')
          ..write('snr: $snr, ')
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
    ackCode,
    flooded,
    pathLength,
    snr,
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
          other.ackCode == this.ackCode &&
          other.flooded == this.flooded &&
          other.pathLength == this.pathLength &&
          other.snr == this.snr &&
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
  final Value<int?> ackCode;
  final Value<bool?> flooded;
  final Value<int?> pathLength;
  final Value<double?> snr;
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
    this.ackCode = const Value.absent(),
    this.flooded = const Value.absent(),
    this.pathLength = const Value.absent(),
    this.snr = const Value.absent(),
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
    this.ackCode = const Value.absent(),
    this.flooded = const Value.absent(),
    this.pathLength = const Value.absent(),
    this.snr = const Value.absent(),
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
    Expression<int>? ackCode,
    Expression<bool>? flooded,
    Expression<int>? pathLength,
    Expression<double>? snr,
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
      if (ackCode != null) 'ack_code': ackCode,
      if (flooded != null) 'flooded': flooded,
      if (pathLength != null) 'path_length': pathLength,
      if (snr != null) 'snr': snr,
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
    Value<int?>? ackCode,
    Value<bool?>? flooded,
    Value<int?>? pathLength,
    Value<double?>? snr,
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
      ackCode: ackCode ?? this.ackCode,
      flooded: flooded ?? this.flooded,
      pathLength: pathLength ?? this.pathLength,
      snr: snr ?? this.snr,
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
          ..write('ackCode: $ackCode, ')
          ..write('flooded: $flooded, ')
          ..write('pathLength: $pathLength, ')
          ..write('snr: $snr, ')
          ..write('dedupeKey: $dedupeKey')
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
  late final Index messagesByThread = Index(
    'messages_by_thread',
    'CREATE INDEX messages_by_thread ON messages (radio_key, thread, id)',
  );
  late final Index messagesByAck = Index(
    'messages_by_ack',
    'CREATE INDEX messages_by_ack ON messages (radio_key, ack_code)',
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
    messagesByThread,
    messagesByAck,
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
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (contactsRefs) db.contacts,
                    if (channelsRefs) db.channels,
                    if (messagesRefs) db.messages,
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
  Value<int?> ackCode,
  Value<bool?> flooded,
  Value<int?> pathLength,
  Value<double?> snr,
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
  Value<int?> ackCode,
  Value<bool?> flooded,
  Value<int?> pathLength,
  Value<double?> snr,
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
                Value<int?> ackCode = const Value.absent(),
                Value<bool?> flooded = const Value.absent(),
                Value<int?> pathLength = const Value.absent(),
                Value<double?> snr = const Value.absent(),
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
                ackCode: ackCode,
                flooded: flooded,
                pathLength: pathLength,
                snr: snr,
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
                Value<int?> ackCode = const Value.absent(),
                Value<bool?> flooded = const Value.absent(),
                Value<int?> pathLength = const Value.absent(),
                Value<double?> snr = const Value.absent(),
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
                ackCode: ackCode,
                flooded: flooded,
                pathLength: pathLength,
                snr: snr,
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
}
