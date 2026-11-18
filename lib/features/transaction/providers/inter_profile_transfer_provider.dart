import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../profile/providers/profile_provider.dart';
import '../widgets/custom_numeric_keypad.dart';

enum InterTransferBridgeType {
  prive, // Bisnis -> Pribadi (Ambil Gaji / Prive)
  suntikModal, // Pribadi -> Bisnis (Suntik / Tambah Modal)
  general, // Antar Pribadi atau Antar Bisnis
}

class InterProfileTransferState {
  final List<ProfileModel> profiles;
  final ProfileModel? fromProfile;
  final AccountWithBalance? fromAccount;
  final List<AccountWithBalance> fromAccounts;

  final ProfileModel? toProfile;
  final AccountWithBalance? toAccount;
  final List<AccountWithBalance> toAccounts;

  final String rawAmount;
  final String note;
  final DateTime date;
  final bool isSubmitting;
  final bool isLoading;
  final String? errorMessage;

  const InterProfileTransferState({
    this.profiles = const [],
    this.fromProfile,
    this.fromAccount,
    this.fromAccounts = const [],
    this.toProfile,
    this.toAccount,
    this.toAccounts = const [],
    this.rawAmount = '0',
    this.note = '',
    required this.date,
    this.isSubmitting = false,
    this.isLoading = false,
    this.errorMessage,
  });

  int get amount => int.tryParse(rawAmount) ?? 0;

  InterTransferBridgeType get bridgeType {
    if (fromProfile == null || toProfile == null) {
      return InterTransferBridgeType.general;
    }
    if (fromProfile!.isBusiness && !toProfile!.isBusiness) {
      return InterTransferBridgeType.prive;
    }
    if (!fromProfile!.isBusiness && toProfile!.isBusiness) {
      return InterTransferBridgeType.suntikModal;
    }
    return InterTransferBridgeType.general;
  }

