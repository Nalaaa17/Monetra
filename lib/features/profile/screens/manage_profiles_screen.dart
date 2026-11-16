import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/color_helper.dart';
import '../../../data/database/app_database.dart';
import '../../home/providers/home_providers.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../providers/profile_provider.dart';

class ManageProfilesScreen extends ConsumerStatefulWidget {
  const ManageProfilesScreen({super.key});

  @override
  ConsumerState<ManageProfilesScreen> createState() => _ManageProfilesScreenState();
}

class _ManageProfilesScreenState extends ConsumerState<ManageProfilesScreen> {
  static const List<String> _paletteColors = [
    '0xFF10B981', // Emerald
    '0xFF3B82F6', // Blue
    '0xFFF59E0B', // Amber
    '0xFF8B5CF6', // Purple
    '0xFFEC4899', // Pink
    '0xFFEF4444', // Red
    '0xFF14B8A6', // Teal
    '0xFF6366F1', // Indigo
  ];

  static const List<int> _profileIcons = [
    0xe491, // Icons.person_rounded
    0xe5e1, // Icons.storefront_rounded
    0xe59c, // Icons.shopping_bag_rounded
    0xe11e, // Icons.business_rounded
    0xe532, // Icons.restaurant_rounded
    0xe6f2, // Icons.work_rounded
    0xe3b3, // Icons.local_shipping_rounded
    0xe3ab, // Icons.local_cafe_rounded
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profilesAsync = ref.watch(profilesListProvider);
    final activeKeyAsync = ref.watch(activeProfileKeyProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      appBar: AppBar(
        title: Text(
          'Kelola Profil',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 26),
            tooltip: 'Tambah Profil Baru',
            onPressed: () => _showProfileDialog(context),
          ),
        ],
      ),
      body: profilesAsync.when(
        data: (profiles) {
          final activeKey = activeKeyAsync.valueOrNull ?? AppDatabase.defaultProfileKey;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: profiles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final p = profiles[index];
              final isActive = p.key == activeKey;
              final isDefault = p.key == AppDatabase.defaultProfileKey;
              final color = ColorHelper.fromHex(p.colorHex);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161A23) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isActive ? color : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                    width: isActive ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            // ignore: non_const_argument_for_const_parameter
                            IconData(p.iconCodePoint, fontFamily: 'MaterialIcons'),
                            color: color,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      p.name,
                                      style: AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimaryOf(context),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: p.isBusiness
                                          ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                                          : AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      p.isBusiness ? 'Bisnis' : 'Pribadi',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: p.isBusiness ? const Color(0xFF3B82F6) : AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p.isBusiness
                                    ? 'Kategori omzet, kulakan & kas usaha'
                                    : 'Kategori belanja harian & tabungan',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondaryOf(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, color: color, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Aktif',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!isActive)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: color,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () async {
                              await switchActiveProfile(ref, p.key);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Beralih ke profil "${p.name}"'),
                                    backgroundColor: color,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.sync_alt_rounded, size: 16),
                            label: const Text('Beralih Profil'),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Ubah Profil',
                          onPressed: () => _showProfileDialog(context, existingProfile: p),
                        ),
                        if (!isDefault)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                            tooltip: 'Hapus Profil',
                            onPressed: () => _confirmDeleteProfile(context, p),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text('Gagal memuat profil: $e'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showProfileDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Profil Baru'),
      ),
    );
  }

  void _showProfileDialog(BuildContext context, {ProfileModel? existingProfile}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = existingProfile != null;
    final nameCtrl = TextEditingController(text: existingProfile?.name ?? '');
    String selectedType = existingProfile?.type ?? 'personal';
    String selectedColor = existingProfile?.colorHex ?? _paletteColors.first;
    int selectedIcon = existingProfile?.iconCodePoint ?? _profileIcons.first;
    bool switchNow = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final activeColor = ColorHelper.fromHex(selectedColor);

            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      isEdit ? 'Ubah Profil' : 'Tambah Profil Baru',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tipe Profil (hanya bisa dipilih saat buat baru)
                    if (!isEdit) ...[
                      Text(
                        'Tipe Profil',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setModalState(() {
                                selectedType = 'personal';
                                selectedIcon = 0xe491; // Icons.person
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: selectedType == 'personal'
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selectedType == 'personal' ? AppColors.primary : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      color: selectedType == 'personal' ? AppColors.primary : AppColors.textSecondaryOf(context),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Pribadi',
                                      style: AppTypography.labelMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: selectedType == 'personal' ? AppColors.primary : AppColors.textPrimaryOf(context),
                                      ),
                                    ),
                                    Text(
                                      'Harian & Tabungan',
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 10,
                                        color: AppColors.textSecondaryOf(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setModalState(() {
                                selectedType = 'business';
                                selectedIcon = 0xe5e1; // Icons.storefront
                                selectedColor = '0xFF3B82F6';
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: selectedType == 'business'
                                      ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                                      : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selectedType == 'business' ? const Color(0xFF3B82F6) : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.storefront_rounded,
                                      color: selectedType == 'business' ? const Color(0xFF3B82F6) : AppColors.textSecondaryOf(context),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Bisnis / Usaha',
                                      style: AppTypography.labelMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: selectedType == 'business' ? const Color(0xFF3B82F6) : AppColors.textPrimaryOf(context),
                                      ),
                                    ),
                                    Text(
                                      'Omzet & Kasir Toko',
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 10,
                                        color: AppColors.textSecondaryOf(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Nama Profil
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama Profil',
                        hintText: selectedType == 'business' ? 'Contoh: Toko Kopi, Kafe Berkah' : 'Contoh: Pribadi, Keluarga',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(
                          // ignore: non_const_argument_for_const_parameter
                          IconData(selectedIcon, fontFamily: 'MaterialIcons'),
                          color: activeColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pilih Warna
                    Text(
                      'Pilih Warna Aksen',
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _paletteColors.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final cHex = _paletteColors[i];
                          final c = ColorHelper.fromHex(cHex);
                          final isSelected = cHex == selectedColor;
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedColor = cHex),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pilih Ikon
                    Text(
                      'Pilih Ikon',
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _profileIcons.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final code = _profileIcons[i];
                          final isSelected = code == selectedIcon;
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedIcon = code),
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: isSelected ? activeColor.withValues(alpha: 0.18) : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? activeColor : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                // ignore: non_const_argument_for_const_parameter
                                IconData(code, fontFamily: 'MaterialIcons'),
                                color: isSelected ? activeColor : AppColors.textPrimaryOf(context),
                                size: 22,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    if (!isEdit) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: switchNow,
                        title: const Text('Langsung beralih ke profil ini setelah dibuat'),
                        onChanged: (val) => setModalState(() => switchNow = val),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Tombol Simpan
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;

                        if (isEdit) {
                          final updated = existingProfile.copyWith(
                            name: name,
                            colorHex: selectedColor,
                            iconCodePoint: selectedIcon,
                          );
                          await AppDatabase.updateProfile(updated);
                          ref.read(profileRefreshTriggerProvider.notifier).state++;
                        } else {
                          final key = selectedType == 'business'
                              ? 'bisnis_${DateTime.now().millisecondsSinceEpoch}'
                              : 'profil_${DateTime.now().millisecondsSinceEpoch}';
                          final newProfile = ProfileModel(
                            key: key,
                            name: name,
                            type: selectedType,
                            iconCodePoint: selectedIcon,
                            colorHex: selectedColor,
                            createdAt: DateTime.now(),
                          );
                          await AppDatabase.createProfile(newProfile);
                          if (switchNow) {
                            await switchActiveProfile(ref, key);
                          } else {
                            ref.read(profileRefreshTriggerProvider.notifier).state++;
                          }
                        }

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                      },
                      child: Text(
                        isEdit ? 'Simpan Perubahan' : 'Buat Profil',
                        style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteProfile(BuildContext context, ProfileModel profile) async {
    final confirmed = await AppDialog.delete(
      context,
      title: 'Hapus Profil "${profile.name}"?',
      message:
          'Seluruh data rekening, transaksi, dan riwayat yang tersimpan khusus di profil ini akan dihapus permanen.\n\nAksi ini tidak dapat dibatalkan.',
      confirmLabel: 'Hapus Profil',
    );

    if (confirmed) {
      await AppDatabase.deleteProfile(profile.key);
      ref.read(profileRefreshTriggerProvider.notifier).state++;
      ref.read(homeRefreshTriggerProvider.notifier).state++;
      if (context.mounted) {
        AppSnackBar.showError(
          context,
          'Profil "${profile.name}" berhasil dihapus',
        );
      }
    }
  }
}
