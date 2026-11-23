// Модели данных приложения Roll House.

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int? _iOrNull(dynamic v) => v == null || v == '' ? null : (v is num ? v.toInt() : int.tryParse('$v'));

class Variant {
  final String name;
  final double price;
  const Variant(this.name, this.price);
}

class Product {
  final String id, name, description, portion, image, categoryId;
  final double price;
  /// Размеры с разной ценой (пусто — одна цена).
  final List<Variant> variants;
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.portion,
    required this.image,
    required this.price,
    required this.categoryId,
    this.variants = const [],
  });

  bool get hasVariants => variants.isNotEmpty;

  factory Product.fromJson(Map<String, dynamic> j, String categoryId) => Product(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        description: '${j['description'] ?? ''}',
        portion: '${j['portion'] ?? ''}',
        image: '${j['image'] ?? ''}',
        price: _d(j['price']),
        categoryId: categoryId,
        variants: [
          for (final v in (j['variants'] as List? ?? const []))
            if (v is Map && '${v['name'] ?? ''}'.isNotEmpty) Variant('${v['name']}', _d(v['price'])),
        ],
      );
}

class Category {
  final String id, name, subtitle, image;
  final List<Product> products;
  const Category({required this.id, required this.name, required this.subtitle, required this.image, required this.products});

  factory Category.fromJson(Map<String, dynamic> j) {
    final id = '${j['id']}';
    return Category(
      id: id,
      name: '${j['name'] ?? ''}',
      subtitle: '${j['subtitle'] ?? ''}',
      image: '${j['image'] ?? ''}',
      products: [for (final p in (j['products'] as List? ?? const [])) Product.fromJson(Map<String, dynamic>.from(p), id)],
    );
  }
}

class PromoBanner {
  final String id, image, title, subtitle, action, value;
  const PromoBanner({required this.id, required this.image, required this.title, required this.subtitle, required this.action, required this.value});
  factory PromoBanner.fromJson(Map<String, dynamic> j) => PromoBanner(
        id: '${j['id'] ?? ''}',
        image: '${j['image'] ?? ''}',
        title: '${j['title'] ?? ''}',
        subtitle: '${j['subtitle'] ?? ''}',
        action: '${j['action'] ?? 'none'}',
        value: '${j['value'] ?? ''}',
      );
}

class District {
  final String id, name, note;
  final int fee;
  final int? freeFrom;
  const District({required this.id, required this.name, required this.fee, required this.freeFrom, required this.note});
  factory District.fromJson(Map<String, dynamic> j) => District(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        fee: _iOrNull(j['fee']) ?? 0,
        freeFrom: _iOrNull(j['freeFrom']),
        note: '${j['note'] ?? ''}',
      );

  bool get isPickup => id == 'pickup';

  /// Стоимость доставки при сумме заказа [total] (со скидкой, без доставки) — как на сайте.
  int feeFor(double total) {
    if (freeFrom != null && total >= freeFrom!) return 0;
    return fee;
  }
}

class Collection {
  final String id, title, subtitle, image;
  final List<String> products;
  const Collection({required this.id, required this.title, required this.subtitle, required this.image, required this.products});
  factory Collection.fromJson(Map<String, dynamic> j) => Collection(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        subtitle: '${j['subtitle'] ?? ''}',
        image: '${j['image'] ?? ''}',
        products: [for (final p in (j['products'] as List? ?? const [])) '$p'],
      );
}

/// Применённый промокод: процент или рубли; [bot] — одноразовый код из бота (помечаем использованным).
class Promo {
  final String code, type, title;
  final double value;
  final int minOrder;
  final bool bot;
  const Promo({required this.code, required this.type, required this.value, this.minOrder = 0, this.title = '', this.bot = false});

  String get label => type == 'percent' ? '−${value % 1 == 0 ? value.toInt() : value}%' : '−${rub(value)}';

