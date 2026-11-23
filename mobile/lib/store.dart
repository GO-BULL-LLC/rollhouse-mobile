// Состояние приложения: меню, настройки, корзина, профиль, история заказов.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

class Profile {
  String name, phone, districtId, address, apartment;
  Profile({this.name = '', this.phone = '', this.districtId = '', this.address = '', this.apartment = ''});
  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'district': districtId, 'address': address, 'apartment': apartment};
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: '${j['name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        districtId: '${j['district'] ?? ''}',
        address: '${j['address'] ?? ''}',
        apartment: '${j['apartment'] ?? ''}',
      );
}

enum LoadState { loading, ready, error }

class AppStore extends ChangeNotifier {
  final Api api = Api();
  /// Активная вкладка нижнего меню (0 меню, 1 корзина, 2 заказы, 3 профиль).
  final ValueNotifier<int> tab = ValueNotifier(0);
  late SharedPreferences _prefs;

  LoadState state = LoadState.loading;
  String? loadError;
  AppConfig? config;
  List<Category> categories = [];
  final Map<String, Product> _byId = {};

  final List<CartLine> cart = [];
  Promo? promo;
  String? get promoCode => promo?.code;

  Profile profile = Profile();
  List<PastOrder> orders = [];

  /// Бонусы: вход через ВКонтакте.
  String? vkToken;
  BonusUser? bonusUser;
  /// Сколько баллов списать в текущем заказе.
  int spendPoints = 0;

