import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Android ana ekran widget'ına (PaceWidgetProvider.kt) veri yazar.
///
/// Widget yalnızca bu değerleri gösterir: seri, bugün çalışıldı mı ve günün
/// kelimesi. iOS'ta widget yok (ayrı bir Xcode uzantısı gerekir); orada ve
/// testlerde hiçbir şey yapmaz.
class HomeWidgetSync {
  const HomeWidgetSync._();

  static const androidName = 'PaceWidgetProvider';

  /// Son yazılan değerler; aynı veri tekrar tekrar yazılmasın.
  static String? _last;

  /// Gerçek açılışta (main) açılır; testlerde ve önizlemelerde kapalı.
  static bool enabled = false;

  static bool get supported =>
      enabled && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> update({
    required int streak,
    required bool doneToday,
    required String word,
    required String meaning,
  }) async {
    if (!supported) return;
    final key = '$streak|$doneToday|$word|$meaning';
    if (key == _last) return;
    try {
      await HomeWidget.saveWidgetData<int>('streak', streak);
      await HomeWidget.saveWidgetData<bool>('done_today', doneToday);
      await HomeWidget.saveWidgetData<String>('word', word);
      await HomeWidget.saveWidgetData<String>('meaning', meaning);
      await HomeWidget.updateWidget(androidName: androidName);
      _last = key;
    } catch (e) {
      // Widget eklenmemiş ya da eklenti yoksa uygulama etkilenmesin.
      debugPrint('Ana ekran widget\'ı güncellenemedi: $e');
    }
  }
}
