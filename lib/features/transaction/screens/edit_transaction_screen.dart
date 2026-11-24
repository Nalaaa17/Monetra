import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../home/providers/home_providers.dart';
import '../providers/transaction_form_provider.dart';
import '../widgets/account_chips_selector.dart';
import '../widgets/balance_warning_dialog.dart';
import '../widgets/category_grid_selector.dart';
import '../widgets/custom_numeric_keypad.dart';
import '../widgets/discard_changes_dialog.dart';
import '../widgets/receipt_attachment_card.dart';

class EditTransactionScreen extends ConsumerStatefulWidget {
  final TransactionDetail detail;

  const EditTransactionScreen({
    super.key,
    required this.detail,
  });

  @override
  ConsumerState<EditTransactionScreen> createState() =>
      _EditTransactionScreenState();
}

class _EditTransactionScreenState extends ConsumerState<EditTransactionScreen> {
  late String _type;
  late String _rawAmount;
  late TextEditingController _noteController;
  late int _selectedAccountId;
  late int? _selectedCategoryId;
  late DateTime _selectedDate;
  String? _imagePath;
  bool _isSaving = false;
  bool _allowPop = false;
  String? _errorMessage;

  int get _amount => int.tryParse(_rawAmount) ?? 0;

  bool get _hasUnsavedChanges {
    final orig = widget.detail.transaction;
    return _type != orig.type ||
        _amount != orig.amount ||
        _selectedAccountId != orig.accountId ||
        _selectedCategoryId != orig.categoryId ||
        _noteController.text.trim() != (orig.note ?? '').trim() ||
        _selectedDate != orig.date ||
        _imagePath != orig.imagePath;
  }

