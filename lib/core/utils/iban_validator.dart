/// Validates IBANs using the standard ISO 13616 mod-97 checksum, and converts
/// between Czech account numbers and IBANs.
class IbanValidator {
  IbanValidator._();

  /// Length of a Czech IBAN.
  static const int czLength = 24;

  static String normalize(String input) =>
      input.replaceAll(RegExp(r'\s'), '').toUpperCase();

  /// Groups an IBAN in blocks of four for display.
  static String pretty(String input) {
    final iban = normalize(input);
    final buffer = StringBuffer();
    for (var i = 0; i < iban.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(iban[i]);
    }
    return buffer.toString();
  }

  static bool isValid(String input) {
    final iban = normalize(input);
    if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$').hasMatch(iban)) {
      return false;
    }
    if (iban.startsWith('CZ') && iban.length != czLength) return false;
    return _mod97(iban.substring(4) + iban.substring(0, 4)) == 1;
  }

  /// Builds a Czech IBAN from an account number such as "19-2000145399/0800"
  /// or "2000145399/0800". Returns null when the input is not a valid
  /// account number.
  static String? fromCzechAccount(String input) {
    final match = RegExp(
      r'^(?:(\d{1,6})-)?(\d{2,10})/(\d{4})$',
    ).firstMatch(input.replaceAll(RegExp(r'\s'), ''));
    if (match == null) return null;
    final prefix = (match.group(1) ?? '').padLeft(6, '0');
    final number = match.group(2)!.padLeft(10, '0');
    final bank = match.group(3)!;
    if (!_czechWeightsOk(prefix) || !_czechWeightsOk(number)) return null;

    final bban = '$bank$prefix$number';
    final check = 98 - _mod97('${bban}CZ00');
    return 'CZ${check.toString().padLeft(2, '0')}$bban';
  }

  /// "CZ6508000000192000145399" -> "19-2000145399/0800". Null for
  /// non-Czech IBANs.
  static String? toCzechAccount(String input) {
    final iban = normalize(input);
    if (!iban.startsWith('CZ') || iban.length != czLength) return null;
    final bank = iban.substring(4, 8);
    final prefix = iban.substring(8, 14).replaceFirst(RegExp(r'^0+'), '');
    final number = iban.substring(14).replaceFirst(RegExp(r'^0+'), '');
    return '${prefix.isEmpty ? '' : '$prefix-'}$number/$bank';
  }

  /// Czech account parts use a weighted mod-11 check.
  static bool _czechWeightsOk(String digits) {
    const weights = [6, 3, 7, 9, 10, 5, 8, 4, 2, 1];
    final padded = digits.padLeft(10, '0');
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      sum += int.parse(padded[i]) * weights[i];
    }
    return sum % 11 == 0;
  }

  /// Letters count as numbers (A = 10 ... Z = 35).
  static int _mod97(String value) {
    var remainder = 0;
    for (final unit in value.codeUnits) {
      final digit = unit >= 65 ? unit - 55 : unit - 48;
      remainder = digit > 9
          ? (remainder * 100 + digit) % 97
          : (remainder * 10 + digit) % 97;
    }
    return remainder;
  }
}
