import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../../../core/utils/bank_logo_helper.dart';
import '../../../../core/utils/color_helper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/repositories/goal_repository.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../home/providers/home_providers.dart';

void showAddContributionModal(
  BuildContext context,
  WidgetRef ref,
  GoalDetail detail,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddContributionSheet(detail: detail),
  );
}

void showGoalContributionsHistoryModal(
  BuildContext context,
  GoalDetail detail,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _GoalContributionsHistorySheet(detail: detail),
  );
}

class _AddContributionSheet extends ConsumerStatefulWidget {
  final GoalDetail detail;

  const _AddContributionSheet({required this.detail});

  @override
  ConsumerState<_AddContributionSheet> createState() =>
      _AddContributionSheetState();
}

class _AddContributionSheetState extends ConsumerState<_AddContributionSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  int? _selectedAccountId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.detail.sourceAccountId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _parsedAmount =>
      int.tryParse(
          _amountController.text.replaceAll('.', '').replaceAll(',', '')) ??
      0;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Isi Tabungan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.detail.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryOf(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Sisa ${CurrencyFormatter.format(widget.detail.remainingAmount)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.primary
                            : AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Input Nominal dengan tombol 'Penuhi'
              Text('Nominal Disisihkan', style: AppTypography.labelSmall),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '0',
                  prefixText: 'Rp ',
                  filled: true,
                  fillColor: AppColors.surfaceOf(context),
                  suffixIcon: widget.detail.remainingAmount > 0
                      ? TextButton(
                          onPressed: () {
                            setState(() {
                              _amountController.text =
                                  widget.detail.remainingAmount.toString();
                            });
                          },
                          child: Text(
                            'Penuhi',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.primary
                                  : AppColors.primaryDark,
                            ),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.4)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
              ),
              const SizedBox(height: 14),

              // Pilih Rekening / Dompet Sumber (Horizontal Card Selector)
              Text(
                'Sumber Dana',
                style: AppTypography.labelSmall,
              ),
              const SizedBox(height: 8),
              accountsAsync.when(
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return const Text('Tidak ada akun tersedia.',
                        style: TextStyle(fontSize: 12));
                  }
                  if (_selectedAccountId == null ||
                      !accounts.any((a) => a.id == _selectedAccountId)) {
                    _selectedAccountId = accounts.first.id;
                  }

                  final selectedAcc = accounts
                      .where((a) => a.id == _selectedAccountId)
                      .firstOrNull;
                  final isExceeding = selectedAcc != null &&
                      _parsedAmount > 0 &&
                      _parsedAmount > selectedAcc.balance;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: accounts.map((acc) {
                            final isSelected = _selectedAccountId == acc.id;
                            final accColor = ColorHelper.parseHex(acc.colorHex);

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => setState(
                                    () => _selectedAccountId = acc.id),
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                            .withValues(alpha: isDark ? 0.22 : 0.16)
                                        : AppColors.surfaceOf(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Theme.of(context)
                                              .dividerColor
                                              .withValues(alpha: 0.4),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      BankLogoHelper.buildAccountBadge(
                                        context: context,
                                        accountName: acc.name,
                                        accountColor: accColor,
                                        logoKey: acc.logoKey,
                                        iconCodePoint: acc.iconCodePoint,
                                        size: 24,
                                        iconSize: 13,
                                        borderRadius: 6,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            acc.name,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? (isDark
                                                      ? AppColors.primary
                                                      : AppColors.primaryDark)
                                                  : AppColors.textPrimaryOf(
                                                      context),
                                            ),
                                          ),
                                          Text(
                                            CurrencyFormatter.format(
                                                acc.balance),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondaryOf(
                                                  context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      if (isExceeding) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 14, color: AppColors.danger),
                            const SizedBox(width: 4),
                            Text(
                              'Saldo "${selectedAcc.name}" kurang (${CurrencyFormatter.format(selectedAcc.balance)})',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 28,
                  child: Center(
                    child:
                        Text('Memuat akun...', style: TextStyle(fontSize: 12)),
                  ),
                ),
                error: (e, _) => Text('Gagal memuat akun: $e'),
              ),
              const SizedBox(height: 14),

              // Catatan
              Text('Catatan', style: AppTypography.labelSmall),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: 'Keterangan (opsional)',
                  filled: true,
                  fillColor: AppColors.surfaceOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.4)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    elevation: 0,
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
                          'Sisihkan ke Target',
                          style: TextStyle(
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
    );
  }

  Future<void> _submit() async {
    final amount = _parsedAmount;
    if (amount <= 0) {
      AppSnackBar.showWarning(
        context,
        'Masukkan nominal setoran lebih dari Rp 0.',
      );
      return;
    }
    if (_selectedAccountId == null) {
      AppSnackBar.showWarning(
        context,
        'Pilih dompet / rekening sumber terlebih dahulu.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final accounts = ref.read(accountsWithBalanceProvider).valueOrNull ?? [];
      final chosenAcc =
          accounts.where((a) => a.id == _selectedAccountId).firstOrNull;

      if (chosenAcc != null && amount > chosenAcc.balance) {
        final proceed = await AppDialog.confirm(
          context,
          type: AppDialogType.warning,
          icon: Icons.account_balance_wallet_outlined,
          title: 'Saldo Bebas Kurang',
          message:
              'Nominal setoran (${CurrencyFormatter.format(amount)}) melebihi saldo bebas di "${chosenAcc.name}" (${CurrencyFormatter.format(chosenAcc.balance)}). Tetap sisihkan?',
          confirmLabel: 'Tetap Simpan',
          cancelLabel: 'Batal',
          isDestructive: false,
        );
        if (proceed != true) {
          if (mounted) setState(() => _isSubmitting = false);
          return;
        }
      }

      final repo = ref.read(goalRepositoryProvider);
      await repo.addContribution(
        goalId: widget.detail.id,
        sourceAccountId: _selectedAccountId!,
        amount: amount,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      ref.read(homeRefreshTriggerProvider.notifier).state++;

      if (mounted) {
        final sourceLabel = chosenAcc?.name ?? 'rekening sumber';
        AppSnackBar.showSuccess(
          context,
          '${CurrencyFormatter.format(amount)} disisihkan dari $sourceLabel ke "${widget.detail.name}"!',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Gagal menyisihkan dana: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _GoalContributionsHistorySheet extends ConsumerWidget {
  final GoalDetail detail;

  const _GoalContributionsHistorySheet({required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(goalRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Riwayat Setoran: ${detail.name}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Sumber rekening dana yang disisihkan ke target ini',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),
              FutureBuilder<List<GoalContributionDetail>>(
                future: repo.getContributionDetailsForGoal(detail.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('Belum ada catatan setoran pada target ini.'),
                      ),
                    );
                  }
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: Theme.of(context).dividerColor),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final accColor = ColorHelper.parseHex(item.accountColorHex);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: BankLogoHelper.buildAccountBadge(
                            context: context,
                            accountName: item.accountName,
                            accountColor: accColor,
                            logoKey: item.accountLogoKey,
                            iconCodePoint: item.accountIconCodePoint,
                            size: 38,
                            borderRadius: 10,
                          ),
                          title: Text(
                            'Dari ${item.accountName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormatter.formatFull(item.date),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                              if (item.note != null && item.note!.isNotEmpty)
                                Text(
                                  item.note!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryOf(context),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                          trailing: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 115),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    CurrencyFormatter.format(item.amount),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark
                                          ? AppColors.primary
                                          : const Color(0xFF059669),
                                    ),
                                  ),
                                ),
                                Text(
                                  item.isRealized
                                      ? 'Sudah dipakai'
                                      : 'Terkunci',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: item.isRealized
                                        ? AppColors.textSecondaryOf(context)
                                        : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

