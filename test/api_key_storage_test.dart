import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/constants.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('eski düz metin anahtar kasaya taşınır ve silinir', () async {
    SharedPreferences.setMockInitialValues({AppConstants.prefApiKey: 'abc'});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const storage = FlutterSecureStorage();

    expect(await loadApiKey(prefs, storage), 'abc');
    expect(prefs.containsKey(AppConstants.prefApiKey), isFalse);
    expect(await storage.read(key: apiKeyStorageKey), 'abc');
    // Sonraki açılışta doğrudan kasadan okunur.
    expect(await loadApiKey(prefs, storage), 'abc');
  });

  test('kaydedilen anahtar kasaya yazılır, boşsa silinir', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    const storage = FlutterSecureStorage();

    await container.read(apiKeyProvider.notifier).save('  xyz  ');
    expect(container.read(apiKeyProvider), 'xyz');
    expect(await storage.read(key: apiKeyStorageKey), 'xyz');
    // Düz metin olarak SharedPreferences'a hiç yazılmaz.
    expect(prefs.getKeys(), isEmpty);

    await container.read(apiKeyProvider.notifier).save('');
    expect(await storage.read(key: apiKeyStorageKey), isNull);
  });
}
