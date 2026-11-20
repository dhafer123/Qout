import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Products as the API last returned them (`ProductDetail` JSON), so a
/// product seen once is available offline.
@DataClassName('CachedProductRow')
class CachedProducts extends Table {
  /// The barcode as looked up (the API's EAN too, when different).
  TextColumn get ean => text()();

  /// `ProductDetail.toJson()`, as JSON text.
  TextColumn get json => text()();

  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {ean};
}

/// Barcodes the user scanned (recorded by the scanner, listed on the home
/// screen).
@DataClassName('ScanHistoryRow')
class ScanHistory extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get ean => text()();

  DateTimeColumn get scannedAt => dateTime()();
}

/// Where an outbox entry stands.
enum OutboxState {
  /// Sent at the next sync once [ContributionOutbox.nextAttemptAt] has
  /// passed (or at once when it is null).
  waiting,

  /// The server wants a signed-in user: sent again after signing in.
  needsSignIn,

  /// The server refused it (e.g. invalid values): never retried; the user
  /// deletes it.
  refused,
}

/// What the app sends when it can: new products (T29) and error reports
/// (T20), oldest first (T30).
@DataClassName('OutboxRow')
class ContributionOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// What the payload is (`new_product`, `error_report`); read by the sender.
  TextColumn get kind => text()();

  /// The request's id, also in the payload: the backend stores a request
  /// sent twice once, and the app never queues it twice.
  TextColumn get clientId => text().unique()();

  /// The request to send, as JSON text.
  TextColumn get payload => text()();

  DateTimeColumn get createdAt => dateTime()();

  TextColumn get state => textEnum<OutboxState>().withDefault(
    Constant(OutboxState.waiting.name),
  )();

  /// Not sent before this time (UTC; backoff or the server's Retry-After).
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Why the last attempt failed, in words for the user.
  TextColumn get lastError => text().nullable()();
}

/// The user's profile (T39): one row, id 1, created when onboarding is
/// finished (skipped or not). Stays on the phone, never sent anywhere.
/// Profile fields are all set (age, height, weight, PAL) or all null; sex
/// may be null within a set profile ("not given").
@DataClassName('LocalProfileRow')
class LocalProfile extends Table {
  IntColumn get id => integer()();

  DateTimeColumn get onboardingCompletedAt => dateTime()();

  /// `male` or `female`; null: not given, or no profile.
  TextColumn get sex => text().nullable()();

  /// The age when entered, in whole years, and when: the age now is
  /// computed from both (`ageNow`).
  IntColumn get age => integer().nullable()();
  DateTimeColumn get ageEnteredAt => dateTime().nullable()();

  RealColumn get heightCm => real().nullable()();
  RealColumn get weightKg => real().nullable()();

  /// Physical activity level as written: `1.4`, `1.6`, `1.8`, `2.0`.
  TextColumn get pal => text().nullable()();

  /// Allergen keys (Annex II), as a JSON list.
  TextColumn get allergens => text().withDefault(const Constant('[]'))();

  /// Additive codes to avoid (T40), as a JSON list.
  TextColumn get avoidedAdditives => text().withDefault(const Constant('[]'))();

