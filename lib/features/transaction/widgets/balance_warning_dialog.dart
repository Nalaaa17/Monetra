import 'package:flutter/material.dart';
import '../../../shared/widgets/app_dialog.dart';

/// Dialog peringatan standar saat transaksi atau perubahan membuat saldo minus.
Future<bool> showInsufficientBalanceWarningDialog(
  BuildContext context, {
  String? message,
}) {
  return AppDialog.confirm(
    context,
    type: AppDialogType.warning,
    icon: Icons.account_balance_wallet_outlined,
    title: 'Peringatan Saldo',
    message: message ??
        'Nominal pengeluaran ini melebihi saldo akun saat ini. Tetap simpan sebagai saldo minus sementara?',
    confirmLabel: 'Tetap Simpan',
    cancelLabel: 'Batal',
    isDestructive: false,
  );
}
