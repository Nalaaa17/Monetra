import 'package:intl/intl.dart';

class CalculatorEvaluationResult {
  final double? value;
  final String? error;

  const CalculatorEvaluationResult({this.value, this.error});

  bool get hasError => error != null;
}

class MoneyCalculatorState {
  final List<String> tokens;
  final String? errorMessage;
  final bool justEvaluated;

  const MoneyCalculatorState({
    this.tokens = const ['0'],
    this.errorMessage,
    this.justEvaluated = false,
  });

  String get formattedExpression =>
      tokens.map(MoneyCalculatorEngine.formatToken).join(' ');

  bool get hasOperator =>
      tokens.any(MoneyCalculatorEngine.isOperator);
}

class MoneyCalculatorEngine {
  MoneyCalculatorEngine._();

  static const Set<String> operators = {'+', '-', '×', '÷'};

  static bool isOperator(String token) => operators.contains(token);

  static final NumberFormat _intFormat = NumberFormat('#,##0', 'id_ID');

  /// Memformat angka double ke tampilan Rupiah rapi (`1.500.000` atau `333.333,33`).
  static String formatNumber(double value, {bool includeCurrency = true}) {
    if (value.isNaN || value.isInfinite) return 'Error';
    final isNegative = value < 0;
    final absVal = value.abs();

    // Hilangkan noise floating point kecil (misal 0.1 + 0.2)
    final rounded = (absVal * 100).round() / 100.0;
    final intPart = rounded.truncate();
    final fracPart = ((rounded - intPart) * 100).round();

    var numStr = _intFormat.format(intPart);
    if (fracPart > 0) {
      var fracStr = fracPart.toString().padLeft(2, '0');
      if (fracStr.endsWith('0')) {
        fracStr = fracStr.substring(0, 1);
      }
      numStr = '$numStr,$fracStr';
    }

    final prefix = isNegative ? '-' : '';
    return includeCurrency ? '${prefix}Rp $numStr' : '$prefix$numStr';
  }

  /// Memformat satu token angka/operator untuk ditampilkan pada baris ekspresi.
  static String formatToken(String token) {
    if (isOperator(token)) return token;
    final hasPercent = token.endsWith('%');
    final rawNum = hasPercent ? token.substring(0, token.length - 1) : token;
    final formattedNum = _formatRawNumberInput(rawNum);
    return hasPercent ? '$formattedNum%' : formattedNum;
  }

  static String _formatRawNumberInput(String raw) {
    final isNeg = raw.startsWith('-');
    final unsigned = isNeg ? raw.substring(1) : raw;
    final parts = unsigned.split(',');
    final intDigits = parts[0].isEmpty ? '0' : parts[0];
    final intVal = int.tryParse(intDigits);
    final formattedInt =
        intVal != null ? _intFormat.format(intVal) : intDigits;
    final prefix = isNeg ? '-' : '';

    if (parts.length > 1) {
      return '$prefix$formattedInt,${parts[1]}';
    }
    return '$prefix$formattedInt';
  }

  static MoneyCalculatorState inputDigit(
    MoneyCalculatorState state,
    String key,
  ) {
    final tokens = List<String>.from(state.tokens);

    if (state.justEvaluated && tokens.length == 1 && !isOperator(tokens.last)) {
      if (key == '000' || key == '0') {
        return const MoneyCalculatorState(tokens: ['0']);
      }
      return MoneyCalculatorState(tokens: [key]);
    }

    if (isOperator(tokens.last)) {
      if (key == '000' || key == '0') {
        tokens.add('0');
      } else {
        tokens.add(key);
      }
      return MoneyCalculatorState(tokens: tokens);
    }

    var current = tokens.last;
    if (current.endsWith('%')) {
      // Setelah %, mulai ekspresi angka baru jika tidak diawali operator
      tokens.add('×');
      tokens.add(key == '000' || key == '0' ? '0' : key);
      return MoneyCalculatorState(tokens: tokens);
    }

    if (current == '0') {
      if (key == '000' || key == '0') return state.copyWithoutError();
      current = key;
    } else {
      final intPart = current.split(',')[0].replaceFirst('-', '');
      final hasDecimal = current.contains(',');
      if (key == '000') {
        if (hasDecimal || intPart.length + 3 > 12) {
          return state.copyWithoutError();
        }
        current = '$current$key';
      } else {
        if (!hasDecimal && intPart.length >= 12) {
          return state.copyWithoutError();
        }
        if (hasDecimal && current.split(',')[1].length >= 2) {
          return state.copyWithoutError();
        }
        current = '$current$key';
      }
    }

    tokens[tokens.length - 1] = current;
    return MoneyCalculatorState(tokens: tokens);
  }

