import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Dialog konfirmasi standar saat pengguna menekan kembali dengan perubahan belum disimpan.
Future<bool> confirmDiscardChangesDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Keluar Tanpa Menyimpan?'),
      content: const Text(
        'Data yang sudah Anda isi akan hilang jika keluar sekarang.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Lanjut Isi'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
          ),
          child: const Text('Buang Perubahan'),
        ),
      ],
    ),
  );
  return result == true;
}

