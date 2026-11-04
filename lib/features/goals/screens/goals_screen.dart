import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/goal.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';
import '../providers/goal_providers.dart';
import '../widgets/goal_card.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsListProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: Text(
            'Target & Tabungan',
            style: AppTypography.headlineMedium.copyWith(fontSize: 18),
          ),
          bottom: const TabBar(
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryDark,
            indicatorWeight: 3,
            tabs: [
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddGoalModal(context, ref),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.black),
          label: const Text(
            'Target Baru',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
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
                  onPressed: () => _showAddGoalModal(context, ref),
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

  void _showAddGoalModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddGoalBottomSheetContent(),
    );
  }
}

class _AddGoalBottomSheetContent extends ConsumerStatefulWidget {
  const _AddGoalBottomSheetContent();

  @override
  ConsumerState<_AddGoalBottomSheetContent> createState() =>
      _AddGoalBottomSheetContentState();
}

class _AddGoalBottomSheetContentState
    extends ConsumerState<_AddGoalBottomSheetContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _initialDepositController = TextEditingController();

  DateTime _deadline = DateTime.now().add(const Duration(days: 30));
  int? _selectedAccountId;
  bool _reminderEnabled = true;
  bool _repeatMonthly = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _initialDepositController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Sheet
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.flag_rounded,
                            color: AppColors.primaryDark, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Buat Target Baru',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // 1. Nama Target
                Text('Nama Target / Keperluan',
                    style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Misal: Bayar Ressa, Liquid + Coil',
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nama target wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 2. Target Nominal
                Text('Target Nominal (Rp)',
                    style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _targetAmountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '710.000',
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Target nominal wajib diisi';
                    }
                    final parsed = int.tryParse(
                        val.replaceAll('.', '').replaceAll(',', ''));
                    if (parsed == null || parsed <= 0) {
                      return 'Nominal target harus lebih dari 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 3. Setoran Awal (Opsional)
                Text('Setoran Awal (Opsional)',
                    style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _initialDepositController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '0 (Isi nanti juga bisa)',
                    prefixIcon: const Icon(Icons.savings_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Tanggal Jatuh Tempo
                Text('Tenggat Jatuh Tempo',
                    style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDeadlineDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded,
                                size: 20, color: AppColors.primaryDark),
                            const SizedBox(width: 10),
                            Text(
                              DateFormatter.formatFull(_deadline),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down_rounded),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Akun Sumber / Dompet yang Dialokasikan
                Text('Dompet / Rekening Sumber',
                    style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                accountsAsync.when(
                  data: (accounts) {
                    if (accounts.isEmpty) {
                      return const Text('Tidak ada akun tersedia.');
                    }
                    if (_selectedAccountId == null ||
                        !accounts
                            .any((a) => a.account.id == _selectedAccountId)) {
                      _selectedAccountId = accounts.first.account.id;
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: accounts.map((acc) {
                        final isSelected =
                            _selectedAccountId == acc.account.id;
                        return ChoiceChip(
                          selected: isSelected,
                          label: Text(
                            '${acc.account.name} (${CurrencyFormatter.format(acc.balance)})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? Colors.black : null,
                            ),
                          ),
                          selectedColor: AppColors.primary,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedAccountId = acc.account.id;
                              });
                            }
                          },
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const SizedBox(
                    height: 24,
                    child: Center(
                      child: Text('Memuat akun...',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  error: (e, _) => Text('Gagal memuat akun: $e'),
                ),
                const SizedBox(height: 12),

                // 6. Switches: Reminder & Repeat Monthly
                SwitchListTile(
                  value: _reminderEnabled,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.primaryDark,
                  title: const Text(
                    'Pengingat H-3 Jatuh Tempo',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Kirim notifikasi lokal 3 hari sebelum tenggat',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: (val) => setState(() => _reminderEnabled = val),
                ),
                SwitchListTile(
                  value: _repeatMonthly,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.primaryDark,
                  title: const Text(
                    'Target Berulang Tiap Bulan',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Cocok untuk tagihan rutin (misal tiap tgl 23)',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: (val) => setState(() => _repeatMonthly = val),
                ),
                const SizedBox(height: 20),

                // 7. Tombol Simpan
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _saveGoal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Simpan Target',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDeadlineDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked != null) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih rekening/dompet sumber')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final targetAmount = int.parse(
        _targetAmountController.text.replaceAll('.', '').replaceAll(',', ''),
      );
      final initialDeposit = int.tryParse(
            _initialDepositController.text
                .replaceAll('.', '')
                .replaceAll(',', ''),
          ) ??
          0;

      final goalRepo = ref.read(goalRepositoryProvider);

      final newGoal = Goal(
        name: _nameController.text.trim(),
        targetAmount: targetAmount,
        collectedAmount: 0,
        deadline: _deadline,
        sourceAccountId: _selectedAccountId!,
        reminderEnabled: _reminderEnabled,
        repeatMonthly: _repeatMonthly,
        status: 'active',
        createdAt: DateTime.now(),
      );

      final insertedId = await goalRepo.insertGoal(newGoal);

      if (initialDeposit > 0) {
        await goalRepo.addContribution(
          goalId: insertedId,
          amount: initialDeposit,
          note: 'Setoran awal',
        );
      }

      ref.read(homeRefreshTriggerProvider.notifier).state++;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Target "${newGoal.name}" senilai ${CurrencyFormatter.format(targetAmount)} berhasil dibuat!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan target: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
