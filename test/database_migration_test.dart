import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';

/// Şema güvencesi: yeni kurulumda tüm tablolar oluşur ve sürüm kayıtlıdır.
/// Şema sürümü artırıldığında buraya eski sürümden göç testi eklenir
/// (bkz. AppDatabase.schemaVersion açıklaması).
void main() {
  test('yeni kurulumda tüm tablolar oluşur ve sürüm yazılır', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final tables = rows.map((r) => r.read<String>('name')).toSet();
    expect(tables, {
      for (final t in db.allTables) t.actualTableName,
    });

    final version = await db
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);
  });

  test('dosyadaki veritabanı yeniden açılınca veriler korunur', () async {
    final dir = await Directory.systemTemp.createTemp('paceora_db');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/paceora.sqlite');

    final first = AppDatabase.forTesting(NativeDatabase(file));
    await first.into(first.userProfiles).insert(
      UserProfilesCompanion.insert(name: 'Yağız', level: 'B1', dailyMinutes: 15),
    );
    await first.close();

    // Uygulama güncellenip yeniden açılmış gibi: aynı dosya, yeni bağlantı.
    final second = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(second.close);
    final profiles = await second.select(second.userProfiles).get();
    expect(profiles.single.name, 'Yağız');
  });
}
