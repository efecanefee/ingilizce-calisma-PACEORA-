import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// [finder]'ı ilk kaydırılabilir listede görünür yapar ve dokunulabilir
/// konuma getirir.
///
/// `scrollUntilVisible` hedefi ekran dışında ama çizilmişken bulup bırakabilir;
/// listeye yeni giren öğeler de giriş animasyonuyla kayarak belirir. Hedef
/// hizalanırken animasyon sürüyorsa animasyon bitince yerinden kayar. Bu
/// yüzden animasyonlar küçük adımlarla bitirilir (tek uzun `pump` onları
/// yalnızca başlatır), sonra hedef hizalanır.
Future<void> scrollIntoView(
  WidgetTester tester,
  Finder finder, {
  double step = 300,
}) async {
  await tester.scrollUntilVisible(
    finder,
    step,
    scrollable: find.byType(Scrollable).first,
  );
  await _settle(tester);
  await tester.ensureVisible(finder.first);
  await _settle(tester);
}

/// Tekrarlayan animasyonlar yüzünden pumpAndSettle bitmez; sabit adımlar.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
