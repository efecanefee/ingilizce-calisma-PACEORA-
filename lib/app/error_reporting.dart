import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Beklenmeyen hataların cihazdaki kaydı.
///
/// Sunucu yok: hatalar yalnızca bu telefonda, son [capacity] kayıt olarak
/// tutulur. Kullanıcı isterse Ayarlar'dan paylaşabilir (ör. geliştiriciye
/// e-postayla); kendiliğinden hiçbir yere gönderilmez.
class ErrorLog {
  ErrorLog(this._prefs);

  static const key = 'error_log';
  static const capacity = 20;

  final SharedPreferences _prefs;

  List<ErrorEntry> get entries => [
    for (final raw in _prefs.getStringList(key) ?? const <String>[])
      ?ErrorEntry.tryParse(raw),
  ];

  Future<void> record(Object error, StackTrace? stack, {String? context}) {
    final entry = ErrorEntry(
      time: clock.now(),
      message: '${context == null ? '' : '$context: '}$error',
      // Yığının ilk satırları sorunu bulmaya yeter; kayıt küçük kalır.
      stack: (stack?.toString() ?? '').split('\n').take(8).join('\n'),
    );
    final list = [
      jsonEncode(entry.toJson()),
      ...?_prefs.getStringList(key),
    ].take(capacity).toList();
    return _prefs.setStringList(key, list);
  }

  Future<void> clear() => _prefs.remove(key);

  /// Paylaşılacak düz metin rapor.
  String report({required String appVersion}) {
    final buffer = StringBuffer('Paceora $appVersion hata kaydı\n\n');
    for (final e in entries) {
      buffer
        ..writeln('[${e.time.toIso8601String()}] ${e.message}')
        ..writeln(e.stack)
        ..writeln();
    }
    return buffer.toString();
  }
}

class ErrorEntry {
  const ErrorEntry({
    required this.time,
    required this.message,
    required this.stack,
  });

  final DateTime time;
  final String message;
  final String stack;

  Map<String, Object> toJson() => {
    't': time.toIso8601String(),
    'm': message,
    's': stack,
  };

  static ErrorEntry? tryParse(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ErrorEntry(
        time: DateTime.parse(map['t'] as String),
        message: map['m'] as String,
        stack: map['s'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Flutter çerçevesi ve platform hatalarını yakalar, kaydeder.
///
/// Geliştirme sırasında hatalar yine konsola ve kırmızı ekrana düşer;
/// sürüm derlemesinde kırmızı ekran yerine sakin bir hata kutusu görünür.
void installErrorHandlers(ErrorLog log) {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(log.record(details.exception, details.stack, context: 'UI'));
    (previous ?? FlutterError.presentError)(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(log.record(error, stack, context: 'Async'));
    debugPrint('Yakalanmamış hata: $error');
    // true: hata ele alındı, uygulama kapanmasın.
    return true;
  };

  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const FriendlyErrorBox();
  }
}

/// Bir widget çizilemediğinde kırmızı ekran yerine gösterilen kutu.
class FriendlyErrorBox extends StatelessWidget {
  const FriendlyErrorBox({super.key});

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Bu bölüm gösterilemedi. Sayfayı kapatıp yeniden açmayı dene.',
                textDirection: TextDirection.ltr,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
