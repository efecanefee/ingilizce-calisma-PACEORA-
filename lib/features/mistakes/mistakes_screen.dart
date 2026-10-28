import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Hata defteri: yanlış yapılan ifadeler ve pekişmeye ne kadar kaldığı.
class MistakesScreen extends ConsumerWidget {
  const MistakesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mistakes = ref.watch(mistakesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Hata defterim')),
      body: switch (mistakes) {
        AsyncError(:final error) => Center(child: Text('$error')),
        AsyncData(:final value) when value.isEmpty => const _EmptyView(),
        AsyncData(:final value) => _MistakeList(items: value),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _MistakeList extends StatelessWidget {
  const _MistakeList({required this.items});

  final List<Mistake> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = items.where((m) => !m.resolved).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          open == 0
              ? 'Tüm hatalarını pekiştirdin, harika!'
              : '$open ifade hâlâ pekişmedi. Her biri sonraki derslerde '
                    'karşına çıkar; üst üste 3 kez doğru yapınca kapanır.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ).entrance(0),
        const SizedBox(height: 16),
        for (final (i, m) in items.indexed)
          _MistakeTile(mistake: m).entrance((i + 1).clamp(0, 10)),
      ],
    );
  }
}

class _MistakeTile extends StatelessWidget {
  const _MistakeTile({required this.mistake});

  final Mistake mistake;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = mistake;
    final (typeLabel, typeIcon) = switch (m.type) {
      'translation' => ('Çeviri', Icons.translate_rounded),
      'grammar' => ('Dilbilgisi', Icons.rule_rounded),
      _ => ('Kelime', Icons.abc_rounded),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: m.resolved
              ? AppColors.success.withValues(alpha: 0.6)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(typeIcon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(typeLabel, style: theme.textTheme.labelMedium),
              const Spacer(),
              if (m.resolved)
                const Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 18,
                      color: AppColors.success,
                    ),
                    SizedBox(width: 4),
                    Text('Pekişti'),
                  ],
                )
              else
                Text(
                  '${m.timesWrong} kez yanlış',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            m.item,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (m.context.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              m.context,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (!m.resolved) ...[
            const SizedBox(height: 12),
            // Pekişme: üst üste 3 doğru.
            Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child:
                        Container(
                              height: 6,
                              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: i < m.timesCorrect
                                    ? AppColors.success
                                    : theme.colorScheme.surfaceContainerHighest,
                              ),
                            )
                            .animate(delay: (120 * i).ms)
                            .scaleX(
                              begin: 0,
                              alignment: Alignment.centerLeft,
                              duration: Motion.medium,
                            ),
                  ),
                const SizedBox(width: 10),
                Text('${m.timesCorrect}/3', style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit_note_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ).animate().scale(curve: Curves.elasticOut, duration: Motion.slow),
            const SizedBox(height: 16),
            Text(
              'Hata defterin boş',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Derslerde yanlış yaptığın ifadeler burada toplanır ve sonraki '
              'derslerde tekrar sorulur.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