  static MoneyCalculatorState inputDecimalComma(MoneyCalculatorState state) {
    final tokens = List<String>.from(state.tokens);
    if (state.justEvaluated && tokens.length == 1) {
      return const MoneyCalculatorState(tokens: ['0,']);
    }

    if (isOperator(tokens.last)) {
      tokens.add('0,');
      return MoneyCalculatorState(tokens: tokens);
    }

    final current = tokens.last;
    if (current.contains(',') || current.endsWith('%')) {
      return state.copyWithoutError();
    }

    tokens[tokens.length - 1] = '$current,';
    return MoneyCalculatorState(tokens: tokens);
  }

  static MoneyCalculatorState inputPercent(MoneyCalculatorState state) {
    final tokens = List<String>.from(state.tokens);
    if (isOperator(tokens.last) || tokens.last.endsWith('%')) {
      return state.copyWithoutError();
    }

    var current = tokens.last;
    if (current.endsWith(',')) {
      current = current.substring(0, current.length - 1);
    }
    tokens[tokens.length - 1] = '$current%';
    return MoneyCalculatorState(tokens: tokens);
  }

  static MoneyCalculatorState inputOperator(
    MoneyCalculatorState state,
    String op,
  ) {
    if (!isOperator(op)) return state;
    final tokens = List<String>.from(state.tokens);

    if (isOperator(tokens.last)) {
      tokens[tokens.length - 1] = op;
      return MoneyCalculatorState(tokens: tokens);
    }

    var last = tokens.last;
    if (last.endsWith(',')) {
      last = last.substring(0, last.length - 1);
      tokens[tokens.length - 1] = last;
    }

    tokens.add(op);
    return MoneyCalculatorState(tokens: tokens);
  }

  static MoneyCalculatorState inputWalletBalance(
    MoneyCalculatorState state,
    int balance,
  ) {
    final valStr = balance.toString();
    final tokens = List<String>.from(state.tokens);

    if (state.justEvaluated && tokens.length == 1) {
      return MoneyCalculatorState(tokens: [valStr]);
    }

    if (isOperator(tokens.last)) {
      tokens.add(valStr);
      return MoneyCalculatorState(tokens: tokens);
    }

    tokens[tokens.length - 1] = valStr;
    return MoneyCalculatorState(tokens: tokens);
  }

  static MoneyCalculatorState backspace(MoneyCalculatorState state) {
    final tokens = List<String>.from(state.tokens);
    if (tokens.isEmpty) return const MoneyCalculatorState();

    final last = tokens.last;
    if (isOperator(last)) {
      tokens.removeLast();
      if (tokens.isEmpty) return const MoneyCalculatorState();
      return MoneyCalculatorState(tokens: tokens);
    }

    if (last.length <= 1 || (last.startsWith('-') && last.length <= 2)) {
      if (tokens.length == 1) {
        return const MoneyCalculatorState(tokens: ['0']);
      }
      tokens.removeLast();
      return MoneyCalculatorState(tokens: tokens);
    }

    tokens[tokens.length - 1] = last.substring(0, last.length - 1);
    return MoneyCalculatorState(tokens: tokens);
  }

