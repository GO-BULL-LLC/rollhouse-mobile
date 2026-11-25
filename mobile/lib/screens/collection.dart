import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cart.dart';
import 'home.dart';

class CollectionScreen extends StatelessWidget {
  final Collection collection;
  const CollectionScreen({super.key, required this.collection});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = store.productsByIds(collection.products);
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: collection.image.isNotEmpty ? 240 : 0,
          title: Text(collection.title),
          flexibleSpace: collection.image.isEmpty
              ? null
              : FlexibleSpaceBar(
                  background: Stack(fit: StackFit.expand, children: [
                    ColoredBox(color: Colors.white, child: Padding(padding: const EdgeInsets.only(top: 40), child: NetImg(collection.image, fit: BoxFit.contain, bg: Colors.white))),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Colors.transparent, Colors.transparent, RH.bg], stops: [0, 0.3, 0.8, 1]),
                      ),
                    ),
                  ]),
                ),
        ),
        if (collection.subtitle.isNotEmpty)
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: Text(collection.subtitle, style: const TextStyle(color: RH.muted)))),
        SliverPadding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), sliver: productGrid(items)),
        SliverToBoxAdapter(child: SizedBox(height: store.cartCount > 0 ? 100 : 24)),
      ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: store.cartCount > 0
          ? CartFab(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen(standalone: true))))
          : null,
    );
  }
}

/// Горизонтальная лента карточек-подборок для главной.
class CollectionsStrip extends StatelessWidget {
  final List<Collection> items;
  const CollectionsStrip({super.key, required this.items});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (c, i) {
          final col = items[i];
          return SizedBox(
            width: 160,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(RH.radius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionScreen(collection: col))),
                child: Stack(fit: StackFit.expand, children: [
                  NetImg(col.image, bg: Colors.white),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(col.title, maxLines: 2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: RH.ink, height: 1.15)),
                      if (col.subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(col.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: RH.inkMuted, height: 1.25)),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
