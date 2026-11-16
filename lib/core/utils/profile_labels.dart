import '../constants/app_colors.dart';
import '../../data/models/profile_model.dart';
import 'package:flutter/material.dart';

class ProfileLabels {
  final ProfileModel? profile;

  const ProfileLabels(this.profile);

  bool get isBusiness => profile?.isBusiness ?? false;

  String get income => isBusiness ? 'Omzet' : 'Pemasukan';
  String get expense => isBusiness ? 'Biaya Operasional' : 'Pengeluaran';
  String get netSummary => isBusiness ? 'Laba Bersih' : 'Sisa Uang';
  String get totalBalance => isBusiness ? 'Kas Usaha & Aset' : 'Total Saldo';
  String get dailySummaryTitle => isBusiness ? 'Omzet & Biaya Hari Ini' : 'Pemasukan & Pengeluaran Hari Ini';
  String get recentTransactionTitle => isBusiness ? 'Transaksi Usaha Terakhir' : 'Transaksi Terakhir';
  String get emptyTransactionMsg => isBusiness ? 'Belum ada transaksi usaha tercatat' : 'Belum ada transaksi tercatat';

  Color get badgeColor => isBusiness ? const Color(0xFF3B82F6) : AppColors.primary;
  IconData get iconData {
    final code = profile?.iconCodePoint;
    if (code != null) {
      // ignore: non_const_argument_for_const_parameter
      return IconData(code, fontFamily: 'MaterialIcons');
    }
    return isBusiness ? Icons.storefront_rounded : Icons.person_rounded;
  }
}
