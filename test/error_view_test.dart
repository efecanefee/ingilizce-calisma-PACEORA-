import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:paceora/app/error_view.dart';
import 'package:paceora/data/providers.dart';

void main() {
  test('uygulamanın kendi mesajları olduğu gibi, teknik hatalar sade', () {
    expect(
      friendlyErrorMessage(const LessonUnavailable('Hazır ders bulunamadı.')),
      'Hazır ders bulunamadı.',
    );
    expect(
      friendlyErrorMessage(StateError('Rapor için önce profil oluşturulmalı')),
      'Rapor için önce profil oluşturulmalı',
    );
    expect(friendlyErrorMessage(TimeoutException(null)), contains('uzun sürdü'));
    expect(
      friendlyErrorMessage(http.ClientException('Failed host lookup')),
      contains('İnternete bağlanılamadı'),
    );
    final generic = friendlyErrorMessage(const FormatException('<html>'));
    expect(generic, isNot(contains('FormatException')));
    expect(generic, isNot(contains('<html>')));
  });

  testWidgets('tekrar dene düğmesi geri çağrıyı çalıştırır', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorView(error: Exception('x'), onRetry: () => retried++),
        ),
      ),
    );
    expect(find.textContaining('Exception'), findsNothing);
    await tester.tap(find.text('Tekrar dene'));
    expect(retried, 1);
  });

  testWidgets('geri çağrı yoksa düğme gösterilmez', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ErrorView(error: Exception('x')))),
    );
    expect(find.text('Tekrar dene'), findsNothing);
  });
}
