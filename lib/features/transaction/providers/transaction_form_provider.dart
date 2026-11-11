import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/category.dart';
import '../../../data/models/transaction.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';
import '../widgets/custom_numeric_keypad.dart';

class TransactionFormState {
  final String type; // 'expense' | 'income'
  final String rawAmount; // '50000'
  final int? selectedAccountId;
  final int? selectedCategoryId;
  final String note;
  final DateTime date;
  final bool isSubmitting;
  final String? errorMessage;

  const TransactionFormState({
    this.type = 'expense',
    this.rawAmount = '0',
    this.selectedAccountId,
    this.selectedCategoryId,
    this.note = '',
    required this.date,
    this.isSubmitting = false,
    this.errorMessage,
  });

  int get amount => int.tryParse(rawAmount) ?? 0;
  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  TransactionFormState copyWith({
    String? type,
    String? rawAmount,
    int? selectedAccountId,
    int? selectedCategoryId,
    bool clearCategory = false,
    String? note,
    DateTime? date,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return TransactionFormState(
      type: type ?? this.type,
      rawAmount: rawAmount ?? this.rawAmount,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      selectedCategoryId:
          clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      note: note ?? this.note,
      date: date ?? this.date,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}

final categoriesByTypeProvider =
    FutureProvider.family<List<Category>, String>((ref, type) async {
  ref.watch(homeRefreshTriggerProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  return await repo.getAllCategories(type: type);
});

final transactionFormNotifierProvider =
    StateNotifierProvider.autoDispose<TransactionFormNotifier, TransactionFormState>(
        (ref) {
  return TransactionFormNotifier(ref);
});

class TransactionFormNotifier extends StateNotifier<TransactionFormState> {
  final Ref ref;
  int _categoryRequestToken = 0;

  TransactionFormNotifier(this.ref)
      : super(TransactionFormState(date: DateTime.now())) {
    _initDefaults();
  }

  void _initDefaults() async {
    final requestedType = state.type;
    final token = ++_categoryRequestToken;

    final accountRepo = ref.read(accountRepositoryProvider);
    final accounts = await accountRepo.getAllAccounts();
    if (!mounted) return;

    if (accounts.isNotEmpty && state.selectedAccountId == null) {
      // Default ke Mandiri atau Cash (operasional harian) jika ada
      final defaultAcc = accounts.firstWhere(
        (a) =>
            a.name.toLowerCase().contains('cash') ||
            a.name.toLowerCase().contains('mandiri'),
        orElse: () => accounts.first,
      );
      state = state.copyWith(selectedAccountId: defaultAcc.id);
    }

    // Default category pertama untuk tipe awal (abaikan jika tipe sudah berubah)
    final categoryRepo = ref.read(categoryRepositoryProvider);
    final categories = await categoryRepo.getAllCategories(type: requestedType);
    if (!mounted ||
        state.type != requestedType ||
        token != _categoryRequestToken) {
      return;
    }

    if (categories.isNotEmpty) {
      state = state.copyWith(selectedCategoryId: categories.first.id);
    }
  }

  void appendKey(String key) {
    final next = CustomNumericKeypad.applyKey(state.rawAmount, key);
    if (next == state.rawAmount) return;
    state = state.copyWith(rawAmount: next);
  }

  void backspace() {
    state = state.copyWith(
      rawAmount: CustomNumericKeypad.applyBackspace(state.rawAmount),
    );
  }

  void clearAmount() {
    state = state.copyWith(rawAmount: '0');
  }

  void setType(String newType) async {
    if (state.type == newType) return;
    final token = ++_categoryRequestToken;
    state = state.copyWith(type: newType, clearCategory: true);

    final categoryRepo = ref.read(categoryRepositoryProvider);
    final categories = await categoryRepo.getAllCategories(type: newType);
    if (!mounted ||
        state.type != newType ||
        token != _categoryRequestToken) {
      return;
    }

    if (categories.isNotEmpty) {
      state = state.copyWith(selectedCategoryId: categories.first.id);
    }
  }

  void setAccount(int accountId) {
    state = state.copyWith(selectedAccountId: accountId);
  }

  void setCategory(int categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
  }

  void setNote(String note) {
    state = state.copyWith(note: note);
  }

  void setDate(DateTime date) {
    state = state.copyWith(date: date);
  }

  /// Memeriksa saldo sebelum simpan (warning jika minus)
  Future<bool> checkBalanceWarning() async {
    if (state.isIncome) return false;
    if (state.selectedAccountId == null) return false;

    final accountRepo = ref.read(accountRepositoryProvider);
    final currentBalance =
        await accountRepo.calculateAccountBalance(state.selectedAccountId!);

    return state.amount > currentBalance;
  }

  Future<bool> submit() async {
    if (state.amount <= 0) {
      state = state.copyWith(errorMessage: 'Jumlah uang harus lebih dari Rp 0');
      return false;
    }

    if (state.selectedAccountId == null) {
      state = state.copyWith(errorMessage: 'Silakan pilih akun / dompet');
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final transactionRepo = ref.read(transactionRepositoryProvider);
      final newTx = TransactionModel(
        type: state.type,
        amount: state.amount,
        accountId: state.selectedAccountId!,
        categoryId: state.selectedCategoryId,
        note: state.note.trim().isEmpty ? null : state.note.trim(),
        date: state.date,
        createdAt: DateTime.now(),
      );

      await transactionRepo.insertTransaction(newTx);

      // Trigger pembaruan saldo di Home & History
      ref.read(homeRefreshTriggerProvider.notifier).state++;
      if (mounted) {
        // Reset state form bersih agar tidak ada sisa nominal/catatan saat layar ditutup
        state = TransactionFormState(
          type: state.type,
          rawAmount: '0',
          selectedAccountId: state.selectedAccountId,
          selectedCategoryId: state.selectedCategoryId,
          note: '',
          date: DateTime.now(),
          isSubmitting: false,
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Gagal menyimpan transaksi: $e',
        );
      }
      return false;
    }
  }
}
