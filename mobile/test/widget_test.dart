import 'package:flutter_test/flutter_test.dart';
import 'package:rollhouse/models.dart';

void main() {
  test('доставка: бесплатно от порога, иначе тариф', () {
    const d = District(id: 'lenino', name: 'Ленино', fee: 200, freeFrom: 1650, note: '');
    expect(d.feeFor(1000), 200);
    expect(d.feeFor(1650), 0);
    const pickup = District(id: 'pickup', name: 'Самовывоз', fee: 0, freeFrom: null, note: '');
    expect(pickup.feeFor(10), 0);
  });

  test('RH-5: 5% только на товары, округление до рубля', () {
    const p = Promo(code: 'RH-5', type: 'percent', value: 5);
    expect(p.discountFor(1490), 75); // 74.5 → 75
    expect(p.discountFor(0), 0);
    expect(p.label, '−5%');
    const big = Promo(code: 'X', type: 'rubles', value: 500, minOrder: 1000);
    expect(big.discountFor(900), 0);
    expect(big.discountFor(300 + 1000), 500);
  });

  test('позиция с размером', () {
    final l = CartLine(productId: 'pizza-plus:1', name: 'Маргарита', image: '', portion: '', price: 900, qty: 1, variant: '40 см');
    expect(l.key, 'pizza-plus:1|40 см');
    expect(l.title, 'Маргарита (40 см)');
  });

  test('формат цены', () {
    expect(rub(1490), '1 490 ₽');
    expect(rub(80), '80 ₽');
  });
}
