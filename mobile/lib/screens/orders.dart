import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  static const _months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
  static String _date(DateTime d) => '${d.day} ${_months[d.month - 1]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Мои заказы')),
      body: store.orders.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: RH.line),
                  SizedBox(height: 16),
                  Text('Здесь появятся ваши заказы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  SizedBox(height: 6),
                  Text('Любой заказ можно будет повторить в одно касание', textAlign: TextAlign.center, style: TextStyle(color: RH.muted)),
                ]),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: store.orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (c, i) => _OrderCard(order: store.orders[i]),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final PastOrder order;
  const _OrderCard({required this.order});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final count = order.lines.fold(0, (s, l) => s + l.qty);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: RH.surface, borderRadius: BorderRadius.circular(RH.radius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${order.number > 0 ? '№${order.number} · ' : ''}${OrdersScreen._date(order.date)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          Text(rub(order.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        const SizedBox(height: 4),
        Text('${order.when.isNotEmpty ? 'Предзаказ ${order.when} · ' : ''}${order.district} · $count поз. · ${order.payment}', style: const TextStyle(color: RH.muted, fontSize: 13)),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: order.lines.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (c, i) => ClipRRect(borderRadius: BorderRadius.circular(10), child: NetImg(order.lines[i].image, width: 56, height: 56)),
          ),
        ),
        const SizedBox(height: 10),
        Text(order.lines.map((l) => l.qty > 1 ? '${l.title} ×${l.qty}' : l.title).join(', '),
            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFD9D2C7), fontSize: 14)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Повторить заказ'),
            onPressed: () {
              final missed = store.repeat(order);
              toast(context, missed == 0 ? 'Добавили в корзину' : 'Добавили в корзину. $missed поз. больше нет в меню');
              store.tab.value = 1;
            },
          ),
        ),
      ]),
    );
  }
}
