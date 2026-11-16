import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../home/providers/home_providers.dart';
import '../providers/inter_profile_transfer_provider.dart';
import '../providers/transfer_form_provider.dart';
import '../widgets/custom_numeric_keypad.dart';
import '../widgets/discard_changes_dialog.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../widgets/inter_profile_accounts_card.dart';
import '../widgets/transfer_accounts_card.dart';

enum TransferScreenMode {
  intraProfile, // Antar Akun di Profil Aktif
  interProfile, // Jembatan Antar Profil (Pribadi <-> Bisnis)
}

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  late final TextEditingController _intraNoteController;
  late final TextEditingController _interNoteController;
  TransferScreenMode _currentMode = TransferScreenMode.intraProfile;
  bool _isSaving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _intraNoteController = TextEditingController();
    _interNoteController = TextEditingController();
  }

  @override
  void dispose() {
    _intraNoteController.dispose();
    _interNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intraFormState = ref.watch(transferFormNotifierProvider);
    final intraFormNotifier = ref.read(transferFormNotifierProvider.notifier);

    final interFormState = ref.watch(interProfileTransferNotifierProvider);
    final interFormNotifier =
        ref.read(interProfileTransferNotifierProvider.notifier);

    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final isBusy = _isSaving ||
        intraFormState.isSubmitting ||
        interFormState.isSubmitting;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final hasUnsavedChanges = _currentMode == TransferScreenMode.intraProfile
        ? (intraFormState.amount > 0 || intraFormState.note.trim().isNotEmpty)
        : (interFormState.amount > 0 || interFormState.note.trim().isNotEmpty);

    final activeDate = _currentMode == TransferScreenMode.intraProfile
        ? intraFormState.date
        : interFormState.date;

    return PopScope(
      canPop: _allowPop || !hasUnsavedChanges || isBusy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await confirmDiscardChangesDialog(context);
        if (discard && context.mounted) {
          setState(() => _allowPop = true);
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _currentMode == TransferScreenMode.intraProfile
                ? 'Transfer Antar Akun'
                : 'Jembatan Pribadi ↔ Bisnis',
            style: AppTypography.headlineMedium.copyWith(fontSize: 18),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: activeDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  final now = DateTime.now();
                  final newDate = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    now.hour,
                    now.minute,
                  );
                  if (_currentMode == TransferScreenMode.intraProfile) {
                    intraFormNotifier.setDate(newDate);
                  } else {
                    interFormNotifier.setDate(newDate);
                  }
                }
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text(
                DateFormatter.formatShort(activeDate),
                style: AppTypography.labelSmall,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  // Mode Segmented Switcher (Antar Rekening vs Jembatan Profil)
                  _buildModeSelector(),
                  const SizedBox(height: 14),

                  if (_currentMode == TransferScreenMode.intraProfile) ...[
                    // Mode A: Transfer Antar Akun biasa
                    accountsAsync.when(
                      data: (accounts) => TransferAccountsCard(
                        accounts: accounts,
                        fromAccountId: intraFormState.fromAccountId,
                        toAccountId: intraFormState.toAccountId,
                        onSelectFrom: intraFormNotifier.setFromAccount,
                        onSelectTo: intraFormNotifier.setToAccount,
                        onSwap: intraFormNotifier.swapAccounts,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                    ),
                    const SizedBox(height: 16),
                    _buildAmountDisplay(context, intraFormState.amount),
                    const SizedBox(height: 16),
                    _buildNoteTextField(
                      controller: _intraNoteController,
                      hint: 'Keterangan transfer (misal: Tarik tunai, Nabung)',
                      onChanged: intraFormNotifier.setNote,
                    ),
                    if (intraFormState.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _buildErrorBox(intraFormState.errorMessage!),
                    ],
                  ] else ...[
                    // Mode B: Jembatan Antar Profil (Pribadi <-> Bisnis)
                    if (interFormState.profiles.length < 2)
                      _buildSingleProfileNotice()
                    else ...[
                      InterProfileAccountsCard(
                        profiles: interFormState.profiles,
                        fromProfile: interFormState.fromProfile,
                        fromAccount: interFormState.fromAccount,
                        fromAccounts: interFormState.fromAccounts,
                        toProfile: interFormState.toProfile,
                        toAccount: interFormState.toAccount,
                        toAccounts: interFormState.toAccounts,
                        onSelectFromProfile: interFormNotifier.setFromProfile,
                        onSelectFromAccount: interFormNotifier.setFromAccount,
                        onSelectToProfile: interFormNotifier.setToProfile,
                        onSelectToAccount: interFormNotifier.setToAccount,
                        onSwap: interFormNotifier.swapProfilesAndAccounts,
                        bridgeType: interFormState.bridgeType,
                      ),
                      const SizedBox(height: 16),
                      _buildAmountDisplay(context, interFormState.amount),
                      const SizedBox(height: 16),
                      _buildNoteTextField(
                        controller: _interNoteController,
                        hint: interFormState.bridgeType ==
                                InterTransferBridgeType.prive
                            ? 'Catatan (misal: Gaji owner bulan ini, Bonus)'
                            : interFormState.bridgeType ==
                                    InterTransferBridgeType.suntikModal
                                ? 'Catatan (misal: Talangan belanja bahan, Modal awal)'
                                : 'Catatan transfer antar profil',
                        onChanged: interFormNotifier.setNote,
                      ),
                      if (interFormState.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _buildErrorBox(interFormState.errorMessage!),
                      ],
                    ],
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Tombol Eksekusi Transfer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isBusy
                      ? null
                      : (_currentMode == TransferScreenMode.intraProfile
                          ? ((accountsAsync.valueOrNull?.length ?? 0) >= 2
                              ? _handleIntraTransfer
                              : null)
                          : (interFormState.profiles.length >= 2
                              ? _handleInterTransfer
                              : null)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isBusy
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
                            Icon(
                              _currentMode == TransferScreenMode.intraProfile
                                  ? Icons.swap_horiz_rounded
                                  : Icons.sync_alt_rounded,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _currentMode == TransferScreenMode.intraProfile
                                      ? 'Kirim Transfer'
                                      : 'Kirim Transfer Antar Profil',
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

            // Keypad Angka
            if (!isKeyboardOpen)
              CustomNumericKeypad(
                onKeyPress: (key) {
                  FocusScope.of(context).unfocus();
                  if (_currentMode == TransferScreenMode.intraProfile) {
                    intraFormNotifier.appendKey(key);
                  } else {
                    interFormNotifier.appendKey(key);
                  }
                },
                onBackspace: () {
                  FocusScope.of(context).unfocus();
                  if (_currentMode == TransferScreenMode.intraProfile) {
                    intraFormNotifier.backspace();
                  } else {
                    interFormNotifier.backspace();
                  }
                },
                onClear: () {
                  FocusScope.of(context).unfocus();
                  if (_currentMode == TransferScreenMode.intraProfile) {
                    intraFormNotifier.clearAmount();
                  } else {
                    interFormNotifier.clearAmount();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTab(
              title: 'Antar Rekening',
              icon: Icons.account_balance_wallet_outlined,
              isSelected: _currentMode == TransferScreenMode.intraProfile,
              onTap: () {
                FocusScope.of(context).unfocus();
                setState(() => _currentMode = TransferScreenMode.intraProfile);
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildModeTab(
              title: 'Jembatan Profil',
              icon: Icons.sync_alt_rounded,
              isSelected: _currentMode == TransferScreenMode.interProfile,
              onTap: () {
                FocusScope.of(context).unfocus();
                setState(() => _currentMode = TransferScreenMode.interProfile);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.black
                  : AppColors.textSecondaryOf(context),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.black
                    : AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleProfileNotice() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.business_center_outlined,
            size: 36,
            color: AppColors.primaryDark,
          ),
          const SizedBox(height: 10),
          Text(
            'Perlu Profil Bisnis',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Jembatan transfer menghubungkan pembukuan Pribadi & Bisnis (Prive / Modal). Buat profil bisnis untuk mulai menggunakan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryOf(context),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => context.push('/profiles'),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Buat Profil Bisnis', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDisplay(BuildContext context, int amount) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Nominal yang Dipindahkan',
            style: AppTypography.labelSmall,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.format(amount),
              style: AppTypography.headlineLarge.copyWith(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: amount > 0
                    ? AppColors.secondary
                    : AppColors.textSecondaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteTextField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyMedium,
        prefixIcon: Icon(Icons.note_alt_outlined,
            color: AppColors.textSecondaryOf(context)),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.danger,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _handleIntraTransfer() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final notifier = ref.read(transferFormNotifierProvider.notifier);

    try {
      final isWarning = await notifier.checkBalanceWarning();
      if (!mounted) return;

      if (isWarning) {
        final proceed = await _showBalanceWarningDialog();
        if (proceed != true) {
          if (mounted) setState(() => _isSaving = false);
          return;
        }
      }

      final success = await notifier.submit();
      if (!mounted) return;

      if (success) {
        _allowPop = true;
        _intraNoteController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Transfer saldo berhasil!'),
              ],
            ),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1500),
          ),
        );
        context.pop();
        return;
      }

      if (mounted) setState(() => _isSaving = false);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleInterTransfer() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final interNotifier =
        ref.read(interProfileTransferNotifierProvider.notifier);
    final interState = ref.read(interProfileTransferNotifierProvider);

    try {
      final isWarning = interNotifier.checkBalanceWarning();
      if (isWarning) {
        final proceed = await _showBalanceWarningDialog();
        if (proceed != true) {
          if (mounted) setState(() => _isSaving = false);
          return;
        }
      }

      final success = await interNotifier.submit();
      if (!mounted) return;

      if (success) {
        _allowPop = true;
        _interNoteController.clear();

        String successMessage;
        switch (interState.bridgeType) {
          case InterTransferBridgeType.prive:
            successMessage =
                'Penarikan Prive berhasil dicatat di pembukuan Bisnis & Pribadi!';
            break;
          case InterTransferBridgeType.suntikModal:
            successMessage =
                'Suntik modal berhasil dicatat di pembukuan Pribadi & Bisnis!';
            break;
          case InterTransferBridgeType.general:
            successMessage =
                'Transfer antar profil berhasil disinkronkan!';
            break;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.sync_alt_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        context.pop();
        return;
      }

      if (mounted) setState(() => _isSaving = false);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool?> _showBalanceWarningDialog() {
    return AppDialog.confirm(
      context,
      type: AppDialogType.warning,
      icon: Icons.account_balance_wallet_outlined,
      title: 'Saldo Sumber Kurang',
      message:
          'Nominal transfer melebihi saldo akun sumber saat ini. Apakah tetap ingin memindahkan saldo?',
      confirmLabel: 'Tetap Transfer',
      cancelLabel: 'Batal',
      isDestructive: false,
    );
  }
}
