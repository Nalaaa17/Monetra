import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../data/models/account.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';

class ManageAccountsScreen extends ConsumerWidget {
  const ManageAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsWithBalanceProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Kelola Dompet & Rekening',
          style: AppTypography.headlineMedium.copyWith(fontSize: 18),
        ),
      ),
      body: accountsAsync.when(
        data: (accounts) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Text(
                'Daftar Akun Aktif',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: 12),
              ...accounts.map((acc) => _buildAccountItem(context, ref, acc)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddAccountDialog(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Tambah Dompet / Rekening Baru',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildAccountItem(
    BuildContext context,
    WidgetRef ref,
    AccountWithBalance item,
  ) {
    final color = Color(int.parse(item.colorHex));
    final icon = IconHelper.getIcon(item.iconCodePoint);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            radius: 22,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.type.toUpperCase(),
                  style: AppTypography.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Saldo', style: AppTypography.labelSmall),
              Text(
                CurrencyFormatter.format(item.balance),
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController(text: '0');
    String selectedType = 'bank';
    String selectedColor = '0xFF0284C7'; // Blue
    int selectedIcon = Icons.account_balance_rounded.codePoint;

    final colorOptions = [
      '0xFF0284C7', // Biru
      '0xFFF59E0B', // Emas
      '0xFF10B981', // Hijau
      '0xFF8B5CF6', // Ungu
      '0xFFEC4899', // Pink
      '0xFF6B7280', // Abu
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Tambah Dompet Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Akun / Dompet',
                    hintText: 'Misal: BCA, GoPay, OVO, Bibit',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Saldo Awal (Rp)',
                    hintText: '0',
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Tipe Akun:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButton<String>(
                  value: selectedType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'bank', child: Text('Bank (Rekening)')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash (Tunai)')),
                    DropdownMenuItem(value: 'ewallet', child: Text('E-Wallet (Dompet Digital)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        selectedType = val;
                        if (val == 'bank') selectedIcon = Icons.account_balance_rounded.codePoint;
                        if (val == 'cash') selectedIcon = Icons.payments_rounded.codePoint;
                        if (val == 'ewallet') selectedIcon = Icons.wallet_rounded.codePoint;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
                const Text('Pilih Warna:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: colorOptions.map((c) {
                    final color = Color(int.parse(c));
                    final isSelected = selectedColor == c;
                    return InkWell(
                      onTap: () => setState(() => selectedColor = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final initBal =
                    int.tryParse(balanceController.text.replaceAll('.', '')) ?? 0;
                if (name.isEmpty) return;

                final repo = ref.read(accountRepositoryProvider);
                await repo.insertAccount(
                  Account(
                    name: name,
                    type: selectedType,
                    colorHex: selectedColor,
                    iconCodePoint: selectedIcon,
                    initialBalance: initBal,
                    createdAt: DateTime.now(),
                  ),
                );

                ref.read(homeRefreshTriggerProvider.notifier).state++;
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Akun "$name" berhasil ditambahkan!')),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

