import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Puanlama penceresi bir kez istendi mi. Sıfırlamada silinmez: Apple ve
/// Google pencereyi zaten sınırlar, aynı kişiye ikinci kez sormak istemeyiz.
const reviewRequestedKey = 'review_requested';

/// Puanlama isteğinin sorulacağı ilk seri hedefi.
const reviewStreakMilestone = 7;

/// Bu seri hedefinde puanlama istenmeli mi: hedef 7 gün ve üzeri, daha
/// önce hiç istenmemiş.
bool shouldRequestReview(SharedPreferences prefs, int reachedMilestone) =>
    reachedMilestone >= reviewStreakMilestone &&
    !(prefs.getBool(reviewRequestedKey) ?? false);

/// Mağazanın uygulama içi puanlama penceresini açar; testlerde sahtesiyle
/// değiştirilir. Pencerenin gerçekten görünüp görünmeyeceğine sistem karar
/// verir; hata olursa sessizce geçilir.
final reviewRequesterProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } catch (_) {}
  },
);
