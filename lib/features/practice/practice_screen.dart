import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/feature_colors.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../data/writing.dart';

/// "Pratik" sekmesi: dersin dışındaki bütün çalışma alanları.
///
/// Her alan kendi [Feature] rengini taşır; kullanıcı neyin ne olduğunu
/// renginden tanır. Üstte öne çıkan iki kart (sohbet, ralli), altta iki
/// sütunlu kutucuklar.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cards = ref.watch(flashcardSummaryProvider).value;
    final rally = ref.watch(matchRecordsProvider);
    final roleplay = ref.watch(roleplayRecordsProvider);
    final writing = WritingRecords.read(ref.watch(sharedPreferencesProvider));
    final due = cards?.due ?? 0;

    // Dönüşte rozet ve XP güncel olsun.
    Future<void> open(String route) async {
      await context.push(route);
      if (!context.mounted) return;
      ref.invalidate(flashcardSummaryProvider);
      ref.invalidate(gameProvider);
    }

    final featured = [
      _FeaturedCard(
        feature: Feature.roleplay,
        description:
            'Kafede, otelde, iş görüşmesinde gerçek bir sohbet gibi '
            'konuş; hatalarını anında düzelt.',
        stat: roleplay.completed > 0
            ? '${roleplay.completed} sohbet · '
                  '${roleplay.goalScenarios.length} görev başarıldı'
            : null,
        onTap: () => open('/roleplay'),
      ),
      _FeaturedCard(
        feature: Feature.rally,
        description: '60 saniyede kelimeleri eşleştir, rekorunu kır.',
        stat: rally.games > 0 ? 'Rekorun: ${rally.bestScore} puan' : null,
        onTap: () => open('/match'),
      ),
    ];

    final tiles = [
      _PracticeTile(
        feature: Feature.flashcards,
        subtitle: due > 0
            ? '$due kart seni bekliyor'
            : cards == null || cards.total == 0
            ? 'Ders bitirince dolar'
            : 'Bugünlük tamam',
        badge: due > 0 ? '$due' : null,
        onTap: () => open('/flashcards'),
      ),
      _PracticeTile(
        feature: Feature.writing,
        subtitle: writing.count > 0
            ? 'En iyi puanın: %${writing.bestScore}'
            : 'Yaz, Pace düzeltsin',
        onTap: () => open('/writing'),
      ),
      _PracticeTile(
        feature: Feature.story,
        subtitle: 'Oku ve anla',
        onTap: () => open('/story'),
      ),
      _PracticeTile(
        feature: Feature.speaking,
        subtitle: 'Söyle, puanını gör',
        onTap: () => open('/speaking'),
      ),
      _PracticeTile(
        feature: Feature.dictation,
        subtitle: 'Kulağını eğit',
        onTap: () => open('/dictation'),
      ),
      _PracticeTile(
        feature: Feature.mistakes,
        subtitle: 'Pekişmeyenler',
        onTap: () => open('/mistakes'),
      ),
      _PracticeTile(
        feature: Feature.review,
        subtitle: 'Seviye önerisi',
        onTap: () => open('/review'),
      ),
    ];

    var index = 0;
    Widget item(Widget child) => child.entrance(index++);

    // Sabit en-boy oranı büyük yazı boyutunda kutucuğu taşırıyordu;
    // yükseklik yazı ölçeğiyle birlikte büyür.
    final scaler = MediaQuery.textScalerOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pratik'),
        actions: [
          IconButton(
            tooltip: 'Ara',
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(flashcardSummaryProvider);
          await ref.read(flashcardSummaryProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            item(
              Text(
                'Dersin dışında kendini dene: konuş, oku, dinle, oyna.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            for (final card in featured) ...[
              const SizedBox(height: 14),
              item(card),
            ],
            const SizedBox(height: 14),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 84 + scaler.scale(56),
              ),
              children: [for (final tile in tiles) item(tile)],
            ),
          ],
        ),
      ),
    );
  }
}

/// Öne çıkan pratik girişi: bölüm renginde, tam genişlikte büyük kart.
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.feature,
    required this.description,
    required this.onTap,
    this.stat,
  });

  final Feature feature;
  final String description;

  /// Kullanıcının bu alandaki kaydı; henüz yoksa null.
  final String? stat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = feature.color(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: PressableScale(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  feature.tint(context),
                  theme.colorScheme.surfaceContainer,
                ],
              ),
              border: Border.all(color: feature.border(context), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: feature.tint(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: feature.border(context)),
                  ),
                  child: Icon(feature.icon, size: 30, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                      if (stat != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.emoji_events_rounded,
                              size: 16,
                              color: color,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                stat!,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// İki sütunlu ızgaradaki pratik kutucuğu; bölüm renginde ikon ve kenarlık.
class _PracticeTile extends StatelessWidget {
  const _PracticeTile({
    required this.feature,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final Feature feature;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = feature.color(context);

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: PressableScale(
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: feature.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: feature.tint(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(feature.icon, size: 20, color: color),
                    ),
                    const Spacer(),
                    if (badge != null)
                      ExcludeSemantics(
                        child:
                            Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    badge!,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      // Koyu temada renk parlak, açıkta koyu.
                                      color: isDark
                                          ? AppColors.graphite900
                                          : Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                                .animate(onPlay: Motion.loop(reverse: true))
                                .scaleXY(begin: 1, end: 1.12, duration: 800.ms),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  feature.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
