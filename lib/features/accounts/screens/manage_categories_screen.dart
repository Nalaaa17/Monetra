import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../data/models/category.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';

class ManageCategoriesScreen extends ConsumerStatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  ConsumerState<ManageCategoriesScreen> createState() =>
      _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState
    extends ConsumerState<ManageCategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Kelola Kategori',
          style: AppTypography.headlineMedium.copyWith(fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textSecondaryOf(context),
          tabs: const [
            Tab(text: '💸 Pengeluaran'),
            Tab(text: '💰 Pemasukan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList('expense'),
          _buildCategoryList('income'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(
          context,
          _tabController.index == 0 ? 'expense' : 'income',
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
    );
  }

  Widget _buildCategoryList(String type) {
    ref.watch(homeRefreshTriggerProvider);
    final categoryRepo = ref.watch(categoryRepositoryProvider);

    return FutureBuilder<List<Category>>(
      future: categoryRepo.getAllCategories(type: type, onlyActive: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data!;
        if (categories.isEmpty) {
          return const Center(child: Text('Belum ada kategori'));
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: categories.length,
          separatorBuilder: (context, index) =>
              Divider(height: 12, color: Theme.of(context).dividerColor),
          itemBuilder: (context, index) {
            final cat = categories[index];
            final color = ColorHelper.parseHex(cat.colorHex);
            final icon = IconHelper.getIcon(cat.iconCodePoint);

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Text(
                cat.name,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                cat.isActive ? 'Aktif' : 'Disembunyikan',
                style: AppTypography.labelSmall.copyWith(
                  color: cat.isActive ? const Color(0xFF059669) : AppColors.textSecondaryOf(context),
                ),
              ),
              trailing: Switch(
                value: cat.isActive,
                activeThumbColor: AppColors.primary,
                onChanged: (val) async {
                  await categoryRepo.toggleActive(cat.id!, val);
                  ref.read(homeRefreshTriggerProvider.notifier).state++;
                  setState(() {});
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCategoryDialog(BuildContext context, String currentType) {
    final nameController = TextEditingController();
    String selectedColor = '0xFFEF4444';
    int selectedIcon = Icons.shopping_bag_rounded.codePoint;

    final colorOptions = [
      '0xFFEF4444', // Merah
      '0xFFF59E0B', // Kuning/Oranye
      '0xFF10B981', // Hijau
      '0xFF3B82F6', // Biru
      '0xFF8B5CF6', // Ungu
      '0xFFEC4899', // Pink
      '0xFF14B8A6', // Teal
      '0xFF6B7280', // Abu
    ];

    final iconOptions = [
      Icons.shopping_bag_rounded,
      Icons.fastfood_rounded,
      Icons.local_cafe_rounded,
      Icons.directions_car_rounded,
      Icons.local_mall_rounded,
      Icons.fitness_center_rounded,
      Icons.pets_rounded,
      Icons.school_rounded,
      Icons.flight_takeoff_rounded,
      Icons.home_repair_service_rounded,
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(currentType == 'expense'
              ? 'Tambah Kategori Pengeluaran'
              : 'Tambah Kategori Pemasukan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kategori',
                    hintText: 'Misal: Kopi, Skincare, Donasi',
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Pilih Ikon:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: iconOptions.map((iconData) {
                    final isSelected = selectedIcon == iconData.codePoint;
                    return InkWell(
                      onTap: () =>
                          setState(() => selectedIcon = iconData.codePoint),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : (Theme.of(ctx).brightness == Brightness.dark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryDark
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(iconData, size: 22),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Pilih Warna:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: colorOptions.map((c) {
                    final color = ColorHelper.parseHex(c);
                    final isSelected = selectedColor == c;
                    return InkWell(
                      onTap: () => setState(() => selectedColor = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? (Theme.of(ctx).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final repo = ref.read(categoryRepositoryProvider);
                await repo.insertCategory(
                  Category(
                    name: name,
                    type: currentType,
                    iconCodePoint: selectedIcon,
                    colorHex: selectedColor,
                    isActive: true,
                  ),
                );

                ref.read(homeRefreshTriggerProvider.notifier).state++;
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (!mounted) return;
                AppSnackBar.showSuccess(
                  this.context,
                  'Kategori "$name" berhasil disimpan!',
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    ).whenComplete(nameController.dispose);
  }
}
