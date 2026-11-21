import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/turkish_letters.dart';

void main() {
  test('Türkçe büyük harf', () {
    expect(trUpper('i'), 'İ');
    expect(trUpper('ı'), 'I');
    expect(trUpper('ğüşöç'), 'ĞÜŞÖÇ');
  });

  testWidgets('kelime başında büyük, içinde küçük harf eklenir', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(controller: controller),
              TurkishLetterBar(controller: controller),
            ],
          ),
        ),
      ),
    );
    // Boş alan: kelime başı → büyük harfler gösterilir.
    expect(find.text('İ'), findsOneWidget);
    await tester.tap(find.text('İ'));
    await tester.pump();
    expect(controller.text, 'İ');

    // Kelime içi: küçük harfler.
    controller.text = 'İlk';
    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();
    await tester.tap(find.text('ü'));
    expect(controller.text, 'İlkü');
    controller.text = 'Yağ';
    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();
    await tester.tap(find.text('ı'));
    expect(controller.text, 'Yağı');

    // İmlecin olduğu yere yazılır; boşluktan sonra yine büyük.
    controller.value = const TextEditingValue(
      text: 'Ali ',
      selection: TextSelection.collapsed(offset: 4),
    );
    await tester.pump();
    await tester.tap(find.text('Ş'));
    expect(controller.text, 'Ali Ş');
  });
}