  static MoneyCalculatorState clearAll() => const MoneyCalculatorState();

  /// Menghitung ekspresi saat ini. Mengabaikan operator menggantung di akhir saat preview.
  static CalculatorEvaluationResult evaluate(List<String> rawTokens) {
    if (rawTokens.isEmpty) {
      return const CalculatorEvaluationResult(value: 0);
    }

    final tokens = List<String>.from(rawTokens);
    while (tokens.isNotEmpty && isOperator(tokens.last)) {
      tokens.removeLast();
    }
    if (tokens.isEmpty) {
      return const CalculatorEvaluationResult(value: 0);
    }

    // Pass 1: selesaikan perkalian (×) & pembagian (÷) terlebih dahulu
    final List<String> pass1 = [tokens.first];
    int i = 1;
    while (i < tokens.length - 1) {
      final op = tokens[i];
      final rightToken = tokens[i + 1];

      if (op == '×' || op == '÷') {
        final leftToken = pass1.removeLast();
        final leftVal = _parseNumericValue(leftToken, asFractionIfPercent: true);
        final rightVal =
            _parseNumericValue(rightToken, asFractionIfPercent: true);

        if (op == '÷' && rightVal == 0) {
          return const CalculatorEvaluationResult(
            error: 'Tidak bisa dibagi 0',
          );
        }

        final res = op == '×' ? leftVal * rightVal : leftVal / rightVal;
        pass1.add(res.toString());
      } else {
        pass1.add(op);
        pass1.add(rightToken);
      }
      i += 2;
    }

    // Pass 2: selesaikan penjumlahan (+) & pengurangan (-) dengan dukungan % relatif
    double acc = _parseNumericValue(pass1.first, asFractionIfPercent: true);
    int j = 1;
    while (j < pass1.length - 1) {
      final op = pass1[j];
      final rightToken = pass1[j + 1];

      double operand;
      if (rightToken.endsWith('%')) {
        final pct = _parseNumericValue(rightToken, asFractionIfPercent: true);
        operand = acc * pct;
      } else {
        operand = _parseNumericValue(rightToken, asFractionIfPercent: false);
      }

      if (op == '+') {
        acc += operand;
      } else if (op == '-') {
        acc -= operand;
      }
      j += 2;
    }

    final cleaned = (acc * 1e9).round() / 1e9;
    return CalculatorEvaluationResult(value: cleaned);
  }

  static MoneyCalculatorState equals(MoneyCalculatorState state) {
    final result = evaluate(state.tokens);
    if (result.hasError) {
      return MoneyCalculatorState(
        tokens: state.tokens,
        errorMessage: result.error,
        justEvaluated: false,
      );
    }
    final resToken = _doubleToPlainToken(result.value ?? 0);
    return MoneyCalculatorState(
      tokens: [resToken],
      justEvaluated: true,
    );
  }

  static double _parseNumericValue(
    String token, {
    required bool asFractionIfPercent,
  }) {
    final hasPercent = token.endsWith('%');
    var clean = hasPercent ? token.substring(0, token.length - 1) : token;
    clean = clean.replaceAll(',', '.');
    if (clean.endsWith('.')) clean = clean.substring(0, clean.length - 1);
    final val = double.tryParse(clean) ?? 0.0;
    if (hasPercent && asFractionIfPercent) {
      return val / 100.0;
    }
    return val;
  }

  static String _doubleToPlainToken(double value) {
    final normalized = (value * 1000000).round() / 1000000.0;
    if (normalized == normalized.truncateToDouble()) {
      return normalized.truncate().toString();
    }
    var str = normalized.toString();
    if (str.contains('.')) {
      str = str.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return str.replaceAll('.', ',');
  }
}

extension on MoneyCalculatorState {
  MoneyCalculatorState copyWithoutError() => MoneyCalculatorState(
        tokens: tokens,
        justEvaluated: justEvaluated,
      );
}
