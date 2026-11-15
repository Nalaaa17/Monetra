import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/category.dart';
import '../../../data/models/transaction.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';

class SplitCategoryItem {
  final int? categoryId;
  final String categoryName;
  final int amount;
  final String note;

  const SplitCategoryItem({
    this.categoryId,
    this.categoryName = '',
    required this.amount,
    this.note = '',
  });

  SplitCategoryItem copyWith({
    int? categoryId,
    String? categoryName,
    int? amount,
    String? note,
  }) {
    return SplitCategoryItem(
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      amount: amount ?? this.amount,
      note: note ?? this.note,
    );
  }
}

class TransactionFormState {
  final String type; // 'income' | 'expense'
  final String rawAmount;
  final int? selectedAccountId;
  final int? selectedCategoryId;
  final String note;
  final DateTime date;
  final bool isSubmitting;
  final String? errorMessage;
  final String? imagePath;
  final bool isSplit;
  final List<SplitCategoryItem> splitItems;

  const TransactionFormState({
    required this.type,
    this.rawAmount = '0',
    this.selectedAccountId,
    this.selectedCategoryId,
    this.note = '',
    required this.date,
    this.isSubmitting = false,
    this.errorMessage,
    this.imagePath,
    this.isSplit = false,
    this.splitItems = const [],
  });

  int get amount => int.tryParse(rawAmount) ?? 0;
  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get hasReceipt => imagePath != null && imagePath!.isNotEmpty;

  int get splitTotalAmount =>
      splitItems.fold(0, (sum, item) => sum + item.amount);
  int get splitRemainingAmount => amount - splitTotalAmount;
  bool get isSplitBalanced =>
      !isSplit || (amount > 0 && splitTotalAmount == amount);

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
    String? imagePath,
    bool clearImage = false,
    bool? isSplit,
    List<SplitCategoryItem>? splitItems,
  }) {
    return TransactionFormState(
      type: type ?? this.type,
      rawAmount: rawAmount ?? this.rawAmount,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      selectedCategoryId: clearCategory
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      note: note ?? this.note,
      date: date ?? this.date,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      isSplit: isSplit ?? this.isSplit,
      splitItems: splitItems ?? this.splitItems,
    );
  }
}

