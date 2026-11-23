import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Приводит ввод к формату сайта 8XXXXXXXXXX. null — если номер некорректный.
String? normalizePhone(String s) {
  var d = s.replaceAll(RegExp(r'\D'), '');
  if (d.length == 10 && d.startsWith('9')) d = '8$d';
  if (d.length == 11 && d.startsWith('7')) d = '8${d.substring(1)}';
  return RegExp(r'^8\d{10}$').hasMatch(d) ? d : null;
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _phone, _address, _apt, _comment, _accrual;
  String? _districtId;
  String _payment = 'Наличные';
  int _sticks = 0;
  bool _sending = false;
  // предзаказ
  bool _asap = true;
  List<PreDay>? _days;
  bool _slotsError = false;
  String? _preDate, _preTime;

  @override
  void initState() {
    super.initState();
    final p = StoreScope.read(context).profile;
    _name = TextEditingController(text: p.name);
    _phone = TextEditingController(text: p.phone);
    _address = TextEditingController(text: p.address);
    _apt = TextEditingController(text: p.apartment);
    _comment = TextEditingController();
    _accrual = TextEditingController();
    _districtId = StoreScope.read(context).districtById(p.districtId)?.id;
    final store = StoreScope.read(context);
    if (!store.config!.isOpenNow && store.config!.preorderEnabled) _asap = false;
    if (store.config!.preorderEnabled) _loadSlots();
    store.refreshBonus();
  }

  Future<void> _loadSlots() async {
    setState(() => _slotsError = false);
    try {
      final d = await StoreScope.read(context).api.slots();
      if (!mounted) return;
      setState(() {
        _days = d;
        if (_preDate == null || !d.any((x) => x.date == _preDate)) {
          _preDate = d.where((x) => x.hasFree).firstOrNull?.date;
          _preTime = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _slotsError = true);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _apt, _comment, _accrual]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final store = StoreScope.read(context);
    final district = _districtId == null ? null : store.districtById(_districtId!);
    if (!_form.currentState!.validate() || district == null) {
      if (district == null) toast(context, 'Выберите район доставки или самовывоз');
      return;
    }
    final cfg = store.config!;
    if (!_asap && (_preDate == null || _preTime == null)) {
      toast(context, 'Выберите дату и время предзаказа');
      return;
    }
    if (_asap && !cfg.isOpenNow) {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: RH.surface,
          title: const Text('Сейчас мы закрыты'),
          content: Text('${cfg.closedText}\n\nОтправить заказ? Мы обработаем его, как только откроемся.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Отправить')),
          ],
        ),
      );
      if (go != true) return;
    }
    setState(() => _sending = true);
    try {
      final total = store.totalNoDelivery + district.feeFor(store.totalNoDelivery);
      final (number, notify) = await store.placeOrder(
        name: _name.text.trim(),
        phone: normalizePhone(_phone.text)!,
        district: district,
        address: _address.text.trim(),
        apartment: _apt.text.trim(),
        payment: _payment,
        chopsticks: _sticks,
        comment: _comment.text.trim(),
        accrualCode: store.vkToken != null ? '' : _accrual.text.trim().toUpperCase(),
        preDate: _asap ? null : _preDate,
        preTime: _asap ? null : _preTime,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => OrderDoneScreen(total: total, number: number, notify: notify, when: _asap ? null : '$_preTime')),
        (r) => r.isFirst,
      );
    } catch (e) {
      if (mounted) {
        toast(context, '$e');
        if (!_asap) _loadSlots(); // время могли занять — обновим сетку
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cfg = store.config!;
    final district = _districtId == null ? null : store.districtById(_districtId!);
    final goods = store.totalNoDelivery;
    final fee = district?.feeFor(goods) ?? 0;
    final feeUnknown = district != null && !district.isPickup && district.fee == 0 && district.freeFrom == null && district.note.isNotEmpty;

    String? deliveryHint;
    if (district != null && !district.isPickup && district.freeFrom != null && goods < district.freeFrom!) {
      deliveryHint = 'До бесплатной доставки ещё ${rub(district.freeFrom! - goods)}';
    } else if (district != null && district.note.isNotEmpty) {
      deliveryHint = district.note;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Оформление')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          const _H('Куда доставить'),
          DropdownButtonFormField<String>(
            initialValue: _districtId,
            isExpanded: true,
            dropdownColor: RH.surface2,
            decoration: const InputDecoration(labelText: 'Район *', prefixIcon: Icon(Icons.place_outlined)),
            items: [
              for (final d in cfg.districts)
                DropdownMenuItem(
                  value: d.id,
                  child: Text(d.isPickup ? d.name : '${d.name} · ${d.fee > 0 ? rub(d.fee) : 'цена у оператора'}${d.freeFrom != null ? ', бесплатно от ${rub(d.freeFrom!)}' : ''}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _districtId = v),
          ),
          if (deliveryHint != null) Padding(padding: const EdgeInsets.only(top: 8, left: 4), child: Text(deliveryHint, style: const TextStyle(color: RH.gold, fontSize: 13))),
          if (district != null && !district.isPickup) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Улица и дом *', hintText: 'ул. Ленина, 1'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Укажите адрес' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _apt, decoration: const InputDecoration(labelText: 'Квартира / офис')),
          ],
          if (cfg.preorderEnabled) ...[
            const _H('Когда'),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: const Text('Как можно скорее'), enabled: cfg.isOpenNow),
                const ButtonSegment(value: false, label: Text('Ко времени')),
              ],
              selected: {_asap},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: RH.red,
                selectedForegroundColor: Colors.white,
                minimumSize: const Size(0, 50),
                side: const BorderSide(color: RH.line),
              ),
              onSelectionChanged: (v) => setState(() => _asap = v.first),
            ),
            if (!cfg.isOpenNow)
              const Padding(padding: EdgeInsets.only(top: 8, left: 4), child: Text('Сейчас мы закрыты — выберите время, к которому привезти заказ.', style: TextStyle(color: RH.gold, fontSize: 13))),
            if (!_asap) ...[const SizedBox(height: 12), _slotPicker()],
          ],
          const _H('Контакты'),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+\-() ]'))],
            decoration: const InputDecoration(labelText: 'Телефон *', hintText: '8 978 123-45-67', prefixIcon: Icon(Icons.phone_outlined)),
            validator: (v) => normalizePhone(v ?? '') == null ? 'Номер из 11 цифр, например 8 978 123-45-67' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
            decoration: const InputDecoration(labelText: 'Имя', prefixIcon: Icon(Icons.person_outline_rounded)),
          ),
          const _H('Оплата при получении'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Наличные', label: Text('Наличные'), icon: Icon(Icons.payments_outlined)),
              ButtonSegment(value: 'Картой', label: Text('Картой'), icon: Icon(Icons.credit_card_rounded)),
            ],
            selected: {_payment},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: RH.red,
              selectedForegroundColor: Colors.white,
              minimumSize: const Size(0, 50),
              side: const BorderSide(color: RH.line),
            ),
            onSelectionChanged: (s) => setState(() => _payment = s.first),
          ),
          const _H('К заказу'),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            decoration: BoxDecoration(color: RH.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: RH.line)),
            child: Row(children: [
              const Expanded(child: Text('Палочки', style: TextStyle(fontSize: 16))),
              IconButton(tooltip: 'Меньше палочек', onPressed: _sticks > 0 ? () => setState(() => _sticks--) : null, icon: const Icon(Icons.remove_rounded)),
              SizedBox(width: 28, child: Text('$_sticks', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              IconButton(tooltip: 'Больше палочек', onPressed: _sticks < 30 ? () => setState(() => _sticks++) : null, icon: const Icon(Icons.add_rounded)),
            ]),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _comment,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Комментарий', hintText: 'Домофон, сдача с 5000, без лука…', alignLabelWithHint: true),
          ),
          const _H('Бонусные баллы'),
          _bonusBlock(store),
          if (store.vkToken == null) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _accrual,
            maxLength: 5,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Персональный код для бонусов', helperText: 'Необязательно. 5 букв — выдаёт наш бот', counterText: ''),
            validator: (v) {
              final s = (v ?? '').trim();
              return s.isEmpty || RegExp(r'^[A-Za-zА-Яа-яЁё]{5}$').hasMatch(s) ? null : 'Код — ровно 5 букв';
            },
          ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: RH.surface, borderRadius: BorderRadius.circular(RH.radius)),
            child: Column(children: [
              _Sum('Товары', rub(store.subtotal)),
              if (store.promoDiscount > 0) _Sum('Промокод ${store.promoCode}', '−${rub(store.promoDiscount)}'),
              if (store.pointsDiscount > 0) _Sum('Баллы (${store.effectiveSpend})', '−${rub(store.pointsDiscount)}'),
              _Sum('Доставка', district == null ? '—' : (feeUnknown ? 'уточнит оператор' : (fee == 0 ? 'бесплатно' : rub(fee)))),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
              _Sum('К оплате', rub(goods + fee), bold: true),
              if (store.accrualPoints > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    const Icon(Icons.stars_rounded, color: RH.gold, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        store.bonusUser != null
                            ? 'Начислим ${store.accrualPoints} баллов (${_pct(cfg.cashbackPercent)}%)${cfg.cashbackTitle.isNotEmpty ? ' · ${cfg.cashbackTitle}' : ''}'
                            : 'Войдите через ВК — начислим ${store.accrualPoints} баллов (${_pct(cfg.cashbackPercent)}%)',
                        style: const TextStyle(color: RH.gold, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text('Отправить заказ · ${rub(goods + fee)}'),
          ),
          const SizedBox(height: 10),
          const Text('После отправки оператор перезвонит, чтобы подтвердить заказ.', textAlign: TextAlign.center, style: TextStyle(color: RH.muted, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _slotPicker() {
    if (_slotsError) {
      return Row(children: [
        const Expanded(child: Text('Не удалось загрузить свободное время', style: TextStyle(color: RH.muted))),
        TextButton(onPressed: _loadSlots, child: const Text('Повторить')),
      ]);
    }
    final days = _days;
    if (days == null) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    if (days.isEmpty) return const Text('Свободного времени для предзаказа сейчас нет — позвоните нам.', style: TextStyle(color: RH.muted));
    final day = days.where((d) => d.date == _preDate).firstOrNull;
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (c, i) {
            final d = days[i];
            return ChoiceChip(
              label: Text(d.label(now)),
              selected: d.date == _preDate,
              onSelected: d.hasFree ? (_) => setState(() { _preDate = d.date; _preTime = null; }) : null,
              selectedColor: RH.red,
              labelStyle: TextStyle(color: d.hasFree ? RH.text : RH.muted, fontWeight: FontWeight.w600),
              showCheckmark: false,
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      if (day != null)
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in day.slots)
            ChoiceChip(
              label: Text(s.time),
              selected: s.time == _preTime,
              onSelected: s.free ? (_) => setState(() => _preTime = s.time) : null,
              selectedColor: RH.red,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: s.free ? RH.text : RH.muted,
                decoration: s.free ? null : TextDecoration.lineThrough,
                fontWeight: FontWeight.w600,
              ),
            ),
        ]),
      if (_preTime != null)
        Padding(
          padding: const EdgeInsets.only(top: 10, left: 4),
          child: Text('Привезём к $_preTime, ${day?.label(now).toLowerCase() ?? ''}', style: const TextStyle(color: RH.gold, fontSize: 13)),
        ),
    ]);
  }

  Widget _bonusBlock(AppStore store) {
    final u = store.bonusUser;
    if (u == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: RH.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: RH.line)),
        child: Row(children: [
          const Icon(Icons.stars_rounded, color: RH.gold),
          const SizedBox(width: 12),
          const Expanded(child: Text('Войдите, чтобы списать накопленные баллы', style: TextStyle(fontSize: 14))),
          TextButton(
            onPressed: () async {
              try {
                await store.loginVk();
              } catch (e) {
                if (mounted) toast(context, '$e');
              }
            },
            child: const Text('Войти через VK'),
          ),
        ]),
      );
    }
    final maxP = store.maxSpendPoints;
    return Container(
      decoration: BoxDecoration(color: RH.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: RH.line)),
      child: SwitchListTile(
        value: store.effectiveSpend > 0,
        onChanged: maxP > 0 ? store.setSpend : null,
        activeThumbColor: RH.red,
        title: Text('Списать баллы: ${maxP > 0 ? maxP : 0}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          maxP > 0
              ? 'Скидка ${rub(maxP * store.pointRub)} · на счёте ${u.points} б.'
              : (u.points > 0 ? 'На счёте ${u.points} б.' : 'Пока 0 баллов'),
          style: const TextStyle(color: RH.muted),
        ),
      ),
    );
  }
}

