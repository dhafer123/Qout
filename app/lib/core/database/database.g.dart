// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
mixin _$ProfileDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalProfileTable get localProfile => attachedDatabase.localProfile;
  ProfileDaoManager get managers => ProfileDaoManager(this);
}

class ProfileDaoManager {
  final _$ProfileDaoMixin _db;
  ProfileDaoManager(this._db);
  $$LocalProfileTableTableManager get localProfile =>
      $$LocalProfileTableTableManager(_db.attachedDatabase, _db.localProfile);
}

mixin _$ProductCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $CachedProductsTable get cachedProducts => attachedDatabase.cachedProducts;
  ProductCacheDaoManager get managers => ProductCacheDaoManager(this);
}

class ProductCacheDaoManager {
  final _$ProductCacheDaoMixin _db;
  ProductCacheDaoManager(this._db);
  $$CachedProductsTableTableManager get cachedProducts =>
      $$CachedProductsTableTableManager(
        _db.attachedDatabase,
        _db.cachedProducts,
      );
}

mixin _$ScanHistoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $ScanHistoryTable get scanHistory => attachedDatabase.scanHistory;
  $CachedProductsTable get cachedProducts => attachedDatabase.cachedProducts;
  ScanHistoryDaoManager get managers => ScanHistoryDaoManager(this);
}

class ScanHistoryDaoManager {
  final _$ScanHistoryDaoMixin _db;
  ScanHistoryDaoManager(this._db);
  $$ScanHistoryTableTableManager get scanHistory =>
      $$ScanHistoryTableTableManager(_db.attachedDatabase, _db.scanHistory);
  $$CachedProductsTableTableManager get cachedProducts =>
      $$CachedProductsTableTableManager(
        _db.attachedDatabase,
        _db.cachedProducts,
      );
}

mixin _$OutboxDaoMixin on DatabaseAccessor<AppDatabase> {
  $ContributionOutboxTable get contributionOutbox =>
      attachedDatabase.contributionOutbox;
  OutboxDaoManager get managers => OutboxDaoManager(this);
}

class OutboxDaoManager {
  final _$OutboxDaoMixin _db;
  OutboxDaoManager(this._db);
  $$ContributionOutboxTableTableManager get contributionOutbox =>
      $$ContributionOutboxTableTableManager(
        _db.attachedDatabase,
        _db.contributionOutbox,
      );
}

mixin _$DiaryDaoMixin on DatabaseAccessor<AppDatabase> {
  $DiaryEntriesTable get diaryEntries => attachedDatabase.diaryEntries;
  DiaryDaoManager get managers => DiaryDaoManager(this);
}

class DiaryDaoManager {
  final _$DiaryDaoMixin _db;
  DiaryDaoManager(this._db);
  $$DiaryEntriesTableTableManager get diaryEntries =>
      $$DiaryEntriesTableTableManager(_db.attachedDatabase, _db.diaryEntries);
}

mixin _$SettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AppSettingsTable get appSettings => attachedDatabase.appSettings;
  SettingsDaoManager get managers => SettingsDaoManager(this);
}

class SettingsDaoManager {
  final _$SettingsDaoMixin _db;
  SettingsDaoManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db.attachedDatabase, _db.appSettings);
}

class $CachedProductsTable extends CachedProducts
    with TableInfo<$CachedProductsTable, CachedProductRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eanMeta = const VerificationMeta('ean');
  @override
  late final GeneratedColumn<String> ean = GeneratedColumn<String>(
    'ean',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [ean, json, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_products';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedProductRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ean')) {
      context.handle(
        _eanMeta,
        ean.isAcceptableOrUnknown(data['ean']!, _eanMeta),
      );
    } else if (isInserting) {
      context.missing(_eanMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ean};
  @override
  CachedProductRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedProductRow(
      ean: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ean'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $CachedProductsTable createAlias(String alias) {
    return $CachedProductsTable(attachedDatabase, alias);
  }
}

