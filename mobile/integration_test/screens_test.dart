// Скриншоты для App Store: проходит по основным экранам на симуляторе.
// Запуск: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/screens_test.dart -d <sim>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rollhouse/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester t, [int seconds = 3]) async {
    for (var i = 0; i < seconds * 4; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> shot(WidgetTester t, String name) async {
    await settle(t, 2);
    await binding.takeScreenshot(name);
  }

  testWidgets('screens', (t) async {
    app.main();
    // ждём меню с сервера и картинки
    for (var i = 0; i < 60 && find.text('Меню').evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    await settle(t, 6);
    await shot(t, '01_home');

    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
    await settle(t, 4);
    await shot(t, '02_home_scroll');

    await t.tap(find.text('Сеты').first);
    await settle(t, 6);
    await shot(t, '03_menu');

    // карточка товара
    await t.tap(find.text('Катана').first);
    await settle(t, 4);
    await shot(t, '04_product');
    final add = find.textContaining('В корзину');
    if (add.evaluate().isNotEmpty) await t.tap(add.first);
    await settle(t, 1);
    await t.tap(find.byTooltip('Закрыть'));
    await settle(t, 1);

    // пицца с выбором размера — вкладка «Пицца» на том же экране
    await t.tap(find.text('Пицца').first);
    await settle(t, 5);
    await t.tap(find.text('Салями').first);
    await settle(t, 4);
    final big = find.text('40 см');
    if (big.evaluate().isNotEmpty) await t.tap(big.first);
    await shot(t, '05_pizza_size');
    final add2 = find.textContaining('В корзину');
    if (add2.evaluate().isNotEmpty) await t.tap(add2.first);
    await settle(t, 1);
    await t.tap(find.byTooltip('Закрыть'));
    await settle(t, 1);
    await t.pageBack();
    await settle(t, 2);

    await t.tap(find.text('Корзина').last);
    await shot(t, '06_cart');

    await t.tap(find.textContaining('Оформить').first);
    await settle(t, 4);
    final pre = find.text('Ко времени');
    if (pre.evaluate().isNotEmpty) {
      await t.tap(pre.first);
      await settle(t, 4);
    }
    await shot(t, '07_checkout');
    await t.pageBack();
    await settle(t, 1);

    await t.tap(find.text('Профиль').last);
    await shot(t, '08_profile');

    // подборка
    await t.tap(find.text('Меню').last);
    await settle(t, 2);
    final col = find.text('Запечённые');
    if (col.evaluate().isNotEmpty) {
      await t.tap(col.first);
      await settle(t, 6);
      await shot(t, '09_collection');
    }
  });
}
