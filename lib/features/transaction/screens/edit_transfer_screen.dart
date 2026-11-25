import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/transfer_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../home/providers/home_providers.dart';
import '../widgets/balance_warning_dialog.dart';
import '../widgets/custom_numeric_keypad.dart';
import '../widgets/discard_changes_dialog.dart';
import '../widgets/transfer_accounts_card.dart';

class EditTransferScreen extends ConsumerStatefulWidget {
  final TransferDetail detail;

  const EditTransferScreen({
    super.key,
    required this.detail,
  });

  @override
  ConsumerState<EditTransferScreen> createState() => _EditTransferScreenState();
}

class _EditTransferScreenState extends ConsumerState<EditTransferScreen> {
  late int _fromAccountId;
  late int _toAccountId;
  late String _rawAmount;
  late final TextEditingController _noteController;
  late DateTime _selectedDate;
  bool _isSaving = false;
  bool _allowPop = false;
  String? _errorMessage;

  int get _amount => int.tryParse(_rawAmount) ?? 0;

  bool get _hasUnsavedChanges {
    final orig = widget.detail.transfer;
    return _fromAccountId != orig.fromAccountId ||
        _toAccountId != orig.toAccountId ||
        _amount != orig.amount ||
        _noteController.text.trim() != (orig.note ?? '').trim() ||
        _selectedDate != orig.date;
  }

  @override
  void initState() {
    super.initState();
    final tr = widget.detail.transfer;
    _fromAccountId = tr.fromAccountId;
    _toAccountId = tr.toAccountId;
    _rawAmount = tr.amount > 0 ? tr.amount.toString() : '0';
    _noteController = TextEditingController(text: tr.note ?? '');
    _selectedDate = tr.date;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _appendKey(String key) {
    FocusScope.of(context).unfocus();
    final next = CustomNumericKeypad.applyKey(_rawAmount, key);
    if (next == _rawAmount && _errorMessage == null) return;
    setState(() {
      _rawAmount = next;
      _errorMessage = null;
    });
  }

  void _backspace() {
    FocusScope.of(context).unfocus();
    setState(() {
      _rawAmount = CustomNumericKeypad.applyBackspace(_rawAmount);
      _errorMessage = null;
    });
  }

  void _clearAmount() {
    FocusScope.of(context).unfocus();
    setState(() {
      _rawAmount = '0';
      _errorMessage = null;
    });
  }

  void _selectFromAccount(int id) {
    setState(() {
      if (_toAccountId == id) {
        _toAccountId = _fromAccountId;
      }
      _fromAccountId = id;
      _errorMessage = null;
    });
  }

  void _selectToAccount(int id) {
    setState(() {
      if (_fromAccountId == id) {
        _fromAccountId = _toAccountId;
      }
      _toAccountId = id;
      _errorMessage = null;
    });
  }

  void _swapAccounts() {
    setState(() {
      final tmp = _fromAccountId;
      _fromAccountId = _toAccountId;
      _toAccountId = tmp;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final hasEnoughAccounts = (accountsAsync.valueOrNull?.length ?? 2) >= 2;

    return PopScope(
      canPop: _allowPop || !_hasUnsavedChanges || _isSaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await confirmDiscardChangesDialog(context);
        if (discard && context.mounted) {
          setState(() => _allowPop = true);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Ubah Transfer',
            style: AppTypography.headlineMedium.copyWith(fontSize: 18),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null && mounted) {
                  setState(() {
                    _selectedDate = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      _selectedDate.hour,
                      _selectedDate.minute,
                    );
                  });
                }
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text(
                DateFormatter.formatShort(_selectedDate),
                style: AppTypography.labelSmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger),
              tooltip: 'Hapus Transfer',
              onPressed: _isSaving ? null : _handleDelete,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  accountsAsync.when(
                    data: (accounts) => TransferAccountsCard(
                      accounts: accounts,
                      fromAccountId: _fromAccountId,
                      toAccountId: _toAccountId,
                      onSelectFrom: _selectFromAccount,
                      onSelectTo: _selectToAccount,
                      onSwap: _swapAccounts,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 16),
                  _buildAmountDisplay(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText:
                          'Keterangan transfer (misal: Tarik tunai, Nabung)',
                      hintStyle: AppTypography.bodyMedium,
                      prefixIcon: Icon(Icons.note_alt_outlined,
                          color: AppColors.textSecondaryOf(context)),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      (_isSaving || !hasEnoughAccounts) ? null : _handleUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Simpan Perubahan',
                                  maxLines: 1,
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            if (!isKeyboardOpen)
              CustomNumericKeypad(
                onKeyPress: _appendKey,
                onBackspace: _backspace,
                onClear: _clearAmount,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Nominal yang Dipindahkan', style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyFormatter.format(_amount),
                    style: AppTypography.headlineLarge.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: _amount > 0
                          ? AppColors.secondary
                          : AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 32,
            child: _amount > 0
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    tooltip: 'Reset nominal ke 0',
                    color: AppColors.textSecondaryOf(context),
                    onPressed: _clearAmount,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdate() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    final amount = _amount;
    if (amount <= 0) {
      setState(() => _errorMessage = 'Nominal transfer harus lebih dari Rp 0');
      return;
    }
    if (_fromAccountId == _toAccountId) {
      setState(
          () => _errorMessage = 'Akun asal dan akun tujuan tidak boleh sama');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final orig = widget.detail.transfer;
      final accountRepo = ref.read(accountRepositoryProvider);
      final warning = await accountRepo.checkEditTransferBalanceWarning(
        oldFromAccountId: orig.fromAccountId,
        oldToAccountId: orig.toAccountId,
        oldAmount: orig.amount,
        newFromAccountId: _fromAccountId,
        newToAccountId: _toAccountId,
        newAmount: amount,
      );
      if (!mounted) return;

      if (warning != null) {
        final proceed = await showInsufficientBalanceWarningDialog(
          context,
          message:
              'Perubahan transfer ini membuat saldo "${warning.accountName}" menjadi minus (${CurrencyFormatter.format(warning.projectedBalance)}). Tetap simpan?',
        );
        if (!proceed) {
          if (mounted) setState(() => _isSaving = false);
          return;
        }
      }

      final transferRepo = ref.read(transferRepositoryProvider);
      final updated = orig.copyWith(
        fromAccountId: _fromAccountId,
        toAccountId: _toAccountId,
        amount: amount,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        date: _selectedDate,
      );

      await transferRepo.updateTransfer(updated);
      ref.read(homeRefreshTriggerProvider.notifier).state++;

      if (mounted) {
        _allowPop = true;
        AppSnackBar.showSuccess(context, 'Transfer berhasil diperbarui');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Gagal memperbarui transfer: $e';
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await AppDialog.delete(
      context,
      title: 'Hapus Transfer?',
      message:
          'Yakin ingin menghapus transfer ${widget.detail.fromAccountName} → ${widget.detail.toAccountName} sebesar ${CurrencyFormatter.format(widget.detail.amount)}? Saldo akan dikembalikan ke akun asal.',
      confirmLabel: 'Hapus Transfer',
    );

    if (confirm == true) {
      final repo = ref.read(transferRepositoryProvider);
      await repo.deleteTransfer(widget.detail.id);
      ref.read(homeRefreshTriggerProvider.notifier).state++;

      if (mounted) {
        _allowPop = true;
        AppSnackBar.showInfo(context, 'Transfer telah dihapus');
        Navigator.of(context).pop();
      }
    }
  }
}

