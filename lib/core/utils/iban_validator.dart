/// Validates IBANs using the standard ISO 13616 mod-97 checksum.
class IbanValidator {
  IbanValidator._();

  static String normalize(String input) =>
      input.replaceAll(RegExp(r'\s'), '').toUpperCase();

  static bool isValid(String input) {
    final iban = normalize(input);
    if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$').hasMatch(iban)) {
      return false;
    }

    // Move the country code and check digits to the end, then convert
    // letters to numbers (A = 10 ... Z = 35) and compute mod 97.
    final rearranged = iban.substring(4) + iban.substring(0, 4);
    var remainder = 0;
    for (final unit in rearranged.codeUnits) {
      final value = unit >= 65 ? unit - 55 : unit - 48;
      remainder = value > 9
          ? (remainder * 100 + value) % 97
          : (remainder * 10 + value) % 97;
    }
    return remainder == 1;
  }
}