class CachedProductRow extends DataClass
    implements Insertable<CachedProductRow> {
  /// The barcode as looked up (the API's EAN too, when different).
  final String ean;

  /// `ProductDetail.toJson()`, as JSON text.
  final String json;
  final DateTime fetchedAt;
  const CachedProductRow({
    required this.ean,
    required this.json,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ean'] = Variable<String>(ean);
    map['json'] = Variable<String>(json);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedProductsCompanion toCompanion(bool nullToAbsent) {
    return CachedProductsCompanion(
      ean: Value(ean),
      json: Value(json),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedProductRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedProductRow(
      ean: serializer.fromJson<String>(json['ean']),
      json: serializer.fromJson<String>(json['json']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ean': serializer.toJson<String>(ean),
      'json': serializer.toJson<String>(json),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedProductRow copyWith({String? ean, String? json, DateTime? fetchedAt}) =>
      CachedProductRow(
        ean: ean ?? this.ean,
        json: json ?? this.json,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  CachedProductRow copyWithCompanion(CachedProductsCompanion data) {
    return CachedProductRow(
      ean: data.ean.present ? data.ean.value : this.ean,
      json: data.json.present ? data.json.value : this.json,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedProductRow(')
          ..write('ean: $ean, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ean, json, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedProductRow &&
          other.ean == this.ean &&
          other.json == this.json &&
          other.fetchedAt == this.fetchedAt);
}

class CachedProductsCompanion extends UpdateCompanion<CachedProductRow> {
  final Value<String> ean;
  final Value<String> json;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CachedProductsCompanion({
    this.ean = const Value.absent(),
    this.json = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedProductsCompanion.insert({
    required String ean,
    required String json,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : ean = Value(ean),
       json = Value(json),
       fetchedAt = Value(fetchedAt);
  static Insertable<CachedProductRow> custom({
    Expression<String>? ean,
    Expression<String>? json,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ean != null) 'ean': ean,
      if (json != null) 'json': json,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedProductsCompanion copyWith({
    Value<String>? ean,
    Value<String>? json,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return CachedProductsCompanion(
      ean: ean ?? this.ean,
      json: json ?? this.json,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ean.present) {
      map['ean'] = Variable<String>(ean.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedProductsCompanion(')
          ..write('ean: $ean, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScanHistoryTable extends ScanHistory
    with TableInfo<$ScanHistoryTable, ScanHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanHistoryTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _eanMeta = const VerificationMeta('ean');
  @override
  late final GeneratedColumn<String> ean = GeneratedColumn<String>(
    'ean',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scannedAtMeta = const VerificationMeta(
    'scannedAt',
  );
  @override
  late final GeneratedColumn<DateTime> scannedAt = GeneratedColumn<DateTime>(
    'scanned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, ean, scannedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ean')) {
      context.handle(
        _eanMeta,
        ean.isAcceptableOrUnknown(data['ean']!, _eanMeta),
      );
    } else if (isInserting) {
      context.missing(_eanMeta);
    }
    if (data.containsKey('scanned_at')) {
      context.handle(
        _scannedAtMeta,
        scannedAt.isAcceptableOrUnknown(data['scanned_at']!, _scannedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_scannedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ean: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ean'],
      )!,
      scannedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scanned_at'],
      )!,
    );
  }

  @override
  $ScanHistoryTable createAlias(String alias) {
    return $ScanHistoryTable(attachedDatabase, alias);
  }
}

class ScanHistoryRow extends DataClass implements Insertable<ScanHistoryRow> {
  final int id;
  final String ean;
  final DateTime scannedAt;
  const ScanHistoryRow({
    required this.id,
    required this.ean,
    required this.scannedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ean'] = Variable<String>(ean);
    map['scanned_at'] = Variable<DateTime>(scannedAt);
    return map;
  }

  ScanHistoryCompanion toCompanion(bool nullToAbsent) {
    return ScanHistoryCompanion(
      id: Value(id),
      ean: Value(ean),
      scannedAt: Value(scannedAt),
    );
  }

  factory ScanHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanHistoryRow(
      id: serializer.fromJson<int>(json['id']),
      ean: serializer.fromJson<String>(json['ean']),
      scannedAt: serializer.fromJson<DateTime>(json['scannedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ean': serializer.toJson<String>(ean),
      'scannedAt': serializer.toJson<DateTime>(scannedAt),
    };
  }

  ScanHistoryRow copyWith({int? id, String? ean, DateTime? scannedAt}) =>
      ScanHistoryRow(
        id: id ?? this.id,
        ean: ean ?? this.ean,
        scannedAt: scannedAt ?? this.scannedAt,
      );
  ScanHistoryRow copyWithCompanion(ScanHistoryCompanion data) {
    return ScanHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      ean: data.ean.present ? data.ean.value : this.ean,
      scannedAt: data.scannedAt.present ? data.scannedAt.value : this.scannedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanHistoryRow(')
          ..write('id: $id, ')
          ..write('ean: $ean, ')
          ..write('scannedAt: $scannedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ean, scannedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanHistoryRow &&
          other.id == this.id &&
          other.ean == this.ean &&
          other.scannedAt == this.scannedAt);
}

class ScanHistoryCompanion extends UpdateCompanion<ScanHistoryRow> {
  final Value<int> id;
  final Value<String> ean;
  final Value<DateTime> scannedAt;
  const ScanHistoryCompanion({
    this.id = const Value.absent(),
    this.ean = const Value.absent(),
    this.scannedAt = const Value.absent(),
  });
  ScanHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String ean,
    required DateTime scannedAt,
  }) : ean = Value(ean),
       scannedAt = Value(scannedAt);
  static Insertable<ScanHistoryRow> custom({
    Expression<int>? id,
    Expression<String>? ean,
    Expression<DateTime>? scannedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ean != null) 'ean': ean,
      if (scannedAt != null) 'scanned_at': scannedAt,
    });
  }

  ScanHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? ean,
    Value<DateTime>? scannedAt,
  }) {
    return ScanHistoryCompanion(
      id: id ?? this.id,
      ean: ean ?? this.ean,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ean.present) {
      map['ean'] = Variable<String>(ean.value);
    }
    if (scannedAt.present) {
      map['scanned_at'] = Variable<DateTime>(scannedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanHistoryCompanion(')
          ..write('id: $id, ')
          ..write('ean: $ean, ')
          ..write('scannedAt: $scannedAt')
          ..write(')'))
        .toString();
  }
}

class $ContributionOutboxTable extends ContributionOutbox
    with TableInfo<$ContributionOutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContributionOutboxTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<OutboxState, String> state =
      GeneratedColumn<String>(
        'state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(OutboxState.waiting.name),
      ).withConverter<OutboxState>($ContributionOutboxTable.$converterstate);
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
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
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    clientId,
    payload,
    createdAt,
    state,
    nextAttemptAt,
    attempts,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contribution_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      state: $ContributionOutboxTable.$converterstate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}state'],
        )!,
      ),
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $ContributionOutboxTable createAlias(String alias) {
    return $ContributionOutboxTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OutboxState, String, String> $converterstate =
      const EnumNameConverter<OutboxState>(OutboxState.values);
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final int id;

  /// What the payload is (`new_product`, `error_report`); read by the sender.
  final String kind;

  /// The request's id, also in the payload: the backend stores a request
  /// sent twice once, and the app never queues it twice.
  final String clientId;

  /// The request to send, as JSON text.
  final String payload;
  final DateTime createdAt;
  final OutboxState state;

  /// Not sent before this time (UTC; backoff or the server's Retry-After).
  final DateTime? nextAttemptAt;
  final int attempts;

  /// Why the last attempt failed, in words for the user.
  final String? lastError;
  const OutboxRow({
    required this.id,
    required this.kind,
    required this.clientId,
    required this.payload,
    required this.createdAt,
    required this.state,
    this.nextAttemptAt,
    required this.attempts,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['client_id'] = Variable<String>(clientId);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    {
      map['state'] = Variable<String>(
        $ContributionOutboxTable.$converterstate.toSql(state),
      );
    }
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  ContributionOutboxCompanion toCompanion(bool nullToAbsent) {
    return ContributionOutboxCompanion(
      id: Value(id),
      kind: Value(kind),
      clientId: Value(clientId),
      payload: Value(payload),
      createdAt: Value(createdAt),
      state: Value(state),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      clientId: serializer.fromJson<String>(json['clientId']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      state: $ContributionOutboxTable.$converterstate.fromJson(
        serializer.fromJson<String>(json['state']),
      ),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'clientId': serializer.toJson<String>(clientId),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'state': serializer.toJson<String>(
        $ContributionOutboxTable.$converterstate.toJson(state),
      ),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OutboxRow copyWith({
    int? id,
    String? kind,
    String? clientId,
    String? payload,
    DateTime? createdAt,
    OutboxState? state,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    int? attempts,
    Value<String?> lastError = const Value.absent(),
  }) => OutboxRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    clientId: clientId ?? this.clientId,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    state: state ?? this.state,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  OutboxRow copyWithCompanion(ContributionOutboxCompanion data) {
    return OutboxRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      state: data.state.present ? data.state.value : this.state,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('clientId: $clientId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('state: $state, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    clientId,
    payload,
    createdAt,
    state,
    nextAttemptAt,
    attempts,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.clientId == this.clientId &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.state == this.state &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class ContributionOutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> clientId;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<OutboxState> state;
  final Value<DateTime?> nextAttemptAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  const ContributionOutboxCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.clientId = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.state = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  ContributionOutboxCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String clientId,
    required String payload,
    required DateTime createdAt,
    this.state = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : kind = Value(kind),
       clientId = Value(clientId),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<OutboxRow> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? clientId,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<String>? state,
    Expression<DateTime>? nextAttemptAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (clientId != null) 'client_id': clientId,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (state != null) 'state': state,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  ContributionOutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? clientId,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<OutboxState>? state,
    Value<DateTime?>? nextAttemptAt,
    Value<int>? attempts,
    Value<String?>? lastError,
  }) {
    return ContributionOutboxCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      clientId: clientId ?? this.clientId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      state: state ?? this.state,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(
        $ContributionOutboxTable.$converterstate.toSql(state.value),
      );
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContributionOutboxCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('clientId: $clientId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('state: $state, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $LocalProfileTable extends LocalProfile
    with TableInfo<$LocalProfileTable, LocalProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProfileTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _onboardingCompletedAtMeta =
      const VerificationMeta('onboardingCompletedAt');
  @override
  late final GeneratedColumn<DateTime> onboardingCompletedAt =
      GeneratedColumn<DateTime>(
        'onboarding_completed_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _sexMeta = const VerificationMeta('sex');
  @override
  late final GeneratedColumn<String> sex = GeneratedColumn<String>(
    'sex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
    'age',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ageEnteredAtMeta = const VerificationMeta(
    'ageEnteredAt',
  );
  @override
  late final GeneratedColumn<DateTime> ageEnteredAt = GeneratedColumn<DateTime>(
    'age_entered_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightCmMeta = const VerificationMeta(
    'heightCm',
  );
  @override
  late final GeneratedColumn<double> heightCm = GeneratedColumn<double>(
    'height_cm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _palMeta = const VerificationMeta('pal');
  @override
  late final GeneratedColumn<String> pal = GeneratedColumn<String>(
    'pal',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allergensMeta = const VerificationMeta(
    'allergens',
  );
  @override
  late final GeneratedColumn<String> allergens = GeneratedColumn<String>(
    'allergens',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _avoidedAdditivesMeta = const VerificationMeta(
    'avoidedAdditives',
  );
  @override
  late final GeneratedColumn<String> avoidedAdditives = GeneratedColumn<String>(
    'avoided_additives',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _firstNameMeta = const VerificationMeta(
    'firstName',
  );
  @override
  late final GeneratedColumn<String> firstName = GeneratedColumn<String>(
    'first_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    onboardingCompletedAt,
    sex,
    age,
    ageEnteredAt,
    heightCm,
    weightKg,
    pal,
    allergens,
    avoidedAdditives,
    firstName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_profile';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('onboarding_completed_at')) {
      context.handle(
        _onboardingCompletedAtMeta,
        onboardingCompletedAt.isAcceptableOrUnknown(
          data['onboarding_completed_at']!,
          _onboardingCompletedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_onboardingCompletedAtMeta);
    }
    if (data.containsKey('sex')) {
      context.handle(
        _sexMeta,
        sex.isAcceptableOrUnknown(data['sex']!, _sexMeta),
      );
    }
    if (data.containsKey('age')) {
      context.handle(
        _ageMeta,
        age.isAcceptableOrUnknown(data['age']!, _ageMeta),
      );
    }
    if (data.containsKey('age_entered_at')) {
      context.handle(
        _ageEnteredAtMeta,
        ageEnteredAt.isAcceptableOrUnknown(
          data['age_entered_at']!,
          _ageEnteredAtMeta,
        ),
      );
    }
    if (data.containsKey('height_cm')) {
      context.handle(
        _heightCmMeta,
        heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta),
      );
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    }
    if (data.containsKey('pal')) {
      context.handle(
        _palMeta,
        pal.isAcceptableOrUnknown(data['pal']!, _palMeta),
      );
    }
    if (data.containsKey('allergens')) {
      context.handle(
        _allergensMeta,
        allergens.isAcceptableOrUnknown(data['allergens']!, _allergensMeta),
      );
    }
    if (data.containsKey('avoided_additives')) {
      context.handle(
        _avoidedAdditivesMeta,
        avoidedAdditives.isAcceptableOrUnknown(
          data['avoided_additives']!,
          _avoidedAdditivesMeta,
        ),
      );
    }
    if (data.containsKey('first_name')) {
      context.handle(
        _firstNameMeta,
        firstName.isAcceptableOrUnknown(data['first_name']!, _firstNameMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      onboardingCompletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}onboarding_completed_at'],
      )!,
      sex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sex'],
      ),
      age: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age'],
      ),
      ageEnteredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}age_entered_at'],
      ),
      heightCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height_cm'],
      ),
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      ),
      pal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pal'],
      ),
      allergens: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}allergens'],
      )!,
      avoidedAdditives: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avoided_additives'],
      )!,
      firstName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_name'],
      ),
    );
  }

  @override
  $LocalProfileTable createAlias(String alias) {
    return $LocalProfileTable(attachedDatabase, alias);
  }
}

class LocalProfileRow extends DataClass implements Insertable<LocalProfileRow> {
  final int id;
  final DateTime onboardingCompletedAt;

  /// `male` or `female`; null: not given, or no profile.
  final String? sex;

  /// The age when entered, in whole years, and when: the age now is
  /// computed from both (`ageNow`).
  final int? age;
  final DateTime? ageEnteredAt;
  final double? heightCm;
  final double? weightKg;

  /// Physical activity level as written: `1.4`, `1.6`, `1.8`, `2.0`.
  final String? pal;

  /// Allergen keys (Annex II), as a JSON list.
  final String allergens;

  /// Additive codes to avoid (T40), as a JSON list.
  final String avoidedAdditives;

  /// For the greeting (T41); optional, trimmed, null when not given.
  final String? firstName;
  const LocalProfileRow({
    required this.id,
    required this.onboardingCompletedAt,
    this.sex,
    this.age,
    this.ageEnteredAt,
    this.heightCm,
    this.weightKg,
    this.pal,
    required this.allergens,
    required this.avoidedAdditives,
    this.firstName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['onboarding_completed_at'] = Variable<DateTime>(onboardingCompletedAt);
    if (!nullToAbsent || sex != null) {
      map['sex'] = Variable<String>(sex);
    }
    if (!nullToAbsent || age != null) {
      map['age'] = Variable<int>(age);
    }
    if (!nullToAbsent || ageEnteredAt != null) {
      map['age_entered_at'] = Variable<DateTime>(ageEnteredAt);
    }
    if (!nullToAbsent || heightCm != null) {
      map['height_cm'] = Variable<double>(heightCm);
    }
    if (!nullToAbsent || weightKg != null) {
      map['weight_kg'] = Variable<double>(weightKg);
    }
    if (!nullToAbsent || pal != null) {
      map['pal'] = Variable<String>(pal);
    }
    map['allergens'] = Variable<String>(allergens);
    map['avoided_additives'] = Variable<String>(avoidedAdditives);
    if (!nullToAbsent || firstName != null) {
      map['first_name'] = Variable<String>(firstName);
    }
    return map;
  }

  LocalProfileCompanion toCompanion(bool nullToAbsent) {
    return LocalProfileCompanion(
      id: Value(id),
      onboardingCompletedAt: Value(onboardingCompletedAt),
      sex: sex == null && nullToAbsent ? const Value.absent() : Value(sex),
      age: age == null && nullToAbsent ? const Value.absent() : Value(age),
      ageEnteredAt: ageEnteredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(ageEnteredAt),
      heightCm: heightCm == null && nullToAbsent
          ? const Value.absent()
          : Value(heightCm),
      weightKg: weightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(weightKg),
      pal: pal == null && nullToAbsent ? const Value.absent() : Value(pal),
      allergens: Value(allergens),
      avoidedAdditives: Value(avoidedAdditives),
      firstName: firstName == null && nullToAbsent
          ? const Value.absent()
          : Value(firstName),
    );
  }

  factory LocalProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProfileRow(
      id: serializer.fromJson<int>(json['id']),
      onboardingCompletedAt: serializer.fromJson<DateTime>(
        json['onboardingCompletedAt'],
      ),
      sex: serializer.fromJson<String?>(json['sex']),
      age: serializer.fromJson<int?>(json['age']),
      ageEnteredAt: serializer.fromJson<DateTime?>(json['ageEnteredAt']),
      heightCm: serializer.fromJson<double?>(json['heightCm']),
      weightKg: serializer.fromJson<double?>(json['weightKg']),
      pal: serializer.fromJson<String?>(json['pal']),
      allergens: serializer.fromJson<String>(json['allergens']),
      avoidedAdditives: serializer.fromJson<String>(json['avoidedAdditives']),
      firstName: serializer.fromJson<String?>(json['firstName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'onboardingCompletedAt': serializer.toJson<DateTime>(
        onboardingCompletedAt,
      ),
      'sex': serializer.toJson<String?>(sex),
      'age': serializer.toJson<int?>(age),
      'ageEnteredAt': serializer.toJson<DateTime?>(ageEnteredAt),
      'heightCm': serializer.toJson<double?>(heightCm),
      'weightKg': serializer.toJson<double?>(weightKg),
      'pal': serializer.toJson<String?>(pal),
      'allergens': serializer.toJson<String>(allergens),
      'avoidedAdditives': serializer.toJson<String>(avoidedAdditives),
      'firstName': serializer.toJson<String?>(firstName),
    };
  }

  LocalProfileRow copyWith({
    int? id,
    DateTime? onboardingCompletedAt,
    Value<String?> sex = const Value.absent(),
    Value<int?> age = const Value.absent(),
    Value<DateTime?> ageEnteredAt = const Value.absent(),
    Value<double?> heightCm = const Value.absent(),
    Value<double?> weightKg = const Value.absent(),
    Value<String?> pal = const Value.absent(),
    String? allergens,
    String? avoidedAdditives,
    Value<String?> firstName = const Value.absent(),
  }) => LocalProfileRow(
    id: id ?? this.id,
    onboardingCompletedAt: onboardingCompletedAt ?? this.onboardingCompletedAt,
    sex: sex.present ? sex.value : this.sex,
    age: age.present ? age.value : this.age,
    ageEnteredAt: ageEnteredAt.present ? ageEnteredAt.value : this.ageEnteredAt,
    heightCm: heightCm.present ? heightCm.value : this.heightCm,
    weightKg: weightKg.present ? weightKg.value : this.weightKg,
    pal: pal.present ? pal.value : this.pal,
    allergens: allergens ?? this.allergens,
    avoidedAdditives: avoidedAdditives ?? this.avoidedAdditives,
    firstName: firstName.present ? firstName.value : this.firstName,
  );
  LocalProfileRow copyWithCompanion(LocalProfileCompanion data) {
    return LocalProfileRow(
      id: data.id.present ? data.id.value : this.id,
      onboardingCompletedAt: data.onboardingCompletedAt.present
          ? data.onboardingCompletedAt.value
          : this.onboardingCompletedAt,
      sex: data.sex.present ? data.sex.value : this.sex,
      age: data.age.present ? data.age.value : this.age,
      ageEnteredAt: data.ageEnteredAt.present
          ? data.ageEnteredAt.value
          : this.ageEnteredAt,
      heightCm: data.heightCm.present ? data.heightCm.value : this.heightCm,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      pal: data.pal.present ? data.pal.value : this.pal,
      allergens: data.allergens.present ? data.allergens.value : this.allergens,
      avoidedAdditives: data.avoidedAdditives.present
          ? data.avoidedAdditives.value
          : this.avoidedAdditives,
      firstName: data.firstName.present ? data.firstName.value : this.firstName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfileRow(')
          ..write('id: $id, ')
          ..write('onboardingCompletedAt: $onboardingCompletedAt, ')
          ..write('sex: $sex, ')
          ..write('age: $age, ')
          ..write('ageEnteredAt: $ageEnteredAt, ')
          ..write('heightCm: $heightCm, ')
          ..write('weightKg: $weightKg, ')
          ..write('pal: $pal, ')
          ..write('allergens: $allergens, ')
          ..write('avoidedAdditives: $avoidedAdditives, ')
          ..write('firstName: $firstName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    onboardingCompletedAt,
    sex,
    age,
    ageEnteredAt,
    heightCm,
    weightKg,
    pal,
    allergens,
    avoidedAdditives,
    firstName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProfileRow &&
          other.id == this.id &&
          other.onboardingCompletedAt == this.onboardingCompletedAt &&
          other.sex == this.sex &&
          other.age == this.age &&
          other.ageEnteredAt == this.ageEnteredAt &&
          other.heightCm == this.heightCm &&
          other.weightKg == this.weightKg &&
          other.pal == this.pal &&
          other.allergens == this.allergens &&
          other.avoidedAdditives == this.avoidedAdditives &&
          other.firstName == this.firstName);
}

class LocalProfileCompanion extends UpdateCompanion<LocalProfileRow> {
  final Value<int> id;
  final Value<DateTime> onboardingCompletedAt;
  final Value<String?> sex;
  final Value<int?> age;
  final Value<DateTime?> ageEnteredAt;
  final Value<double?> heightCm;
  final Value<double?> weightKg;
  final Value<String?> pal;
  final Value<String> allergens;
  final Value<String> avoidedAdditives;
  final Value<String?> firstName;
  const LocalProfileCompanion({
    this.id = const Value.absent(),
    this.onboardingCompletedAt = const Value.absent(),
    this.sex = const Value.absent(),
    this.age = const Value.absent(),
    this.ageEnteredAt = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.pal = const Value.absent(),
    this.allergens = const Value.absent(),
    this.avoidedAdditives = const Value.absent(),
    this.firstName = const Value.absent(),
  });
  LocalProfileCompanion.insert({
    this.id = const Value.absent(),
    required DateTime onboardingCompletedAt,
    this.sex = const Value.absent(),
    this.age = const Value.absent(),
    this.ageEnteredAt = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.pal = const Value.absent(),
    this.allergens = const Value.absent(),
    this.avoidedAdditives = const Value.absent(),
    this.firstName = const Value.absent(),
  }) : onboardingCompletedAt = Value(onboardingCompletedAt);
  static Insertable<LocalProfileRow> custom({
    Expression<int>? id,
    Expression<DateTime>? onboardingCompletedAt,
    Expression<String>? sex,
    Expression<int>? age,
    Expression<DateTime>? ageEnteredAt,
    Expression<double>? heightCm,
    Expression<double>? weightKg,
    Expression<String>? pal,
    Expression<String>? allergens,
    Expression<String>? avoidedAdditives,
    Expression<String>? firstName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (onboardingCompletedAt != null)
        'onboarding_completed_at': onboardingCompletedAt,
      if (sex != null) 'sex': sex,
      if (age != null) 'age': age,
      if (ageEnteredAt != null) 'age_entered_at': ageEnteredAt,
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (pal != null) 'pal': pal,
      if (allergens != null) 'allergens': allergens,
      if (avoidedAdditives != null) 'avoided_additives': avoidedAdditives,
      if (firstName != null) 'first_name': firstName,
    });
  }

  LocalProfileCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? onboardingCompletedAt,
    Value<String?>? sex,
    Value<int?>? age,
    Value<DateTime?>? ageEnteredAt,
    Value<double?>? heightCm,
    Value<double?>? weightKg,
    Value<String?>? pal,
    Value<String>? allergens,
    Value<String>? avoidedAdditives,
    Value<String?>? firstName,
  }) {
    return LocalProfileCompanion(
      id: id ?? this.id,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      sex: sex ?? this.sex,
      age: age ?? this.age,
      ageEnteredAt: ageEnteredAt ?? this.ageEnteredAt,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      pal: pal ?? this.pal,
      allergens: allergens ?? this.allergens,
      avoidedAdditives: avoidedAdditives ?? this.avoidedAdditives,
      firstName: firstName ?? this.firstName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (onboardingCompletedAt.present) {
      map['onboarding_completed_at'] = Variable<DateTime>(
        onboardingCompletedAt.value,
      );
    }
    if (sex.present) {
      map['sex'] = Variable<String>(sex.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    if (ageEnteredAt.present) {
      map['age_entered_at'] = Variable<DateTime>(ageEnteredAt.value);
    }
    if (heightCm.present) {
      map['height_cm'] = Variable<double>(heightCm.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (pal.present) {
      map['pal'] = Variable<String>(pal.value);
    }
    if (allergens.present) {
      map['allergens'] = Variable<String>(allergens.value);
    }
    if (avoidedAdditives.present) {
      map['avoided_additives'] = Variable<String>(avoidedAdditives.value);
    }
    if (firstName.present) {
      map['first_name'] = Variable<String>(firstName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfileCompanion(')
          ..write('id: $id, ')
          ..write('onboardingCompletedAt: $onboardingCompletedAt, ')
          ..write('sex: $sex, ')
          ..write('age: $age, ')
          ..write('ageEnteredAt: $ageEnteredAt, ')
          ..write('heightCm: $heightCm, ')
          ..write('weightKg: $weightKg, ')
          ..write('pal: $pal, ')
          ..write('allergens: $allergens, ')
          ..write('avoidedAdditives: $avoidedAdditives, ')
          ..write('firstName: $firstName')
          ..write(')'))
        .toString();
  }
}

class $DiaryEntriesTable extends DiaryEntries
    with TableInfo<$DiaryEntriesTable, DiaryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiaryEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _eatenAtMeta = const VerificationMeta(
    'eatenAt',
  );
  @override
  late final GeneratedColumn<DateTime> eatenAt = GeneratedColumn<DateTime>(
    'eaten_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DiaryMeal, String> meal =
      GeneratedColumn<String>(
        'meal',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DiaryMeal>($DiaryEntriesTable.$convertermeal);
  static const VerificationMeta _eanMeta = const VerificationMeta('ean');
  @override
  late final GeneratedColumn<String> ean = GeneratedColumn<String>(
    'ean',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gradeMeta = const VerificationMeta('grade');
  @override
  late final GeneratedColumn<String> grade = GeneratedColumn<String>(
    'grade',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _novaGroupMeta = const VerificationMeta(
    'novaGroup',
  );
  @override
  late final GeneratedColumn<int> novaGroup = GeneratedColumn<int>(
    'nova_group',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _servingQuantityMeta = const VerificationMeta(
    'servingQuantity',
  );
  @override
  late final GeneratedColumn<double> servingQuantity = GeneratedColumn<double>(
    'serving_quantity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _energyKjMeta = const VerificationMeta(
    'energyKj',
  );
  @override
  late final GeneratedColumn<double> energyKj = GeneratedColumn<double>(
    'energy_kj',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fatGMeta = const VerificationMeta('fatG');
  @override
  late final GeneratedColumn<double> fatG = GeneratedColumn<double>(
    'fat_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _saturatesGMeta = const VerificationMeta(
    'saturatesG',
  );
  @override
  late final GeneratedColumn<double> saturatesG = GeneratedColumn<double>(
    'saturates_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sugarsGMeta = const VerificationMeta(
    'sugarsG',
  );
  @override
  late final GeneratedColumn<double> sugarsG = GeneratedColumn<double>(
    'sugars_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _saltGMeta = const VerificationMeta('saltG');
  @override
  late final GeneratedColumn<double> saltG = GeneratedColumn<double>(
    'salt_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eatenAt,
    meal,
    ean,
    name,
    brand,
    imageUrl,
    grade,
    novaGroup,
    unit,
    amount,
    servingQuantity,
    energyKj,
    fatG,
    saturatesG,
    sugarsG,
    saltG,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('eaten_at')) {
      context.handle(
        _eatenAtMeta,
        eatenAt.isAcceptableOrUnknown(data['eaten_at']!, _eatenAtMeta),
      );
    } else if (isInserting) {
      context.missing(_eatenAtMeta);
    }
    if (data.containsKey('ean')) {
      context.handle(
        _eanMeta,
        ean.isAcceptableOrUnknown(data['ean']!, _eanMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('grade')) {
      context.handle(
        _gradeMeta,
        grade.isAcceptableOrUnknown(data['grade']!, _gradeMeta),
      );
    }
    if (data.containsKey('nova_group')) {
      context.handle(
        _novaGroupMeta,
        novaGroup.isAcceptableOrUnknown(data['nova_group']!, _novaGroupMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    }
    if (data.containsKey('serving_quantity')) {
      context.handle(
        _servingQuantityMeta,
        servingQuantity.isAcceptableOrUnknown(
          data['serving_quantity']!,
          _servingQuantityMeta,
        ),
      );
    }
    if (data.containsKey('energy_kj')) {
      context.handle(
        _energyKjMeta,
        energyKj.isAcceptableOrUnknown(data['energy_kj']!, _energyKjMeta),
      );
    }
    if (data.containsKey('fat_g')) {
      context.handle(
        _fatGMeta,
        fatG.isAcceptableOrUnknown(data['fat_g']!, _fatGMeta),
      );
    }
    if (data.containsKey('saturates_g')) {
      context.handle(
        _saturatesGMeta,
        saturatesG.isAcceptableOrUnknown(data['saturates_g']!, _saturatesGMeta),
      );
    }
    if (data.containsKey('sugars_g')) {
      context.handle(
        _sugarsGMeta,
        sugarsG.isAcceptableOrUnknown(data['sugars_g']!, _sugarsGMeta),
      );
    }
    if (data.containsKey('salt_g')) {
      context.handle(
        _saltGMeta,
        saltG.isAcceptableOrUnknown(data['salt_g']!, _saltGMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiaryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      eatenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}eaten_at'],
      )!,
      meal: $DiaryEntriesTable.$convertermeal.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}meal'],
        )!,
      ),
      ean: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ean'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      ),
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      grade: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grade'],
      ),
      novaGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}nova_group'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      ),
      servingQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}serving_quantity'],
      ),
      energyKj: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}energy_kj'],
      ),
      fatG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fat_g'],
      ),
      saturatesG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}saturates_g'],
      ),
      sugarsG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sugars_g'],
      ),
      saltG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}salt_g'],
      ),
    );
  }

  @override
  $DiaryEntriesTable createAlias(String alias) {
    return $DiaryEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DiaryMeal, String, String> $convertermeal =
      const EnumNameConverter<DiaryMeal>(DiaryMeal.values);
}

class DiaryRow extends DataClass implements Insertable<DiaryRow> {
  final int id;

  /// The day (and time) it counts for, in UTC.
  final DateTime eatenAt;
  final DiaryMeal meal;

  /// Null for a quick add.
  final String? ean;
  final String? name;
  final String? brand;
  final String? imageUrl;

  /// Grade letter when logged (`A`..`E`); null: not graded or quick add.
  final String? grade;
  final int? novaGroup;

  /// `g` or `ml`; null for a quick add.
  final String? unit;

  /// Amount eaten in [unit]; null for a quick add.
  final double? amount;

  /// The label's serving in [unit], if it has one.
  final double? servingQuantity;

  /// Product: per 100 g/mL. Quick add: [energyKj] is what was eaten.
  final double? energyKj;
  final double? fatG;
  final double? saturatesG;
  final double? sugarsG;
  final double? saltG;
  const DiaryRow({
    required this.id,
    required this.eatenAt,
    required this.meal,
    this.ean,
    this.name,
    this.brand,
    this.imageUrl,
    this.grade,
    this.novaGroup,
    this.unit,
    this.amount,
    this.servingQuantity,
    this.energyKj,
    this.fatG,
    this.saturatesG,
    this.sugarsG,
    this.saltG,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['eaten_at'] = Variable<DateTime>(eatenAt);
    {
      map['meal'] = Variable<String>(
        $DiaryEntriesTable.$convertermeal.toSql(meal),
      );
    }
    if (!nullToAbsent || ean != null) {
      map['ean'] = Variable<String>(ean);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || grade != null) {
      map['grade'] = Variable<String>(grade);
    }
    if (!nullToAbsent || novaGroup != null) {
      map['nova_group'] = Variable<int>(novaGroup);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<double>(amount);
    }
    if (!nullToAbsent || servingQuantity != null) {
      map['serving_quantity'] = Variable<double>(servingQuantity);
    }
    if (!nullToAbsent || energyKj != null) {
      map['energy_kj'] = Variable<double>(energyKj);
    }
    if (!nullToAbsent || fatG != null) {
      map['fat_g'] = Variable<double>(fatG);
    }
    if (!nullToAbsent || saturatesG != null) {
      map['saturates_g'] = Variable<double>(saturatesG);
    }
    if (!nullToAbsent || sugarsG != null) {
      map['sugars_g'] = Variable<double>(sugarsG);
    }
    if (!nullToAbsent || saltG != null) {
      map['salt_g'] = Variable<double>(saltG);
    }
    return map;
  }

  DiaryEntriesCompanion toCompanion(bool nullToAbsent) {
    return DiaryEntriesCompanion(
      id: Value(id),
      eatenAt: Value(eatenAt),
      meal: Value(meal),
      ean: ean == null && nullToAbsent ? const Value.absent() : Value(ean),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      brand: brand == null && nullToAbsent
          ? const Value.absent()
          : Value(brand),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      grade: grade == null && nullToAbsent
          ? const Value.absent()
          : Value(grade),
      novaGroup: novaGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(novaGroup),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      amount: amount == null && nullToAbsent
          ? const Value.absent()
          : Value(amount),
      servingQuantity: servingQuantity == null && nullToAbsent
          ? const Value.absent()
          : Value(servingQuantity),
      energyKj: energyKj == null && nullToAbsent
          ? const Value.absent()
          : Value(energyKj),
      fatG: fatG == null && nullToAbsent ? const Value.absent() : Value(fatG),
      saturatesG: saturatesG == null && nullToAbsent
          ? const Value.absent()
          : Value(saturatesG),
      sugarsG: sugarsG == null && nullToAbsent
          ? const Value.absent()
          : Value(sugarsG),
      saltG: saltG == null && nullToAbsent
          ? const Value.absent()
          : Value(saltG),
    );
  }

  factory DiaryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryRow(
      id: serializer.fromJson<int>(json['id']),
      eatenAt: serializer.fromJson<DateTime>(json['eatenAt']),
      meal: $DiaryEntriesTable.$convertermeal.fromJson(
        serializer.fromJson<String>(json['meal']),
      ),
      ean: serializer.fromJson<String?>(json['ean']),
      name: serializer.fromJson<String?>(json['name']),
      brand: serializer.fromJson<String?>(json['brand']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      grade: serializer.fromJson<String?>(json['grade']),
      novaGroup: serializer.fromJson<int?>(json['novaGroup']),
      unit: serializer.fromJson<String?>(json['unit']),
      amount: serializer.fromJson<double?>(json['amount']),
      servingQuantity: serializer.fromJson<double?>(json['servingQuantity']),
      energyKj: serializer.fromJson<double?>(json['energyKj']),
      fatG: serializer.fromJson<double?>(json['fatG']),
      saturatesG: serializer.fromJson<double?>(json['saturatesG']),
      sugarsG: serializer.fromJson<double?>(json['sugarsG']),
      saltG: serializer.fromJson<double?>(json['saltG']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eatenAt': serializer.toJson<DateTime>(eatenAt),
      'meal': serializer.toJson<String>(
        $DiaryEntriesTable.$convertermeal.toJson(meal),
      ),
      'ean': serializer.toJson<String?>(ean),
      'name': serializer.toJson<String?>(name),
      'brand': serializer.toJson<String?>(brand),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'grade': serializer.toJson<String?>(grade),
      'novaGroup': serializer.toJson<int?>(novaGroup),
      'unit': serializer.toJson<String?>(unit),
      'amount': serializer.toJson<double?>(amount),
      'servingQuantity': serializer.toJson<double?>(servingQuantity),
      'energyKj': serializer.toJson<double?>(energyKj),
      'fatG': serializer.toJson<double?>(fatG),
      'saturatesG': serializer.toJson<double?>(saturatesG),
      'sugarsG': serializer.toJson<double?>(sugarsG),
      'saltG': serializer.toJson<double?>(saltG),
    };
  }

  DiaryRow copyWith({
    int? id,
    DateTime? eatenAt,
    DiaryMeal? meal,
    Value<String?> ean = const Value.absent(),
    Value<String?> name = const Value.absent(),
    Value<String?> brand = const Value.absent(),
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> grade = const Value.absent(),
    Value<int?> novaGroup = const Value.absent(),
    Value<String?> unit = const Value.absent(),
    Value<double?> amount = const Value.absent(),
    Value<double?> servingQuantity = const Value.absent(),
    Value<double?> energyKj = const Value.absent(),
    Value<double?> fatG = const Value.absent(),
    Value<double?> saturatesG = const Value.absent(),
    Value<double?> sugarsG = const Value.absent(),
    Value<double?> saltG = const Value.absent(),
  }) => DiaryRow(
    id: id ?? this.id,
    eatenAt: eatenAt ?? this.eatenAt,
    meal: meal ?? this.meal,
    ean: ean.present ? ean.value : this.ean,
    name: name.present ? name.value : this.name,
    brand: brand.present ? brand.value : this.brand,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    grade: grade.present ? grade.value : this.grade,
    novaGroup: novaGroup.present ? novaGroup.value : this.novaGroup,
    unit: unit.present ? unit.value : this.unit,
    amount: amount.present ? amount.value : this.amount,
    servingQuantity: servingQuantity.present
        ? servingQuantity.value
        : this.servingQuantity,
    energyKj: energyKj.present ? energyKj.value : this.energyKj,
    fatG: fatG.present ? fatG.value : this.fatG,
    saturatesG: saturatesG.present ? saturatesG.value : this.saturatesG,
    sugarsG: sugarsG.present ? sugarsG.value : this.sugarsG,
    saltG: saltG.present ? saltG.value : this.saltG,
  );
  DiaryRow copyWithCompanion(DiaryEntriesCompanion data) {
    return DiaryRow(
      id: data.id.present ? data.id.value : this.id,
      eatenAt: data.eatenAt.present ? data.eatenAt.value : this.eatenAt,
      meal: data.meal.present ? data.meal.value : this.meal,
      ean: data.ean.present ? data.ean.value : this.ean,
      name: data.name.present ? data.name.value : this.name,
      brand: data.brand.present ? data.brand.value : this.brand,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      grade: data.grade.present ? data.grade.value : this.grade,
      novaGroup: data.novaGroup.present ? data.novaGroup.value : this.novaGroup,
      unit: data.unit.present ? data.unit.value : this.unit,
      amount: data.amount.present ? data.amount.value : this.amount,
      servingQuantity: data.servingQuantity.present
          ? data.servingQuantity.value
          : this.servingQuantity,
      energyKj: data.energyKj.present ? data.energyKj.value : this.energyKj,
      fatG: data.fatG.present ? data.fatG.value : this.fatG,
      saturatesG: data.saturatesG.present
          ? data.saturatesG.value
          : this.saturatesG,
      sugarsG: data.sugarsG.present ? data.sugarsG.value : this.sugarsG,
      saltG: data.saltG.present ? data.saltG.value : this.saltG,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryRow(')
          ..write('id: $id, ')
          ..write('eatenAt: $eatenAt, ')
          ..write('meal: $meal, ')
          ..write('ean: $ean, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('grade: $grade, ')
          ..write('novaGroup: $novaGroup, ')
          ..write('unit: $unit, ')
          ..write('amount: $amount, ')
          ..write('servingQuantity: $servingQuantity, ')
          ..write('energyKj: $energyKj, ')
          ..write('fatG: $fatG, ')
          ..write('saturatesG: $saturatesG, ')
          ..write('sugarsG: $sugarsG, ')
          ..write('saltG: $saltG')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eatenAt,
    meal,
    ean,
    name,
    brand,
    imageUrl,
    grade,
    novaGroup,
    unit,
    amount,
    servingQuantity,
    energyKj,
    fatG,
    saturatesG,
    sugarsG,
    saltG,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryRow &&
          other.id == this.id &&
          other.eatenAt == this.eatenAt &&
          other.meal == this.meal &&
          other.ean == this.ean &&
          other.name == this.name &&
          other.brand == this.brand &&
          other.imageUrl == this.imageUrl &&
          other.grade == this.grade &&
          other.novaGroup == this.novaGroup &&
          other.unit == this.unit &&
          other.amount == this.amount &&
          other.servingQuantity == this.servingQuantity &&
          other.energyKj == this.energyKj &&
          other.fatG == this.fatG &&
          other.saturatesG == this.saturatesG &&
          other.sugarsG == this.sugarsG &&
          other.saltG == this.saltG);
}

class DiaryEntriesCompanion extends UpdateCompanion<DiaryRow> {
  final Value<int> id;
  final Value<DateTime> eatenAt;
  final Value<DiaryMeal> meal;
  final Value<String?> ean;
  final Value<String?> name;
  final Value<String?> brand;
  final Value<String?> imageUrl;
  final Value<String?> grade;
  final Value<int?> novaGroup;
  final Value<String?> unit;
  final Value<double?> amount;
  final Value<double?> servingQuantity;
  final Value<double?> energyKj;
  final Value<double?> fatG;
  final Value<double?> saturatesG;
  final Value<double?> sugarsG;
  final Value<double?> saltG;
  const DiaryEntriesCompanion({
    this.id = const Value.absent(),
    this.eatenAt = const Value.absent(),
    this.meal = const Value.absent(),
    this.ean = const Value.absent(),
    this.name = const Value.absent(),
    this.brand = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.grade = const Value.absent(),
    this.novaGroup = const Value.absent(),
    this.unit = const Value.absent(),
    this.amount = const Value.absent(),
    this.servingQuantity = const Value.absent(),
    this.energyKj = const Value.absent(),
    this.fatG = const Value.absent(),
    this.saturatesG = const Value.absent(),
    this.sugarsG = const Value.absent(),
    this.saltG = const Value.absent(),
  });
  DiaryEntriesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime eatenAt,
    required DiaryMeal meal,
    this.ean = const Value.absent(),
    this.name = const Value.absent(),
    this.brand = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.grade = const Value.absent(),
    this.novaGroup = const Value.absent(),
    this.unit = const Value.absent(),
    this.amount = const Value.absent(),
    this.servingQuantity = const Value.absent(),
    this.energyKj = const Value.absent(),
    this.fatG = const Value.absent(),
    this.saturatesG = const Value.absent(),
    this.sugarsG = const Value.absent(),
    this.saltG = const Value.absent(),
  }) : eatenAt = Value(eatenAt),
       meal = Value(meal);
  static Insertable<DiaryRow> custom({
    Expression<int>? id,
    Expression<DateTime>? eatenAt,
    Expression<String>? meal,
    Expression<String>? ean,
    Expression<String>? name,
    Expression<String>? brand,
    Expression<String>? imageUrl,
    Expression<String>? grade,
    Expression<int>? novaGroup,
    Expression<String>? unit,
    Expression<double>? amount,
    Expression<double>? servingQuantity,
    Expression<double>? energyKj,
    Expression<double>? fatG,
    Expression<double>? saturatesG,
    Expression<double>? sugarsG,
    Expression<double>? saltG,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eatenAt != null) 'eaten_at': eatenAt,
      if (meal != null) 'meal': meal,
      if (ean != null) 'ean': ean,
      if (name != null) 'name': name,
      if (brand != null) 'brand': brand,
      if (imageUrl != null) 'image_url': imageUrl,
      if (grade != null) 'grade': grade,
      if (novaGroup != null) 'nova_group': novaGroup,
      if (unit != null) 'unit': unit,
      if (amount != null) 'amount': amount,
      if (servingQuantity != null) 'serving_quantity': servingQuantity,
      if (energyKj != null) 'energy_kj': energyKj,
      if (fatG != null) 'fat_g': fatG,
      if (saturatesG != null) 'saturates_g': saturatesG,
      if (sugarsG != null) 'sugars_g': sugarsG,
      if (saltG != null) 'salt_g': saltG,
    });
  }

  DiaryEntriesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? eatenAt,
    Value<DiaryMeal>? meal,
    Value<String?>? ean,
    Value<String?>? name,
    Value<String?>? brand,
    Value<String?>? imageUrl,
    Value<String?>? grade,
    Value<int?>? novaGroup,
    Value<String?>? unit,
    Value<double?>? amount,
    Value<double?>? servingQuantity,
    Value<double?>? energyKj,
    Value<double?>? fatG,
    Value<double?>? saturatesG,
    Value<double?>? sugarsG,
    Value<double?>? saltG,
  }) {
    return DiaryEntriesCompanion(
      id: id ?? this.id,
      eatenAt: eatenAt ?? this.eatenAt,
      meal: meal ?? this.meal,
      ean: ean ?? this.ean,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      imageUrl: imageUrl ?? this.imageUrl,
      grade: grade ?? this.grade,
      novaGroup: novaGroup ?? this.novaGroup,
      unit: unit ?? this.unit,
      amount: amount ?? this.amount,
      servingQuantity: servingQuantity ?? this.servingQuantity,
      energyKj: energyKj ?? this.energyKj,
      fatG: fatG ?? this.fatG,
      saturatesG: saturatesG ?? this.saturatesG,
      sugarsG: sugarsG ?? this.sugarsG,
      saltG: saltG ?? this.saltG,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eatenAt.present) {
      map['eaten_at'] = Variable<DateTime>(eatenAt.value);
    }
    if (meal.present) {
      map['meal'] = Variable<String>(
        $DiaryEntriesTable.$convertermeal.toSql(meal.value),
      );
    }
    if (ean.present) {
      map['ean'] = Variable<String>(ean.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (grade.present) {
      map['grade'] = Variable<String>(grade.value);
    }
    if (novaGroup.present) {
      map['nova_group'] = Variable<int>(novaGroup.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (servingQuantity.present) {
      map['serving_quantity'] = Variable<double>(servingQuantity.value);
    }
    if (energyKj.present) {
      map['energy_kj'] = Variable<double>(energyKj.value);
    }
    if (fatG.present) {
      map['fat_g'] = Variable<double>(fatG.value);
    }
    if (saturatesG.present) {
      map['saturates_g'] = Variable<double>(saturatesG.value);
    }
    if (sugarsG.present) {
      map['sugars_g'] = Variable<double>(sugarsG.value);
    }
    if (saltG.present) {
      map['salt_g'] = Variable<double>(saltG.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('eatenAt: $eatenAt, ')
          ..write('meal: $meal, ')
          ..write('ean: $ean, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('grade: $grade, ')
          ..write('novaGroup: $novaGroup, ')
          ..write('unit: $unit, ')
          ..write('amount: $amount, ')
          ..write('servingQuantity: $servingQuantity, ')
          ..write('energyKj: $energyKj, ')
          ..write('fatG: $fatG, ')
          ..write('saturatesG: $saturatesG, ')
          ..write('sugarsG: $sugarsG, ')
          ..write('saltG: $saltG')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, themeMode];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingsRow extends DataClass implements Insertable<AppSettingsRow> {
  final int id;

  /// `system`, `light` or `dark`. Plain text, not an enum column, so a value
  /// this version doesn't know reads as the default instead of failing.
  final String themeMode;
  const AppSettingsRow({required this.id, required this.themeMode});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['theme_mode'] = Variable<String>(themeMode);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(id: Value(id), themeMode: Value(themeMode));
  }

  factory AppSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingsRow(
      id: serializer.fromJson<int>(json['id']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'themeMode': serializer.toJson<String>(themeMode),
    };
  }

  AppSettingsRow copyWith({int? id, String? themeMode}) =>
      AppSettingsRow(id: id ?? this.id, themeMode: themeMode ?? this.themeMode);
  AppSettingsRow copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingsRow(
      id: data.id.present ? data.id.value : this.id,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsRow(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, themeMode);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingsRow &&
          other.id == this.id &&
          other.themeMode == this.themeMode);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingsRow> {
  final Value<int> id;
  final Value<String> themeMode;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
  });
  static Insertable<AppSettingsRow> custom({
    Expression<int>? id,
    Expression<String>? themeMode,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (themeMode != null) 'theme_mode': themeMode,
    });
  }

  AppSettingsCompanion copyWith({Value<int>? id, Value<String>? themeMode}) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedProductsTable cachedProducts = $CachedProductsTable(this);
  late final $ScanHistoryTable scanHistory = $ScanHistoryTable(this);
  late final $ContributionOutboxTable contributionOutbox =
      $ContributionOutboxTable(this);
  late final $LocalProfileTable localProfile = $LocalProfileTable(this);
  late final $DiaryEntriesTable diaryEntries = $DiaryEntriesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final ProductCacheDao productCacheDao = ProductCacheDao(
    this as AppDatabase,
  );
  late final ScanHistoryDao scanHistoryDao = ScanHistoryDao(
    this as AppDatabase,
  );
  late final OutboxDao outboxDao = OutboxDao(this as AppDatabase);
  late final ProfileDao profileDao = ProfileDao(this as AppDatabase);
  late final DiaryDao diaryDao = DiaryDao(this as AppDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedProducts,
    scanHistory,
    contributionOutbox,
    localProfile,
    diaryEntries,
    appSettings,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$CachedProductsTableCreateCompanionBuilder =
    CachedProductsCompanion Function({
      required String ean,
      required String json,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$CachedProductsTableUpdateCompanionBuilder =
    CachedProductsCompanion Function({
      Value<String> ean,
      Value<String> json,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$CachedProductsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedProductsTable> {
  $$CachedProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ean => $composableBuilder(
    column: $table.ean,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedProductsTable> {
  $$CachedProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ean => $composableBuilder(
    column: $table.ean,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedProductsTable> {
  $$CachedProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ean =>
      $composableBuilder(column: $table.ean, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedProductsTable,
          CachedProductRow,
          $$CachedProductsTableFilterComposer,
          $$CachedProductsTableOrderingComposer,
          $$CachedProductsTableAnnotationComposer,
          $$CachedProductsTableCreateCompanionBuilder,
          $$CachedProductsTableUpdateCompanionBuilder,
          (
            CachedProductRow,
            BaseReferences<
              _$AppDatabase,
              $CachedProductsTable,
              CachedProductRow
            >,
          ),
          CachedProductRow,
          PrefetchHooks Function()
        > {
  $$CachedProductsTableTableManager(
    _$AppDatabase db,
    $CachedProductsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ean = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedProductsCompanion(
                ean: ean,
                json: json,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ean,
                required String json,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedProductsCompanion.insert(
                ean: ean,
                json: json,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedProductsTable,
      CachedProductRow,
      $$CachedProductsTableFilterComposer,
      $$CachedProductsTableOrderingComposer,
      $$CachedProductsTableAnnotationComposer,
      $$CachedProductsTableCreateCompanionBuilder,
      $$CachedProductsTableUpdateCompanionBuilder,
      (
        CachedProductRow,
        BaseReferences<_$AppDatabase, $CachedProductsTable, CachedProductRow>,
      ),
      CachedProductRow,
      PrefetchHooks Function()
    >;
typedef $$ScanHistoryTableCreateCompanionBuilder =
    ScanHistoryCompanion Function({
      Value<int> id,
      required String ean,
      required DateTime scannedAt,
    });
typedef $$ScanHistoryTableUpdateCompanionBuilder =
    ScanHistoryCompanion Function({
      Value<int> id,
      Value<String> ean,
      Value<DateTime> scannedAt,
    });

class $$ScanHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $ScanHistoryTable> {
  $$ScanHistoryTableFilterComposer({
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

  ColumnFilters<String> get ean => $composableBuilder(
    column: $table.ean,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanHistoryTable> {
  $$ScanHistoryTableOrderingComposer({
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

  ColumnOrderings<String> get ean => $composableBuilder(
    column: $table.ean,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanHistoryTable> {
  $$ScanHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ean =>
      $composableBuilder(column: $table.ean, builder: (column) => column);

  GeneratedColumn<DateTime> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => column);
}

class $$ScanHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScanHistoryTable,
          ScanHistoryRow,
          $$ScanHistoryTableFilterComposer,
          $$ScanHistoryTableOrderingComposer,
          $$ScanHistoryTableAnnotationComposer,
          $$ScanHistoryTableCreateCompanionBuilder,
          $$ScanHistoryTableUpdateCompanionBuilder,
          (
            ScanHistoryRow,
            BaseReferences<_$AppDatabase, $ScanHistoryTable, ScanHistoryRow>,
          ),
          ScanHistoryRow,
          PrefetchHooks Function()
        > {
  $$ScanHistoryTableTableManager(_$AppDatabase db, $ScanHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> ean = const Value.absent(),
                Value<DateTime> scannedAt = const Value.absent(),
              }) =>
                  ScanHistoryCompanion(id: id, ean: ean, scannedAt: scannedAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String ean,
                required DateTime scannedAt,
              }) => ScanHistoryCompanion.insert(
                id: id,
                ean: ean,
                scannedAt: scannedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScanHistoryTable,
      ScanHistoryRow,
      $$ScanHistoryTableFilterComposer,
      $$ScanHistoryTableOrderingComposer,
      $$ScanHistoryTableAnnotationComposer,
      $$ScanHistoryTableCreateCompanionBuilder,
      $$ScanHistoryTableUpdateCompanionBuilder,
      (
        ScanHistoryRow,
        BaseReferences<_$AppDatabase, $ScanHistoryTable, ScanHistoryRow>,
      ),
      ScanHistoryRow,
      PrefetchHooks Function()
    >;
typedef $$ContributionOutboxTableCreateCompanionBuilder =
    ContributionOutboxCompanion Function({
      Value<int> id,
      required String kind,
      required String clientId,
      required String payload,
      required DateTime createdAt,
      Value<OutboxState> state,
      Value<DateTime?> nextAttemptAt,
      Value<int> attempts,
      Value<String?> lastError,
    });
typedef $$ContributionOutboxTableUpdateCompanionBuilder =
    ContributionOutboxCompanion Function({
      Value<int> id,
      Value<String> kind,
      Value<String> clientId,
      Value<String> payload,
      Value<DateTime> createdAt,
      Value<OutboxState> state,
      Value<DateTime?> nextAttemptAt,
      Value<int> attempts,
      Value<String?> lastError,
    });

class $$ContributionOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $ContributionOutboxTable> {
  $$ContributionOutboxTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OutboxState, OutboxState, String> get state =>
      $composableBuilder(
        column: $table.state,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContributionOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $ContributionOutboxTable> {
  $$ContributionOutboxTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContributionOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContributionOutboxTable> {
  $$ContributionOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OutboxState, String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$ContributionOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContributionOutboxTable,
          OutboxRow,
          $$ContributionOutboxTableFilterComposer,
          $$ContributionOutboxTableOrderingComposer,
          $$ContributionOutboxTableAnnotationComposer,
          $$ContributionOutboxTableCreateCompanionBuilder,
          $$ContributionOutboxTableUpdateCompanionBuilder,
          (
            OutboxRow,
            BaseReferences<_$AppDatabase, $ContributionOutboxTable, OutboxRow>,
          ),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$ContributionOutboxTableTableManager(
    _$AppDatabase db,
    $ContributionOutboxTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContributionOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContributionOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContributionOutboxTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<OutboxState> state = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => ContributionOutboxCompanion(
                id: id,
                kind: kind,
                clientId: clientId,
                payload: payload,
                createdAt: createdAt,
                state: state,
                nextAttemptAt: nextAttemptAt,
                attempts: attempts,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                required String clientId,
                required String payload,
                required DateTime createdAt,
                Value<OutboxState> state = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => ContributionOutboxCompanion.insert(
                id: id,
                kind: kind,
                clientId: clientId,
                payload: payload,
                createdAt: createdAt,
                state: state,
                nextAttemptAt: nextAttemptAt,
                attempts: attempts,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContributionOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContributionOutboxTable,
      OutboxRow,
      $$ContributionOutboxTableFilterComposer,
      $$ContributionOutboxTableOrderingComposer,
      $$ContributionOutboxTableAnnotationComposer,
      $$ContributionOutboxTableCreateCompanionBuilder,
      $$ContributionOutboxTableUpdateCompanionBuilder,
      (
        OutboxRow,
        BaseReferences<_$AppDatabase, $ContributionOutboxTable, OutboxRow>,
      ),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$LocalProfileTableCreateCompanionBuilder =
    LocalProfileCompanion Function({
      Value<int> id,
      required DateTime onboardingCompletedAt,
      Value<String?> sex,
      Value<int?> age,
      Value<DateTime?> ageEnteredAt,
      Value<double?> heightCm,
      Value<double?> weightKg,
      Value<String?> pal,
      Value<String> allergens,
      Value<String> avoidedAdditives,
      Value<String?> firstName,
    });
typedef $$LocalProfileTableUpdateCompanionBuilder =
    LocalProfileCompanion Function({
      Value<int> id,
      Value<DateTime> onboardingCompletedAt,
      Value<String?> sex,
      Value<int?> age,
      Value<DateTime?> ageEnteredAt,
      Value<double?> heightCm,
      Value<double?> weightKg,
      Value<String?> pal,
      Value<String> allergens,
      Value<String> avoidedAdditives,
      Value<String?> firstName,
    });

class $$LocalProfileTableFilterComposer
    extends Composer<_$AppDatabase, $LocalProfileTable> {
  $$LocalProfileTableFilterComposer({
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

  ColumnFilters<DateTime> get onboardingCompletedAt => $composableBuilder(
    column: $table.onboardingCompletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ageEnteredAt => $composableBuilder(
    column: $table.ageEnteredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pal => $composableBuilder(
    column: $table.pal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get allergens => $composableBuilder(
    column: $table.allergens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avoidedAdditives => $composableBuilder(
    column: $table.avoidedAdditives,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProfileTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalProfileTable> {
  $$LocalProfileTableOrderingComposer({
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

  ColumnOrderings<DateTime> get onboardingCompletedAt => $composableBuilder(
    column: $table.onboardingCompletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ageEnteredAt => $composableBuilder(
    column: $table.ageEnteredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pal => $composableBuilder(
    column: $table.pal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get allergens => $composableBuilder(
    column: $table.allergens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avoidedAdditives => $composableBuilder(
    column: $table.avoidedAdditives,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProfileTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalProfileTable> {
  $$LocalProfileTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get onboardingCompletedAt => $composableBuilder(
    column: $table.onboardingCompletedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<int> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);

  GeneratedColumn<DateTime> get ageEnteredAt => $composableBuilder(
    column: $table.ageEnteredAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get heightCm =>
      $composableBuilder(column: $table.heightCm, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<String> get pal =>
      $composableBuilder(column: $table.pal, builder: (column) => column);

  GeneratedColumn<String> get allergens =>
      $composableBuilder(column: $table.allergens, builder: (column) => column);

  GeneratedColumn<String> get avoidedAdditives => $composableBuilder(
    column: $table.avoidedAdditives,
    builder: (column) => column,
  );

  GeneratedColumn<String> get firstName =>
      $composableBuilder(column: $table.firstName, builder: (column) => column);
}

class $$LocalProfileTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalProfileTable,
          LocalProfileRow,
          $$LocalProfileTableFilterComposer,
          $$LocalProfileTableOrderingComposer,
          $$LocalProfileTableAnnotationComposer,
          $$LocalProfileTableCreateCompanionBuilder,
          $$LocalProfileTableUpdateCompanionBuilder,
          (
            LocalProfileRow,
            BaseReferences<_$AppDatabase, $LocalProfileTable, LocalProfileRow>,
          ),
          LocalProfileRow,
          PrefetchHooks Function()
        > {
  $$LocalProfileTableTableManager(_$AppDatabase db, $LocalProfileTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProfileTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalProfileTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalProfileTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> onboardingCompletedAt = const Value.absent(),
                Value<String?> sex = const Value.absent(),
                Value<int?> age = const Value.absent(),
                Value<DateTime?> ageEnteredAt = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<String?> pal = const Value.absent(),
                Value<String> allergens = const Value.absent(),
                Value<String> avoidedAdditives = const Value.absent(),
                Value<String?> firstName = const Value.absent(),
              }) => LocalProfileCompanion(
                id: id,
                onboardingCompletedAt: onboardingCompletedAt,
                sex: sex,
                age: age,
                ageEnteredAt: ageEnteredAt,
                heightCm: heightCm,
                weightKg: weightKg,
                pal: pal,
                allergens: allergens,
                avoidedAdditives: avoidedAdditives,
                firstName: firstName,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime onboardingCompletedAt,
                Value<String?> sex = const Value.absent(),
                Value<int?> age = const Value.absent(),
                Value<DateTime?> ageEnteredAt = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<String?> pal = const Value.absent(),
                Value<String> allergens = const Value.absent(),
                Value<String> avoidedAdditives = const Value.absent(),
                Value<String?> firstName = const Value.absent(),
              }) => LocalProfileCompanion.insert(
                id: id,
                onboardingCompletedAt: onboardingCompletedAt,
                sex: sex,
                age: age,
                ageEnteredAt: ageEnteredAt,
                heightCm: heightCm,
                weightKg: weightKg,
                pal: pal,
                allergens: allergens,
                avoidedAdditives: avoidedAdditives,
                firstName: firstName,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProfileTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalProfileTable,
      LocalProfileRow,
      $$LocalProfileTableFilterComposer,
      $$LocalProfileTableOrderingComposer,
      $$LocalProfileTableAnnotationComposer,
      $$LocalProfileTableCreateCompanionBuilder,
      $$LocalProfileTableUpdateCompanionBuilder,
      (
        LocalProfileRow,
        BaseReferences<_$AppDatabase, $LocalProfileTable, LocalProfileRow>,
      ),
      LocalProfileRow,
      PrefetchHooks Function()
    >;
typedef $$DiaryEntriesTableCreateCompanionBuilder =
    DiaryEntriesCompanion Function({
      Value<int> id,
      required DateTime eatenAt,
      required DiaryMeal meal,
      Value<String?> ean,
      Value<String?> name,
      Value<String?> brand,
      Value<String?> imageUrl,
      Value<String?> grade,
      Value<int?> novaGroup,
      Value<String?> unit,
      Value<double?> amount,
      Value<double?> servingQuantity,
      Value<double?> energyKj,
      Value<double?> fatG,
      Value<double?> saturatesG,
      Value<double?> sugarsG,
      Value<double?> saltG,
    });
typedef $$DiaryEntriesTableUpdateCompanionBuilder =
    DiaryEntriesCompanion Function({
      Value<int> id,
      Value<DateTime> eatenAt,
      Value<DiaryMeal> meal,
      Value<String?> ean,
      Value<String?> name,
      Value<String?> brand,
      Value<String?> imageUrl,
      Value<String?> grade,
      Value<int?> novaGroup,
      Value<String?> unit,
      Value<double?> amount,
      Value<double?> servingQuantity,
      Value<double?> energyKj,
      Value<double?> fatG,
      Value<double?> saturatesG,
      Value<double?> sugarsG,
      Value<double?> saltG,
    });

class $$DiaryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DiaryEntriesTable> {
  $$DiaryEntriesTableFilterComposer({
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

  ColumnFilters<DateTime> get eatenAt => $composableBuilder(
    column: $table.eatenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DiaryMeal, DiaryMeal, String> get meal =>
      $composableBuilder(
        column: $table.meal,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get ean => $composableBuilder(
    column: $table.ean,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get novaGroup => $composableBuilder(
    column: $table.novaGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get servingQuantity => $composableBuilder(
    column: $table.servingQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get energyKj => $composableBuilder(
    column: $table.energyKj,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fatG => $composableBuilder(
    column: $table.fatG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get saturatesG => $composableBuilder(
    column: $table.saturatesG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sugarsG => $composableBuilder(
    column: $table.sugarsG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get saltG => $composableBuilder(
    column: $table.saltG,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiaryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DiaryEntriesTable> {
  $$DiaryEntriesTableOrderingComposer({
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

  ColumnOrderings<DateTime> get eatenAt => $composableBuilder(
    column: $table.eatenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meal => $composableBuilder(
    column: $table.meal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ean => $composableBuilder(
    column: $table.ean,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get novaGroup => $composableBuilder(
    column: $table.novaGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get servingQuantity => $composableBuilder(
    column: $table.servingQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get energyKj => $composableBuilder(
    column: $table.energyKj,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fatG => $composableBuilder(
    column: $table.fatG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get saturatesG => $composableBuilder(
    column: $table.saturatesG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sugarsG => $composableBuilder(
    column: $table.sugarsG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get saltG => $composableBuilder(
    column: $table.saltG,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiaryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiaryEntriesTable> {
  $$DiaryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get eatenAt =>
      $composableBuilder(column: $table.eatenAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DiaryMeal, String> get meal =>
      $composableBuilder(column: $table.meal, builder: (column) => column);

  GeneratedColumn<String> get ean =>
      $composableBuilder(column: $table.ean, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get grade =>
      $composableBuilder(column: $table.grade, builder: (column) => column);

  GeneratedColumn<int> get novaGroup =>
      $composableBuilder(column: $table.novaGroup, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<double> get servingQuantity => $composableBuilder(
    column: $table.servingQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<double> get energyKj =>
      $composableBuilder(column: $table.energyKj, builder: (column) => column);

  GeneratedColumn<double> get fatG =>
      $composableBuilder(column: $table.fatG, builder: (column) => column);

  GeneratedColumn<double> get saturatesG => $composableBuilder(
    column: $table.saturatesG,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sugarsG =>
      $composableBuilder(column: $table.sugarsG, builder: (column) => column);

  GeneratedColumn<double> get saltG =>
      $composableBuilder(column: $table.saltG, builder: (column) => column);
}

class $$DiaryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiaryEntriesTable,
          DiaryRow,
          $$DiaryEntriesTableFilterComposer,
          $$DiaryEntriesTableOrderingComposer,
          $$DiaryEntriesTableAnnotationComposer,
          $$DiaryEntriesTableCreateCompanionBuilder,
          $$DiaryEntriesTableUpdateCompanionBuilder,
          (
            DiaryRow,
            BaseReferences<_$AppDatabase, $DiaryEntriesTable, DiaryRow>,
          ),
          DiaryRow,
          PrefetchHooks Function()
        > {
  $$DiaryEntriesTableTableManager(_$AppDatabase db, $DiaryEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiaryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiaryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiaryEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> eatenAt = const Value.absent(),
                Value<DiaryMeal> meal = const Value.absent(),
                Value<String?> ean = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> brand = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> grade = const Value.absent(),
                Value<int?> novaGroup = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<double?> amount = const Value.absent(),
                Value<double?> servingQuantity = const Value.absent(),
                Value<double?> energyKj = const Value.absent(),
                Value<double?> fatG = const Value.absent(),
                Value<double?> saturatesG = const Value.absent(),
                Value<double?> sugarsG = const Value.absent(),
                Value<double?> saltG = const Value.absent(),
              }) => DiaryEntriesCompanion(
                id: id,
                eatenAt: eatenAt,
                meal: meal,
                ean: ean,
                name: name,
                brand: brand,
                imageUrl: imageUrl,
                grade: grade,
                novaGroup: novaGroup,
                unit: unit,
                amount: amount,
                servingQuantity: servingQuantity,
                energyKj: energyKj,
                fatG: fatG,
                saturatesG: saturatesG,
                sugarsG: sugarsG,
                saltG: saltG,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime eatenAt,
                required DiaryMeal meal,
                Value<String?> ean = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> brand = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> grade = const Value.absent(),
                Value<int?> novaGroup = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<double?> amount = const Value.absent(),
                Value<double?> servingQuantity = const Value.absent(),
                Value<double?> energyKj = const Value.absent(),
                Value<double?> fatG = const Value.absent(),
                Value<double?> saturatesG = const Value.absent(),
                Value<double?> sugarsG = const Value.absent(),
                Value<double?> saltG = const Value.absent(),
              }) => DiaryEntriesCompanion.insert(
                id: id,
                eatenAt: eatenAt,
                meal: meal,
                ean: ean,
                name: name,
                brand: brand,
                imageUrl: imageUrl,
                grade: grade,
                novaGroup: novaGroup,
                unit: unit,
                amount: amount,
                servingQuantity: servingQuantity,
                energyKj: energyKj,
                fatG: fatG,
                saturatesG: saturatesG,
                sugarsG: sugarsG,
                saltG: saltG,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiaryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiaryEntriesTable,
      DiaryRow,
      $$DiaryEntriesTableFilterComposer,
      $$DiaryEntriesTableOrderingComposer,
      $$DiaryEntriesTableAnnotationComposer,
      $$DiaryEntriesTableCreateCompanionBuilder,
      $$DiaryEntriesTableUpdateCompanionBuilder,
      (DiaryRow, BaseReferences<_$AppDatabase, $DiaryEntriesTable, DiaryRow>),
      DiaryRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({Value<int> id, Value<String> themeMode});
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({Value<int> id, Value<String> themeMode});

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
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

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
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

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSettingsRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSettingsRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingsRow>,
          ),
          AppSettingsRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
              }) => AppSettingsCompanion(id: id, themeMode: themeMode),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
              }) => AppSettingsCompanion.insert(id: id, themeMode: themeMode),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSettingsRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSettingsRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingsRow>,
      ),
      AppSettingsRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedProductsTableTableManager get cachedProducts =>
      $$CachedProductsTableTableManager(_db, _db.cachedProducts);
  $$ScanHistoryTableTableManager get scanHistory =>
      $$ScanHistoryTableTableManager(_db, _db.scanHistory);
  $$ContributionOutboxTableTableManager get contributionOutbox =>
      $$ContributionOutboxTableTableManager(_db, _db.contributionOutbox);
  $$LocalProfileTableTableManager get localProfile =>
      $$LocalProfileTableTableManager(_db, _db.localProfile);
  $$DiaryEntriesTableTableManager get diaryEntries =>
      $$DiaryEntriesTableTableManager(_db, _db.diaryEntries);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
