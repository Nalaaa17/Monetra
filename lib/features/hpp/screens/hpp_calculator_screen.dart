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

  // State FnB
  final _fnbNameCtrl = TextEditingController(text: 'Kopi Susu Aren');
  final _fnbYieldCtrl = TextEditingController(text: '1');
  final _fnbOverheadCtrl = TextEditingController(text: '1500');
  double _fnbTargetFoodCost = 35.0;
  final List<HppIngredientItem> _fnbIngredients = [
    const HppIngredientItem(name: 'Espresso Blend (20g)', cost: 3500),
    const HppIngredientItem(name: 'Susu UHT Fresh (150ml)', cost: 4000),
    const HppIngredientItem(name: 'Gula Aren Organik (30ml)', cost: 1500),
  ];

  // State Jasa
  final _serviceNameCtrl = TextEditingController(text: 'Jasa Desain Logo & Brand Kit');
  final _serviceMaterialCtrl = TextEditingController(text: '150000');
  final _serviceHoursCtrl = TextEditingController(text: '8');
  final _serviceRateCtrl = TextEditingController(text: '50000');
  double _serviceMargin = 25.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fnbNameCtrl.dispose();
    _fnbYieldCtrl.dispose();
    _fnbOverheadCtrl.dispose();
    _serviceNameCtrl.dispose();
    _serviceMaterialCtrl.dispose();
    _serviceHoursCtrl.dispose();
    _serviceRateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      appBar: AppBar(
        title: Text(
          'Kalkulator HPP & Harga Jual',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryOf(context),
          ),
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
            Tab(icon: Icon(Icons.handyman_rounded), text: 'Jasa / Freelance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFnbTab(context, isDark),
          _buildServiceTab(context, isDark),
        ],
      ),
    );
  }

  // TAB 1: KULINER / FNB
  Widget _buildFnbTab(BuildContext context, bool isDark) {
    final portionYield = int.tryParse(_fnbYieldCtrl.text) ?? 1;
    final overhead = int.tryParse(_fnbOverheadCtrl.text) ?? 0;

    final result = HppEngine.calculateFnb(
      ingredients: _fnbIngredients,
      portionYield: portionYield,
      overheadPerPortion: overhead,
      targetFoodCostPercent: _fnbTargetFoodCost,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nama Produk
          TextField(
            controller: _fnbNameCtrl,
            decoration: InputDecoration(
              labelText: 'Nama Menu / Makanan / Minuman',
              hintText: 'Contoh: Ricebowl Sambal Matah, Es Kopi Susu',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.fastfood_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // Daftar Bahan Baku
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Komposisi Bahan Baku (Resep)',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () => _showAddIngredientDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah Bahan'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_fnbIngredients.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('Belum ada bahan baku ditambahkan.')),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.name, style: AppTypography.bodyMedium),
                      Row(
                        children: [
                          Text(
                            CurrencyFormatter.format(item.cost),
                            style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                            onPressed: () {
                              setState(() {
                                _fnbIngredients.removeAt(i);
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 16),

          // Porsi & Overhead
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fnbYieldCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Hasil Porsi',
                    hintText: '1',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    labelText: 'Overhead / Kemasan (Rp)',
                    hintText: '1500',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Slider Target Food Cost
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Target Food Cost %', style: AppTypography.labelMedium),
              Text(
                '${_fnbTargetFoodCost.toStringAsFixed(0)}% (Standar Ideal: 30% - 38%)',
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
          const SizedBox(height: 16),

          // HASIL KALKULASI CARD
          _buildResultSummaryCard(
            context,
            isDark,
            title: 'ANALISIS HPP KULINER',
            hppValue: result.hppPerPortion,
            sellingPriceValue: result.suggestedSellingPrice,
            profitValue: result.grossProfitPerPortion,
            marginPercent: result.profitMarginPercent,
            extraInfo: 'Food Cost Ratio: ${result.foodCostPercent}% dari harga jual',
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

  // TAB 2: JASA / FREELANCE
  Widget _buildServiceTab(BuildContext context, bool isDark) {
    final material = int.tryParse(_serviceMaterialCtrl.text) ?? 0;
    final hours = double.tryParse(_serviceHoursCtrl.text) ?? 1.0;
    final rate = int.tryParse(_serviceRateCtrl.text) ?? 50000;

    final result = HppEngine.calculateService(
      materialCost: material,
      estimatedHours: hours,
      hourlyRate: rate,
      profitMarginPercent: _serviceMargin,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _serviceNameCtrl,
            decoration: InputDecoration(
              labelText: 'Nama Layanan / Proyek Jasa',
              hintText: 'Contoh: Jasa Pembuatan Website, Servis AC',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.design_services_rounded),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _serviceMaterialCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Biaya Material / Lisensi / Sparepart (Rp)',
              hintText: '0',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serviceHoursCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Estimasi Jam Kerja',
                    hintText: '8',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    labelText: 'Tarif / Jam (Rp)',
                    hintText: '50000',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Target Margin Keuntungan %', style: AppTypography.labelMedium),
              Text(
                '${_serviceMargin.toStringAsFixed(0)}%',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          Slider(
            value: _serviceMargin,
            min: 10.0,
            max: 70.0,
            divisions: 60,
            activeColor: const Color(0xFF3B82F6),
            label: '${_serviceMargin.toStringAsFixed(0)}%',
            onChanged: (val) => setState(() => _serviceMargin = val),
          ),
          const SizedBox(height: 16),

          _buildResultSummaryCard(
            context,
            isDark,
            title: 'ANALISIS HPP JASA & PROYEK',
            hppValue: result.totalHpp,
            sellingPriceValue: result.suggestedSellingPrice,
            profitValue: result.profit,
            marginPercent: result.profitMarginPercent,
            extraInfo: 'Biaya Tenaga Kerja: ${CurrencyFormatter.format(result.laborCost)}',
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

  Widget _buildResultSummaryCard(
    BuildContext context,
    bool isDark, {
    required String title,
    required int hppValue,
    required int sellingPriceValue,
    required int profitValue,
    required double marginPercent,
    required String extraInfo,
    required VoidCallback onSaveToCatalog,
  }) {
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
          Text(
            title,
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white60,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
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
              Container(width: 1, height: 40, color: Colors.white24),
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
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),
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
          const SizedBox(height: 6),
          Text(
            extraInfo,
            style: AppTypography.bodySmall.copyWith(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onSaveToCatalog,
            icon: const Icon(Icons.bookmark_add_rounded, size: 20),
            label: const Text('Simpan ke Katalog Produk & Jualan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddIngredientDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final costCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Tambah Bahan Baku'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Bahan',
                  hintText: 'Misal: Biji Kopi, Tepung Terigu, Ayam',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Biaya Terpakai (Rp)',
                  hintText: '3500',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final cost = int.tryParse(costCtrl.text) ?? 0;
                if (name.isNotEmpty && cost > 0) {
                  setState(() {
                    _fnbIngredients.add(HppIngredientItem(name: name, cost: cost));
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Tambah'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveToCatalog({
    required String name,
    required String type,
    required int costPrice,
    required int sellingPrice,
    List<HppIngredientItem>? ingredients,
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama produk tidak boleh kosong'), backgroundColor: AppColors.danger),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Menu "$name" berhasil disimpan ke Katalog Jualan!'),
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
