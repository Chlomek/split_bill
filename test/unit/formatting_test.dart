import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill/core/utils/currency_formatter.dart';
import 'package:split_bill/core/utils/iban_validator.dart';

void main() {
  group('Czech account and IBAN', () {
    test('account number converts to the matching IBAN and back', () {
      final iban = IbanValidator.fromCzechAccount('19-2000145399/0800');
      expect(iban, 'CZ6508000000192000145399');
      expect(IbanValidator.isValid(iban!), isTrue);
      expect(IbanValidator.toCzechAccount(iban), '19-2000145399/0800');
    });

    test('rejects an account number that fails the bank checksum', () {
      expect(IbanValidator.fromCzechAccount('19-2000145398/0800'), isNull);
      expect(IbanValidator.fromCzechAccount('nonsense'), isNull);
    });

    test('a Czech IBAN of the wrong length is invalid', () {
      expect(IbanValidator.isValid('CZ65 0800 0000 1920 0014 53'), isFalse);
    });
  });

  group('CurrencyFormatter.compact', () {
    String plain(String s) => s.replaceAll(' ', ' ');

    test('drops hellers on whole amounts and keeps them otherwise', () {
      expect(plain(CurrencyFormatter.compact(1284)), '1 284 Kč');
      expect(plain(CurrencyFormatter.compact(84.6)), '84,60 Kč');
    });

    test('signed amounts use plus and a real minus sign', () {
      expect(plain(CurrencyFormatter.compact(1700, signed: true)), '+1 700 Kč');
      expect(plain(CurrencyFormatter.compact(-450, signed: true)), '−450 Kč');
      expect(plain(CurrencyFormatter.compact(0, signed: true)), '0 Kč');
    });
  });
}
