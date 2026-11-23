import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/providers.dart';
import 'mascot.dart';

/// Ekranın verisi yüklenemediğinde kullanıcıya gösterilecek anlaşılır metin.
/// Uygulamanın kendi Türkçe mesajları olduğu gibi gösterilir; teknik hatalar
/// ("Bad state", "Exception: ...") kullanıcıya hiç yansımaz.
String friendlyErrorMessage(Object error) => switch (error) {
  LessonUnavailable(:final message) => message,
  StateError(:final message) => message,
  TimeoutException() =>
    'Bağlantı çok uzun sürdü. İnternetini kontrol edip tekrar dene.',
  http.ClientException() =>
    'İnternete bağlanılamadı. Bağlantını kontrol edip tekrar dene.',
  _ => 'Bir şeyler ters gitti. Tekrar denemek ister misin?',
};

/// Tam ekran hata görünümü: şaşkın Pace, anlaşılır mesaj ve isteğe bağlı
/// "Tekrar dene" düğmesi.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;

  /// Verilirse "Tekrar dene" düğmesi gösterilir.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PaceSticker(PacePose.confused, size: 120, animate: false),
            const SizedBox(height: 20),
            Text(
              friendlyErrorMessage(error),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar dene'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
