import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/utils/bank_logo_helper.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/account_repository.dart';
import '../../home/providers/home_providers.dart';
import '../utils/money_calculator_engine.dart';
import '../widgets/split_bill_view.dart';

class _CalcHistoryEntry {
  final String expression;
  final double result;
  final String formattedResult;

  const _CalcHistoryEntry({
    required this.expression,
    required this.result,
    required this.formattedResult,
  });
}

class MoneyCalculatorScreen extends ConsumerStatefulWidget {
  const MoneyCalculatorScreen({super.key});

  @override
  ConsumerState<MoneyCalculatorScreen> createState() =>
      _MoneyCalculatorScreenState();
}

class _MoneyCalculatorScreenState extends ConsumerState<MoneyCalculatorScreen> {
  MoneyCalculatorState _state = const MoneyCalculatorState();
  final List<_CalcHistoryEntry> _history = [];
  int _activeTab = 0; // 0: Kalkulator, 1: Bagi Tagihan (Split Bill)

  void _updateState(MoneyCalculatorState next) {
    setState(() => _state = next);
  }

  void _onDigit(String digit) =>
      _updateState(MoneyCalculatorEngine.inputDigit(_state, digit));

  void _onOperator(String op) =>
      _updateState(MoneyCalculatorEngine.inputOperator(_state, op));

  void _onComma() =>
      _updateState(MoneyCalculatorEngine.inputDecimalComma(_state));

  void _onPercent() => _updateState(MoneyCalculatorEngine.inputPercent(_state));

  void _onBackspace() => _updateState(MoneyCalculatorEngine.backspace(_state));

  void _onClear() => _updateState(MoneyCalculatorEngine.clearAll());

  void _onWalletTap(int balance) =>
      _updateState(MoneyCalculatorEngine.inputWalletBalance(_state, balance));

  void _onEquals() {
    final prevExpression = _state.formattedExpression;
    final hadOperator = _state.hasOperator;
    final next = MoneyCalculatorEngine.equals(_state);
    if (hadOperator && next.errorMessage == null) {
      final eval = MoneyCalculatorEngine.evaluate(next.tokens);
      final resVal = eval.value ?? 0;
      _history.insert(
        0,
        _CalcHistoryEntry(
          expression: prevExpression,
          result: resVal,
          formattedResult: MoneyCalculatorEngine.formatNumber(resVal),
        ),
      );
      if (_history.length > 6) {
        _history.removeLast();
      }
    }
    _updateState(next);
  }

