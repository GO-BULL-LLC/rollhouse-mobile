import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'category.dart';
import 'collection.dart';
import 'search.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenCart;
  const HomeScreen({super.key, required this.onOpenCart});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cfg = store.config!;
    final hits = store.hits;
    return Scaffold(
      body: RefreshIndicator(
        color: RH.red,
        onRefresh: store.refresh,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            toolbarHeight: 64,
            titleSpacing: 16,
            title: Image.asset('assets/logo.png', height: 30, semanticLabel: 'Roll House'),
            actions: [
              if (cfg.phone.isNotEmpty)
                IconButton(
                  tooltip: 'Позвонить',
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => launchUrl(Uri.parse('tel:${cfg.phone}')),
                ),
              const SizedBox(width: 6),
            ],
          ),
          if (store.loadError != null)
            SliverToBoxAdapter(child: _Strip(text: store.loadError!, color: RH.surface2, icon: Icons.wifi_off_rounded)),
          if (cfg.announcement != null)
            SliverToBoxAdapter(
              child: _Strip(
                text: cfg.announcement!.text,
                icon: Icons.campaign_outlined,
                color: switch (cfg.announcement!.style) { 'red' => RH.red, 'dark' => RH.surface2, _ => RH.gold },
                dark: cfg.announcement!.style == 'gold',
              ),
            ),
          if (!cfg.isOpenNow && cfg.closedText.isNotEmpty)
            SliverToBoxAdapter(child: _Strip(text: cfg.closedText, color: RH.surface2, icon: Icons.schedule_rounded)),
          if (cfg.banners.isNotEmpty) SliverToBoxAdapter(child: BannerCarousel(banners: cfg.banners)),
          if (store.orders.isNotEmpty) SliverToBoxAdapter(child: _RepeatLast(order: store.orders.first)),
          if (cfg.collections.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionTitle('Подборки')),
            SliverToBoxAdapter(child: CollectionsStrip(items: cfg.collections)),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Material(
                color: RH.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                  child: const SizedBox(
                    height: 50,
                    child: Row(children: [
                      SizedBox(width: 14),
                      Icon(Icons.search_rounded, color: RH.muted),
                      SizedBox(width: 10),
                      Text('Найти ролл, пиццу, сет…', style: TextStyle(color: RH.muted, fontSize: 15)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SectionTitle('Меню')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.25),
              delegate: SliverChildBuilderDelegate(
                (c, i) => _CategoryTile(category: store.categories[i]),
                childCount: store.categories.length,
              ),
            ),
          ),
          if (hits.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionTitle('Хиты')),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 300,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: hits.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (c, i) => SizedBox(width: 172, child: ProductCard(key: ValueKey(hits[i].id), product: hits[i])),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: store.cartCount > 0 ? 96 : 24)),
        ]),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: store.cartCount > 0 ? CartFab(onTap: onOpenCart) : null,
    );
  }
}

class CartFab extends StatelessWidget {
  final VoidCallback onTap;
  const CartFab({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(elevation: 6, shadowColor: Colors.black),
          child: Row(children: [
            const Icon(Icons.shopping_bag_outlined),
            const SizedBox(width: 10),
            Text('Корзина · ${store.cartCount}'),
            const Spacer(),
            Text(rub(store.totalNoDelivery)),
          ]),
        ),
      ),
    );
  }
}

