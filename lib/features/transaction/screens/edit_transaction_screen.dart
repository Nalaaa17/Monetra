import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/category.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';
import '../widgets/account_chips_selector.dart';
import '../widgets/category_grid_selector.dart';

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
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late int _selectedAccountId;
  late int? _selectedCategoryId;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.detail.transaction;
    _type = tx.type;
    _amountController = TextEditingController(text: tx.amount.toString());
    _noteController = TextEditingController(text: tx.note ?? '');
    _selectedAccountId = tx.accountId;
    _selectedCategoryId = tx.categoryId;
    _selectedDate = tx.date;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final categoryRepo = ref.watch(categoryRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Ubah Transaksi',
          style: AppTypography.headlineMedium.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger),
            tooltip: 'Hapus Transaksi',
            onPressed: _handleDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 1. Toggle Type
          _buildTypeToggle(),
          const SizedBox(height: 20),

          // 2. Input Nominal
          Text('Nominal (Rupiah)', style: AppTypography.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: AppTypography.headlineMedium.copyWith(
              color: _type == 'expense' ? AppColors.danger : AppColors.tertiary,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              prefixText: 'Rp ',
              filled: true,
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Tanggal Transaksi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tanggal Transaksi', style: AppTypography.titleMedium),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(DateFormatter.formatShort(_selectedDate)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4. Pilih Akun
          accountsAsync.when(
            data: (accounts) => AccountChipsSelector(
              accounts: accounts,
              selectedAccountId: _selectedAccountId,
              onSelectAccount: (id) => setState(() => _selectedAccountId = id),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 20),

          // 5. Pilih Kategori
          FutureBuilder<List<Category>>(
            future: categoryRepo.getAllCategories(type: _type),
            builder: (context, snapshot) {
              final cats = snapshot.data ?? [];
              return CategoryGridSelector(
                categories: cats,
                selectedCategoryId: _selectedCategoryId,
                onSelectCategory: (id) =>
                    setState(() => _selectedCategoryId = id),
              );
            },
          ),
          const SizedBox(height: 20),

          // 6. Catatan
          Text('Catatan', style: AppTypography.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: 'Tulis keterangan...',
              filled: true,
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
          ),
          const SizedBox(height: 36),

          // Tombol Simpan Perubahan
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text(
                      'Simpan Perubahan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Center(child: Text('💸 Pengeluaran')),
            selected: _type == 'expense',
            selectedColor: AppColors.danger.withValues(alpha: 0.15),
            onSelected: (val) {
              if (val) setState(() => _type = 'expense');
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ChoiceChip(
            label: const Center(child: Text('💰 Pemasukan')),
            selected: _type == 'income',
            selectedColor: AppColors.tertiary.withValues(alpha: 0.15),
            onSelected: (val) {
              if (val) setState(() => _type = 'income');
            },
          ),
        ),
      ],
    );
  }

  void _handleUpdate() async {
    final amount = int.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal harus lebih dari 0')),
      );
      return;
    }

    setState(() => _isSaving = true);
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
    );

    await txRepo.updateTransaction(updatedTx);
    ref.read(homeRefreshTriggerProvider.notifier).state++;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi berhasil diperbarui')),
      );
      context.pop();
    }
  }

  void _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: Text(
          'Yakin ingin menghapus transaksi "${widget.detail.note ?? widget.detail.categoryName ?? 'ini'}" sebesar ${CurrencyFormatter.format(widget.detail.amount)}? Saldo akun akan dikembalikan otomatis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final txRepo = ref.read(transactionRepositoryProvider);
      await txRepo.deleteTransaction(widget.detail.id);
      ref.read(homeRefreshTriggerProvider.notifier).state++;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi telah dihapus')),
        );
        context.pop();
      }
    }
  }
}