  /// For the greeting (T41); optional, trimmed, null when not given.
  TextColumn get firstName => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftAccessor(tables: [LocalProfile])
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.attachedDatabase);

  static const _id = 1;

  Future<LocalProfileRow?> get() => (select(
    localProfile,
  )..where((t) => t.id.equals(_id))).getSingleOrNull();

  Stream<LocalProfileRow?> watch() => (select(
    localProfile,
  )..where((t) => t.id.equals(_id))).watchSingleOrNull();

  /// Marks onboarding as finished; keeps an existing row as it is.
  Future<void> completeOnboarding(DateTime at) => into(localProfile).insert(
    LocalProfileCompanion.insert(
      id: const Value(_id),
      onboardingCompletedAt: at,
    ),
    mode: InsertMode.insertOrIgnore,
  );

  /// Saves the profile (also finishing onboarding, at [now], if needed).
  Future<void> saveProfile({
    required String? sex,
    required int age,
    required DateTime ageEnteredAt,
    required double heightCm,
    required double weightKg,
    required String pal,
    required String allergens,
    required DateTime now,
  }) => transaction(() async {
    await completeOnboarding(now);
    await (update(localProfile)..where((t) => t.id.equals(_id))).write(
      LocalProfileCompanion(
        sex: Value(sex),
        age: Value(age),
        ageEnteredAt: Value(ageEnteredAt),
        heightCm: Value(heightCm),
        weightKg: Value(weightKg),
        pal: Value(pal),
        allergens: Value(allergens),
      ),
    );
  });

  /// Replaces the additives to avoid ([codes]: a JSON list), finishing
  /// onboarding at [now] if needed (the row must exist).
  Future<void> saveAvoidedAdditives(String codes, {required DateTime now}) =>
      transaction(() async {
        await completeOnboarding(now);
        await (update(localProfile)..where((t) => t.id.equals(_id))).write(
          LocalProfileCompanion(avoidedAdditives: Value(codes)),
        );
      });

  /// Saves the first name (null: none), finishing onboarding if needed.
  Future<void> saveFirstName(String? name, {required DateTime now}) =>
      transaction(() async {
        await completeOnboarding(now);
        await (update(localProfile)..where((t) => t.id.equals(_id))).write(
          LocalProfileCompanion(firstName: Value(name)),
        );
      });

  /// Deletes everything personal; onboarding stays finished.
  Future<void> clearProfile() =>
      (update(localProfile)..where((t) => t.id.equals(_id))).write(
        const LocalProfileCompanion(
          firstName: Value(null),
          sex: Value(null),
          age: Value(null),
          ageEnteredAt: Value(null),
          heightCm: Value(null),
          weightKg: Value(null),
          pal: Value(null),
          allergens: Value('[]'),
          avoidedAdditives: Value('[]'),
        ),
      );
}

@DriftAccessor(tables: [CachedProducts])
class ProductCacheDao extends DatabaseAccessor<AppDatabase>
    with _$ProductCacheDaoMixin {
  ProductCacheDao(super.attachedDatabase);

  Future<CachedProductRow?> find(String ean) => (select(
    cachedProducts,
  )..where((t) => t.ean.equals(ean))).getSingleOrNull();

  /// Stores [json] under every barcode in [eans], replacing older entries.
  Future<void> save(
    Iterable<String> eans, {
    required String json,
    required DateTime fetchedAt,
  }) => batch((batch) {
    batch.insertAllOnConflictUpdate(cachedProducts, [
      for (final ean in eans.toSet())
        CachedProductsCompanion.insert(
          ean: ean,
          json: json,
          fetchedAt: fetchedAt,
        ),
    ]);
  });

  Future<void> remove(Iterable<String> eans) => (delete(
    cachedProducts,
  )..where((t) => t.ean.isIn(eans.toSet()))).go();
}

@DriftAccessor(tables: [ScanHistory, CachedProducts])
class ScanHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$ScanHistoryDaoMixin {
  ScanHistoryDao(super.attachedDatabase);

  /// Stored in UTC: the list is ordered by the stored text, which must not mix
  /// UTC offsets (e.g. across a daylight-saving change).
  Future<int> add(String ean, {required DateTime scannedAt}) =>
      into(scanHistory).insert(
        ScanHistoryCompanion.insert(ean: ean, scannedAt: scannedAt.toUtc()),
      );

  /// A scan of [ean], replacing any earlier entry for it: the history lists
  /// each product once, at its latest scan.
  Future<int> record(String ean, {required DateTime scannedAt}) =>
      transaction(() async {
        await (delete(scanHistory)..where((t) => t.ean.equals(ean))).go();
        return add(ean, scannedAt: scannedAt);
      });

  /// Newest first, each with the cached product for its barcode (null if not
  /// cached); updates as scans or cached products change.
  Stream<List<(ScanHistoryRow, CachedProductRow?)>> watchRecentWithProducts({
    int limit = 100,
  }) {
    final query =
        select(scanHistory).join([
            leftOuterJoin(
              cachedProducts,
              cachedProducts.ean.equalsExp(scanHistory.ean),
            ),
          ])
          ..orderBy([
            OrderingTerm.desc(scanHistory.scannedAt),
            OrderingTerm.desc(scanHistory.id),
          ])
          ..limit(limit);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          (row.readTable(scanHistory), row.readTableOrNull(cachedProducts)),
      ],
    );
  }

  /// Newest first; updates as scans are added or deleted.
  Stream<List<ScanHistoryRow>> watchRecent({int limit = 100}) =>
      (select(scanHistory)
            ..orderBy([
              (t) => OrderingTerm.desc(t.scannedAt),
              (t) => OrderingTerm.desc(t.id),
            ])
            ..limit(limit))
          .watch();

  Future<void> remove(int id) =>
      (delete(scanHistory)..where((t) => t.id.equals(id))).go();

  Future<void> clear() => delete(scanHistory).go();
}