  InterProfileTransferState copyWith({
    List<ProfileModel>? profiles,
    ProfileModel? fromProfile,
    AccountWithBalance? fromAccount,
    List<AccountWithBalance>? fromAccounts,
    ProfileModel? toProfile,
    AccountWithBalance? toAccount,
    List<AccountWithBalance>? toAccounts,
    String? rawAmount,
    String? note,
    DateTime? date,
    bool? isSubmitting,
    bool? isLoading,
    String? errorMessage,
  }) {
    return InterProfileTransferState(
      profiles: profiles ?? this.profiles,
      fromProfile: fromProfile ?? this.fromProfile,
      fromAccount: fromAccount ?? this.fromAccount,
      fromAccounts: fromAccounts ?? this.fromAccounts,
      toProfile: toProfile ?? this.toProfile,
      toAccount: toAccount ?? this.toAccount,
      toAccounts: toAccounts ?? this.toAccounts,
      rawAmount: rawAmount ?? this.rawAmount,
      note: note ?? this.note,
      date: date ?? this.date,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final interProfileTransferNotifierProvider = StateNotifierProvider.autoDispose<
    InterProfileTransferNotifier, InterProfileTransferState>((ref) {
  return InterProfileTransferNotifier(ref);
});

class InterProfileTransferNotifier
    extends StateNotifier<InterProfileTransferState> {
  final Ref ref;

  InterProfileTransferNotifier(this.ref)
      : super(InterProfileTransferState(date: DateTime.now())) {
    _initDefaults();
  }

  Future<void> _initDefaults() async {
    state = state.copyWith(isLoading: true);
    try {
      final profiles = await AppDatabase.getAllProfiles();
      if (!mounted) return;

      if (profiles.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final activeKey = await AppDatabase.getActiveProfileKey();
      final activeProfile = profiles.firstWhere(
        (p) => p.key == activeKey,
        orElse: () => profiles.first,
      );

      // Cari pasangan profil default (jika ada Bisnis & Pribadi)
      ProfileModel fromP;
      ProfileModel toP;

      if (profiles.length >= 2) {
        fromP = activeProfile;
        toP = profiles.firstWhere(
          (p) => p.key != fromP.key,
          orElse: () => profiles[1],
        );
      } else {
        fromP = activeProfile;
        toP = activeProfile;
      }

      final accountRepo = ref.read(accountRepositoryProvider);
      final fromAccs =
          await accountRepo.getAccountsWithBalancesForProfile(fromP.key);
      final toAccs =
          await accountRepo.getAccountsWithBalancesForProfile(toP.key);

      if (!mounted) return;

      state = state.copyWith(
        profiles: profiles,
        fromProfile: fromP,
        fromAccounts: fromAccs,
        fromAccount: fromAccs.isNotEmpty ? fromAccs.first : null,
        toProfile: toP,
        toAccounts: toAccs,
        toAccount: toAccs.isNotEmpty ? toAccs.first : null,
        isLoading: false,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Gagal memuat profil: $e',
        );
      }
    }
  }

  Future<void> setFromProfile(ProfileModel profile) async {
    if (state.fromProfile?.key == profile.key) return;

    final accountRepo = ref.read(accountRepositoryProvider);
    final accs =
        await accountRepo.getAccountsWithBalancesForProfile(profile.key);

    state = state.copyWith(
      fromProfile: profile,
      fromAccounts: accs,
      fromAccount: accs.isNotEmpty ? accs.first : null,
    );
  }

  void setFromAccount(AccountWithBalance account) {
    state = state.copyWith(fromAccount: account);
  }

  Future<void> setToProfile(ProfileModel profile) async {
    if (state.toProfile?.key == profile.key) return;

    final accountRepo = ref.read(accountRepositoryProvider);
    final accs =
        await accountRepo.getAccountsWithBalancesForProfile(profile.key);

    state = state.copyWith(
      toProfile: profile,
      toAccounts: accs,
      toAccount: accs.isNotEmpty ? accs.first : null,
    );
  }

  void setToAccount(AccountWithBalance account) {
    state = state.copyWith(toAccount: account);
  }

  void swapProfilesAndAccounts() {
    final prevFromProfile = state.fromProfile;
    final prevFromAccount = state.fromAccount;
    final prevFromAccounts = state.fromAccounts;

    final prevToProfile = state.toProfile;
    final prevToAccount = state.toAccount;
    final prevToAccounts = state.toAccounts;

    state = state.copyWith(
      fromProfile: prevToProfile,
      fromAccount: prevToAccount,
      fromAccounts: prevToAccounts,
      toProfile: prevFromProfile,
      toAccount: prevFromAccount,
      toAccounts: prevFromAccounts,
    );
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

  void setNote(String note) {
    state = state.copyWith(note: note);
  }

  void setDate(DateTime date) {
    state = state.copyWith(date: date);
  }

  bool checkBalanceWarning() {
    if (state.fromAccount == null || state.amount <= 0) return false;
    return state.amount > state.fromAccount!.balance;
  }

  Future<bool> submit() async {
    if (state.amount <= 0) {
      state = state.copyWith(
        errorMessage: 'Nominal transfer harus lebih dari Rp 0',
      );
      return false;
    }

    if (state.fromProfile == null || state.toProfile == null) {
      state = state.copyWith(
        errorMessage: 'Pilih profil asal dan profil tujuan',
      );
      return false;
    }

    if (state.fromAccount == null || state.toAccount == null) {
      state = state.copyWith(
        errorMessage: 'Pilih rekening asal dan rekening tujuan',
      );
      return false;
    }

    if (state.fromProfile!.key == state.toProfile!.key &&
        state.fromAccount!.id == state.toAccount!.id) {
      state = state.copyWith(
        errorMessage: 'Akun asal dan akun tujuan tidak boleh sama persis',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final transferRepo = ref.read(transferRepositoryProvider);

      await transferRepo.executeInterProfileTransfer(
        fromProfileKey: state.fromProfile!.key,
        fromProfileName: state.fromProfile!.name,
        isFromBusiness: state.fromProfile!.isBusiness,
        fromAccountId: state.fromAccount!.id,
        fromAccountName: state.fromAccount!.name,
        toProfileKey: state.toProfile!.key,
        toProfileName: state.toProfile!.name,
        isToBusiness: state.toProfile!.isBusiness,
        toAccountId: state.toAccount!.id,
        toAccountName: state.toAccount!.name,
        amount: state.amount,
        note: state.note.trim().isEmpty ? null : state.note.trim(),
        date: state.date,
      );

      // Trigger sinkronisasi di seluruh aplikasi
      ref.read(homeRefreshTriggerProvider.notifier).state++;
      ref.read(profileRefreshTriggerProvider.notifier).state++;

      if (mounted) {
        state = state.copyWith(
          rawAmount: '0',
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
          errorMessage: 'Gagal melakukan transfer antar profil: $e',
        );
      }
      return false;
    }
  }
}
