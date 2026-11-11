import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../home/providers/home_providers.dart';
import '../providers/goal_providers.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_form_modal.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsListProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Target & Tabungan',
            style: AppTypography.headlineMedium.copyWith(fontSize: 18),
          ),
          bottom: TabBar(
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: AppColors.textSecondaryOf(context),
            indicatorColor: AppColors.primaryDark,
            indicatorWeight: 3,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🎯 Berjalan'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🎉 Tercapai'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Segarkan',
              onPressed: () {
                ref.read(homeRefreshTriggerProvider.notifier).state++;
              },
            ),
          ],
        ),
        body: goalsAsync.when(
          data: (goals) {
            final activeGoals = goals.where((g) => !g.isDone).toList();
            final completedGoals = goals.where((g) => g.isDone).toList();

            return TabBarView(
              children: [
                _buildGoalListTab(
                  context,
                  ref,
                  goals: activeGoals,
                  emptyTitle: 'Belum Ada Target Aktif',
                  emptySubtitle:
                      'Buat target tabungan atau tagihan rutin seperti "Bayar Ressa" atau "Liquid + Coil".',
                  isActiveTab: true,
                ),
                _buildGoalListTab(
                  context,
                  ref,
                  goals: completedGoals,
                  emptyTitle: 'Belum Ada Target Tercapai',
                  emptySubtitle:
                      'Target yang progresnya telah mencapai 100% akan otomatis dipindahkan ke sini.',
                  isActiveTab: false,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Gagal memuat target: $err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          ),
        ),
        floatingActionButton: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () => showGoalFormModal(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: const Icon(Icons.add_rounded, color: Colors.black, size: 22),
            label: const Text(
              'Target Baru',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalListTab(
    BuildContext context,
    WidgetRef ref, {
    required List<GoalDetail> goals,
    required String emptyTitle,
    required String emptySubtitle,
    required bool isActiveTab,
  }) {
    if (goals.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActiveTab
                      ? Icons.track_changes_rounded
                      : Icons.celebration_rounded,
                  size: 60,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                emptyTitle,
                style: AppTypography.headlineMedium.copyWith(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
              if (isActiveTab) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => showGoalFormModal(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, color: Colors.black),
                  label: const Text(
                    'Tambah Target Sekarang',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(homeRefreshTriggerProvider.notifier).state++;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
        itemCount: goals.length,
        itemBuilder: (context, index) {
          return GoalCard(detail: goals[index]);
        },
      ),
    );
  }
}
