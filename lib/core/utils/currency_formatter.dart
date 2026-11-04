import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String format(int amount) {
    return _formatter.format(amount);
  }

  static String formatWithSign(int amount, {required bool isIncome}) {
    if (isIncome) {
      return '+${_formatter.format(amount)}';
    } else {
      return '-${_formatter.format(amount)}';
    }
  }

  static int parse(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }
}

