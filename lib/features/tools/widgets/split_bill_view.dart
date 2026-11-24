import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/currency_formatter.dart';

class SplitBillView extends StatefulWidget {
  const SplitBillView({super.key});

  @override
  State<SplitBillView> createState() => _SplitBillViewState();
}

class _SplitBillViewState extends State<SplitBillView> {
  final TextEditingController _subtotalController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _customTaxController = TextEditingController();
  final TextEditingController _customServiceController = TextEditingController();

  int _pax = 3;
  double _taxPercent = 11.0; // Default PPN 11% di Indonesia
  double _servicePercent = 0.0;
  bool _roundUpToHundred = true;

  @override
  void dispose() {
    _subtotalController.dispose();
    _discountController.dispose();
    _customTaxController.dispose();
    _customServiceController.dispose();
    super.dispose();
  }

  int get _subtotal {
    final raw = _subtotalController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }

  int get _discount {
    final raw = _discountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }

  int get _taxAmount {
    final net = (_subtotal - _discount).clamp(0, double.infinity);
    return (net * (_taxPercent / 100)).round();
  }

  int get _serviceAmount {
    final net = (_subtotal - _discount).clamp(0, double.infinity);
    return (net * (_servicePercent / 100)).round();
  }

  int get _grandTotal {
    final net = (_subtotal - _discount).clamp(0, double.infinity);
    return (net + _taxAmount + _serviceAmount).round();
  }

  int get _perPersonAmount {
    if (_pax <= 0 || _grandTotal <= 0) return 0;
    final exact = _grandTotal / _pax;
    if (_roundUpToHundred) {
      return (exact / 100).ceil() * 100;
    }
    return exact.round();
  }

