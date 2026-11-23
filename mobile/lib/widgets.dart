import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

class NetImg extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width, height;
  const NetImg(this.url, {super.key, this.fit = BoxFit.cover, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    final ph = Container(
      width: width,
      height: height,
      color: RH.surface2,
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant_rounded, color: RH.line, size: 32),
    );
    if (url.isEmpty) return ph;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => ph,
      errorWidget: (_, _, _) => ph,
    );
  }
}

/// Кнопка «−  n  +», при n == 0 — кнопка «+ цена».
class QtyControl extends StatelessWidget {
  final Product product;
  final Variant? variant;
  final bool compact;
  const QtyControl({super.key, required this.product, this.variant, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final h = compact ? 40.0 : 52.0;
    // В сетке у товара с размерами — кнопка «от …», размер выбирается в карточке
    if (compact && product.hasVariants) {
      final inCart = store.qtyOf(product.id);
      return SizedBox(
        height: h,
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: Size(0, h),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            backgroundColor: inCart > 0 ? RH.red : RH.surface2,
            foregroundColor: RH.text,
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          onPressed: () => openProduct(context, product),
          child: Text(inCart > 0 ? 'В корзине · $inCart' : 'от ${rub(product.price)}'),
        ),
      );
    }
    final key = variant == null ? product.id : '${product.id}|${variant!.name}';
    final price = variant?.price ?? product.price;
    final q = store.qtyOf(product.id, variant?.name ?? '');
    if (q == 0) {
      return SizedBox(
        height: h,
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: Size(0, h),
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 20),
            backgroundColor: compact ? RH.surface2 : RH.red,
            foregroundColor: RH.text,
            textStyle: TextStyle(fontSize: compact ? 15 : 16, fontWeight: FontWeight.w700),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            store.add(product, 1, variant);
          },
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, size: compact ? 18 : 20),
            const SizedBox(width: 4),
            Text(compact ? rub(price) : 'В корзину · ${rub(price)}'),
          ]),
        ),
      );
    }
    return Container(
      height: h,
      decoration: BoxDecoration(color: RH.red, borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _btn(Icons.remove_rounded, 'Убрать одну', () => store.setQty(key, q - 1), h),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('$q', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        _btn(Icons.add_rounded, 'Добавить ещё', () => store.add(product, 1, variant), h),
      ]),
    );
  }

  Widget _btn(IconData i, String label, VoidCallback onTap, double h) => Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(width: h + 4, height: h, child: Icon(i, color: Colors.white, size: 20)),
        ),
      );
}

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RH.surface,
      borderRadius: BorderRadius.circular(RH.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openProduct(context, product),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(aspectRatio: 1, child: Hero(tag: 'p-${product.id}', child: NetImg(product.image))),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25)),
                if (product.portion.isNotEmpty && product.portion != '1 шт')
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(product.portion, style: const TextStyle(fontSize: 13, color: RH.muted))),
                const Spacer(),
                QtyControl(product: product),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Сетка карточек: 2 колонки на телефоне, больше на планшете.
SliverGrid productGrid(List<Product> items) => SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.58,
      ),
      delegate: SliverChildBuilderDelegate((c, i) => ProductCard(key: ValueKey(items[i].id), product: items[i]), childCount: items.length),
    );

Future<void> openProduct(BuildContext context, Product p) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    clipBehavior: Clip.antiAlias,
    builder: (c) => _ProductSheet(product: p),
  );
}

class _ProductSheet extends StatefulWidget {
  final Product product;
  const _ProductSheet({required this.product});
  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  Variant? _v;

  @override
  void initState() {
    super.initState();
    final vs = widget.product.variants;
    if (vs.isNotEmpty) _v = vs.first; // по умолчанию меньший размер — цена совпадает с «от …» в сетке
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final store = StoreScope.of(context);
    final cat = store.category(product.categoryId);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (c, scroll) => Stack(children: [
        ListView(controller: scroll, padding: EdgeInsets.zero, children: [
          AspectRatio(aspectRatio: 1.1, child: Hero(tag: 'p-${product.id}', child: NetImg(product.image))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (cat != null) Text(cat.name.toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: 1.2, color: RH.gold, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
              if (product.portion.isNotEmpty && !product.hasVariants)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(product.portion, style: const TextStyle(color: RH.muted))),
              const SizedBox(height: 14),
              if (product.hasVariants) ...[
                const Text('Размер', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [for (final v in product.variants) ButtonSegment(value: v.name, label: Text(v.name))],
                    selected: {_v!.name},
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: RH.red,
                      selectedForegroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      side: const BorderSide(color: RH.line),
                    ),
                    onSelectionChanged: (sel) => setState(() => _v = product.variants.firstWhere((v) => v.name == sel.first)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (product.description.isNotEmpty) Text(product.description, style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFFD9D2C7))),
            ]),
          ),
        ]),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(tooltip: 'Закрыть', icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
            decoration: const BoxDecoration(color: RH.surface, border: Border(top: BorderSide(color: RH.line))),
            child: Row(children: [
              Text(rub(_v?.price ?? product.price), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const Spacer(),
              QtyControl(product: product, variant: _v, compact: false),
            ]),
          ),
        ),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Row(children: [Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge)), ?trailing]),
      );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
