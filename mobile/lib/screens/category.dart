import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cart.dart';
import 'home.dart';

class CategoryScreen extends StatelessWidget {
  final String initialId;
  const CategoryScreen({super.key, required this.initialId});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cats = store.categories;
    final initial = cats.indexWhere((c) => c.id == initialId).clamp(0, cats.length - 1);
    return DefaultTabController(
      length: cats.length,
      initialIndex: initial,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Меню'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: RH.red,
            indicatorWeight: 3,
            labelColor: RH.text,
            unselectedLabelColor: RH.muted,
            labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            dividerColor: RH.line,
            tabs: [for (final c in cats) Tab(text: c.name)],
          ),
        ),
        body: TabBarView(children: [
          for (final c in cats)
            CustomScrollView(key: PageStorageKey(c.id), slivers: [
              if (c.subtitle.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: Text(c.subtitle, style: const TextStyle(color: RH.muted))),
                ),
              SliverPadding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), sliver: productGrid(c.products)),
              SliverToBoxAdapter(child: SizedBox(height: store.cartCount > 0 ? 100 : 24)),
            ]),
        ]),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: store.cartCount > 0
            ? CartFab(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen(standalone: true))))
            : null,
      ),
    );
  }
}