  void _copySummary() {
    final buffer = StringBuffer();
    buffer.writeln('🧾 *Rincian Bagi Tagihan (Split Bill) - Monetra*');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Subtotal: ${CurrencyFormatter.format(_subtotal)}');
    if (_discount > 0) {
      buffer.writeln('Diskon: -${CurrencyFormatter.format(_discount)}');
    }
    if (_taxAmount > 0) {
      buffer.writeln('Pajak (${_taxPercent.toStringAsFixed(1)}%): ${CurrencyFormatter.format(_taxAmount)}');
    }
    if (_serviceAmount > 0) {
      buffer.writeln('Service (${_servicePercent.toStringAsFixed(1)}%): ${CurrencyFormatter.format(_serviceAmount)}');
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('*Total Tagihan: ${CurrencyFormatter.format(_grandTotal)}*');
    buffer.writeln('Jumlah: $_pax orang');
    buffer.writeln('');
    buffer.writeln('👉 *Masing-masing Bayar: ${CurrencyFormatter.format(_perPersonAmount)}*');
    buffer.writeln('');
    buffer.writeln('✨ Dihitung dengan Monetra (Multi-Wallet Finance)');

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(milliseconds: 1600),
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Rincian berhasil disalin ke clipboard!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF059669),
      ),
    );
  }

  void _recordMyShare() {
    final share = _perPersonAmount;
    if (share <= 0) return;
    context.push(
      AppRouter.addTransaction,
      extra: {'type': 'expense', 'amount': share},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Kartu Hasil Ringkasan Utama (Hero Card)
          _buildHeroResultCard(context, isDark),
          const SizedBox(height: 18),

          // 2. Input Subtotal Makanan & Diskon
          _buildSectionHeader('Tagihan'),
          const SizedBox(height: 8),
          _buildSubtotalAndDiscountInput(context, isDark),
          const SizedBox(height: 18),

          // 3. Pengaturan Pajak (Tax) & Biaya Layanan (Service)
          _buildSectionHeader('Pajak & Servis'),
          const SizedBox(height: 8),
          _buildTaxAndServiceSection(context, isDark),
          const SizedBox(height: 18),

          // 4. Jumlah Orang (Pax) & Pembulatan
          _buildSectionHeader('Jumlah Orang'),
          const SizedBox(height: 8),
          _buildPaxSelector(context, isDark),
          const SizedBox(height: 24),

          // 5. Tombol Aksi (Salin & Catat Langsung)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _grandTotal > 0 ? _copySummary : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Salin Rincian'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _perPersonAmount > 0 ? _recordMyShare : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text(
                    'Catat Bagianku',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.titleSmall.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryOf(context),
      ),
    );
  }

  Widget _buildHeroResultCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.group_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Tagihan Per Orang ($_pax Pax)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () =>
                    setState(() => _roundUpToHundred = !_roundUpToHundred),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _roundUpToHundred
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _roundUpToHundred
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _roundUpToHundred
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        size: 11,
                        color: _roundUpToHundred
                            ? AppColors.primaryDark
                            : AppColors.textSecondaryOf(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Bulat Rp100',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _roundUpToHundred
                              ? AppColors.primaryDark
                              : AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.format(_perPersonAmount),
              style: AppTypography.headlineLarge.copyWith(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniSummaryItem('Subtotal', CurrencyFormatter.format(_subtotal)),
              _buildMiniSummaryItem('Pajak & Svc', CurrencyFormatter.format(_taxAmount + _serviceAmount)),
              _buildMiniSummaryItem('Total Akhir', CurrencyFormatter.format(_grandTotal), isBold: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSummaryItem(String label, String value, {bool isBold = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(
              fontSize: 11,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtotalAndDiscountInput(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _subtotalController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (val) {
              if (val.isNotEmpty) {
                final numVal = int.tryParse(val) ?? 0;
                final formatted = CurrencyFormatter.format(numVal).replaceAll('Rp ', '');
                _subtotalController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
              setState(() {});
            },
            decoration: InputDecoration(
              labelText: 'Subtotal Tagihan (Sebelum Pajak)',
              prefixText: 'Rp ',
              prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _discountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (val) {
              if (val.isNotEmpty) {
                final numVal = int.tryParse(val) ?? 0;
                final formatted = CurrencyFormatter.format(numVal).replaceAll('Rp ', '');
                _discountController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
              setState(() {});
            },
            decoration: InputDecoration(
              labelText: 'Diskon / Potongan Promo (Opsional)',
              prefixText: '- Rp ',
              prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxAndServiceSection(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pajak Presets
          Text(
            'Pajak (Tax): ${_taxPercent.toStringAsFixed(1)}% (${CurrencyFormatter.format(_taxAmount)})',
            style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTaxChip(0.0, '0%'),
                const SizedBox(width: 8),
                _buildTaxChip(10.0, '10%'),
                const SizedBox(width: 8),
                _buildTaxChip(11.0, '11% (PPN)'),
                const SizedBox(width: 8),
                _buildTaxChip(12.0, '12%'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Biaya Layanan Presets
          Text(
            'Biaya Layanan (Service Charge): ${_servicePercent.toStringAsFixed(1)}% (${CurrencyFormatter.format(_serviceAmount)})',
            style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildServiceChip(0.0, '0%'),
                const SizedBox(width: 8),
                _buildServiceChip(5.0, '5%'),
                const SizedBox(width: 8),
                _buildServiceChip(7.0, '7%'),
                const SizedBox(width: 8),
                _buildServiceChip(10.0, '10%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxChip(double pct, String label) {
    final isSelected = _taxPercent == pct;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: AppColors.primary,
      onSelected: (val) {
        if (val) setState(() => _taxPercent = pct);
      },
    );
  }

  Widget _buildServiceChip(double pct, String label) {
    final isSelected = _servicePercent == pct;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: const Color(0xFF0284C7),
      onSelected: (val) {
        if (val) setState(() => _servicePercent = pct);
      },
    );
  }

  Widget _buildPaxSelector(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dibagi Ke',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '$_pax Orang',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryOf(context)),
              ),
            ],
          ),
          Row(
            children: [
              IconButton.outlined(
                onPressed: _pax > 1 ? () => setState(() => _pax--) : null,
                icon: const Icon(Icons.remove_rounded, size: 18),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$_pax',
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              IconButton.outlined(
                onPressed: _pax < 50 ? () => setState(() => _pax++) : null,
                icon: const Icon(Icons.add_rounded, size: 18),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
