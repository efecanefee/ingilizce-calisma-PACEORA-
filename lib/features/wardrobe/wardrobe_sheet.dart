import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/celebration.dart';
import '../../app/mascot.dart';
import '../../app/motion.dart';
import '../../data/providers.dart';
import '../../data/wardrobe.dart';

/// Pace'in dolabı: formaları harcanabilir XP ile al ve giydir.
Future<void> showWardrobeSheet(BuildContext context) {
  Haptics.tap();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const WardrobeSheet(),
  );
}

class WardrobeSheet extends ConsumerStatefulWidget {
  const WardrobeSheet({super.key});

  @override
  ConsumerState<WardrobeSheet> createState() => _WardrobeSheetState();
}

class _WardrobeSheetState extends ConsumerState<WardrobeSheet> {
  /// Önizlenen forma; ilk açılışta giyili olan.
  PaceKit? _preview;
  var _busy = false;

  Future<void> _act(PaceKit kit, WardrobeState wardrobe) async {
    if (wardrobe.owns(kit)) {
      Haptics.tap();
      await equipKit(ref, kit);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${kit.label} alınsın mı?'),
        content: Text(
          '${kit.price} XP harcanacak. Seviyen düşmez; harcanabilir XP '
          'seri dondurma haklarıyla ortaktır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: Text('${kit.price} XP harca'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final ok = await buyKit(ref, kit);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    Haptics.success();
    CelebrationHost.show(
      context,
      Celebration(
        title: 'Yeni forma: ${kit.label}',
        subtitle: 'Pace artık ${kit.label} formasını giyiyor.',
        icon: Icons.checkroom_rounded,
        color: kit.trim ?? const Color(0xFFC6F432),
        chip: '-${kit.price} XP',
        art: PaceMascot(mood: PaceMood.cheer, kit: kit, size: 130),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wardrobe = ref.watch(wardrobeProvider);
    final xp = ref.watch(gameProvider).value?.level.xp ?? 0;
    final balance = ref.watch(freezeProvider).balance(xp);
    final preview = _preview ?? wardrobe.equipped;
    final owned = wardrobe.owns(preview);
    final equipped = wardrobe.equipped == preview;
    final affordable = balance >= preview.price;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    final String label;
    if (equipped) {
      label = 'Giyiliyor';
    } else if (owned) {
      label = 'Giydir';
    } else {
      label = '${preview.label} al · ${preview.price} XP';
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          children: [
            Text(
              "Pace'in dolabı",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Kazandığın XP ile Pace\'e yeni formalar al.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 16),
            PaceMascot(mood: PaceMood.cheer, kit: preview, size: 170),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final kit in PaceKit.values)
                  _KitChip(
                    kit: kit,
                    selected: kit == preview,
                    owned: wardrobe.owns(kit),
                    equipped: kit == wardrobe.equipped,
                    onTap: () => setState(() => _preview = kit),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    equipped || _busy || (!owned && !affordable)
                    ? null
                    : () => _act(preview, wardrobe),
                icon: Icon(
                  owned ? Icons.checkroom_rounded : Icons.shopping_bag_rounded,
                ),
                label: Text(label),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              owned || affordable
                  ? 'Harcanabilir XP: $balance. Seviyen düşmez.'
                  : 'Harcanabilir XP: $balance. '
                        '${preview.price - balance} XP daha kazanınca '
                        'alabilirsin.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _KitChip extends StatelessWidget {
  const _KitChip({
    required this.kit,
    required this.selected,
    required this.owned,
    required this.equipped,
    required this.onTap,
  });

  final PaceKit kit;
  final bool selected;
  final bool owned;
  final bool equipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const graphite = Color(0xFF2B2F35);
    const lime = Color(0xFFC6F432);

    return Semantics(
      button: true,
      selected: selected,
      label: kit.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              // Forma rengi: gövde dolgu, şerit çerçeve.
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: kit.body ?? graphite,
                  shape: BoxShape.circle,
                  border: Border.all(color: kit.trim ?? lime, width: 4),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                kit.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                equipped
                    ? 'Giyili'
                    : owned
                    ? 'Sende'
                    : '${kit.price} XP',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
