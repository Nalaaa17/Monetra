import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/repository_providers.dart';
import '../providers/hpp_providers.dart';

class HppCalculatorScreen extends ConsumerStatefulWidget {
  const HppCalculatorScreen({super.key});

  @override
  ConsumerState<HppCalculatorScreen> createState() => _HppCalculatorScreenState();
}

class _HppCalculatorScreenState extends ConsumerState<HppCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ---------------------------------------------------------------------------
  // STATE 1: KULINER & MINUMAN (FNB)
  // ---------------------------------------------------------------------------
  final _fnbNameCtrl = TextEditingController(text: 'Kopi Susu Aren');
  final _fnbYieldCtrl = TextEditingController(text: '1');
  final _fnbOverheadCtrl = TextEditingController(text: '1500');
  final _fnbCustomPriceCtrl = TextEditingController();
  double _fnbWastePercent = 3.0;
  double _fnbTargetFoodCost = 35.0;
  int _fnbDailyUnits = 35;
  final List<HppIngredientItem> _fnbIngredients = [
    const HppIngredientItem(
      name: 'Espresso Blend',
      cost: 2160,
      packagePrice: 120000,
      packageSize: 1000,
      recipeAmount: 18,
      unit: 'gram',
    ),
    const HppIngredientItem(
      name: 'Susu Fresh UHT',
      cost: 2925,
      packagePrice: 19500,
      packageSize: 1000,
      recipeAmount: 150,
      unit: 'ml',
    ),
    const HppIngredientItem(
      name: 'Sirup Gula Aren',
      cost: 1350,
      packagePrice: 45000,
      packageSize: 1000,
      recipeAmount: 30,
      unit: 'ml',
    ),
  ];

  // ---------------------------------------------------------------------------
  // STATE 2: RETAIL, RESELLER & OLSHOP
  // ---------------------------------------------------------------------------
  final _retailNameCtrl = TextEditingController(text: 'Kemeja Katun Oversize');
  final _retailCostCtrl = TextEditingController(text: '65000');
  final _retailShippingCtrl = TextEditingController(text: '4000');
  final _retailPackagingCtrl = TextEditingController(text: '2500');
  final _retailCustomPriceCtrl = TextEditingController();
  double _retailMarketplaceFee = 6.5; // Shopee/TikTok rata-rata 6.5%
  double _retailTargetMargin = 30.0;
  int _retailDailyUnits = 12;

  // ---------------------------------------------------------------------------
  // STATE 3: JASA & PROYEK / FREELANCE
  // ---------------------------------------------------------------------------
  final _serviceNameCtrl = TextEditingController(text: 'Jasa Desain Logo & Brand Kit');
  final _serviceMaterialCtrl = TextEditingController(text: '150000');
  final _serviceHoursCtrl = TextEditingController(text: '8');
  final _serviceRateCtrl = TextEditingController(text: '50000');
  final _serviceCustomPriceCtrl = TextEditingController();
  double _serviceMargin = 25.0;
  int _serviceMonthlyProjects = 4;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fnbNameCtrl.dispose();
    _fnbYieldCtrl.dispose();
    _fnbOverheadCtrl.dispose();
    _fnbCustomPriceCtrl.dispose();

    _retailNameCtrl.dispose();
    _retailCostCtrl.dispose();
    _retailShippingCtrl.dispose();
    _retailPackagingCtrl.dispose();
    _retailCustomPriceCtrl.dispose();

    _serviceNameCtrl.dispose();
    _serviceMaterialCtrl.dispose();
    _serviceHoursCtrl.dispose();
    _serviceRateCtrl.dispose();
    _serviceCustomPriceCtrl.dispose();
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
              'Kalkulator HPP Profesional',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            Text(
              'Hitung Harga Pokok, Margin & Proyeksi Laba Usaha',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 11,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Katalog Menu & Jualan',
            onPressed: () => context.push(AppRouter.menuCatalog),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryOf(context),
          tabs: const [
            Tab(icon: Icon(Icons.restaurant_rounded), text: 'Kuliner / FnB'),
            Tab(icon: Icon(Icons.shopping_bag_rounded), text: 'Retail / Olshop'),
            Tab(icon: Icon(Icons.handyman_rounded), text: 'Jasa / Proyek'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFnbTab(context, isDark),
          _buildRetailTab(context, isDark),
          _buildServiceTab(context, isDark),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. TAB KULINER / FNB
  // ===========================================================================
  Widget _buildFnbTab(BuildContext context, bool isDark) {
    final portionYield = int.tryParse(_fnbYieldCtrl.text) ?? 1;
    final overhead = int.tryParse(_fnbOverheadCtrl.text) ?? 0;
    final customPrice = int.tryParse(_fnbCustomPriceCtrl.text);

    final result = HppEngine.calculateFnb(
      ingredients: _fnbIngredients,
      portionYield: portionYield,
      overheadPerPortion: overhead,
      wastePercent: _fnbWastePercent,
      targetFoodCostPercent: _fnbTargetFoodCost,
      customSellingPrice: customPrice,
    );

    final projection = HppEngine.calculateProjection(
      sellingPrice: result.suggestedSellingPrice,
      hpp: result.hppPerPortion,
      dailyUnits: _fnbDailyUnits,
      activeDays: 30,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nama Produk Menu
          TextField(
            controller: _fnbNameCtrl,
            decoration: InputDecoration(
              labelText: 'Nama Menu / Makanan / Minuman',
              hintText: 'Contoh: Es Kopi Susu Aren, Ayam Geprek',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.fastfood_rounded),
            ),
          ),
          const SizedBox(height: 18),

          // Header Bahan Baku Resep
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Komposisi Resep & Takaran',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_fnbIngredients.length} bahan baku ditambahkan',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryOf(context)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  foregroundColor: AppColors.primaryDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showSmartIngredientDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Tambah Bahan'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // List Bahan Baku
          if (_fnbIngredients.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.kitchen_rounded, size: 36, color: AppColors.textSecondaryOf(context).withValues(alpha: 0.5)),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada bahan baku.\nTekan tombol "+ Tambah Bahan" untuk input resep.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryOf(context)),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _fnbIngredients.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = _fnbIngredients[i];
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
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600)),
                            if (item.hasDetailedBreakdown)
                              Text(
                                '${item.recipeAmount} ${item.unit ?? ''} (dari beli ${CurrencyFormatter.format(item.packagePrice!)} / ${item.packageSize} ${item.unit ?? ''})',
                                style: AppTypography.bodySmall.copyWith(fontSize: 10.5, color: AppColors.textSecondaryOf(context)),
                              )
                            else
                              Text(
                                'Input nominal langsung',
                                style: AppTypography.bodySmall.copyWith(fontSize: 10.5, color: AppColors.textSecondaryOf(context)),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(item.cost),
                        style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.danger),
                        tooltip: 'Hapus Bahan',
                        onPressed: () {
                          setState(() {
                            _fnbIngredients.removeAt(i);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 18),

          // Porsi & Biaya Overhead/Kemasan
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fnbYieldCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Hasil Porsi Resep',
                    hintText: '1',
                    helperText: 'Porsi yang dihasilkan',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.pie_chart_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _fnbOverheadCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Kemasan & Cup (Rp)',
                    hintText: '1500',
                    helperText: 'Cup, sedotan, kresek, stiker',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.takeout_dining_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Toleransi Susut / Waste Bahan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Toleransi Susut Bahan (Waste)', style: AppTypography.labelMedium),
              Text(
                '${_fnbWastePercent.toStringAsFixed(0)}% (+${CurrencyFormatter.format(result.wasteCostPerPortion)})',
                style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: Colors.amber),
              ),
            ],
          ),
          Slider(
            value: _fnbWastePercent,
            min: 0.0,
            max: 15.0,
            divisions: 15,
            activeColor: Colors.amber,
            label: '${_fnbWastePercent.toStringAsFixed(0)}%',
            onChanged: (val) => setState(() => _fnbWastePercent = val),
          ),
          const SizedBox(height: 8),

          // Slider Target Food Cost %
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Target Food Cost %', style: AppTypography.labelMedium),
              Text(
                '${_fnbTargetFoodCost.toStringAsFixed(0)}% (Ideal: 30% - 38%)',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _fnbTargetFoodCost,
            min: 20.0,
            max: 60.0,
            divisions: 40,
            activeColor: AppColors.primary,
            label: '${_fnbTargetFoodCost.toStringAsFixed(0)}%',
            onChanged: (val) => setState(() => _fnbTargetFoodCost = val),
          ),
          const SizedBox(height: 12),

          // Custom Selling Price Override (Opsional)
          TextField(
            controller: _fnbCustomPriceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Punya Patokan Harga Jual Sendiri? (Opsional)',
              hintText: 'Kosongkan untuk pakai rekomendasi otomatis',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.price_check_rounded),
              suffixIcon: _fnbCustomPriceCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _fnbCustomPriceCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),

          // KARTU HASIL & PROYEKSI FNB
          _buildResultSummaryCard(
            context,
            isDark,
            title: 'ANALISIS HPP KULINER & FNB',
            hppValue: result.hppPerPortion,
            sellingPriceValue: result.suggestedSellingPrice,
            promoPriceValue: result.promoPrice,
            premiumPriceValue: result.premiumPrice,
            profitValue: result.grossProfitPerPortion,
            marginPercent: result.profitMarginPercent,
            healthStatus: result.healthStatus,
            healthMessage: result.healthMessage,
            costRatioText: 'Food Cost Ratio: ${result.foodCostPercent}% dari harga jual',
            onApplyPrice: (price) {
              _fnbCustomPriceCtrl.text = price.toString();
              setState(() {});
            },
            dailyUnits: _fnbDailyUnits,
            projection: projection,
            onDailyUnitsChanged: (val) => setState(() => _fnbDailyUnits = val),
            onSaveToCatalog: () => _saveToCatalog(
              name: _fnbNameCtrl.text.trim(),
              type: 'fnb',
              costPrice: result.hppPerPortion,
              sellingPrice: result.suggestedSellingPrice,
              ingredients: _fnbIngredients,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. TAB RETAIL, RESELLER & OLSHOP
  // ===========================================================================
  Widget _buildRetailTab(BuildContext context, bool isDark) {
    final costPrice = int.tryParse(_retailCostCtrl.text) ?? 0;
    final shipping = int.tryParse(_retailShippingCtrl.text) ?? 0;
    final packaging = int.tryParse(_retailPackagingCtrl.text) ?? 0;
    final customPrice = int.tryParse(_retailCustomPriceCtrl.text);

    final result = HppEngine.calculateRetail(
      costPrice: costPrice,
      shippingPerUnit: shipping,
      packagingCost: packaging,
      marketplaceFeePercent: _retailMarketplaceFee,
      targetMarginPercent: _retailTargetMargin,
      customSellingPrice: customPrice,
    );

    final projection = HppEngine.calculateProjection(
      sellingPrice: result.suggestedSellingPrice,
      hpp: result.totalCogs,
      dailyUnits: _retailDailyUnits,
      activeDays: 30,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nama Produk Retail
          TextField(
            controller: _retailNameCtrl,
            decoration: InputDecoration(
              labelText: 'Nama Produk / Barang Jualan',
              hintText: 'Contoh: Kemeja Flanel, Tas Selempang, Snack Box',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.shopping_bag_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // Modal Kulakan Supplier
          TextField(
            controller: _retailCostCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Harga Beli Kulakan Modal (Rp)',
              hintText: '65000',
              helperText: 'Harga beli dari supplier per unit',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.inventory_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // Ongkir Masuk & Biaya Packing
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _retailShippingCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Ongkir Masuk / Pcs',
                    hintText: '4000',
                    helperText: 'Bagi total ongkir kargo',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.local_shipping_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _retailPackagingCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Kemasan Packing / Pcs',
                    hintText: '2500',
                    helperText: 'Dus, bubble wrap, polymailer',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.inventory_2_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Potongan Admin Marketplace
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Potongan Admin Marketplace (%)', style: AppTypography.labelMedium),
              Text(
                '${_retailMarketplaceFee.toStringAsFixed(1)}% (${CurrencyFormatter.format(result.marketplaceFeeAmount)})',
                style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
            ],
          ),
          Slider(
            value: _retailMarketplaceFee,
            min: 0.0,
            max: 15.0,
            divisions: 30,
            activeColor: Colors.blueAccent,
            label: '${_retailMarketplaceFee.toStringAsFixed(1)}%',
            onChanged: (val) => setState(() => _retailMarketplaceFee = val),
          ),
          // Preset Chip Marketplace
          Wrap(
            spacing: 8,
            children: [
              _buildPresetChip('Offline / Toko (0%)', 0.0, _retailMarketplaceFee, (v) => setState(() => _retailMarketplaceFee = v)),
              _buildPresetChip('Tokopedia (4.5%)', 4.5, _retailMarketplaceFee, (v) => setState(() => _retailMarketplaceFee = v)),
              _buildPresetChip('Shopee (6.5%)', 6.5, _retailMarketplaceFee, (v) => setState(() => _retailMarketplaceFee = v)),
              _buildPresetChip('TikTok Shop (8.0%)', 8.0, _retailMarketplaceFee, (v) => setState(() => _retailMarketplaceFee = v)),
            ],
          ),
          const SizedBox(height: 16),

          // Target Margin Bersih (%)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Target Margin Bersih (%)', style: AppTypography.labelMedium),
              Text(
                '${_retailTargetMargin.toStringAsFixed(0)}% (Ideal: 25% - 40%)',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _retailTargetMargin,
            min: 10.0,
            max: 60.0,
            divisions: 50,
            activeColor: AppColors.primary,
            label: '${_retailTargetMargin.toStringAsFixed(0)}%',
            onChanged: (val) => setState(() => _retailTargetMargin = val),
          ),
          const SizedBox(height: 12),

          // Custom Selling Price
          TextField(
            controller: _retailCustomPriceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Punya Patokan Harga Jual Sendiri? (Opsional)',
              hintText: 'Kosongkan untuk pakai rekomendasi otomatis',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.price_check_rounded),
              suffixIcon: _retailCustomPriceCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _retailCustomPriceCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),

          // KARTU HASIL & PROYEKSI RETAIL
          _buildResultSummaryCard(
            context,
            isDark,
            title: 'ANALISIS HPP RETAIL & OLSHOP',
            hppValue: result.totalCogs,
            sellingPriceValue: result.suggestedSellingPrice,
            promoPriceValue: result.promoPrice,
            premiumPriceValue: result.premiumPrice,
            profitValue: result.netProfit,
            marginPercent: result.netMarginPercent,
            healthStatus: result.healthStatus,
            healthMessage: result.healthMessage,
            costRatioText: 'Modal: ${CurrencyFormatter.format(result.totalCogs)} • Admin MP: ${CurrencyFormatter.format(result.marketplaceFeeAmount)}',
            onApplyPrice: (price) {
              _retailCustomPriceCtrl.text = price.toString();
              setState(() {});
            },
            dailyUnits: _retailDailyUnits,
            projection: projection,
            onDailyUnitsChanged: (val) => setState(() => _retailDailyUnits = val),
            onSaveToCatalog: () => _saveToCatalog(
              name: _retailNameCtrl.text.trim(),
              type: 'retail',
              costPrice: result.totalCogs,
              sellingPrice: result.suggestedSellingPrice,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. TAB JASA & PROYEK / FREELANCE
  // ===========================================================================
  Widget _buildServiceTab(BuildContext context, bool isDark) {
    final material = int.tryParse(_serviceMaterialCtrl.text) ?? 0;
    final hours = double.tryParse(_serviceHoursCtrl.text) ?? 1.0;
    final rate = int.tryParse(_serviceRateCtrl.text) ?? 50000;
    final customPrice = int.tryParse(_serviceCustomPriceCtrl.text);

    final result = HppEngine.calculateService(
      materialCost: material,
      estimatedHours: hours,
      hourlyRate: rate,
      profitMarginPercent: _serviceMargin,
      customSellingPrice: customPrice,
    );

    final projection = HppEngine.calculateProjection(
      sellingPrice: result.suggestedSellingPrice,
      hpp: result.totalHpp,
      dailyUnits: _serviceMonthlyProjects,
      activeDays: 1, // Untuk jasa: satuan adalah proyek per bulan
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nama Jasa
          TextField(
            controller: _serviceNameCtrl,
            decoration: InputDecoration(
              labelText: 'Nama Layanan / Proyek Jasa',
              hintText: 'Contoh: Desain Feed Instagram, Jasa Servis AC',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.handyman_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // Biaya Material & Aset
          TextField(
            controller: _serviceMaterialCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Biaya Material / Lisensi / Server (Rp)',
              hintText: '150000',
              helperText: 'Aset font, lisensi stock photo, sparepart, dll.',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.extension_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // Estimasi Jam & Tarif per Jam
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serviceHoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Estimasi Jam Kerja',
                    hintText: '8',
                    helperText: 'Total jam pengerjaan',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.schedule_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _serviceRateCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Tarif Tenaga (Rp/Jam)',
                    hintText: '50000',
                    helperText: 'Upah keahlian Anda / jam',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.payments_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Target Margin Keuntungan (%)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Target Margin Keuntungan (%)', style: AppTypography.labelMedium),
              Text(
                '${_serviceMargin.toStringAsFixed(0)}% (Ideal: 20% - 35%)',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _serviceMargin,
            min: 10.0,
            max: 50.0,
            divisions: 40,
            activeColor: AppColors.primary,
            label: '${_serviceMargin.toStringAsFixed(0)}%',
            onChanged: (val) => setState(() => _serviceMargin = val),
          ),
          const SizedBox(height: 12),

          // Custom Selling Price
          TextField(
            controller: _serviceCustomPriceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Punya Patokan Harga Invoice Sendiri? (Opsional)',
              hintText: 'Kosongkan untuk pakai rekomendasi otomatis',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.price_check_rounded),
              suffixIcon: _serviceCustomPriceCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _serviceCustomPriceCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),

          // KARTU HASIL & PROYEKSI JASA
          _buildResultSummaryCard(
            context,
            isDark,
            title: 'ANALISIS TARIF JASA & FREELANCE',
            hppValue: result.totalHpp,
            sellingPriceValue: result.suggestedSellingPrice,
            promoPriceValue: result.promoPrice,
            premiumPriceValue: result.premiumPrice,
            profitValue: result.profit,
            marginPercent: result.profitMarginPercent,
            healthStatus: result.healthStatus,
            healthMessage: result.healthMessage,
            costRatioText: 'Material: ${CurrencyFormatter.format(result.materialCost)} • Jasa Tenaga: ${CurrencyFormatter.format(result.laborCost)}',
            onApplyPrice: (price) {
              _serviceCustomPriceCtrl.text = price.toString();
              setState(() {});
            },
            isServiceMode: true,
            dailyUnits: _serviceMonthlyProjects,
            projection: projection,
            onDailyUnitsChanged: (val) => setState(() => _serviceMonthlyProjects = val),
            onSaveToCatalog: () => _saveToCatalog(
              name: _serviceNameCtrl.text.trim(),
              type: 'service',
              costPrice: result.totalHpp,
              sellingPrice: result.suggestedSellingPrice,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET KARTU HASIL & SIMULASI PROYEKSI LABA
  // ===========================================================================
  Widget _buildResultSummaryCard(
    BuildContext context,
    bool isDark, {
    required String title,
    required int hppValue,
    required int sellingPriceValue,
    required int promoPriceValue,
    required int premiumPriceValue,
    required int profitValue,
    required double marginPercent,
    required HppHealthStatus healthStatus,
    required String healthMessage,
    required String costRatioText,
    required ValueChanged<int> onApplyPrice,
    required int dailyUnits,
    required MonthlyProjectionResult projection,
    required ValueChanged<int> onDailyUnitsChanged,
    required VoidCallback onSaveToCatalog,
    bool isServiceMode = false,
  }) {
    Color healthColor;
    IconData healthIcon;
    switch (healthStatus) {
      case HppHealthStatus.healthy:
        healthColor = const Color(0xFF10B981);
        healthIcon = Icons.check_circle_rounded;
        break;
      case HppHealthStatus.warning:
        healthColor = const Color(0xFFF59E0B);
        healthIcon = Icons.warning_amber_rounded;
        break;
      case HppHealthStatus.danger:
        healthColor = const Color(0xFFEF4444);
        healthIcon = Icons.error_outline_rounded;
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
          // Header & Health Status Badge
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
                  color: healthColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: healthColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(healthIcon, size: 14, color: healthColor),
                    const SizedBox(width: 5),
                    Text(
                      healthStatus == HppHealthStatus.healthy
                          ? 'Margin Sehat'
                          : (healthStatus == HppHealthStatus.warning ? 'Waspada' : 'Kritis'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: healthColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            healthMessage,
            style: const TextStyle(fontSize: 11.5, color: Colors.white70),
          ),
          const SizedBox(height: 16),

          // Split View: HPP vs Harga Jual Ideal
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Harga Pokok (HPP)', style: AppTypography.bodySmall.copyWith(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(hppValue),
                      style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 42, color: Colors.white24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Harga Jual Ideal', style: AppTypography.bodySmall.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(sellingPriceValue),
                      style: AppTypography.titleLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tiga Tingkat Rekomendasi Harga (Tier Pricing)
          Text(
            'PILIHAN TIER HARGA JUAL:',
            style: AppTypography.labelSmall.copyWith(color: Colors.white54, fontSize: 10, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTierPriceCard('Promo/Grosir', promoPriceValue, onApplyPrice),
              const SizedBox(width: 8),
              _buildTierPriceCard('Ideal (Sehat)', sellingPriceValue, onApplyPrice, isRecommended: true),
              const SizedBox(width: 8),
              _buildTierPriceCard('Premium', premiumPriceValue, onApplyPrice),
            ],
          ),
          const SizedBox(height: 14),

          const Divider(color: Colors.white24),
          const SizedBox(height: 10),

          // Detail Laba Bersih & Rasio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimasi Laba Bersih:',
                style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
              ),
              Text(
                '${CurrencyFormatter.format(profitValue)} (${marginPercent.toStringAsFixed(1)}%)',
                style: AppTypography.titleMedium.copyWith(color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            costRatioText,
            style: AppTypography.bodySmall.copyWith(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 16),

          // SIMULASI PROYEKSI LABA BULANAN
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isServiceMode ? 'Simulasi Proyek / Bulan:' : 'Simulasi Penjualan / Hari:',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    Text(
                      isServiceMode ? '$dailyUnits proyek/bln' : '$dailyUnits unit/hari',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                Slider(
                  value: dailyUnits.toDouble(),
                  min: 1.0,
                  max: isServiceMode ? 20.0 : 150.0,
                  divisions: isServiceMode ? 19 : 149,
                  activeColor: AppColors.primary,
                  onChanged: (val) => onDailyUnitsChanged(val.toInt()),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildProjectionMetric(
                        'Total Terjual',
                        isServiceMode ? '${projection.monthlyUnits} Proyek' : '${projection.monthlyUnits} Pcs',
                        Colors.white70,
                      ),
                    ),
                    Expanded(
                      child: _buildProjectionMetric(
                        'Estimasi Omzet',
                        CurrencyFormatter.format(projection.monthlyRevenue),
                        Colors.white,
                      ),
                    ),
                    Expanded(
                      child: _buildProjectionMetric(
                        'Estimasi Laba',
                        CurrencyFormatter.format(projection.monthlyGrossProfit),
                        Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Tombol Simpan ke Katalog Jualan
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onSaveToCatalog,
            icon: const Icon(Icons.bookmark_add_rounded, size: 20),
            label: const Text(
              'Simpan ke Katalog Produk & Kasir',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierPriceCard(
    String label,
    int price,
    ValueChanged<int> onApply, {
    bool isRecommended = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => onApply(price),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isRecommended
                ? AppColors.primary.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isRecommended ? AppColors.primary : Colors.white12,
              width: isRecommended ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isRecommended ? FontWeight.bold : FontWeight.normal,
                  color: isRecommended ? AppColors.primary : Colors.white70,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                CurrencyFormatter.format(price),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isRecommended ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectionMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, double value, double currentValue, ValueChanged<double> onSelect) {
    final isSelected = (value - currentValue).abs() < 0.1;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: Colors.blueAccent.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? Colors.blueAccent : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => onSelect(value),
    );
  }

  // ===========================================================================
  // DIALOG INPUT BAHAN CERDAS (SMART UNIT CONVERTER)
  // ===========================================================================
  void _showSmartIngredientDialog(BuildContext context) {
    int activeInputMode = 0; // 0: Takaran Riil Kemasan, 1: Nominal Langsung

    final nameCtrl = TextEditingController();
    final pkgPriceCtrl = TextEditingController();
    final pkgSizeCtrl = TextEditingController(text: '1000');
    final recipeAmountCtrl = TextEditingController();
    final directCostCtrl = TextEditingController();
    String selectedUnit = 'gram';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final pkgPrice = int.tryParse(pkgPriceCtrl.text) ?? 0;
            final pkgSize = double.tryParse(pkgSizeCtrl.text) ?? 0.0;
            final recipeAmt = double.tryParse(recipeAmountCtrl.text) ?? 0.0;

            final calculatedCost = HppEngine.calculateIngredientCost(
              packagePrice: pkgPrice,
              packageSize: pkgSize,
              recipeAmount: recipeAmt,
            );

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Tambah Bahan Baku', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode Selector Pill
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).dividerColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => activeInputMode = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: activeInputMode == 0 ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'Takaran Beli (Otomatis)',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: activeInputMode == 0 ? Colors.white : AppColors.textSecondaryOf(ctx),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => activeInputMode = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: activeInputMode == 1 ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'Nominal Langsung',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: activeInputMode == 1 ? Colors.white : AppColors.textSecondaryOf(ctx),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nama Bahan
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Bahan Baku',
                        hintText: 'Misal: Biji Kopi Robusta, Susu Fresh, Tepung',
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (activeInputMode == 0) ...[
                      // MODE 1: TAKARAN RIIL KEMASAN
                      TextField(
                        controller: pkgPriceCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Harga Beli 1 Kemasan (Rp)',
                          hintText: '120000',
                          helperText: 'Harga saat Anda beli di toko/pasar',
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: pkgSizeCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setDialogState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Isi Kemasan',
                                hintText: '1000',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedUnit,
                              decoration: const InputDecoration(labelText: 'Satuan'),
                              items: const [
                                DropdownMenuItem(value: 'gram', child: Text('gram')),
                                DropdownMenuItem(value: 'ml', child: Text('ml')),
                                DropdownMenuItem(value: 'pcs', child: Text('pcs/biji')),
                                DropdownMenuItem(value: 'lembar', child: Text('lembar')),
                                DropdownMenuItem(value: 'sdm', child: Text('sdm')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedUnit = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: recipeAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Takaran Dipakai di Resep ($selectedUnit)',
                          hintText: '18',
                          helperText: 'Jumlah $selectedUnit yang masuk 1 resep',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Box Preview Hasil Hitungan
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Biaya Bahan di Resep:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            Text(
                              CurrencyFormatter.format(calculatedCost),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // MODE 2: INPUT CEPAT DIRECT
                      TextField(
                        controller: directCostCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Biaya Terpakai Langsung (Rp)',
                          hintText: '3500',
                          helperText: 'Nominal rupiah bahan untuk resep ini',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;

                    int finalCost = 0;
                    HppIngredientItem newItem;

                    if (activeInputMode == 0) {
                      finalCost = calculatedCost;
                      if (finalCost <= 0) return;
                      newItem = HppIngredientItem(
                        name: name,
                        cost: finalCost,
                        packagePrice: pkgPrice,
                        packageSize: pkgSize,
                        recipeAmount: recipeAmt,
                        unit: selectedUnit,
                      );
                    } else {
                      finalCost = int.tryParse(directCostCtrl.text) ?? 0;
                      if (finalCost <= 0) return;
                      newItem = HppIngredientItem(name: name, cost: finalCost);
                    }

                    setState(() {
                      _fnbIngredients.add(newItem);
                    });
                    Navigator.pop(ctx);
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

  // ===========================================================================
  // SIMPAN KE KATALOG MENU
  // ===========================================================================
  Future<void> _saveToCatalog({
    required String name,
    required String type,
    required int costPrice,
    required int sellingPrice,
    List<HppIngredientItem>? ingredients,
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 1600),
          content: Text('Nama produk tidak boleh kosong'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final repo = ref.read(menuRepositoryProvider);
    final jsonStr = ingredients != null && ingredients.isNotEmpty
        ? jsonEncode(ingredients.map((e) => e.toMap()).toList())
        : null;

    final item = MenuItem(
      name: name,
      type: type,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      ingredientsJson: jsonStr,
      createdAt: DateTime.now(),
    );

    await repo.insertMenu(item);
    ref.read(menuRefreshTriggerProvider.notifier).state++;

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1800),
          content: Text('Produk "$name" berhasil disimpan ke Katalog Jualan!'),
          backgroundColor: AppColors.primary,
          action: SnackBarAction(
            label: 'Lihat Katalog',
            textColor: Colors.white,
            onPressed: () => context.push(AppRouter.menuCatalog),
          ),
        ),
      );
    }
  }
}
