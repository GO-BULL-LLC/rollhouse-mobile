import 'package:flutter_test/flutter_test.dart';
import 'package:rollhouse/screens/checkout.dart';

void main() {
  test('нормализация телефона к формату сайта', () {
    expect(normalizePhone('8 978 123-45-67'), '89781234567');
    expect(normalizePhone('+7 (978) 123-45-67'), '89781234567');
    expect(normalizePhone('9781234567'), '89781234567');
    expect(normalizePhone('12345'), isNull);
  });
}
