/// Service for generating banking QR payment strings:
/// 1. SPAYD (Short Payment Descriptor - Czech QR Platba)
/// 2. EPC QR (European Payments Council / SEPA QR)
class QrPaymentService {
  QrPaymentService._();

  /// Generates a Czech SPAYD (Short Payment Descriptor) string for "QR Platba".
  /// Standard: SPD*1.0*ACC:CZ...*AM:120.50*CC:CZK*MSG:Split bill*
  static String generateSpayd({
    required String iban,
    required double amount,
    String currency = 'CZK',
    String? message,
    String? variableSymbol,
  }) {
    final cleanIban = iban.replaceAll(' ', '').toUpperCase();
    final buffer = StringBuffer('SPD*1.0*');

    buffer.write('ACC:$cleanIban*');
    buffer.write('AM:${amount.toStringAsFixed(2)}*');
    buffer.write('CC:$currency*');

    if (message != null && message.isNotEmpty) {
      // Limit message to 60 alphanumeric characters per SPAYD spec
      final cleanMsg = message.replaceAll('*', ' ').trim();
      buffer.write('MSG:${cleanMsg.length > 60 ? cleanMsg.substring(0, 60) : cleanMsg}*');
    }

    if (variableSymbol != null && variableSymbol.isNotEmpty) {
      final cleanVs = variableSymbol.replaceAll(RegExp(r'\D'), '');
      if (cleanVs.isNotEmpty) {
        buffer.write('X-VS:$cleanVs*');
      }
    }

    return buffer.toString();
  }

  /// Generates a SEPA EPC QR code payload (002 standard).
  static String generateEpcQr({
    required String iban,
    required String recipientName,
    required double amount,
    String? bic,
    String? remittanceInfo,
  }) {
    final cleanIban = iban.replaceAll(' ', '').toUpperCase();
    final lines = [
      'BCD',
      '002',
      '1',
      'SCT',
      bic ?? '',
      recipientName,
      cleanIban,
      'EUR${amount.toStringAsFixed(2)}',
      '',
      '',
      remittanceInfo ?? 'Split Bill',
    ];
    return lines.join('\n');
  }
}
