import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../data/database/app_database.dart';
import '../providers/profile_provider.dart';

class ProfileSwitcherSheet extends ConsumerWidget {
  const ProfileSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ProfileSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profilesAsync = ref.watch(profilesListProvider);
    final activeKeyAsync = ref.watch(activeProfileKeyProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Profil Keuangan',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Data rekening, catatan & anggaran terpisah mandiri',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 22),
                  tooltip: 'Kelola Profil',
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(AppRouter.profiles);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Profiles List
            profilesAsync.when(
              data: (profiles) {
                final activeKey = activeKeyAsync.valueOrNull ?? AppDatabase.defaultProfileKey;
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: profiles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = profiles[index];
                    final isActive = p.key == activeKey;
                    final profileColor = ColorHelper.fromHex(p.colorHex);

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        if (!isActive) {
                          await switchActiveProfile(ref, p.key);
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? (isDark ? profileColor.withValues(alpha: 0.15) : profileColor.withValues(alpha: 0.08))
                              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive ? profileColor : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                            width: isActive ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: profileColor.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                IconHelper.getIcon(p.iconCodePoint, fallback: p.isBusiness ? Icons.storefront_rounded : Icons.person_rounded),
                                color: profileColor,
                                size: 22,
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                                  const SizedBox(height: 3),
                                  Text(
                                    p.isBusiness ? 'Kasir, omzet & biaya operasional usaha' : 'Pengeluaran dapur & tabungan harian',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondaryOf(context),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isActive)
                              Icon(Icons.check_circle_rounded, color: profileColor, size: 22)
                            else
                              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondaryOf(context), size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (e, _) => Text('Gagal memuat profil: $e'),
            ),
            const SizedBox(height: 18),

            // Button Tambah / Kelola Profil
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: BorderSide(
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                context.push(AppRouter.profiles);
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                'Kelola & Tambah Profil Baru',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
