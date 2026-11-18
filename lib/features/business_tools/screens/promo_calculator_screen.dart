import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../hpp/providers/hpp_providers.dart';
import '../utils/promo_engine.dart';

class PromoCalculatorScreen extends ConsumerStatefulWidget {
  const PromoCalculatorScreen({super.key});

  @override
  ConsumerState<PromoCalculatorScreen> createState() => _PromoCalculatorScreenState();
}

class _PromoCalculatorScreenState extends ConsumerState<PromoCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State Tab 1: Diskon Tunggal
  final _singleNameCtrl = TextEditingController(text: 'Kopi Susu Aren');
  final _singleCostCtrl = TextEditingController(text: '12000');
  final _singleNormalPriceCtrl = TextEditingController(text: '25000');
  final _singleDiscountValCtrl = TextEditingController(text: '20');
  bool _isPercentage = true;

  // State Tab 2: Bundling
  final _bundlePriceCtrl = TextEditingController(text: '35000');
  final List<BundleItem> _bundleItems = [
    const BundleItem(name: 'Kopi Susu Aren', costPrice: 12000, normalPrice: 25000),
    const BundleItem(name: 'Croissant Cokelat', costPrice: 9000, normalPrice: 20000),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _singleNameCtrl.dispose();
    _singleCostCtrl.dispose();
    _singleNormalPriceCtrl.dispose();
    _singleDiscountValCtrl.dispose();
    _bundlePriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kalkulator Diskon & Bundling',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            Text(
              'Uji Kelayakan Promo agar Margin Tidak Boncos',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 11,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryOf(context),
          tabs: const [
            Tab(icon: Icon(Icons.local_offer_rounded), text: 'Diskon & Promo Coret'),
            Tab(icon: Icon(Icons.inventory_2_rounded), text: 'Paket Bundling'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSingleDiscountTab(context, isDark),
          _buildBundleTab(context, isDark),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: DISKON TUNGGAL (PROMO CORET)
  // ===========================================================================
  Widget _buildSingleDiscountTab(BuildContext context, bool isDark) {
    final cost = int.tryParse(_singleCostCtrl.text) ?? 0;
    final normal = int.tryParse(_singleNormalPriceCtrl.text) ?? 0;
    final discountVal = double.tryParse(_singleDiscountValCtrl.text) ?? 0.0;

    final result = PromoEngine.calculateDiscount(
      costPrice: cost,
      normalPrice: normal,
      isPercentage: _isPercentage,
      discountValue: discountVal,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris Pemilihan Produk dari Katalog
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Data Produk',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => _pickFromCatalog(onSelect: (item) {
                  _singleNameCtrl.text = item.name;
                  _singleCostCtrl.text = item.costPrice.toString();
                  _singleNormalPriceCtrl.text = item.sellingPrice.toString();
                  setState(() {});
                }),
                icon: const Icon(Icons.menu_book_rounded, size: 16),
                label: const Text('Ambil dari Katalog', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Nama Produk
          TextField(
            controller: _singleNameCtrl,
            decoration: InputDecoration(
              labelText: 'Nama Produk',
              hintText: 'Misal: Kopi Susu, Baju Kaos',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
          const SizedBox(height: 14),

          // Modal HPP & Harga Normal
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _singleCostCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Modal HPP (Rp)',
                    hintText: '12000',
                    helperText: 'Biaya pokok per item',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _singleNormalPriceCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Harga Normal (Rp)',
                    hintText: '25000',
                    helperText: 'Harga sebelum diskon',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.price_check_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pengaturan Diskon
          Text('Skema Diskon', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (!_isPercentage) {
                        setState(() {
                          _isPercentage = true;
                          _singleDiscountValCtrl.text = '20';
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isPercentage ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'Diskon Persen (%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isPercentage ? Colors.white : AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_isPercentage) {
                        setState(() {
                          _isPercentage = false;
                          _singleDiscountValCtrl.text = '5000';
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isPercentage ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'Diskon Potongan (Rp)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: !_isPercentage ? Colors.white : AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Input Nilai Diskon
          TextField(
            controller: _singleDiscountValCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _isPercentage ? 'Besar Diskon (%)' : 'Potongan Diskon (Rp)',
              hintText: _isPercentage ? '20' : '5000',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: Icon(_isPercentage ? Icons.percent_rounded : Icons.money_off_rounded),
            ),
          ),
          const SizedBox(height: 10),

          // Preset Chips
          if (_isPercentage)
            Wrap(
              spacing: 8,
              children: [10, 15, 20, 25, 30, 50].map((pct) {
                final isSelected = discountVal == pct.toDouble();
                return ChoiceChip(
                  label: Text('$pct%'),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _singleDiscountValCtrl.text = pct.toString()),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),

          // KARTU HASIL DISKON
          _buildPromoResultCard(
            context,
            isDark,
            title: 'ANALISIS PROMO CORET',
            priceLabel: 'Harga Jual Promo',
            discountedPrice: result.discountedPrice,
            strikethroughPrice: result.normalPrice,
            profitValue: result.promoProfit,
            marginPercent: result.promoMarginPercent,
            status: result.status,
            customerSavings: result.discountAmount,
            comparisonText:
                'Normal: ${CurrencyFormatter.format(result.normalPrice)} (Laba ${CurrencyFormatter.format(result.normalProfit)} / ${result.normalMarginPercent.toStringAsFixed(0)}%)',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: PAKET BUNDLING (MENU HEMAT)
  // ===========================================================================
  Widget _buildBundleTab(BuildContext context, bool isDark) {
    final bundlePrice = int.tryParse(_bundlePriceCtrl.text) ?? 0;
    final result = PromoEngine.calculateBundle(
      items: _bundleItems,
      bundlePrice: bundlePrice,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Isi Paket Bundling (${_bundleItems.length} Produk)',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  foregroundColor: AppColors.primaryDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showAddBundleItemDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Tambah Item'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // List Produk Bundling
          if (_bundleItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: const Center(child: Text('Belum ada item dalam paket bundling.')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _bundleItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = _bundleItems[i];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161A23) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${item.quantity}x',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                            Text(
                              'HPP: ${CurrencyFormatter.format(item.costPrice)} • Normal: ${CurrencyFormatter.format(item.normalPrice)}',
                              style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondaryOf(context)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.danger),
                        onPressed: () {
                          setState(() {
                            _bundleItems.removeAt(i);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 18),

          // Rangkuman Modal vs Normal Asli
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Modal HPP:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(result.totalCostPrice),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.3)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Harga Normal:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(result.totalNormalPrice),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Input Harga Jual Paket
          TextField(
            controller: _bundlePriceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Tawarkan Harga Paket Bundling (Rp)',
              hintText: '35000',
              helperText: 'Tentukan harga paket menarik untuk pembeli',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.sell_rounded),
            ),
          ),
          const SizedBox(height: 20),

          // KARTU HASIL BUNDLING
          _buildPromoResultCard(
            context,
            isDark,
            title: 'ANALISIS PAKET BUNDLING',
            priceLabel: 'Harga Paket Promo',
            discountedPrice: result.bundlePrice,
            strikethroughPrice: result.totalNormalPrice,
            profitValue: result.bundleProfit,
            marginPercent: result.bundleMarginPercent,
            status: result.status,
            customerSavings: result.customerSavings,
            comparisonText: 'Penghematan Pembeli: ${result.savingsPercent.toStringAsFixed(0)}% Lebih Hemat',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET KARTU HASIL
  // ===========================================================================
  Widget _buildPromoResultCard(
    BuildContext context,
    bool isDark, {
    required String title,
    required String priceLabel,
    required int discountedPrice,
    required int strikethroughPrice,
    required int profitValue,
    required double marginPercent,
    required PromoStatus status,
    required int customerSavings,
    required String comparisonText,
  }) {
    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusMsg;

    switch (status) {
      case PromoStatus.safe:
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
        statusTitle = 'Promo Aman & Cuan';
        statusMsg = 'Margin keuntungan masih sehat setelah dipotong diskon.';
        break;
      case PromoStatus.warning:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.warning_amber_rounded;
        statusTitle = 'Margin Tipis';
        statusMsg = 'Keuntungan di bawah 15%. Pastikan volume penjualan tinggi.';
        break;
      case PromoStatus.danger:
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.error_outline_rounded;
        statusTitle = 'Bahaya Rugi / Boncos!';
        statusMsg = 'Harga promo lebih rendah dari modal HPP!';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A23) : const Color(0xFF1E2430),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white60,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(statusMsg, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
          const SizedBox(height: 16),

          // Display Harga
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(priceLabel, style: AppTypography.bodySmall.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(discountedPrice),
                      style: AppTypography.titleLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
                    ),
                    if (strikethroughPrice > discountedPrice) ...[
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(strikethroughPrice),
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(width: 1, height: 44, color: Colors.white24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Laba Bersih Promo', style: AppTypography.bodySmall.copyWith(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(profitValue),
                      style: AppTypography.titleMedium.copyWith(
                        color: profitValue >= 0 ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Margin: ${marginPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: profitValue >= 0 ? Colors.white60 : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),

          // Detail Penghematan Konsumen
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daya Tarik Diskon (Hemat):', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                CurrencyFormatter.format(customerSavings),
                style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(comparisonText, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ],
      ),
    );
  }

  // Dialog Ambil Produk dari Katalog Menu
  void _pickFromCatalog({required ValueChanged<MenuItem> onSelect}) {
    final menus = ref.read(menusListProvider).valueOrNull ?? [];
    if (menus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Katalog produk masih kosong. Tambahkan menu/produk di Katalog terlebih dahulu.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pilih Produk dari Katalog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: menus.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = menus[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Icon(
                          item.type == 'fnb' ? Icons.restaurant_rounded : Icons.shopping_bag_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('HPP: ${CurrencyFormatter.format(item.costPrice)} • Jual: ${CurrencyFormatter.format(item.sellingPrice)}'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        onSelect(item);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Dialog Tambah Item Bundling
  void _showAddBundleItemDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final normalPriceCtrl = TextEditingController();
    int qty = 1;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Tambah Item Bundling', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nama Produk', hintText: 'Misal: Kopi Susu'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: costCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'HPP (Rp)'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: normalPriceCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'Normal (Rp)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Jumlah (Qty):'),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                if (qty > 1) setDialogState(() => qty--);
                              },
                            ),
                            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => setDialogState(() => qty++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final cost = int.tryParse(costCtrl.text) ?? 0;
                    final normal = int.tryParse(normalPriceCtrl.text) ?? 0;
                    if (name.isNotEmpty && normal > 0) {
                      setState(() {
                        _bundleItems.add(BundleItem(name: name, costPrice: cost, normalPrice: normal, quantity: qty));
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Tambahkan'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
