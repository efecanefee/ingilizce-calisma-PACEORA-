import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/gemini_service.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının adı Gemini'ye giden hiçbir isteğe girmemeli. Servisin ad
/// diye bir girdisi yok; bu test profildeki adın uygulamanın gerçek
/// akışlarında da hiçbir isteğe sızmadığını doğrular.
void main() {
  const secretName = 'Zeynepcik Gizliadsoyad';

  test('profildeki ad Gemini isteklerinde yer almaz', () async {
    final bodies = <String>[];
    final client = MockClient((request) async {
      bodies.add(request.body);
      return http.Response.bytes(
        utf8.encode(jsonEncode({'candidates': <Object>[]})),
        200,
      );
    });
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await Repository(db)
        .saveProfile(name: secretName, level: 'B1', dailyMinutes: 15);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        geminiServiceProvider.overrideWithValue(
          GeminiService(client: client, apiKey: 'test-key'),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Program, günün dersi ve hikaye: hepsi profilden okur.
    await container.read(weekPlanProvider.future);
    final lesson = container.listen(lessonProvider, (_, _) {});
    await _ignoreErrors(container.read(lessonProvider.future));
    lesson.close();
    final story = container.listen(storyProvider, (_, _) {});
    await _ignoreErrors(container.read(storyProvider.future));
    story.close();

    final prompts = bodies.where((b) => b.contains('contents')).toList();
    expect(prompts, hasLength(greaterThanOrEqualTo(3)));
    for (final body in bodies) {
      expect(body, isNot(contains('Zeynepcik')));
      expect(body, isNot(contains('Gizliadsoyad')));
    }
  });
}

/// Boş Gemini cevabıyla akış hata ya da çevrimdışı içerikle bitebilir;
/// burada yalnızca giden istekler önemli.
Future<void> _ignoreErrors(Future<Object?> future) async {
  try {
    await future;
  } catch (_) {}
}
