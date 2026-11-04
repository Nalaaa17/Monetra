import 'package:flutter/material.dart';

class IconHelper {
  static final Map<int, IconData> _iconMap = {
    // Akun / Dompet
    Icons.account_balance_rounded.codePoint: Icons.account_balance_rounded,
    Icons.credit_card_rounded.codePoint: Icons.credit_card_rounded,
    Icons.payments_rounded.codePoint: Icons.payments_rounded,
    Icons.wallet_rounded.codePoint: Icons.wallet_rounded,
    Icons.account_balance_wallet_rounded.codePoint:
        Icons.account_balance_wallet_rounded,

    // Kategori Pengeluaran
    Icons.local_gas_station_rounded.codePoint:
        Icons.local_gas_station_rounded,
    Icons.restaurant_rounded.codePoint: Icons.restaurant_rounded,
    Icons.icecream_rounded.codePoint: Icons.icecream_rounded,
    Icons.shopping_cart_rounded.codePoint: Icons.shopping_cart_rounded,
    Icons.receipt_long_rounded.codePoint: Icons.receipt_long_rounded,
    Icons.movie_rounded.codePoint: Icons.movie_rounded,
    Icons.medical_services_rounded.codePoint: Icons.medical_services_rounded,
    Icons.more_horiz_rounded.codePoint: Icons.more_horiz_rounded,

    // Kategori Pemasukan
    Icons.work_rounded.codePoint: Icons.work_rounded,
    Icons.card_giftcard_rounded.codePoint: Icons.card_giftcard_rounded,
    Icons.trending_up_rounded.codePoint: Icons.trending_up_rounded,
    Icons.swap_horiz_rounded.codePoint: Icons.swap_horiz_rounded,

    // Kategori Kustom Tambahan
    Icons.shopping_bag_rounded.codePoint: Icons.shopping_bag_rounded,
    Icons.fastfood_rounded.codePoint: Icons.fastfood_rounded,
    Icons.local_cafe_rounded.codePoint: Icons.local_cafe_rounded,
    Icons.directions_car_rounded.codePoint: Icons.directions_car_rounded,
    Icons.local_mall_rounded.codePoint: Icons.local_mall_rounded,
    Icons.fitness_center_rounded.codePoint: Icons.fitness_center_rounded,
    Icons.pets_rounded.codePoint: Icons.pets_rounded,
    Icons.school_rounded.codePoint: Icons.school_rounded,
    Icons.flight_takeoff_rounded.codePoint: Icons.flight_takeoff_rounded,
    Icons.home_repair_service_rounded.codePoint:
        Icons.home_repair_service_rounded,
    Icons.category_rounded.codePoint: Icons.category_rounded,
    Icons.flag_rounded.codePoint: Icons.flag_rounded,
    Icons.savings_rounded.codePoint: Icons.savings_rounded,
  };

  static IconData getIcon(int codePoint) {
    return _iconMap[codePoint] ?? Icons.category_rounded;
  }
}