  static const _kBoot = 'bootstrap_cache', _kCart = 'cart', _kProfile = 'profile', _kOrders = 'orders', _kVk = 'vk_session';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      profile = Profile.fromJson(Map<String, dynamic>.from(jsonDecode(_prefs.getString(_kProfile) ?? '{}')));
    } catch (_) {}
    try {
      orders = [for (final o in jsonDecode(_prefs.getString(_kOrders) ?? '[]') as List) PastOrder.fromJson(Map<String, dynamic>.from(o))];
    } catch (_) {}
    try {
      cart.addAll([for (final l in jsonDecode(_prefs.getString(_kCart) ?? '[]') as List) CartLine.fromJson(Map<String, dynamic>.from(l))]);
    } catch (_) {}
    try {
      final v = jsonDecode(_prefs.getString(_kVk) ?? 'null');
      if (v is Map) {
        vkToken = '${v['token']}';
        bonusUser = BonusUser.fromJson(Map<String, dynamic>.from(v['user']));
      }
    } catch (_) {}
    final cached = _prefs.getString(_kBoot);
    if (cached != null) {
      try {
        _apply(cached);
        state = LoadState.ready;
      } catch (_) {}
    }
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final raw = await api.bootstrapRaw();
      _apply(raw);
      await _prefs.setString(_kBoot, raw);
      state = LoadState.ready;
      loadError = null;
    } catch (e) {
      loadError = 'Нет связи с сервером. Проверьте интернет.';
      if (config == null) state = LoadState.error;
    }
    notifyListeners();
  }

  void _apply(String raw) {
    final j = Map<String, dynamic>.from(jsonDecode(raw));
    config = AppConfig.fromJson(Map<String, dynamic>.from(j['config'] ?? const {}));
    categories = [
      for (final c in (j['categories'] as List? ?? const [])) Category.fromJson(Map<String, dynamic>.from(c)),
    ].where((c) => c.products.isNotEmpty).toList();
    _byId
      ..clear()
      ..addEntries(categories.expand((c) => c.products).map((p) => MapEntry(p.id, p)));
    _syncCartWithMenu();
  }

  /// Цены в корзине — всегда актуальные из меню; товары, которых больше нет, убираем.
  void _syncCartWithMenu() {
    if (_byId.isEmpty) return;
    final fresh = <CartLine>[];
    for (final l in cart) {
      final p = _byId[l.productId];
      if (p == null) continue;
      double price = p.price;
      if (l.variant.isNotEmpty || p.hasVariants) {
        final v = p.variants.where((v) => v.name == l.variant).firstOrNull;
        if (v == null) continue; // размер убрали или появились размеры — позицию выбираем заново
        price = v.price;
      }
      fresh.add(CartLine(productId: p.id, name: p.name, image: p.image, portion: p.portion, price: price, qty: l.qty, variant: l.variant));
    }
    cart
      ..clear()
      ..addAll(fresh);
    _saveCart();
  }

  Product? product(String id) => _byId[id];
  Category? category(String id) => categories.where((c) => c.id == id).firstOrNull;

  List<Product> get hits => productsByIds(config?.hits ?? const []);
  List<Product> productsByIds(List<String> ids) => [for (final id in ids) if (_byId[id] != null) _byId[id]!];

  List<Product> search(String q) {
    final s = q.trim().toLowerCase();
    if (s.length < 2) return const [];
    return _byId.values.where((p) => p.name.toLowerCase().contains(s) || p.description.toLowerCase().contains(s)).toList();
  }

  // ---------- корзина ----------
  /// Количество товара в корзине (все размеры) или конкретного размера.
  int qtyOf(String productId, [String? variant]) =>
      cart.where((l) => l.productId == productId && (variant == null || l.variant == variant)).fold(0, (s, l) => s + l.qty);
  int get cartCount => cart.fold(0, (s, l) => s + l.qty);
  double get subtotal => cart.fold(0.0, (s, l) => s + l.price * l.qty);
  /// Скидка по промокоду — только на товары, доставка не входит.
  double get promoDiscount => promo?.discountFor(subtotal) ?? 0;
  double get pointRub => config?.pointRub ?? 0.45;
  /// Сколько баллов максимум можно списать в этом заказе (не больше суммы товаров после промокода).
  int get maxSpendPoints {
    final u = bonusUser;
    if (u == null || u.points <= 0) return 0;
    final cap = ((subtotal - promoDiscount) / pointRub).floor();
    return max(0, min(u.points, cap));
  }

  int get effectiveSpend => min(spendPoints, maxSpendPoints);
  double get pointsDiscount => (effectiveSpend * pointRub * 100).round() / 100;
  double get discount => promoDiscount + pointsDiscount;
  double get totalNoDelivery => (subtotal - discount).clamp(0, double.infinity).toDouble();

  /// Сколько баллов начислим за заказ (кешбэк % от суммы к оплате за товары).
  int get accrualPoints {
    final pct = config?.cashbackPercent ?? 0;
    if (pct <= 0) return 0;
    return (totalNoDelivery * pct / 100 / pointRub).floor();
  }

  void setSpend(bool on) {
    spendPoints = on ? maxSpendPoints : 0;
    notifyListeners();
  }

  // ---------- вход через ВКонтакте (VK ID, PKCE) ----------
  static String _rand(int n) {
    const abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final r = Random.secure();
    return List.generate(n, (_) => abc[r.nextInt(abc.length)]).join();
  }

  Future<void> loginVk() async {
    final cfg = config!;
    final verifier = _rand(64);
    final challenge = base64Url.encode(sha256.convert(utf8.encode(verifier)).bytes).replaceAll('=', '');
    final state = 'app_${_rand(24)}';
    final url = Uri.https('id.vk.com', '/authorize', {
      'response_type': 'code',
      'client_id': cfg.vkClientId,
      'redirect_uri': cfg.vkRedirect,
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'scope': 'vkid.personal_info',
      'lang_id': '0',
      'scheme': 'dark',
    });
    final result = await FlutterWebAuth2.authenticate(url: url.toString(), callbackUrlScheme: 'rollhouse',
        options: const FlutterWebAuth2Options(preferEphemeral: false));
    final q = Uri.parse(result).queryParameters;
    if (q['state'] != state || (q['code'] ?? '').isEmpty) throw ApiException('Вход отменён');
    final (token, user) = await api.vkLogin(code: q['code']!, deviceId: q['device_id'] ?? '', verifier: verifier, state: state);
    vkToken = token;
    bonusUser = user;
    await _saveVk();
    notifyListeners();
  }

  Future<void> refreshBonus() async {
    if (vkToken == null) return;
    try {
      final u = await api.me(vkToken!);
      if (u == null) {
        await logoutVk();
        return;
      }
      bonusUser = u;
      await _saveVk();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logoutVk() async {
    vkToken = null;
    bonusUser = null;
    spendPoints = 0;
    await _prefs.remove(_kVk);
    notifyListeners();
  }

  Future<void> _saveVk() => _prefs.setString(_kVk, jsonEncode({'token': vkToken, 'user': bonusUser?.toJson()}));

  void add(Product p, [int n = 1, Variant? v]) {
    final variant = v?.name ?? '';
    final l = cart.where((l) => l.productId == p.id && l.variant == variant).firstOrNull;
    if (l != null) {
      l.qty += n;
    } else {
      cart.add(CartLine(productId: p.id, name: p.name, image: p.image, portion: p.portion, price: v?.price ?? p.price, qty: n, variant: variant));
    }
    _saveCart();
    notifyListeners();
  }

  /// [key] — CartLine.key (id или id|размер).
  void setQty(String key, int qty) {
    final l = cart.where((l) => l.key == key).firstOrNull;
    if (l == null) return;
    if (qty <= 0) {
      cart.remove(l);
    } else {
      l.qty = qty;
    }
    if (cart.isEmpty) clearPromo(notify: false);
    _saveCart();
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    spendPoints = 0;
    clearPromo(notify: false);
    _saveCart();
    notifyListeners();
  }

  void _saveCart() => _prefs.setString(_kCart, jsonEncode([for (final l in cart) l.toJson()]));

  /// Сначала промокоды приложения (RH-5 и т.п.), затем одноразовые коды из бота.
  Future<Promo> applyPromo(String code) async {
    final p = await api.findPromo(code.trim().toUpperCase());
    promo = p;
    notifyListeners();
    return p;
  }

  void clearPromo({bool notify = true}) {
    promo = null;
    if (notify) notifyListeners();
  }

  // ---------- профиль ----------
  Future<void> saveProfile(Profile p) async {
    profile = p;
    await _prefs.setString(_kProfile, jsonEncode(p.toJson()));
    notifyListeners();
  }

  District? districtById(String id) => config?.districts.where((d) => d.id == id).firstOrNull;

  // ---------- заказ ----------
  /// Возвращает (номер заказа, статус уведомления в ВК).
  Future<(int, String)> placeOrder({
    required String name,
    required String phone,
    required District district,
    required String address,
    required String apartment,
    required String payment,
    required int chopsticks,
    required String comment,
    required String accrualCode,
    String? preDate,
    String? preTime,
  }) async {
    final total = totalNoDelivery;
    final fee = district.feeFor(total);
    final fullAddress = district.isPickup ? 'Самовывоз' : (address.isEmpty ? 'Адрес не указан' : '$address${apartment.isNotEmpty ? ', кв./офис $apartment' : ''}');
    final items = cart.map((l) => '${l.title} - ${l.qty} шт.').join('\n');
    final feeText = district.fee == 0 && district.freeFrom == null && !district.isPickup && district.note.isNotEmpty ? 'уточнит оператор' : '$fee руб.';

    final b = StringBuffer()
      ..writeln('📍 Район: ${district.name}')
      ..writeln('🗺 Адрес: $fullAddress')
      ..writeln('📲 Телефон: $phone');
    if (name.isNotEmpty) b.writeln('👤 Имя: $name');
    b
      ..writeln('💰 Оплата: $payment')
      ..writeln('⚔️ Палочки: $chopsticks')
      ..writeln('📝 Комментарий: ${comment.isEmpty ? 'Нет комментариев' : comment}')
      ..writeln()
      ..writeln('🛒 Корзина:')
      ..writeln(items)
      ..writeln()
      ..writeln('🤑 Итого: ${total.toStringAsFixed(2)} руб.')
      ..writeln('🚚 Доставка: $feeText')
      ..write('🧾 Скидка: -${discount.toStringAsFixed(2)} руб.');
    if (promo != null) b.write('\n🏷 Промокод: ${promo!.code} (${promo!.label}${promoDiscount == 0 ? ', не применён: сумма меньше ${promo!.minOrder} руб.' : ''})');
    if (accrualCode.isNotEmpty) b.write('\n🎫 Персональный код (начислить): $accrualCode');
    b.write('\n💳 К оплате с доставкой: ${(total + fee).toStringAsFixed(2)} руб.');

    final spend = effectiveSpend;
    // Текст для клиента (уведомление в ВК)
    final c = StringBuffer()
      ..writeln(cart.map((l) => '• ${l.title} × ${l.qty} — ${rub(l.price * l.qty)}').join('\n'))
      ..writeln()
      ..writeln(district.isPickup ? '🏠 Самовывоз' : '🚚 ${district.name}, $fullAddress')
      ..writeln('💰 Оплата: $payment');
    if (discount > 0) c.writeln('🧾 Скидка: −${rub(discount)}');
    c.write('💳 К оплате: ${rub(total + fee)}');
    final (number, notify) = await api.sendOrder(
      details: b.toString(),
      customer: c.toString(),
      accrualCode: accrualCode,
      total: total,
      token: vkToken,
      preDate: preDate,
      preTime: preTime,
      spendPoints: spend,
    );
    if (spend > 0 && bonusUser != null) {
      final u = bonusUser!;
      bonusUser = BonusUser(id: u.id, firstName: u.firstName, lastName: u.lastName, picture: u.picture, points: u.points - spend);
      await _saveVk();
    }
    if (promo != null && promo!.bot && discount > 0) await api.markPromoUsed(promo!.code);

    orders.insert(
      0,
      PastOrder(
        number: number,
        when: preDate == null ? '' : '${preDate.substring(8, 10)}.${preDate.substring(5, 7)} к $preTime',
        date: DateTime.now(),
        lines: [for (final l in cart) CartLine.fromJson(l.toJson())],
        total: total + fee,
        delivery: fee,
        district: district.name,
        address: fullAddress,
        payment: payment,
      ),
    );
    if (orders.length > 50) orders = orders.sublist(0, 50);
    await _prefs.setString(_kOrders, jsonEncode([for (final o in orders) o.toJson()]));

    await saveProfile(Profile(name: name, phone: phone, districtId: district.id, address: address, apartment: apartment));
    clearCart();
    return (number, notify);
  }

  /// Повтор заказа: кладём в корзину то, что ещё есть в меню. Возвращает число пропущенных позиций.
  int repeat(PastOrder o) {
    var missed = 0;
    for (final l in o.lines) {
      final p = _byId[l.productId];
      final v = p?.variants.where((v) => v.name == l.variant).firstOrNull;
      if (p == null || (p.hasVariants && v == null)) {
        missed++;
      } else {
        add(p, l.qty, v);
      }
    }
    return missed;
  }

  Future<void> clearPersonalData() async {
    orders = [];
    profile = Profile();
    await _prefs.remove(_kOrders);
    await _prefs.remove(_kProfile);
    notifyListeners();
  }
}

/// Доступ к стору из дерева виджетов.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);
  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static AppStore read(BuildContext context) => context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