/// Быстрый повтор последнего заказа.
class _RepeatLast extends StatelessWidget {
  final PastOrder order;
  const _RepeatLast({required this.order});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final names = order.lines.map((l) => l.title).join(', ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        color: RH.surface,
        borderRadius: BorderRadius.circular(RH.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            final missed = store.repeat(order);
            HapticFeedback.lightImpact();
            toast(context, missed == 0 ? 'Добавили в корзину' : 'Добавили в корзину. $missed поз. больше нет в меню');
            store.tab.value = 1;
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: NetImg(order.lines.isEmpty ? '' : order.lines.first.image, width: 56, height: 56, bg: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Повторить прошлый заказ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(names, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RH.muted, fontSize: 13)),
                ]),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.replay_rounded, color: RH.red),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Strip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  final bool dark;
  const _Strip({required this.text, required this.color, required this.icon, this.dark = false});
  @override
  Widget build(BuildContext context) {
    final fg = dark ? const Color(0xFF1A1206) : RH.text;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: fg, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14, height: 1.35))),
      ]),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  const _CategoryTile({required this.category});
  @override
  Widget build(BuildContext context) {
    // Обложки — на белом фоне, как фото блюд в меню: светлая карточка, тёмный текст сверху.
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(RH.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openCategory(context, category.id),
        child: Stack(fit: StackFit.expand, children: [
          NetImg(category.image.isNotEmpty ? category.image : (category.products.first.image), bg: Colors.white),
          Positioned(
            left: 12,
            right: 12,
            top: 10,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(category.name, maxLines: 2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: RH.ink, height: 1.15)),
              const SizedBox(height: 2),
              Text('${category.products.length} поз.', style: const TextStyle(fontSize: 12, color: RH.inkMuted, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}

void openCategory(BuildContext context, String id) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryScreen(initialId: id)));
}

class BannerCarousel extends StatefulWidget {
  final List<PromoBanner> banners;
  const BannerCarousel({super.key, required this.banners});
  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _pc = PageController(viewportFraction: 0.92);
  int _page = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.banners.length < 2 || !_pc.hasClients) return;
      final next = (_page + 1) % widget.banners.length;
      _pc.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.banners;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(children: [
        AspectRatio(
          aspectRatio: 2 / 0.92,
          child: PageView.builder(
            controller: _pc,
            itemCount: b.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (c, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _BannerCard(banner: b[i]),
            ),
          ),
        ),
        if (b.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < b.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(color: i == _page ? RH.red : RH.line, borderRadius: BorderRadius.circular(3)),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final PromoBanner banner;
  const _BannerCard({required this.banner});
  @override
  Widget build(BuildContext context) {
    final hasText = banner.title.isNotEmpty || banner.subtitle.isNotEmpty;
    return Material(
      color: RH.surface,
      borderRadius: BorderRadius.circular(RH.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: banner.action == 'none' ? null : () => handleBannerTap(context, banner),
        child: Stack(fit: StackFit.expand, children: [
          NetImg(banner.image),
          if (hasText)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xCC000000), Colors.transparent], stops: [0, 0.75]),
              ),
            ),
          if (hasText)
            Positioned(
              left: 18,
              top: 0,
              bottom: 0,
              right: 90,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (banner.title.isNotEmpty)
                  Text(banner.title, maxLines: 2, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                if (banner.subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(banner.subtitle, maxLines: 2, style: const TextStyle(fontSize: 14, color: Color(0xFFEDE5DA))),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}

Future<void> handleBannerTap(BuildContext context, PromoBanner b) async {
  final store = StoreScope.read(context);
  switch (b.action) {
    case 'category':
      if (store.category(b.value) != null) openCategory(context, b.value);
    case 'product':
      final p = store.product(b.value);
      if (p != null) openProduct(context, p);
    case 'url':
      final u = Uri.tryParse(b.value);
      if (u != null) launchUrl(u, mode: LaunchMode.externalApplication);
    case 'promo':
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(b.title.isNotEmpty ? b.title : 'Промокод', style: Theme.of(c).textTheme.titleLarge),
              if (b.subtitle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(b.subtitle, style: const TextStyle(color: RH.muted))),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(border: Border.all(color: RH.gold, width: 1.5), borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: SelectableText(b.value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3, color: RH.gold)),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                icon: const Icon(Icons.local_offer_outlined),
                label: const Text('Применить к заказу'),
                onPressed: () async {
                  Navigator.pop(c);
                  try {
                    final p = await store.applyPromo(b.value);
                    if (context.mounted) toast(context, 'Промокод ${p.code} применён — скидка ${p.label} на товары');
                  } catch (e) {
                    if (context.mounted) toast(context, '$e');
                  }
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Скопировать'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: b.value));
                  Navigator.pop(c);
                  toast(context, 'Промокод скопирован');
                },
              ),
            ]),
          ),
        ),
      );
  }
}
