import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Dialog peringatan standar saat transaksi atau perubahan membuat saldo minus.
Future<bool> showInsufficientBalanceWarningDialog(
  BuildContext context, {
  String? message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Peringatan Saldo'),
      content: Text(
        message ??
            'Nominal pengeluaran ini melebihi saldo akun saat ini. Tetap simpan sebagai saldo minus sementara?',
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
          child: const Text('Tetap Simpan'),
        ),
      ],
    ),
  );
  return result == true;
}

