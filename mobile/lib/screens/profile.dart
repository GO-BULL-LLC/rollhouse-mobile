import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'checkout.dart' show normalizePhone;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name, _phone, _address, _apt;
  String? _district;

  @override
  void initState() {
    super.initState();
    StoreScope.read(context).refreshBonus();
    final p = StoreScope.read(context).profile;
    _name = TextEditingController(text: p.name);
    _phone = TextEditingController(text: p.phone);
    _address = TextEditingController(text: p.address);
    _apt = TextEditingController(text: p.apartment);
    _district = StoreScope.read(context).districtById(p.districtId)?.id;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _apt]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final phone = _phone.text.trim().isEmpty ? '' : normalizePhone(_phone.text);
    if (phone == null) {
      toast(context, 'Проверьте номер телефона');
      return;
    }
    FocusScope.of(context).unfocus();
    await StoreScope.read(context).saveProfile(Profile(
      name: _name.text.trim(),
      phone: phone,
      districtId: _district ?? '',
      address: _address.text.trim(),
      apartment: _apt.text.trim(),
    ));
    if (mounted) toast(context, 'Сохранено — подставим при заказе');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cfg = store.config!;
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: RH.surface, borderRadius: BorderRadius.circular(RH.radius)),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: (cfg.isOpenNow ? RH.green : RH.red).withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(Icons.schedule_rounded, color: cfg.isOpenNow ? RH.green : RH.red),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cfg.isOpenNow ? 'Сейчас открыто' : 'Сейчас закрыто', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(cfg.scheduleText, style: const TextStyle(color: RH.muted)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _BonusCard(store: store),
        const SizedBox(height: 22),
        Text('Мои данные для заказа', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Имя')),
        const SizedBox(height: 10),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Телефон', hintText: '8 978 123-45-67')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _district,
          isExpanded: true,
          dropdownColor: RH.surface2,
          decoration: const InputDecoration(labelText: 'Район'),
          items: [for (final d in cfg.districts) DropdownMenuItem(value: d.id, child: Text(d.name))],
          onChanged: (v) => setState(() => _district = v),
        ),
        const SizedBox(height: 10),
        TextField(controller: _address, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Улица и дом')),
        const SizedBox(height: 10),
        TextField(controller: _apt, decoration: const InputDecoration(labelText: 'Квартира / офис')),
        const SizedBox(height: 12),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
        const SizedBox(height: 26),
        Text('Связаться с нами', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (cfg.phone.isNotEmpty) _Link(Icons.call_outlined, 'Позвонить', cfg.phoneText, () => launchUrl(Uri.parse('tel:${cfg.phone}'))),
        if (cfg.address.isNotEmpty) _Link(Icons.storefront_outlined, 'Адрес', cfg.address, null),
        const SizedBox(height: 18),
        _Link(Icons.privacy_tip_outlined, 'Политика конфиденциальности', null,
            () => launchUrl(Uri.parse('$kBase/app-api/privacy.html'), mode: LaunchMode.inAppBrowserView)),
        _Link(Icons.delete_outline_rounded, 'Удалить мои данные', 'История заказов и сохранённый адрес', () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              backgroundColor: RH.surface,
              title: const Text('Удалить данные?'),
              content: const Text('Удалим историю заказов, телефон и адрес с этого устройства.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Удалить', style: TextStyle(color: RH.red))),
              ],
            ),
          );
          if (ok != true) return;
          await store.clearPersonalData();
          _name.clear();
          _phone.clear();
          _address.clear();
          _apt.clear();
          setState(() => _district = null);
          if (context.mounted) toast(context, 'Данные удалены');
        }),
        const SizedBox(height: 18),
        const Center(child: Text('Ролл Хаус · версия $kAppVersion', style: TextStyle(color: RH.muted, fontSize: 12))),
      ]),
    );
  }
}

class _Link extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _Link(this.icon, this.title, this.subtitle, this.onTap);
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        minVerticalPadding: 12,
        leading: Icon(icon, color: RH.gold),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(color: RH.muted)),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded, color: RH.muted),
        onTap: onTap,
      );
}

class _BonusCard extends StatefulWidget {
  final AppStore store;
  const _BonusCard({required this.store});
  @override
  State<_BonusCard> createState() => _BonusCardState();
}

class _BonusCardState extends State<_BonusCard> {
  bool _busy = false;

  Future<void> _login() async {
    setState(() => _busy = true);
    try {
      await widget.store.loginVk();
      if (mounted) toast(context, 'Готово! Баллы подключены');
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final u = store.bonusUser;
    final deco = BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF3A1712), RH.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(RH.radius),
      border: Border.all(color: RH.red.withValues(alpha: 0.35)),
    );
    if (u == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: deco,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.stars_rounded, color: RH.gold, size: 28),
            SizedBox(width: 10),
            Text('Бонусные баллы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Text('Баллы копятся за заказы (${store.config!.cashbackPercent % 1 == 0 ? store.config!.cashbackPercent.toInt() : store.config!.cashbackPercent}% суммы) и за лайки и комментарии в нашей группе. Войдите через ВКонтакте и списывайте их в заказе: 1 балл = 0,45 ₽.',
              style: TextStyle(color: Color(0xFFD9D2C7), height: 1.4)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _login,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0077FF)),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Войти через ВКонтакте'),
            ),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: deco,
      child: Row(children: [
        CircleAvatar(radius: 26, backgroundColor: RH.surface2, backgroundImage: u.picture.isNotEmpty ? NetworkImage(u.picture) : null,
            child: u.picture.isEmpty ? const Icon(Icons.person_rounded) : null),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.name.isEmpty ? 'Бонусный счёт' : u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${u.points} баллов', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: RH.gold)),
            Text('≈ ${rub(u.points * store.pointRub)} скидки', style: const TextStyle(color: RH.muted, fontSize: 13)),
          ]),
        ),
        IconButton(tooltip: 'Обновить', onPressed: store.refreshBonus, icon: const Icon(Icons.refresh_rounded, color: RH.muted)),
        IconButton(
          tooltip: 'Выйти',
          icon: const Icon(Icons.logout_rounded, color: RH.muted),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                backgroundColor: RH.surface,
                title: const Text('Выйти из бонусного счёта?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Нет')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Выйти', style: TextStyle(color: RH.red))),
                ],
              ),
            );
            if (ok == true) store.logoutVk();
          },
        ),
      ]),
    );
  }
}
