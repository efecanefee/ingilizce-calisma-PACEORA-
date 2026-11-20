import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/motion.dart';

void main() {
  tearDown(() => Motion.reduced = false);

  testWidgets('hareket azaltılmışsa döngü animasyonları durur', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);

    Motion.reduced = true;
    unawaited(controller.forward());
    Motion.loop(reverse: true)(controller);
    expect(controller.isAnimating, isFalse);

    Motion.reduced = false;
    Motion.loop()(controller);
    expect(controller.isAnimating, isTrue);
    controller.stop();
  });

  test('hareket azaltılmışsa giriş animasyonu uygulanmaz', () {
    const child = SizedBox();
    Motion.reduced = true;
    expect(identical(child.entrance(0), child), isTrue);
    Motion.reduced = false;
    expect(identical(child.entrance(0), child), isFalse);
  });
}
