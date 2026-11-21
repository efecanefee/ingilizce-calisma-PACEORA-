import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../data/gemini_service.dart';
import '../../../data/providers.dart';
import '../widgets/settings_sheet.dart';

/// Bağlantı testini alt sayfada açar.
Future<void> openConnectionTestSheet(BuildContext context) =>
    openSettingsSheet(context, 'Bağlantı testi', const ConnectionTest());

/// Gemini bağlantısını uçtan uca dener ve sonucu Türkçe gösterir.
class ConnectionTest extends ConsumerStatefulWidget {
  const ConnectionTest({super.key});

  @override
  ConsumerState<ConnectionTest> createState() => _ConnectionTestState();
}

class _ConnectionTestState extends ConsumerState<ConnectionTest> {
  late final Future<GeminiConnectionReport> _report = ref
      .read(geminiServiceProvider)
      .testConnection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return FutureBuilder<GeminiConnectionReport>(
      future: _report,
      builder: (context, snapshot) {
        final report = snapshot.data;
        if (report == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Gemini\'ye bağlanılıyor…'),
              ],
            ),
          );
        }

        final seconds = report.elapsed == null
            ? null
            : (report.elapsed!.inMilliseconds / 1000).toStringAsFixed(1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  report.ok ? Icons.check_circle_rounded : Icons.error_rounded,
                  // Açık temada koyu tonlar; parlak yeşil beyazda okunmaz.
                  color: report.ok
                      ? (dark ? AppColors.success : AppColors.successDark)
                      : theme.colorScheme.error,
                  size: 32,
                ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    report.ok ? 'Bağlantı çalışıyor' : 'Bağlantı kurulamadı',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (report.route != null)
              _ReportRow(label: 'Bağlantı yolu', value: report.route!),
            if (report.model != null)
              _ReportRow(label: 'Kullanılan model', value: report.model!),
            if (seconds != null)
              _ReportRow(label: 'Yanıt süresi', value: '$seconds sn'),
            if (report.availableModels.isNotEmpty)
              _ReportRow(
                label: report.listedFromApi
                    ? 'Erişilebilir modeller'
                    : report.route == 'Firebase (anahtarsız)'
                    ? 'Denenen modeller'
                    : 'Denenen modeller (liste alınamadı)',
                value: report.availableModels.take(5).join('\n'),
              ),
            if (report.error != null)
              _ReportRow(label: 'Hata', value: report.error!, isError: true),
          ],
        );
      },
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.label,
    required this.value,
    this.isError = false,
  });

  final String label;
  final String value;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isError ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}