String _pct(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

class _H extends StatelessWidget {
  final String t;
  const _H(this.t);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(2, 22, 0, 10), child: Text(t, style: Theme.of(context).textTheme.titleMedium));
}

class _Sum extends StatelessWidget {
  final String l, v;
  final bool bold;
  const _Sum(this.l, this.v, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(l, style: TextStyle(color: bold ? RH.text : RH.muted, fontSize: bold ? 18 : 15, fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          Text(v, style: TextStyle(fontSize: bold ? 18 : 15, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );
}

class OrderDoneScreen extends StatelessWidget {
  final double total;
  final int number;
  final String notify;
  final String? when;
  const OrderDoneScreen({super.key, required this.total, this.number = 0, this.notify = 'none', this.when});
  @override
  Widget build(BuildContext context) {
    final cfg = StoreScope.of(context).config;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: RH.green.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: RH.green, size: 56),
            ),
            const SizedBox(height: 24),
            Text(number > 0 ? 'Заказ №$number оформлен!' : 'Заказ отправлен!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text('Сумма ${rub(total)}${when != null ? ', привезём к $when' : ''}. Оператор скоро вам позвонит, чтобы подтвердить заказ.',
                textAlign: TextAlign.center, style: const TextStyle(color: RH.muted, fontSize: 16, height: 1.45)),
            if (notify == 'sent')
              const Padding(padding: EdgeInsets.only(top: 12), child: Text('Подробности заказа отправили вам в сообщения ВКонтакте.', textAlign: TextAlign.center, style: TextStyle(color: RH.gold))),
            if (notify == 'not_allowed')
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Чтобы получать сообщения о заказе во ВКонтакте, напишите нам один раз в сообщения сообщества Roll House.',
                    textAlign: TextAlign.center, style: TextStyle(color: RH.muted, fontSize: 13)),
              ),
            if (cfg != null && cfg.phoneText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Вопросы: ${cfg.phoneText}', style: const TextStyle(color: RH.muted)),
            ],
            const Spacer(),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () {
                  StoreScope.read(context).tab.value = 0;
                  Navigator.pop(context);
                }, child: const Text('Вернуться в меню'))),
          ]),
        ),
      ),
    );
  }
}