final categoriesByTypeProvider =
    FutureProvider.family<List<Category>, String>((ref, type) async {
  ref.watch(homeRefreshTriggerProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  return await repo.getAllCategories(type: type);
});

final initialTransactionTypeProvider =
    StateProvider.autoDispose<String>((ref) => 'expense');

final transactionFormNotifierProvider = StateNotifierProvider.autoDispose<
    TransactionFormNotifier, TransactionFormState>((ref) {
  final initType = ref.watch(initialTransactionTypeProvider);
  return TransactionFormNotifier(ref, initialType: initType);
}, dependencies: [initialTransactionTypeProvider]);

class TransactionFormNotifier extends StateNotifier<TransactionFormState> {
  final Ref ref;
  int _categoryRequestToken = 0;

  TransactionFormNotifier(this.ref, {String initialType = 'expense'})
      : super(TransactionFormState(
          type: (initialType == 'income') ? 'income' : 'expense',
          date: DateTime.now(),
        )) {
    _initDefaults();
  }

  void _initDefaults() async {
    final requestedType = state.type;
    final token = ++_categoryRequestToken;

    final accountRepo = ref.read(accountRepositoryProvider);
    final accounts = await accountRepo.getAllAccounts();
    if (!mounted) return;

    if (accounts.isNotEmpty && state.selectedAccountId == null) {
      final defaultAcc = accounts.firstWhere(
        (a) =>
            a.name.toLowerCase().contains('cash') ||
            a.name.toLowerCase().contains('mandiri'),
        orElse: () => accounts.first,
      );
      state = state.copyWith(selectedAccountId: defaultAcc.id);
    }

    final categoryRepo = ref.read(categoryRepositoryProvider);
    final categories = await categoryRepo.getAllCategories(type: requestedType);
    if (!mounted || token != _categoryRequestToken) return;

    if (categories.isNotEmpty && state.selectedCategoryId == null) {
      state = state.copyWith(selectedCategoryId: categories.first.id);
    }
  }

  void setType(String type) async {
    if (state.type == type) return;

    final token = ++_categoryRequestToken;
    state = state.copyWith(
      type: type,
      clearCategory: true,
      errorMessage: null,
      isSplit: type == 'expense' ? state.isSplit : false,
    );

    final categoryRepo = ref.read(categoryRepositoryProvider);
    final categories = await categoryRepo.getAllCategories(type: type);

    if (!mounted || token != _categoryRequestToken) return;

    if (categories.isNotEmpty) {
      state = state.copyWith(selectedCategoryId: categories.first.id);
    }
  }

  void appendKey(String key) {
    if (state.rawAmount.length >= 10) return;

    if (key == '000') {
      if (state.rawAmount == '0') return;
      state = state.copyWith(
        rawAmount: '${state.rawAmount}000',
        errorMessage: null,
      );
    } else {
      if (state.rawAmount == '0') {
        state = state.copyWith(rawAmount: key, errorMessage: null);
      } else {
        state = state.copyWith(
          rawAmount: state.rawAmount + key,
          errorMessage: null,
        );
      }
    }
  }

  void backspace() {
    if (state.rawAmount.length <= 1) {
      state = state.copyWith(rawAmount: '0');
    } else {
      state = state.copyWith(
        rawAmount: state.rawAmount.substring(0, state.rawAmount.length - 1),
      );
    }
  }

  void clearAmount() {
    state = state.copyWith(rawAmount: '0');
  }

  void setAmount(int amount) {
    state = state.copyWith(rawAmount: amount.toString());
  }

  void setAccount(int accountId) {
    state = state.copyWith(selectedAccountId: accountId, errorMessage: null);
  }

  void setCategory(int categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId, errorMessage: null);
  }

  void setNote(String note) {
    state = state.copyWith(note: note);
  }

  void setDate(DateTime date) {
    state = state.copyWith(date: date);
  }

  void setImagePath(String? path) {
    state = state.copyWith(imagePath: path, clearImage: path == null);
  }

  void toggleSplit(bool enable) {
    if (enable && state.splitItems.isEmpty && state.amount > 0) {
      final half = (state.amount / 2).floor();
      final rest = state.amount - half;
      state = state.copyWith(
        isSplit: true,
        splitItems: [
          SplitCategoryItem(
            categoryId: state.selectedCategoryId,
            amount: half,
            note: state.note,
          ),
          SplitCategoryItem(
            amount: rest,
          ),
        ],
      );
    } else {
      state = state.copyWith(isSplit: enable);
    }
  }

  void addSplitItem({int? categoryId, int amount = 0, String note = ''}) {
    final remaining = state.splitRemainingAmount;
    final defaultAmount = remaining > 0 ? remaining : amount;
    final updated = List<SplitCategoryItem>.from(state.splitItems)
      ..add(SplitCategoryItem(
        categoryId: categoryId,
        amount: defaultAmount,
        note: note,
      ));
    state = state.copyWith(splitItems: updated, errorMessage: null);
  }

  void updateSplitItem(int index, SplitCategoryItem item) {
    if (index < 0 || index >= state.splitItems.length) return;
    final updated = List<SplitCategoryItem>.from(state.splitItems);
    updated[index] = item;
    state = state.copyWith(splitItems: updated, errorMessage: null);
  }

  void removeSplitItem(int index) {
    if (index < 0 || index >= state.splitItems.length) return;
    final updated = List<SplitCategoryItem>.from(state.splitItems)
      ..removeAt(index);
    state = state.copyWith(splitItems: updated, errorMessage: null);
  }

  Future<bool> checkBalanceWarning() async {
    if (state.type == 'income' ||
        state.selectedAccountId == null ||
        state.amount <= 0) {
      return false;
    }
    final accountRepo = ref.read(accountRepositoryProvider);
    final isMinus = await accountRepo.checkNewTransactionBalanceWarning(
      accountId: state.selectedAccountId!,
      amount: state.amount,
      type: state.type,
    );
    return isMinus;
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

    if (state.isSplit) {
      if (state.splitItems.length < 2) {
        state = state.copyWith(
          errorMessage: 'Minimal 2 pecahan kategori untuk split transaksi',
        );
        return false;
      }
      if (state.splitTotalAmount != state.amount) {
        final diff = (state.amount - state.splitTotalAmount).abs();
        final label = state.splitTotalAmount < state.amount
            ? 'Kurang Rp $diff'
            : 'Kelebihan Rp $diff';
        state = state.copyWith(
          errorMessage: 'Total pecahan tidak seimbang: $label',
        );
        return false;
      }
      for (int i = 0; i < state.splitItems.length; i++) {
        if (state.splitItems[i].amount <= 0) {
          state = state.copyWith(
            errorMessage: 'Nominal item #${i + 1} harus lebih dari Rp 0',
          );
          return false;
        }
      }
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final transactionRepo = ref.read(transactionRepositoryProvider);

      if (state.isSplit) {
        final parentNote = state.note.trim();
        for (final item in state.splitItems) {
          final itemNote = item.note.trim().isNotEmpty
              ? item.note.trim()
              : (parentNote.isNotEmpty ? parentNote : null);
          final splitTx = TransactionModel(
            type: state.type,
            amount: item.amount,
            accountId: state.selectedAccountId!,
            categoryId: item.categoryId,
            note: itemNote,
            date: state.date,
            createdAt: DateTime.now(),
            imagePath: state.imagePath,
          );
          await transactionRepo.insertTransaction(splitTx);
        }
      } else {
        final newTx = TransactionModel(
          type: state.type,
          amount: state.amount,
          accountId: state.selectedAccountId!,
          categoryId: state.selectedCategoryId,
          note: state.note.trim().isEmpty ? null : state.note.trim(),
          date: state.date,
          createdAt: DateTime.now(),
          imagePath: state.imagePath,
        );
        await transactionRepo.insertTransaction(newTx);
      }

      // Trigger pembaruan saldo di Home & History
      ref.read(homeRefreshTriggerProvider.notifier).state++;
      if (mounted) {
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
