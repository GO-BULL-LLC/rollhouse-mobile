// Скриншоты для App Store / Google Play: проходит по основным экранам на симуляторе.
// Запуск: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/screens_test.dart -d <sim>
// Каждый шаг независим: если что-то не нашлось — шаг пропускается, остальные снимки всё равно делаются.
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

  Future<bool> tap(WidgetTester t, Finder f, [int wait = 2]) async {
    if (f.evaluate().isEmpty) return false;
    await t.tap(f.first, warnIfMissed: false);
    await settle(t, wait);
    return true;
  }

  /// Закрыть всё поверх вкладок (шторки, экраны).
  Future<void> toRoot(WidgetTester t) async {
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    nav.popUntil((r) => r.isFirst);
    await settle(t, 1);
  }

  Future<void> step(String name, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      debugPrint('STEP $name FAILED: $e');
    }
  }

  testWidgets('screens', (t) async {
    app.main();
    for (var i = 0; i < 60 && find.text('Меню').evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    await settle(t, 8);

    await step('home', () async => shot(t, '01_home'));

    await step('home_scroll', () async {
      await t.drag(find.byType(CustomScrollView).first, const Offset(0, -520));
      await settle(t, 4);
      await shot(t, '02_home_scroll');
      await t.drag(find.byType(CustomScrollView).first, const Offset(0, 2000));
      await settle(t, 1);
    });

    await step('menu', () async {
      await t.drag(find.byType(CustomScrollView).first, const Offset(0, -520));
      await settle(t, 1);
      await tap(t, find.text('Роллы'), 6);
      await shot(t, '03_menu');
    });

    await step('pizza', () async {
      await tap(t, find.text('Пицца'), 5);
      await tap(t, find.text('Салями'), 4);
      await tap(t, find.text('40 см'), 1);
      await shot(t, '04_pizza_size');
      await tap(t, find.textContaining('В корзину'), 1);
      await toRoot(t);
    });

    await step('set', () async {
      await t.drag(find.byType(CustomScrollView).first, const Offset(0, -520));
      await settle(t, 1);
      await tap(t, find.text('Сеты'), 5);
      await tap(t, find.byIcon(Icons.add_rounded), 1);
      await toRoot(t);
    });

    await step('cart', () async {
      await tap(t, find.text('Корзина').last, 3);
      await shot(t, '05_cart');
    });

    await step('checkout', () async {
      await tap(t, find.textContaining('Оформить'), 4);
      await tap(t, find.text('Ко времени'), 4);
      await shot(t, '06_checkout');
      await toRoot(t);
    });

    await step('profile', () async {
      await tap(t, find.text('Профиль').last, 2);
      await shot(t, '07_profile');
    });

    await step('collection', () async {
      await tap(t, find.text('Меню').last, 2);
      await t.drag(find.byType(CustomScrollView).first, const Offset(0, 2000));
      await settle(t, 1);
      if (await tap(t, find.text('Запечённые'), 6)) await shot(t, '08_collection');
    });
  });
}
