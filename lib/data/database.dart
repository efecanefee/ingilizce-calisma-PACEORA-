import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Kullanıcı profili (tek satır kullanılır).
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// DifficultyLevel.code — A2, B1-, B1, B1+, B2-, B2, B2+, C1
  TextColumn get level => text()();
  IntColumn get dailyMinutes => integer()();
  IntColumn get streak => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastStudyDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Haftalık ders programı — her satır bir gün.
class WeeklyPlanDays extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Haftanın pazartesi tarihi (gün 00:00)
  DateTimeColumn get weekStart => dateTime()();

  /// 0 = Pazartesi ... 6 = Pazar
  IntColumn get dayIndex => integer()();

  /// Günün dilbilgisi konusu (ör. "Present Perfect vs Past Simple")
  TextColumn get grammarTopic => text()();

  /// Günün kelime teması (ör. "Seyahat ve ulaşım")
  TextColumn get vocabTheme => text()();

  /// pending | completed | skipped
  TextColumn get status => text().withDefault(const Constant('pending'))();
}

/// Tamamlanan / üretilen günlük dersler.
class Lessons extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Dersin ait olduğu gün (00:00)
  DateTimeColumn get lessonDate => dateTime()();

  /// Gemini'nin ürettiği ders içeriği (JSON) — günlük önbellek.
  TextColumn get contentJson => text()();

  /// 0-100 arası skor; null = henüz bitmedi.
  RealColumn get score => real().nullable()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Hata takibi: yanlış yapılan kelime/kalıplar.
class Mistakes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Hatalı kelime veya kalıp (ör. "make a decision")
  TextColumn get item => text()();

  /// Hatanın geçtiği cümle/bağlam
  TextColumn get context => text()();

  /// translation | grammar | vocabulary | chat
  TextColumn get type => text()();
  IntColumn get timesWrong => integer().withDefault(const Constant(1))();
  IntColumn get timesCorrect => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAskedAt => dateTime().nullable()();

  /// 3+ kez doğru yapılınca çözülmüş sayılır.
  BoolColumn get resolved => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Flash kartlar (SM-2 aralıklı tekrar).
class Flashcards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get word => text()();
  TextColumn get meaning => text()();
  TextColumn get exampleSentence => text()();

  /// new_word | mistake
  TextColumn get source => text()();

  // SM-2 alanları
  RealColumn get ease => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Günün hikayeleri ve test sonuçları.
class Stories extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get storyDate => dateTime()();
  TextColumn get title => text()();

  /// Hikaye metni + sorular (JSON)
  TextColumn get contentJson => text()();

  /// Test skoru 0-100; null = çözülmedi.
  RealColumn get quizScore => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Haftalık değerlendirme raporları.
class WeeklyReviews extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get weekStart => dateTime()();

  /// Gemini raporu (JSON)
  TextColumn get reportJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [
    UserProfiles,
    WeeklyPlanDays,
    Lessons,
    Mistakes,
    Flashcards,
    Stories,
    WeeklyReviews,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  /// Şema sürümü. Bir tabloya sütun/tablo eklerken:
  /// 1. Bu sayıyı bir artır.
  /// 2. [migration] içindeki `onUpgrade`'e `from < yeniSürüm` adımını ekle.
  /// 3. `test/database_migration_test.dart`'a eski sürümden göç testi ekle.
  /// Adım atlanırsa güncelleme alan kullanıcıların uygulaması açılışta çöker.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Sürüm adımları buraya, sırayla eklenir. Örnek:
      // if (from < 2) await m.addColumn(lessons, lessons.yeniSutun);
    },
    beforeOpen: (details) async {
      if (details.hadUpgrade) {
        debugPrint(
          'Veritabanı ${details.versionBefore} → ${details.versionNow} '
          'sürümüne güncellendi',
        );
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'paceora',
      // Web'de sqlite3 WebAssembly olarak yüklenir; iki dosya da web/ altında.
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
