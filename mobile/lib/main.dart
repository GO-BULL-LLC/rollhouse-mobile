import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/cart.dart';
import 'screens/home.dart';
import 'screens/orders.dart';
import 'screens/profile.dart';
import 'store.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: RH.surface,
  ));
  final store = AppStore()..init();
  runApp(StoreScope(store: store, child: const RollHouseApp()));
}

class RollHouseApp extends StatelessWidget {
  const RollHouseApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ролл Хаус',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        home: const _Root(),
      );
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    switch (store.state) {
      case LoadState.ready:
        return const Shell();
      case LoadState.loading:
        return Scaffold(body: Center(child: Image.asset('assets/logo-round.png', width: 180)));
      case LoadState.error:
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Image.asset('assets/logo-round.png', width: 140),
                const SizedBox(height: 32),
                const Icon(Icons.wifi_off_rounded, size: 48, color: RH.muted),
                const SizedBox(height: 12),
                Text(store.loadError ?? 'Нет связи', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                FilledButton(onPressed: store.refresh, child: const Text('Повторить')),
              ]),
            ),
          ),
        );
    }
  }
}

class Shell extends StatelessWidget {
  const Shell({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: store.tab,
      builder: (context, tab, _) {
        void go(int i) => store.tab.value = i;
        return Scaffold(
          body: IndexedStack(index: tab, children: [
            HomeScreen(onOpenCart: () => go(1)),
            CartScreen(onGoMenu: () => go(0)),
            const OrdersScreen(),
            const ProfileScreen(),
          ]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: go,
            destinations: [
              const NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu_rounded), label: 'Меню'),
              NavigationDestination(
                icon: Badge(isLabelVisible: store.cartCount > 0, label: Text('${store.cartCount}'), child: const Icon(Icons.shopping_bag_outlined)),
                selectedIcon: Badge(isLabelVisible: store.cartCount > 0, label: Text('${store.cartCount}'), child: const Icon(Icons.shopping_bag_rounded)),
                label: 'Корзина',
              ),
              const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Заказы'),
              const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Профиль'),
            ],
          ),
        );
      },
    );
  }
}