  /// Скидка только на товары (доставка не входит).
  double discountFor(double subtotal) {
    if (subtotal <= 0 || subtotal < minOrder) return 0;
    final d = type == 'percent' ? (subtotal * value / 100).roundToDouble() : value;
    return d > subtotal ? subtotal : d;
  }
}

class Announcement {
  final String text, style;
  const Announcement(this.text, this.style);
}

class AppConfig {
  final Announcement? announcement;
  final List<PromoBanner> banners;
  final List<Collection> collections;
  final List<String> hits;
  final List<District> districts;
  final List<int> openDays;
  final String open, close, closedText;
  final String phone, phoneText, address, bonusText;
  final int minOrder;
  final bool preorderEnabled;
  final double pointRub;
  final double cashbackPercent;
  final String cashbackTitle;
  final String vkClientId, vkRedirect;

  const AppConfig({
    required this.announcement,
    required this.banners,
    required this.collections,
    required this.hits,
    required this.districts,
    required this.openDays,
    required this.open,
    required this.close,
    required this.closedText,
    required this.phone,
    required this.phoneText,
    required this.address,
    required this.bonusText,
    required this.minOrder,
    required this.preorderEnabled,
    required this.pointRub,
    required this.cashbackPercent,
    required this.cashbackTitle,
    required this.vkClientId,
    required this.vkRedirect,
  });

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final an = j['announcement'];
    final hours = Map<String, dynamic>.from(j['hours'] ?? const {});
    final ct = Map<String, dynamic>.from(j['contacts'] ?? const {});
    return AppConfig(
      announcement: an is Map && '${an['text'] ?? ''}'.trim().isNotEmpty ? Announcement('${an['text']}', '${an['style'] ?? 'gold'}') : null,
      banners: [for (final b in (j['banners'] as List? ?? const [])) PromoBanner.fromJson(Map<String, dynamic>.from(b))],
      collections: [for (final c in (j['collections'] as List? ?? const [])) Collection.fromJson(Map<String, dynamic>.from(c))],
      hits: [for (final h in (j['hits'] as List? ?? const [])) '$h'],
      districts: [for (final d in (j['districts'] as List? ?? const [])) District.fromJson(Map<String, dynamic>.from(d))],
      openDays: [for (final d in (hours['days'] as List? ?? const [1, 2, 3, 4, 5, 6, 7])) _iOrNull(d) ?? 0],
      open: '${hours['open'] ?? '10:00'}',
      close: '${hours['close'] ?? '20:00'}',
      closedText: '${hours['closedText'] ?? ''}',
      phone: '${ct['phone'] ?? ''}',
      phoneText: '${ct['phoneText'] ?? ct['phone'] ?? ''}',
      address: '${ct['address'] ?? ''}',
      bonusText: '${j['bonusText'] ?? ''}',
      minOrder: _iOrNull(j['minOrder']) ?? 0,
      preorderEnabled: (j['preorder'] is Map) ? j['preorder']['enabled'] == true : false,
      pointRub: (j['points'] is Map) ? _d(j['points']['pointRub']) : 0.45,
      cashbackPercent: (j['cashback'] is Map) ? _d(j['cashback']['percent']) : 0,
      cashbackTitle: (j['cashback'] is Map) ? '${j['cashback']['title'] ?? ''}' : '',
      vkClientId: (j['points'] is Map) ? '${j['points']['vkClientId'] ?? ''}' : '',
      vkRedirect: (j['points'] is Map) ? '${j['points']['vkRedirect'] ?? ''}' : '',
    );
  }

  static int _minutes(String hhmm) {
    final p = hhmm.split(':');
    return (int.tryParse(p[0]) ?? 0) * 60 + (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }

  /// Открыто ли кафе сейчас (по московскому времени).
  bool get isOpenNow {
    final msk = DateTime.now().toUtc().add(const Duration(hours: 3));
    if (!openDays.contains(msk.weekday)) return false;
    final m = msk.hour * 60 + msk.minute;
    return m >= _minutes(open) && m < _minutes(close);
  }

  String get scheduleText {
    const names = {1: 'Пн', 2: 'Вт', 3: 'Ср', 4: 'Чт', 5: 'Пт', 6: 'Сб', 7: 'Вс'};
    final days = [...openDays]..sort();
    return '${days.map((d) => names[d] ?? '').join(', ')} · $open–$close';
  }
}

