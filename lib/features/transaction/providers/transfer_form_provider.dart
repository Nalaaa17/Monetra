import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/transfer.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';

class TransferFormState {
  final int? fromAccountId;
  final int? toAccountId;
  final String rawAmount;
  final String note;
  final DateTime date;
  final bool isSubmitting;
  final String? errorMessage;

  const TransferFormState({
    this.fromAccountId,
    this.toAccountId,
    this.rawAmount = '0',
    this.note = '',
    required this.date,
    this.isSubmitting = false,
    this.errorMessage,
  });

  int get amount => int.tryParse(rawAmount) ?? 0;

  TransferFormState copyWith({
    int? fromAccountId,
    int? toAccountId,
    String? rawAmount,
    String? note,
    DateTime? date,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return TransferFormState(
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      rawAmount: rawAmount ?? this.rawAmount,
      note: note ?? this.note,
      date: date ?? this.date,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}

final transferFormNotifierProvider =
    StateNotifierProvider.autoDispose<TransferFormNotifier, TransferFormState>(
        (ref) {
  return TransferFormNotifier(ref);
});

class TransferFormNotifier extends StateNotifier<TransferFormState> {
  final Ref ref;

  TransferFormNotifier(this.ref)
      : super(TransferFormState(date: DateTime.now())) {
    _initDefaults();
  }

  void _initDefaults() async {
    final accountRepo = ref.read(accountRepositoryProvider);
    final accounts = await accountRepo.getAllAccounts();
    if (!mounted) return;

    if (accounts.length >= 2) {
      // Default: Dari Mandiri ke Cash (atau 2 akun pertama)
      final mandiri = accounts.firstWhere(
        (a) => a.name.toLowerCase().contains('mandiri'),
        orElse: () => accounts[0],
      );
      final cashOrOther = accounts.firstWhere(
        (a) => a.id != mandiri.id,
        orElse: () => accounts[1],
      );

      state = state.copyWith(
        fromAccountId: mandiri.id,
        toAccountId: cashOrOther.id,
      );
    }
  }

  void setFromAccount(int id) {
    if (state.toAccountId == id) {
      // Jika sama dengan tujuan, swap otomatis
      state = state.copyWith(
        fromAccountId: id,
        toAccountId: state.fromAccountId,
      );
    } else {
      state = state.copyWith(fromAccountId: id);
    }
  }

  void setToAccount(int id) {
    if (state.fromAccountId == id) {
      // Jika sama dengan asal, swap otomatis
      state = state.copyWith(
        toAccountId: id,
        fromAccountId: state.toAccountId,
      );
    } else {
      state = state.copyWith(toAccountId: id);
    }
  }

  void swapAccounts() {
    state = state.copyWith(
      fromAccountId: state.toAccountId,
      toAccountId: state.fromAccountId,
    );
  }

  void appendKey(String key) {
    String current = state.rawAmount;
    if (current == '0') {
      if (key == '000' || key == '0') return;
      current = key;
    } else {
      if (current.length >= 10) return;
      current = current + key;
    }
    state = state.copyWith(rawAmount: current);
  }

  void backspace() {
    String current = state.rawAmount;
    if (current.length <= 1) {
      current = '0';
    } else {
      current = current.substring(0, current.length - 1);
    }
    state = state.copyWith(rawAmount: current);
  }

  void clearAmount() {
    state = state.copyWith(rawAmount: '0');
  }

  void setNote(String note) {
    state = state.copyWith(note: note);
  }

  void setDate(DateTime date) {
    state = state.copyWith(date: date);
  }

  Future<bool> checkBalanceWarning() async {
    if (state.fromAccountId == null) return false;
    final accountRepo = ref.read(accountRepositoryProvider);
    final currentBalance =
        await accountRepo.calculateAccountBalance(state.fromAccountId!);
    return state.amount > currentBalance;
  }

  Future<bool> submit() async {
    if (state.amount <= 0) {
      state = state.copyWith(errorMessage: 'Nominal transfer harus lebih dari Rp 0');
      return false;
    }

    if (state.fromAccountId == null || state.toAccountId == null) {
      state = state.copyWith(errorMessage: 'Pilih dompet asal dan tujuan');
      return false;
    }

    if (state.fromAccountId == state.toAccountId) {
      state = state.copyWith(errorMessage: 'Akun asal dan akun tujuan tidak boleh sama');
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final transferRepo = ref.read(transferRepositoryProvider);
      final newTransfer = TransferModel(
        fromAccountId: state.fromAccountId!,
        toAccountId: state.toAccountId!,
        amount: state.amount,
        note: state.note.trim().isEmpty ? null : state.note.trim(),
        date: state.date,
        createdAt: DateTime.now(),
      );

      await transferRepo.insertTransfer(newTransfer);

      // Trigger refresh saldo di seluruh aplikasi
      ref.read(homeRefreshTriggerProvider.notifier).state++;
      if (mounted) {
        state = state.copyWith(isSubmitting: false);
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Gagal melakukan transfer: $e',
        );
      }
      return false;
    }
  }
}