@DriftAccessor(tables: [ContributionOutbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.attachedDatabase);

  /// Queues a request; false when [clientId] is already queued (unchanged).
  Future<bool> enqueue({
    required String kind,
    required String clientId,
    required String payload,
    required DateTime createdAt,
  }) async {
    final row = await into(contributionOutbox).insertReturningOrNull(
      ContributionOutboxCompanion.insert(
        kind: kind,
        clientId: clientId,
        payload: payload,
        createdAt: createdAt.toUtc(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    return row != null;
  }

  Future<OutboxRow?> find(String clientId) => (select(
    contributionOutbox,
  )..where((t) => t.clientId.equals(clientId))).getSingleOrNull();

  /// Waiting entries whose time has come at [now], oldest first.
  Future<List<OutboxRow>> due(DateTime now) =>
      (select(contributionOutbox)
            ..where(
              (t) =>
                  t.state.equalsValue(OutboxState.waiting) &
                  (t.nextAttemptAt.isNull() |
                      t.nextAttemptAt.isSmallerOrEqualValue(now.toUtc())),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  /// The earliest retry time of the waiting entries, or null when none waits
  /// for one.
  Future<DateTime?> nextAttempt() async {
    final rows =
        await (select(contributionOutbox)
              ..where(
                (t) =>
                    t.state.equalsValue(OutboxState.waiting) &
                    t.nextAttemptAt.isNotNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.nextAttemptAt)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.single.nextAttemptAt;
  }

  /// Every entry, oldest first.
  Future<List<OutboxRow>> all() => (select(
    contributionOutbox,
  )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  /// Every entry, oldest first; updates as entries change.
  Stream<List<OutboxRow>> watchAll() => (select(
    contributionOutbox,
  )..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();

  /// Saves progress (e.g. photos uploaded so far).
  Future<void> updatePayload(int id, String payload) =>
      (update(contributionOutbox)..where((t) => t.id.equals(id))).write(
        ContributionOutboxCompanion(payload: Value(payload)),
      );

  /// A failed attempt to try again at [nextAttemptAt].
  Future<void> recordRetry(
    int id, {
    required String error,
    required DateTime nextAttemptAt,
  }) => _fail(id, OutboxState.waiting, error, nextAttemptAt.toUtc());

  Future<void> recordNeedsSignIn(int id, String error) =>
      _fail(id, OutboxState.needsSignIn, error, null);

  Future<void> recordRefused(int id, String error) =>
      _fail(id, OutboxState.refused, error, null);

  Future<void> _fail(
    int id,
    OutboxState state,
    String error,
    DateTime? nextAttemptAt,
  ) => (update(contributionOutbox)..where((t) => t.id.equals(id))).write(
    ContributionOutboxCompanion.custom(
      state: Variable(state.name),
      nextAttemptAt: Variable(nextAttemptAt),
      attempts: contributionOutbox.attempts + const Constant(1),
      lastError: Variable(error),
    ),
  );

  /// Sends [id] at the next sync ("Try now"), unless it was refused.
  Future<void> retryNow(int id) =>
      (update(contributionOutbox)..where(
            (t) =>
                t.id.equals(id) &
                t.state.equalsValue(OutboxState.refused).not(),
          ))
          .write(
            const ContributionOutboxCompanion(
              state: Value(OutboxState.waiting),
              nextAttemptAt: Value(null),
            ),
          );

  /// After signing in: the entries that needed it wait again, due at once.
  Future<void> resumeAfterSignIn() =>
      (update(
        contributionOutbox,
      )..where((t) => t.state.equalsValue(OutboxState.needsSignIn))).write(
        const ContributionOutboxCompanion(
          state: Value(OutboxState.waiting),
          nextAttemptAt: Value(null),
        ),
      );

  Future<void> remove(int id) =>
      (delete(contributionOutbox)..where((t) => t.id.equals(id))).go();
}

/// The meals of the food diary (T42), as stored.
enum DiaryMeal { breakfast, lunch, snack, dinner }

/// The food diary (T42): one row per thing eaten, on the phone only. A
/// product keeps a copy of its label's values per 100 g/mL and the amount
/// eaten; a quick add has no barcode or amount, only its energy.
@DataClassName('DiaryRow')
class DiaryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The day (and time) it counts for, in UTC.
  DateTimeColumn get eatenAt => dateTime()();

  TextColumn get meal => textEnum<DiaryMeal>()();

  /// Null for a quick add.
  TextColumn get ean => text().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get brand => text().nullable()();
  TextColumn get imageUrl => text().nullable()();

  /// Grade letter when logged (`A`..`E`); null: not graded or quick add.
  TextColumn get grade => text().nullable()();
  IntColumn get novaGroup => integer().nullable()();

  /// `g` or `ml`; null for a quick add.
  TextColumn get unit => text().nullable()();

  /// Amount eaten in [unit]; null for a quick add.
  RealColumn get amount => real().nullable()();

  /// The label's serving in [unit], if it has one.
  RealColumn get servingQuantity => real().nullable()();

  /// Product: per 100 g/mL. Quick add: [energyKj] is what was eaten.
  RealColumn get energyKj => real().nullable()();
  RealColumn get fatG => real().nullable()();
  RealColumn get saturatesG => real().nullable()();
  RealColumn get sugarsG => real().nullable()();
  RealColumn get saltG => real().nullable()();
}

@DriftAccessor(tables: [DiaryEntries])
class DiaryDao extends DatabaseAccessor<AppDatabase> with _$DiaryDaoMixin {
  DiaryDao(super.attachedDatabase);

  Future<int> add(DiaryEntriesCompanion entry) =>
      into(diaryEntries).insert(entry);

  /// Puts a removed row back with its id.
  Future<void> restore(DiaryRow row) =>
      into(diaryEntries).insert(row, mode: InsertMode.insertOrReplace);

  Future<void> change(
    int id, {
    required DateTime eatenAt,
    required DiaryMeal meal,
    required double? amount,
  }) => (update(diaryEntries)..where((t) => t.id.equals(id))).write(
    DiaryEntriesCompanion(
      eatenAt: Value(eatenAt.toUtc()),
      meal: Value(meal),
      amount: Value(amount),
    ),
  );

  Future<void> remove(int id) =>
      (delete(diaryEntries)..where((t) => t.id.equals(id))).go();

  Future<void> clear() => delete(diaryEntries).go();

  /// Rows with [from] <= eatenAt < [to], in the order they were logged.
  Stream<List<DiaryRow>> watchBetween(DateTime from, DateTime to) =>
      (select(diaryEntries)
            ..where(
              (t) =>
                  t.eatenAt.isBiggerOrEqualValue(from.toUtc()) &
                  t.eatenAt.isSmallerThanValue(to.toUtc()),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.eatenAt)]))
          .watch();

  Future<List<DiaryRow>> between(DateTime from, DateTime to) =>
      watchBetween(from, to).first;
}

@DriftDatabase(
  tables: [
    CachedProducts,
    ScanHistory,
    ContributionOutbox,
    LocalProfile,
    DiaryEntries,
  ],
  daos: [ProductCacheDao, ScanHistoryDao, OutboxDao, ProfileDao, DiaryDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The app's database file (`qout.sqlite` in the app's documents folder).
  AppDatabase.open() : this(driftDatabase(name: 'qout'));

  /// Bump with every schema change, add a step to [migration], and keep the
  /// old schema in `test/fixtures/database/schema_v<n>.sql` for its test
  /// (`make-migrations` needs a newer drift_dev than this SDK resolves).
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // T30: the outbox gets its client id (from the payload, where the
        // error reports queued since T20 have it), state and retry time.
        await m.alterTable(
          TableMigration(
            contributionOutbox,
            columnTransformer: {
              contributionOutbox.clientId: const CustomExpression<String>(
                r"coalesce(json_extract(payload, '$.client_id'), "
                "'outbox-' || id)",
              ),
            },
            newColumns: [
              contributionOutbox.clientId,
              contributionOutbox.state,
              contributionOutbox.nextAttemptAt,
            ],
          ),
        );
      }
      if (from < 3) {
        // T39: the profile. No row yet, so people updating the app see the
        // welcome screens once too.
        await m.createTable(localProfile);
      }
      // A table created above already has the column.
      if (from >= 3 && from < 4) {
        // T41: the first name for the greeting.
        await m.addColumn(localProfile, localProfile.firstName);
      }
      if (from < 5) {
        // T42: the food diary.
        await m.createTable(diaryEntries);
      }
    },
  );
}