class CartLine {
  final String productId, name, image, portion;
  /// Выбранный размер ('' — без размеров).
  final String variant;
  final double price;
  int qty;
  CartLine({required this.productId, required this.name, required this.image, required this.portion, required this.price, required this.qty, this.variant = ''});

  String get key => variant.isEmpty ? productId : '$productId|$variant';
  String get title => variant.isEmpty ? name : '$name ($variant)';

  Map<String, dynamic> toJson() => {'id': productId, 'name': name, 'image': image, 'portion': portion, 'price': price, 'qty': qty, 'variant': variant};
  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        productId: '${j['id']}',
        name: '${j['name'] ?? ''}',
        image: '${j['image'] ?? ''}',
        portion: '${j['portion'] ?? ''}',
        price: _d(j['price']),
        qty: _iOrNull(j['qty']) ?? 1,
        variant: '${j['variant'] ?? ''}',
      );
}

class PastOrder {
  final int number;
  final String when;
  final DateTime date;
  final List<CartLine> lines;
  final double total;
  final int delivery;
  final String district, address, payment;
  const PastOrder({this.number = 0, this.when = '', required this.date, required this.lines, required this.total, required this.delivery, required this.district, required this.address, required this.payment});

  Map<String, dynamic> toJson() => {
        'number': number,
        'when': when,
        'date': date.toIso8601String(),
        'lines': [for (final l in lines) l.toJson()],
        'total': total,
        'delivery': delivery,
        'district': district,
        'address': address,
        'payment': payment,
      };
  factory PastOrder.fromJson(Map<String, dynamic> j) => PastOrder(
        number: _iOrNull(j['number']) ?? 0,
        when: '${j['when'] ?? ''}',
        date: DateTime.tryParse('${j['date']}') ?? DateTime.now(),
        lines: [for (final l in (j['lines'] as List? ?? const [])) CartLine.fromJson(Map<String, dynamic>.from(l))],
        total: _d(j['total']),
        delivery: _iOrNull(j['delivery']) ?? 0,
        district: '${j['district'] ?? ''}',
        address: '${j['address'] ?? ''}',
        payment: '${j['payment'] ?? ''}',
      );
}

String rub(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '$b ₽';
}

class Slot {
  final String time;
  final bool free;
  const Slot(this.time, this.free);
}

class PreDay {
  final String date; // YYYY-MM-DD
  final int weekday;
  final List<Slot> slots;
  const PreDay(this.date, this.weekday, this.slots);
  factory PreDay.fromJson(Map<String, dynamic> j) => PreDay(
        '${j['date']}',
        _iOrNull(j['weekday']) ?? 1,
        [for (final s in (j['slots'] as List? ?? const [])) Slot('${s['time']}', s['free'] == true)],
      );
  bool get hasFree => slots.any((s) => s.free);

  static const _wd = ['', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
  String label(DateTime now) {
    final d = DateTime.parse(date);
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Завтра';
    return '${_wd[weekday]}, ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  }
}

/// Пользователь бонусной программы (вход через ВКонтакте).
class BonusUser {
  final String id, firstName, lastName, picture;
  final int points;
  const BonusUser({required this.id, required this.firstName, required this.lastName, required this.picture, required this.points});
  factory BonusUser.fromJson(Map<String, dynamic> j) => BonusUser(
        id: '${j['id']}',
        firstName: '${j['firstName'] ?? ''}',
        lastName: '${j['lastName'] ?? ''}',
        picture: '${j['picture'] ?? ''}',
        points: _iOrNull(j['points']) ?? 0,
      );
  Map<String, dynamic> toJson() => {'id': id, 'firstName': firstName, 'lastName': lastName, 'picture': picture, 'points': points};
  String get name => '$firstName $lastName'.trim();
}
