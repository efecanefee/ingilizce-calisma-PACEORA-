import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'motion.dart';

/// Alt gezinme çubuklu ana iskelet: Bugün · Program · İlerleme · Ayarlar.
///
/// Sekmeler `IndexedStack` ile tutulur, böylece kaydırma konumu ve durum
/// korunur; sekme değişince içerik hafifçe yükselerek belirir.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(int index) {
    Haptics.tap();
    // Aynı sekmeye tekrar dokunmak o sekmenin başına döner.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _RiseOnChange(index: shell.currentIndex, child: shell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _select,
        animationDuration: Motion.medium,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny_rounded),
            label: 'Bugün',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Program',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'İlerleme',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}

/// [index] değişince çocuğu yeniden kurmadan solma + yükselme oynatır.
///
/// Anahtar değiştirmek sekmelerin durumunu sıfırlardı; bunun yerine aynı
/// denetleyici baştan oynatılır.
class _RiseOnChange extends StatefulWidget {
  const _RiseOnChange({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_RiseOnChange> createState() => _RiseOnChangeState();
}

class _RiseOnChangeState extends State<_RiseOnChange>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.medium,
    value: 1,
  );
  late final _curve = CurvedAnimation(parent: _controller, curve: Motion.curve);

  @override
  void didUpdateWidget(_RiseOnChange old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: 0.2 + 0.8 * _curve.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - _curve.value)),
          child: child,
        ),
      ),
    );
  }
}
