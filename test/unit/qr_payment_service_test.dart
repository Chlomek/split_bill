import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill/core/services/qr_payment_service.dart';

void main() {
  group('QrPaymentService', () {
    test('generates valid Czech SPAYD payment string', () {
      final spayd = QrPaymentService.generateSpayd(
        iban: 'CZ6508000000192000145399',
        amount: 450.50,
        currency: 'CZK',
        message: 'Obed',
      );

      expect(spayd.startsWith('SPD*1.0*'), isTrue);
      expect(spayd.contains('ACC:CZ6508000000192000145399*'), isTrue);
      expect(spayd.contains('AM:450.50*'), isTrue);
      expect(spayd.contains('CC:CZK*'), isTrue);
      expect(spayd.contains('MSG:Obed*'), isTrue);
    });
  });
}
