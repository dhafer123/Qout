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

/// Contributions waiting to be sent to the backend (T23 to T26).
@DataClassName('OutboxRow')
class ContributionOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// What the payload is, e.g. `new_product`; read by the sender.
  TextColumn get kind => text()();

  /// The request to send, as JSON text.
  TextColumn get payload => text()();

  DateTimeColumn get createdAt => dateTime()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();
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

  Future<int> enqueue({
    required String kind,
    required String payload,
    required DateTime createdAt,
  }) => into(contributionOutbox).insert(
    ContributionOutboxCompanion.insert(
      kind: kind,
      payload: payload,
      createdAt: createdAt,
    ),
  );

  /// Oldest first.
  Future<List<OutboxRow>> pending() => (select(
    contributionOutbox,
  )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  Future<void> recordFailure(int id, String error) =>
      (update(contributionOutbox)..where((t) => t.id.equals(id))).write(
        ContributionOutboxCompanion.custom(
          attempts: contributionOutbox.attempts + const Constant(1),
          lastError: Variable(error),
        ),
      );

  Future<void> remove(int id) =>
      (delete(contributionOutbox)..where((t) => t.id.equals(id))).go();
}

@DriftDatabase(
  tables: [CachedProducts, ScanHistory, ContributionOutbox],
  daos: [ProductCacheDao, ScanHistoryDao, OutboxDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The app's database file (`qout.sqlite` in the app's documents folder).
  AppDatabase.open() : this(driftDatabase(name: 'qout'));

  /// Bump with every schema change, and add a migration step plus a schema
  /// dump (`dart run drift_dev make-migrations`).
  @override
  int get schemaVersion => 1;
}
