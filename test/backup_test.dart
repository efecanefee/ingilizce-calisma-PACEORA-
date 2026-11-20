import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/backup.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('yedek alınıp başka cihaza geri yüklenince her şey aynı', () async {
    // Eski cihaz.
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'accent_color': 'ocean',
      'streak_freezes': 2,
      'seen_badges': ['first_lesson'],
    });
    final oldPrefs = await SharedPreferences.getInstance();
    final oldDb = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(oldDb.close);
    final repo = Repository(oldDb);
    await repo.saveProfile(name: 'Yağız', level: 'B2', dailyMinutes: 30);
    await repo.replaceWeeklyPlan(DateTime(2026, 11, 20), [
      for (var i = 0; i < 7; i++)
        PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
    ]);
    final json = await Backup.export(oldDb, oldPrefs);

    // Yeni cihaz: farklı verilerle başlıyor; geri yükleme hepsinin yerini alır.
    SharedPreferences.setMockInitialValues({'accent_color': 'rose'});
    final newPrefs = await SharedPreferences.getInstance();
    final newDb = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(newDb.close);
    await Repository(newDb)
        .saveProfile(name: 'Başka', level: 'A2', dailyMinutes: 5);

    await Backup.restore(json, newDb, newPrefs);

    final profile = (await newDb.select(newDb.userProfiles).get()).single;
    expect(profile.name, 'Yağız');
    expect(profile.level, 'B2');
    expect(await newDb.select(newDb.weeklyPlanDays).get(), hasLength(7));
    expect(newPrefs.getString('accent_color'), 'ocean');
    expect(newPrefs.getInt('streak_freezes'), 2);
    expect(newPrefs.getStringList('seen_badges'), ['first_lesson']);
    expect(newPrefs.getBool('onboarding_done'), isTrue);
  });

  test('Paceora yedeği olmayan dosya reddedilir, veriye dokunulmaz', () async {
    SharedPreferences.setMockInitialValues({'accent_color': 'rose'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await Repository(db).saveProfile(name: 'A', level: 'B1', dailyMinutes: 10);

    for (final bad in ['bozuk', '{"format":"baska"}', '[]']) {
      await expectLater(
        Backup.restore(bad, db, prefs),
        throwsA(isA<FormatException>()),
      );
    }
    await expectLater(
      Backup.restore(
        '{"format":"paceora-yedek","schemaVersion":999,"tables":{}}',
        db,
        prefs,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(await db.select(db.userProfiles).get(), hasLength(1));
    expect(prefs.getString('accent_color'), 'rose');
  });

  test('dosya adı tarihli', () {
    expect(
      Backup.fileName(DateTime(2026, 3, 7)),
      'paceora-yedek-2026-03-07.json',
    );
  });
}