  Future<void> _copyResult(String formatted) async {
    await Clipboard.setData(ClipboardData(text: formatted));
    if (!mounted) return;
    AppSnackBar.showSuccess(context, 'Disalin: $formatted');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaryAsync = ref.watch(balanceSummaryProvider);
    final accountsAsync = ref.watch(accountsWithBalanceProvider);

    final eval = MoneyCalculatorEngine.evaluate(_state.tokens);
    final activeError = _state.errorMessage ?? eval.error;
    final displayValue = eval.value ?? 0.0;
    final formattedResult =
        activeError ?? MoneyCalculatorEngine.formatNumber(displayValue);
    final isNegative = activeError == null && displayValue < 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _activeTab == 0 ? 'Kalkulator Uang' : 'Bagi Tagihan (Split Bill)',
          style: AppTypography.headlineMedium.copyWith(fontSize: 18),
        ),
        actions: [
          if (_activeTab == 0 && _history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Bersihkan Riwayat Hitung',
              onPressed: () => setState(() => _history.clear()),
            ),
        ],
      ),
      body: Column(
        children: [
          // Segmented Switcher: Kalkulator vs Bagi Tagihan
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E222A)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeTab = 0),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == 0
                              ? (isDark
                                    ? const Color(0xFF2D333F)
                                    : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _activeTab == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calculate_rounded,
                                size: 16,
                                color: _activeTab == 0
                                    ? AppColors.primary
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Kalkulator',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _activeTab == 0
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeTab = 1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == 1
                              ? (isDark
                                    ? const Color(0xFF2D333F)
                                    : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _activeTab == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_rounded,
                                size: 16,
                                color: _activeTab == 1
                                    ? AppColors.primary
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Bagi Tagihan',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _activeTab == 1
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_activeTab == 1)
            const Expanded(child: SplitBillView())
          else ...[
            // 1. Strip Info + Chip Tarik Saldo Akun (Simulasi Aman)
            _buildWalletPresetBar(context, summaryAsync, accountsAsync, isDark),

            // 2. Area Tampilan Ekspresi, Riwayat Singkat, dan Hasil
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        reverse: true,
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Riwayat perhitungan terakhir (bisa diketuk untuk pakai ulang)
                              if (_history.isNotEmpty) ...[
                                SizedBox(
                                  height: 26,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _history.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (context, idx) {
                                      final item = _history[idx];
                                      return InkWell(
                                        onTap: () =>
                                            _onWalletTap(item.result.round()),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppColors.darkSurface
                                                : const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${item.expression} = ${item.formattedResult}',
                                              style: AppTypography.labelSmall
                                                  .copyWith(fontSize: 11),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],

                              // Ekspresi perhitungan
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                reverse: true,
                                child: SelectableText(
                                  _state.formattedExpression,
                                  maxLines: 1,
                                  style: AppTypography.titleLarge.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Hasil akhir + tombol Salin
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (activeError == null)
                                    IconButton(
                                      onPressed: () =>
                                          _copyResult(formattedResult),
                                      icon: Icon(
                                        Icons.copy_rounded,
                                        size: 16,
                                        color: AppColors.textSecondaryOf(
                                          context,
                                        ),
                                      ),
                                      tooltip: 'Salin Hasil',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          formattedResult,
                                          style: AppTypography.headlineLarge
                                              .copyWith(
                                                fontSize: activeError != null
                                                    ? 24
                                                    : 34,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    activeError != null ||
                                                        isNegative
                                                    ? AppColors.danger
                                                    : AppColors.textPrimaryOf(
                                                        context,
                                                      ),
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // 3. Panel Tombol Kalkulator Rupiah
            _buildKeypad(context, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildWalletPresetBar(
    BuildContext context,
    AsyncValue<BalanceSummary> summaryAsync,
    AsyncValue<List<AccountWithBalance>> accountsAsync,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_fix_high_rounded,
                  size: 14,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ketuk saldo untuk masukkan ke hitungan (tidak ubah data asli)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 11.5,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ...summaryAsync.maybeWhen(
                  data: (summary) => [
                    _buildPresetPill(
                      context: context,
                      label:
                          'Siap Pakai (${CurrencyFormatter.format(summary.totalNetWorth)})',
                      accent: AppColors.primaryDark,
                      isDark: isDark,
                      onTap: () => _onWalletTap(summary.totalNetWorth),
                    ),
                    const SizedBox(width: 8),
                    _buildPresetPill(
                      context: context,
                      label:
                          'Harian (${CurrencyFormatter.format(summary.dailySpendingBalance)})',
                      accent: const Color(0xFF0284C7),
                      isDark: isDark,
                      onTap: () => _onWalletTap(summary.dailySpendingBalance),
                    ),
                    const SizedBox(width: 8),
                    _buildPresetPill(
                      context: context,
                      label:
                          'Tabungan (${CurrencyFormatter.format(summary.savingsBalance)})',
                      accent: const Color(0xFF059669),
                      isDark: isDark,
                      onTap: () => _onWalletTap(summary.savingsBalance),
                    ),
                  ],
                  orElse: () => const <Widget>[],
                ),
                ...accountsAsync.maybeWhen(
                  data: (accounts) => accounts.map((acc) {
                    final accColor = ColorHelper.parseHex(acc.colorHex);
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildPresetPill(
                        context: context,
                        label:
                            '${acc.name} (${CurrencyFormatter.format(acc.balance)})',
                        accent: accColor,
                        isDark: isDark,
                        leading: BankLogoHelper.buildAccountBadge(
                          context: context,
                          accountName: acc.name,
                          accountColor: accColor,
                          logoKey: acc.logoKey,
                          iconCodePoint: acc.iconCodePoint,
                          size: 18,
                          iconSize: 11,
                          borderRadius: 5,
                        ),
                        onTap: () => _onWalletTap(acc.balance),
                      ),
                    );
                  }),
                  orElse: () => const <Widget>[],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetPill({
    required BuildContext context,
    required String label,
    required Color accent,
    required bool isDark,
    Widget? leading,
    required VoidCallback onTap,
  }) {
    return Material(
      color: accent.withValues(alpha: isDark ? 0.18 : 0.1),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 6)],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(BuildContext context, bool isDark) {
    final opBg = isDark ? const Color(0xFF283548) : const Color(0xFFFEF3C7);
    final opFg = isDark ? AppColors.primary : const Color(0xFFB45309);
    final numBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final clearBg = AppColors.danger.withValues(alpha: isDark ? 0.22 : 0.12);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildKeyRow([
              _CalcButtonConfig(
                label: 'C',
                bgColor: clearBg,
                fgColor: AppColors.danger,
                onTap: _onClear,
              ),
              _CalcButtonConfig(
                icon: Icons.backspace_outlined,
                bgColor: opBg,
                fgColor: AppColors.textPrimaryOf(context),
                onTap: _onBackspace,
                onLongPress: _onClear,
              ),
              _CalcButtonConfig(
                label: '%',
                bgColor: opBg,
                fgColor: opFg,
                onTap: _onPercent,
              ),
              _CalcButtonConfig(
                label: '÷',
                bgColor: opBg,
                fgColor: opFg,
                fontSize: 24,
                onTap: () => _onOperator('÷'),
              ),
            ]),
            const SizedBox(height: 8),
            _buildKeyRow([
              _CalcButtonConfig(
                label: '7',
                bgColor: numBg,
                onTap: () => _onDigit('7'),
              ),
              _CalcButtonConfig(
                label: '8',
                bgColor: numBg,
                onTap: () => _onDigit('8'),
              ),
              _CalcButtonConfig(
                label: '9',
                bgColor: numBg,
                onTap: () => _onDigit('9'),
              ),
              _CalcButtonConfig(
                label: '×',
                bgColor: opBg,
                fgColor: opFg,
                fontSize: 24,
                onTap: () => _onOperator('×'),
              ),
            ]),
            const SizedBox(height: 8),
            _buildKeyRow([
              _CalcButtonConfig(
                label: '4',
                bgColor: numBg,
                onTap: () => _onDigit('4'),
              ),
              _CalcButtonConfig(
                label: '5',
                bgColor: numBg,
                onTap: () => _onDigit('5'),
              ),
              _CalcButtonConfig(
                label: '6',
                bgColor: numBg,
                onTap: () => _onDigit('6'),
              ),
              _CalcButtonConfig(
                label: '−',
                bgColor: opBg,
                fgColor: opFg,
                fontSize: 24,
                onTap: () => _onOperator('-'),
              ),
            ]),
            const SizedBox(height: 8),
            _buildKeyRow([
              _CalcButtonConfig(
                label: '1',
                bgColor: numBg,
                onTap: () => _onDigit('1'),
              ),
              _CalcButtonConfig(
                label: '2',
                bgColor: numBg,
                onTap: () => _onDigit('2'),
              ),
              _CalcButtonConfig(
                label: '3',
                bgColor: numBg,
                onTap: () => _onDigit('3'),
              ),
              _CalcButtonConfig(
                label: '+',
                bgColor: opBg,
                fgColor: opFg,
                fontSize: 24,
                onTap: () => _onOperator('+'),
              ),
            ]),
            const SizedBox(height: 8),
            _buildKeyRow([
              _CalcButtonConfig(
                label: '000',
                bgColor: numBg,
                fgColor: AppColors.primaryDark,
                fontSize: 17,
                onTap: () => _onDigit('000'),
              ),
              _CalcButtonConfig(
                label: '0',
                bgColor: numBg,
                onTap: () => _onDigit('0'),
              ),
              _CalcButtonConfig(label: ',', bgColor: numBg, onTap: _onComma),
              _CalcButtonConfig(
                label: '=',
                bgColor: AppColors.primary,
                fgColor: Colors.black,
                fontSize: 24,
                onTap: _onEquals,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<_CalcButtonConfig> buttons) {
    return Row(
      children: buttons.asMap().entries.map((entry) {
        final idx = entry.key;
        final btn = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: idx < buttons.length - 1 ? 8 : 0),
            child: Material(
              color: btn.bgColor,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  btn.onTap();
                },
                onLongPress: btn.onLongPress,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context).dividerColor
                          .withValues(alpha: 0.45),
                    ),
                  ),
                  child: btn.icon != null
                      ? Icon(
                          btn.icon,
                          size: 21,
                          color:
                              btn.fgColor ?? AppColors.textPrimaryOf(context),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            btn.label!,
                            style: TextStyle(
                              fontSize: btn.fontSize ?? 20,
                              fontWeight: FontWeight.bold,
                              color:
                                  btn.fgColor ??
                                  AppColors.textPrimaryOf(context),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CalcButtonConfig {
  final String? label;
  final IconData? icon;
  final Color bgColor;
  final Color? fgColor;
  final double? fontSize;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CalcButtonConfig({
    this.label,
    this.icon,
    required this.bgColor,
    this.fgColor,
    this.fontSize,
    required this.onTap,
    this.onLongPress,
  });
}
