import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'checkout.dart';

class CartScreen extends StatefulWidget {
  final bool standalone;
  final VoidCallback? onGoMenu;
  const CartScreen({super.key, this.standalone = false, this.onGoMenu});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _promo = TextEditingController();
  bool _checking = false;

  @override
  void dispose() {
    _promo.dispose();
    super.dispose();
  }

  Future<void> _applyPromo() async {
    final code = _promo.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _checking = true);
    try {
      final p = await StoreScope.read(context).applyPromo(code);
      if (mounted) toast(context, p.title.isNotEmpty ? 'Промокод применён: ${p.title}' : 'Промокод применён');
      _promo.clear();
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cfg = store.config!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Корзина'),
        actions: [
          if (store.cart.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: RH.surface,
                    title: const Text('Очистить корзину?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Нет')),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Очистить', style: TextStyle(color: RH.red))),
                    ],
                  ),
                );
                if (ok == true) store.clearCart();
              },
              child: const Text('Очистить', style: TextStyle(color: RH.muted)),
            ),
        ],
      ),
      body: store.cart.isEmpty
          ? _Empty(onGoMenu: widget.standalone ? () => Navigator.pop(context) : widget.onGoMenu)
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
              _FreeDelivery(),
              for (final l in store.cart) _Line(key: ValueKey(l.key), line: l),
              if (store.upsell.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Добавить к заказу', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 178,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: store.upsell.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (c, i) => _UpsellCard(product: store.upsell[i]),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (store.promoCode == null)
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _promo,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Промокод на скидку', prefixIcon: Icon(Icons.local_offer_outlined)),
                      onSubmitted: (_) => _applyPromo(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      onPressed: _checking ? null : _applyPromo,
                      child: _checking ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Применить'),
                    ),
                  ),
                ])
              else
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                  decoration: BoxDecoration(color: RH.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: RH.green.withValues(alpha: 0.5))),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded, color: RH.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${store.promoCode} · ${store.promo!.label}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          store.discount > 0 ? 'Скидка ${rub(store.discount)} на товары, доставка не входит' : 'Действует от ${rub(store.promo!.minOrder)}',
                          style: const TextStyle(color: RH.muted, fontSize: 13),
                        ),
                      ]),
                    ),
                    IconButton(tooltip: 'Убрать промокод', onPressed: store.clearPromo, icon: const Icon(Icons.close_rounded, color: RH.muted)),
                  ]),
                ),
              if (cfg.bonusText.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 10), child: Text(cfg.bonusText, style: const TextStyle(color: RH.muted, fontSize: 13))),
              const SizedBox(height: 20),
              _SumRow('Товары', rub(store.subtotal)),
              if (store.discount > 0) _SumRow('Скидка', '−${rub(store.discount)}', color: RH.green),
              const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
              _SumRow('Итого без доставки', rub(store.totalNoDelivery), bold: true),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Стоимость доставки зависит от района — посчитаем на следующем шаге.', style: TextStyle(color: RH.muted, fontSize: 13)),
              ),
            ]),
      bottomNavigationBar: store.cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Builder(builder: (context) {
                  final short = cfg.minOrder > 0 && store.totalNoDelivery < cfg.minOrder;
                  return FilledButton(
                    onPressed: short ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                    child: Text(short ? 'Минимальный заказ ${rub(cfg.minOrder)}' : 'Оформить · ${rub(store.totalNoDelivery)}'),
                  );
                }),
              ),
            ),
    );
  }
}

class _Line extends StatelessWidget {
  final CartLine line;
  const _Line({super.key, required this.line});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = store.product(line.productId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        GestureDetector(
          onTap: p == null ? null : () => openProduct(context, p),
          child: ClipRRect(borderRadius: BorderRadius.circular(14), child: NetImg(line.image, width: 76, height: 76)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(line.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(rub(line.price * line.qty), style: const TextStyle(color: RH.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          height: 40,
          decoration: BoxDecoration(color: RH.surface2, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            IconButton(
              tooltip: 'Меньше',
              visualDensity: VisualDensity.compact,
              icon: Icon(line.qty == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded, size: 20),
              onPressed: () => store.setQty(line.key, line.qty - 1),
            ),
            Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.w800)),
            IconButton(
              tooltip: 'Больше',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_rounded, size: 20),
              onPressed: () => store.setQty(line.key, line.qty + 1),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// «До бесплатной доставки осталось …» — по району из прошлого заказа.
class _FreeDelivery extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = store.savedDistrict;
    final from = d?.freeFrom;
    if (d == null || d.isPickup || from == null || from <= 0 || d.fee == 0) return const SizedBox.shrink();
    final total = store.totalNoDelivery;
    final left = from - total;
    final done = left <= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: RH.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(done ? Icons.check_circle_rounded : Icons.delivery_dining_rounded, color: done ? RH.green : RH.gold, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              done ? 'Доставка в ${d.name} — бесплатно' : 'Ещё ${rub(left)} до бесплатной доставки в ${d.name}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (total / from).clamp(0, 1).toDouble(),
            minHeight: 6,
            backgroundColor: RH.surface2,
            color: done ? RH.green : RH.gold,
          ),
        ),
      ]),
    );
  }
}

class _UpsellCard extends StatelessWidget {
  final Product product;
  const _UpsellCard({required this.product});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return SizedBox(
      width: 120,
      child: Material(
        color: RH.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openProduct(context, product),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(height: 84, child: NetImg(product.image, bg: Colors.white)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: SizedBox(
                height: 34,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: EdgeInsets.zero,
                    backgroundColor: RH.surface2,
                    foregroundColor: RH.text,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    store.add(product);
                  },
                  child: Text('+ ${rub(product.price)}'),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SumRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const _SumRow(this.label, this.value, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) {
    final st = TextStyle(fontSize: bold ? 18 : 15, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [Expanded(child: Text(label, style: st.copyWith(color: color ?? (bold ? RH.text : RH.muted)))), Text(value, style: st)]),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback? onGoMenu;
  const _Empty({this.onGoMenu});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.shopping_bag_outlined, size: 64, color: RH.line),
            const SizedBox(height: 16),
            Text('В корзине пока пусто', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Загляните в меню — там роллы, сеты и пицца', textAlign: TextAlign.center, style: TextStyle(color: RH.muted)),
            if (onGoMenu != null) ...[const SizedBox(height: 20), FilledButton(onPressed: onGoMenu, child: const Text('Открыть меню'))],
          ]),
        ),
      );
}
