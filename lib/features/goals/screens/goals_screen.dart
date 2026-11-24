import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../home/providers/home_providers.dart';
import '../providers/goal_providers.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_form_modal.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
        backgroundColor: AppColors.surfaceOf(context),
        appBar: AppBar(
          title: Text(
            'Target Tabungan',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => showGoalFormModal(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'Target',
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: goalsAsync.when(
          data: (goals) {
            final activeGoals = goals.where((g) => !g.isDone).toList();
            final completedGoals = goals.where((g) => g.isDone).toList();

            int totalTarget = 0;
            int totalCollected = 0;
            for (final g in goals) {
              totalTarget += g.targetAmount;
              totalCollected += g.collectedAmount;
            }
            final overallProgress = totalTarget > 0
                ? (totalCollected / totalTarget).clamp(0.0, 1.0)
                : 0.0;
            final overallPct = (overallProgress * 100).toInt();

            return RefreshIndicator(
              color: AppColors.primary,
              notificationPredicate: (n) => n.depth == 2 || n.depth == 0,
              onRefresh: () async {
                ref.read(homeRefreshTriggerProvider.notifier).state++;
                final f = ref.refresh(goalsListProvider.future);
                await f;
              },
              child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HERO SUMMARY CARD
                        _buildHeroGoalsCard(
                          context,
                          isDark,
                          totalTarget: totalTarget,
                          totalCollected: totalCollected,
                          progress: overallProgress,
                          pct: overallPct,
                          activeCount: activeGoals.length,
                        ),
                        const SizedBox(height: 14),

                        // TAB SELECTOR (Sama persis dengan segmented tab Utang)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.cardOf(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.dividerOf(context)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _tabController.animateTo(0),
                                  borderRadius: BorderRadius.circular(10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _tabController.index == 0
                                          ? AppColors.primary.withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.hourglass_top_rounded,
                                            size: 16,
                                            color: _tabController.index == 0
                                                ? AppColors.primaryDark
                                                : AppColors.textSecondaryOf(context),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Berjalan (${activeGoals.length})',
                                            style: AppTypography.labelMedium.copyWith(
                                              fontWeight: _tabController.index == 0
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: _tabController.index == 0
                                                  ? AppColors.primaryDark
                                                  : AppColors.textSecondaryOf(context),
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
                                  onTap: () => _tabController.animateTo(1),
                                  borderRadius: BorderRadius.circular(10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _tabController.index == 1
                                          ? AppColors.primary.withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.task_alt_rounded,
                                            size: 16,
                                            color: _tabController.index == 1
                                                ? AppColors.primaryDark
                                                : AppColors.textSecondaryOf(context),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Tercapai (${completedGoals.length})',
                                            style: AppTypography.labelMedium.copyWith(
                                              fontWeight: _tabController.index == 1
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: _tabController.index == 1
                                                  ? AppColors.primaryDark
                                                  : AppColors.textSecondaryOf(context),
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
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildGoalListTab(
                    context,
                    ref,
                    goals: activeGoals,
                    emptyTitle: 'Belum Ada Target Aktif',
                    emptySubtitle: 'Mulai buat target impian atau dana darurat kamu.',
                    isActiveTab: true,
                  ),
                  _buildGoalListTab(
                    context,
                    ref,
                    goals: completedGoals,
                    emptyTitle: 'Belum Ada Target Tercapai',
                    emptySubtitle: 'Target yang sudah 100% terkumpul akan tampil di sini.',
                    isActiveTab: false,
                  ),
                ],
              ),
            ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
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
      );
  }

  Widget _buildHeroGoalsCard(
    BuildContext context,
    bool isDark, {
    required int totalTarget,
    required int totalCollected,
    required double progress,
    required int pct,
    required int activeCount,
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
            blurRadius: 18,
            offset: const Offset(0, 6),
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
                'TOTAL TABUNGAN TARGET',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white60,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$pct% Tercapai',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                CurrencyFormatter.format(totalCollected),
                style: AppTypography.headlineMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/ ${CurrencyFormatter.format(totalTarget)}',
                style: AppTypography.bodySmall.copyWith(color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ],
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActiveTab ? Icons.track_changes_rounded : Icons.celebration_rounded,
                  size: 48,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              if (isActiveTab) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => showGoalFormModal(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Buat Target Sekarang'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.read(homeRefreshTriggerProvider.notifier).state++;
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: goals.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return GoalCard(detail: goals[index]);
        },
      ),
    );
  }
}