  @override
  void initState() {
    super.initState();
    final tx = widget.detail.transaction;
    _type = tx.type;
    _rawAmount = tx.amount > 0 ? tx.amount.toString() : '0';
    _noteController = TextEditingController(text: tx.note ?? '');
    _selectedAccountId = tx.accountId;
    _selectedCategoryId = tx.categoryId;
    _selectedDate = tx.date;
    _imagePath = tx.imagePath;
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

  Future<void> _onChangeType(String newType) async {
    if (_type == newType) return;
    setState(() {
      _type = newType;
      _selectedCategoryId = null;
    });

    final categories = await ref
        .read(categoryRepositoryProvider)
        .getAllCategories(type: newType);
    if (!mounted || _type != newType) return;

    if (categories.isNotEmpty) {
      setState(() => _selectedCategoryId = categories.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final categoriesAsync = ref.watch(categoriesByTypeProvider(_type));
    final isExpense = _type == 'expense';
    final themeColor = isExpense ? AppColors.danger : AppColors.tertiary;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Ubah Transaksi',
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
            tooltip: 'Hapus Transaksi',
            onPressed: _isSaving ? null : _handleDelete,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // 1. Toggle Type
                _buildTypeToggle(),
                const SizedBox(height: 18),

                // 2. Display Nominal Besar + tombol reset cepat
                _buildAmountDisplay(themeColor),
                const SizedBox(height: 16),

                // 3. Catatan
                TextField(
                  controller: _noteController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Catatan (opsional)',
                    hintStyle: AppTypography.bodyMedium,
                    prefixIcon: Icon(Icons.edit_note_rounded,
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
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 4. Pilih Akun
                accountsAsync.when(
                  data: (accounts) => AccountChipsSelector(
                    accounts: accounts,
                    selectedAccountId: _selectedAccountId,
                    onSelectAccount: (id) =>
                        setState(() => _selectedAccountId = id),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: 18),

                // 5. Lampiran Foto / Struk Nota Belanja
                ReceiptAttachmentCard(
                  imagePath: _imagePath,
                  onImageSelected: (path) => setState(() => _imagePath = path),
                  onOcrResultApplied: (result) {
                    setState(() {
                      if (result.detectedAmount != null) {
                        _rawAmount = result.detectedAmount.toString();
                      }
                      if (result.noteSuggestion != null &&
                          _noteController.text.trim().isEmpty) {
                        _noteController.text = result.noteSuggestion!;
                      }
                      if (result.detectedDate != null) {
                        _selectedDate = result.detectedDate!;
                      }
                      if (result.suggestedCategory != null &&
                          categoriesAsync.valueOrNull != null) {
                        final cats = categoriesAsync.value!;
                        final target = result.suggestedCategory!.toLowerCase();
                        final match = cats.firstWhere(
                          (c) =>
                              c.name.toLowerCase().contains(target) ||
                              target.contains(c.name.toLowerCase()),
                          orElse: () => cats.first,
                        );
                        _selectedCategoryId = match.id;
                      }
                    });
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(milliseconds: 1600),
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Struk diterapkan: ${CurrencyFormatter.format(result.detectedAmount ?? 0)}',
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF059669),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),

                // 6. Pilih Kategori
                categoriesAsync.when(
                  data: (cats) => CategoryGridSelector(
                    categories: cats,
                    selectedCategoryId: _selectedCategoryId,
                    onSelectCategory: (id) =>
                        setState(() => _selectedCategoryId = id),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
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
                const SizedBox(height: 12),
              ],
            ),
          ),

          // Tombol Simpan Perubahan
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
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

          // Keypad Angka Khusus Bawah (selaras dengan Catat Transaksi)
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

  Widget _buildTypeToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final isExpense = _type == 'expense';

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _onChangeType('expense'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isExpense
                      ? Theme.of(context).cardColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isExpense
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('💸 ', style: TextStyle(fontSize: 16)),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Pengeluaran',
                          maxLines: 1,
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 14,
                            color: isExpense
                                ? AppColors.danger
                                : AppColors.textSecondaryOf(context),
                            fontWeight:
                                isExpense ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _onChangeType('income'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !isExpense
                      ? Theme.of(context).cardColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !isExpense
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('💰 ', style: TextStyle(fontSize: 16)),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Pemasukan',
                          maxLines: 1,
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 14,
                            color: !isExpense
                                ? const Color(0xFF059669)
                                : AppColors.textSecondaryOf(context),
                            fontWeight:
                                !isExpense ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDisplay(Color themeColor) {
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
                Text(
                  _type == 'expense'
                      ? 'Nominal Pengeluaran'
                      : 'Nominal Pemasukan',
                  style: AppTypography.labelSmall,
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyFormatter.format(_amount),
                    style: AppTypography.headlineLarge.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: _amount > 0
                          ? themeColor
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

  void _handleUpdate() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    final amount = _amount;
    if (amount <= 0) {
      setState(() => _errorMessage = 'Nominal harus lebih dari Rp 0');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final accountRepo = ref.read(accountRepositoryProvider);
      final warning = await accountRepo.checkEditTransactionBalanceWarning(
        original: widget.detail.transaction,
        newType: _type,
        newAmount: amount,
        newAccountId: _selectedAccountId,
      );
      if (!mounted) return;

      if (warning != null) {
        final proceed = await showInsufficientBalanceWarningDialog(
          context,
          message:
              'Perubahan transaksi ini membuat saldo "${warning.accountName}" menjadi minus (${CurrencyFormatter.format(warning.projectedBalance)}). Tetap simpan sebagai saldo minus sementara?',
        );
        if (!proceed) {
          if (mounted) setState(() => _isSaving = false);
          return;
        }
      }

      final txRepo = ref.read(transactionRepositoryProvider);
      final updatedTx = widget.detail.transaction.copyWith(
        type: _type,
        amount: amount,
        accountId: _selectedAccountId,
        categoryId: _selectedCategoryId,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        date: _selectedDate,
        imagePath: _imagePath,
        clearImage: _imagePath == null,
      );

      await txRepo.updateTransaction(updatedTx);
      ref.read(homeRefreshTriggerProvider.notifier).state++;

      if (mounted) {
        _allowPop = true;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(milliseconds: 1600),
            content: Text('Transaksi berhasil diperbarui'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Gagal memperbarui transaksi: $e';
        });
      }
    }
  }

  void _handleDelete() async {
    final confirm = await AppDialog.delete(
      context,
      title: 'Hapus Transaksi?',
      message:
          'Yakin ingin menghapus transaksi "${widget.detail.note ?? widget.detail.categoryName ?? 'ini'}" sebesar ${CurrencyFormatter.format(widget.detail.amount)}? Saldo akun akan dikembalikan otomatis.',
      confirmLabel: 'Hapus Transaksi',
    );

    if (confirm == true) {
      final txRepo = ref.read(transactionRepositoryProvider);
      await txRepo.deleteTransaction(widget.detail.id);
      ref.read(homeRefreshTriggerProvider.notifier).state++;

      if (mounted) {
        _allowPop = true;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(milliseconds: 1600),
            content: Text('Transaksi telah dihapus'),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }
}
