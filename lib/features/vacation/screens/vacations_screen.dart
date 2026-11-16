import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/vacation.dart';
import '../providers/vacation_providers.dart';
import 'create_vacation_sheet.dart';

class VacationsScreen extends ConsumerWidget {
  const VacationsScreen({super.key});

  void _openCreateSheet(BuildContext context) async {
    final newId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.88,
        child: CreateVacationSheet(),
      ),
    );

    if (newId != null && context.mounted) {
      context.push('${AppRouter.vacationDetail}?id=$newId');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeVacationsAsync = ref.watch(activeVacationsProvider);
    final completedVacationsAsync = ref.watch(completedVacationsProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      appBar: AppBar(
        title: Text(
          'Kantong Liburan',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openCreateSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
        children: [
          // Section: Trip Liburan Aktif
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TRIP AKTIF',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 11,
                ),
              ),
              activeVacationsAsync.when(
                data: (list) => Text(
                  '${list.length} Trip',
                  style: AppTypography.labelSmall.copyWith(
                    color: const Color(0xFF0284C7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          activeVacationsAsync.when(
            data: (vacations) {
              if (vacations.isEmpty) {
                return _buildEmptyActiveState(context, isDark);
              }
              return Column(
                children: vacations
                    .map((vac) => _buildVacationCard(context, ref, vac, isDark))
                    .toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),

          const SizedBox(height: 24),

          // Section: Riwayat Trip Selesai
          completedVacationsAsync.when(
            data: (completed) {
              if (completed.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRIP SELESAI',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...completed.map(
                      (vac) => _buildVacationCard(context, ref, vac, isDark)),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Rencanakan Trip',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildEmptyActiveState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.beach_access_rounded,
                size: 26,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum Ada Trip Aktif',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pisahkan bujet liburan agar saldo harian tetap aman.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => _openCreateSheet(context),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Rencanakan Trip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVacationCard(
      BuildContext context, WidgetRef ref, VacationModel vac, bool isDark) {
    final detailAsync = ref.watch(vacationDetailProvider(vac.id!));

    return GestureDetector(
      onTap: () {
        context.push('${AppRouter.vacationDetail}?id=${vac.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: vac.isActive
                ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            width: vac.isActive ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('🌴', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vac.name,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (vac.destination != null)
                        Text(
                          vac.destination!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: vac.isActive
                        ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    vac.isActive ? 'Aktif' : 'Selesai',
                    style: TextStyle(
                      color: vac.isActive
                          ? const Color(0xFF0284C7)
                          : Colors.grey,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            detailAsync.when(
              data: (detail) {
                if (detail == null) return const SizedBox.shrink();
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sisa Dana',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Rp ${CurrencyFormatter.format(detail.remainingBudget)}',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0284C7),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: detail.spentPercentage,
                        minHeight: 5,
                        backgroundColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF0284C7)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${detail.accounts.length} Rekening',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          'Terpakai Rp ${CurrencyFormatter.format(detail.totalSpent)}',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
