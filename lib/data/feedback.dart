import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/constants.dart';

/// E-posta uygulamasını açar; testlerde sahtesiyle değiştirilir.
final mailLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) async {
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  },
);

/// Hata kaydı e-postaya eklenirken üst sınır: mailto bağlantıları bazı
/// e-posta uygulamalarında uzun gövdeyi keser.
const feedbackLogLimit = 1500;

/// "Geri bildirim gönder" için hazır e-posta bağlantısı. Gövdeye yalnızca
/// sürüm ve platform eklenir; hata kaydı kullanıcı isterse eklenir.
Uri feedbackMailUri({required String platform, String? errorReport}) {
  final log = errorReport == null || errorReport.length <= feedbackLogLimit
      ? errorReport
      : '${errorReport.substring(0, feedbackLogLimit)}\n…';
  final body = StringBuffer()
    ..writeln('Merhaba,')
    ..writeln()
    ..writeln()
    ..writeln()
    ..writeln('---')
    ..writeln('Sürüm: ${AppConstants.appVersion}')
    ..writeln('Platform: $platform');
  if (log != null) {
    body
      ..writeln()
      ..writeln(log);
  }
  // queryParameters boşlukları "+" yapar; e-posta uygulamaları bunu olduğu
  // gibi gösterir. Bileşenler elle kodlanır.
  final query = {
    'subject': 'Paceora geri bildirim (${AppConstants.appVersion})',
    'body': body.toString(),
  }.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
  return Uri.parse('mailto:${AppConstants.supportEmail}?$query');
}
