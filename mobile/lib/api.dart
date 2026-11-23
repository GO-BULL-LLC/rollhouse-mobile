// Сетевой слой: меню и настройки с rollhous.ru, отправка заказа, промокоды.
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

import 'models.dart';

const kBase = 'https://rollhous.ru';
const kAppVersion = '1.3';

String get userAgent => 'RollHouseApp/$kAppVersion (${Platform.isIOS ? 'iOS' : 'Android'})';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class Api {
  final http.Client _c = http.Client();

  Map<String, String> get _headers => {'User-Agent': userAgent, 'Accept': 'application/json'};

  /// Меню + настройки одним запросом. Возвращает сырое тело (для кэша).
  Future<String> bootstrapRaw() async {
    final r = await _c.get(Uri.parse('$kBase/app-api/api.php?r=bootstrap'), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) throw ApiException('Сервер ответил ${r.statusCode}');
    final body = utf8.decode(r.bodyBytes);
    jsonDecode(body); // проверка, что пришёл целый JSON
    return body;
  }

  Map<String, dynamic> _json(http.Response r) {
    try {
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (_) {
      return {'error': 'Сервер ответил ${r.statusCode}'};
    }
  }

  /// Заказ через сервер приложения: бронь предзаказа, списание баллов, отправка админам в ВК.
  /// Возвращает (номер заказа, статус уведомления в ВК: sent|not_allowed|none|error).
  Future<(int, String)> sendOrder({
    required String details,
    required String customer,
    required String accrualCode,
    required double total,
    String? token,
    String? preDate,
    String? preTime,
    int spendPoints = 0,
  }) async {
    final r = await _c
        .post(
          Uri.parse('$kBase/app-api/order.php'),
          headers: {..._headers, 'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
          body: jsonEncode({
            'details': details,
            'customer': customer,
            'source': 'app',
            'accrualCode': accrualCode,
            'orderTotal': (total * 100).round() / 100,
            'preorder': preDate == null ? null : {'date': preDate, 'time': preTime},
            'spendPoints': spendPoints,
          }),
        )
        .timeout(const Duration(seconds: 45));
    final d = _json(r);
    if (r.statusCode != 200 || d['ok'] != true) {
      throw ApiException('${d['error'] ?? 'Не удалось отправить заказ. Попробуйте ещё раз или позвоните нам.'}');
    }
    return ((d['number'] as num?)?.toInt() ?? 0, '${d['notify'] ?? 'none'}');
  }

  Future<List<PreDay>> slots() async {
    final r = await _c.get(Uri.parse('$kBase/app-api/api.php?r=slots'), headers: _headers).timeout(const Duration(seconds: 15));
    final d = _json(r);
    return [for (final x in (d['days'] as List? ?? const [])) PreDay.fromJson(Map<String, dynamic>.from(x))];
  }

  /// Обмен кода VK ID на сессию приложения (обмен делает сервер).
  Future<(String, BonusUser)> vkLogin({required String code, required String deviceId, required String verifier, required String state}) async {
    final r = await _c
        .post(Uri.parse('$kBase/app-api/vk.php?a=login'),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'code': code, 'device_id': deviceId, 'code_verifier': verifier, 'state': state}))
        .timeout(const Duration(seconds: 30));
    final d = _json(r);
    if (r.statusCode != 200 || d['token'] == null) throw ApiException('${d['error'] ?? 'Не удалось войти'}');
    return ('${d['token']}', BonusUser.fromJson(Map<String, dynamic>.from(d['user'])));
  }

  /// null — сессия недействительна (надо войти заново).
  Future<BonusUser?> me(String token) async {
    final r = await _c.get(Uri.parse('$kBase/app-api/vk.php?a=me'), headers: {..._headers, 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
    if (r.statusCode == 401) return null;
    final d = _json(r);
    if (r.statusCode != 200) throw ApiException('${d['error'] ?? 'Сервис баллов недоступен'}');
    return BonusUser.fromJson(Map<String, dynamic>.from(d['user']));
  }

  /// Промокод: сначала многоразовые коды приложения (админка), затем одноразовые коды из бота.
  Future<Promo> findPromo(String code) async {
    if (code.isEmpty) throw ApiException('Введите промокод');
    final r = await _c
        .get(Uri.parse('$kBase/app-api/api.php?r=promo&code=${Uri.encodeQueryComponent(code)}'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    final d = Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)));
    if (d['found'] == true) {
      if (d['error'] != null) throw ApiException('${d['error']}');
      return Promo(
        code: '${d['code']}',
        type: '${d['type']}',
        value: (d['value'] as num).toDouble(),
        minOrder: (d['minOrder'] as num?)?.toInt() ?? 0,
        title: '${d['title'] ?? ''}',
      );
    }
    final rubles = await checkPromo(code);
    return Promo(code: code, type: 'rubles', value: rubles, bot: true);
  }

  /// Проверка одноразового промокода из бота. Возвращает сумму скидки в рублях.
  Future<double> checkPromo(String code) async {
    final r = await _c
        .get(Uri.parse('$kBase/promocodes.php?code=${Uri.encodeQueryComponent(code)}&action=check'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    Map<String, dynamic> d;
    try {
      d = Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (_) {
      throw ApiException('Не удалось проверить промокод');
    }
    if (d['error'] != null) throw ApiException('${d['error']}');
    final rubles = d['rubles'] is num ? (d['rubles'] as num).toDouble() : double.tryParse('${d['rubles']}') ?? 0;
    if (d['valid'] == true && d['type'] == 'spend' && rubles > 0) return rubles;
    throw ApiException('Этот промокод не даёт скидку');
  }

  Future<void> markPromoUsed(String code) async {
    try {
      await _c
          .post(Uri.parse('$kBase/promocodes.php'),
              headers: {..._headers, 'Content-Type': 'application/json'}, body: jsonEncode({'action': 'use', 'code': code}))
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }
}
