import 'package:flutter/material.dart';
import '../../../shared/widgets/app_dialog.dart';

/// Dialog konfirmasi standar saat pengguna menekan kembali dengan perubahan belum disimpan.
Future<bool> confirmDiscardChangesDialog(BuildContext context) {
  return AppDialog.confirm(
    context,
    type: AppDialogType.warning,
    icon: Icons.edit_off_rounded,
    title: 'Keluar Tanpa Menyimpan?',
    message: 'Data yang sudah Anda isi akan hilang jika keluar sekarang.',
    confirmLabel: 'Buang Perubahan',
    cancelLabel: 'Lanjut Isi',
    isDestructive: true,
  );
}
