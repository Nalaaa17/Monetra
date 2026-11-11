import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/category.dart';

class SeedData {
  static List<Account> get defaultAccounts => [
        Account(
          name: 'Seabank',
          type: 'bank',
          category: 'tabungan',
          colorHex: '0xFF00B0FF',
          iconCodePoint: Icons.account_balance_rounded.codePoint,
          initialBalance: 0,
          createdAt: DateTime.now(),
        ),
        Account(
          name: 'Mandiri',
          type: 'bank',
          category: 'harian',
          colorHex: '0xFFF59E0B',
          iconCodePoint: Icons.credit_card_rounded.codePoint,
          initialBalance: 0,
          createdAt: DateTime.now(),
        ),
        Account(
          name: 'Cash',
          type: 'cash',
          category: 'harian',
          colorHex: '0xFF10B981',
          iconCodePoint: Icons.payments_rounded.codePoint,
          initialBalance: 0,
          createdAt: DateTime.now(),
        ),
      ];

  static List<Category> get defaultCategories => [
        // Pengeluaran
        Category(
          name: 'Bensin',
          iconCodePoint: Icons.local_gas_station_rounded.codePoint,
          colorHex: '0xFFF59E0B',
          type: 'expense',
        ),
        Category(
          name: 'Makan',
          iconCodePoint: Icons.restaurant_rounded.codePoint,
          colorHex: '0xFFEF4444',
          type: 'expense',
        ),
        Category(
          name: 'Jajan',
          iconCodePoint: Icons.icecream_rounded.codePoint,
          colorHex: '0xFFEC4899',
          type: 'expense',
        ),
        Category(
          name: 'Belanja Dapur',
          iconCodePoint: Icons.shopping_cart_rounded.codePoint,
          colorHex: '0xFF10B981',
          type: 'expense',
        ),
        Category(
          name: 'Tagihan',
          iconCodePoint: Icons.receipt_long_rounded.codePoint,
          colorHex: '0xFF3B82F6',
          type: 'expense',
        ),
        Category(
          name: 'Hiburan',
          iconCodePoint: Icons.sports_esports_rounded.codePoint,
          colorHex: '0xFF8B5CF6',
          type: 'expense',
        ),
        Category(
          name: 'Kesehatan',
          iconCodePoint: Icons.medical_services_rounded.codePoint,
          colorHex: '0xFF14B8A6',
          type: 'expense',
        ),
        Category(
          name: 'Lainnya',
          iconCodePoint: Icons.inventory_2_rounded.codePoint,
          colorHex: '0xFF6B7280',
          type: 'expense',
        ),

        // Pemasukan
        Category(
          name: 'Gaji',
          iconCodePoint: Icons.account_balance_wallet_rounded.codePoint,
          colorHex: '0xFF10B981',
          type: 'income',
        ),
        Category(
          name: 'Tambahan Uang',
          iconCodePoint: Icons.savings_rounded.codePoint,
          colorHex: '0xFF059669',
          type: 'income',
        ),
      ];
}

