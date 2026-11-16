import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/vacation.dart';
import '../../../data/repositories/account_repository.dart';
import '../../home/providers/home_providers.dart';
import '../providers/vacation_providers.dart';

class CreateVacationSheet extends ConsumerStatefulWidget {
  const CreateVacationSheet({super.key});

  @override
  ConsumerState<CreateVacationSheet> createState() => _CreateVacationSheetState();
}

class _CreateVacationSheetState extends ConsumerState<CreateVacationSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  final Map<int, TextEditingController> _amountControllers = {};
  final Map<int, int> _allocations = {};
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _destController.dispose();
    for (final c in _amountControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _totalBudget =>
      _allocations.values.fold(0, (sum, val) => sum + val);

  void _onAmountChanged(int accountId, String text) {
    final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
    final val = int.tryParse(clean) ?? 0;
    setState(() {
      _allocations[accountId] = val;
    });
  }

  Future<void> _submit(List<AccountWithBalance> accounts) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nama trip terlebih dahulu')),
      );
      return;
    }

    if (_totalBudget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tentukan alokasi dana dari minimal 1 rekening')),
      );
      return;
    }

    for (final acc in accounts) {
      final alloc = _allocations[acc.id] ?? 0;
      if (alloc > acc.balance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Alokasi ${acc.name} melebihi saldo bebas (Rp ${CurrencyFormatter.format(acc.balance)})',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final vacation = VacationModel(
        name: name,
        destination: _destController.text.trim().isNotEmpty
            ? _destController.text.trim()
            : null,
        targetBudget: _totalBudget,
        status: 'active',
        startDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final repo = ref.read(vacationRepositoryProvider);
      final newId = await repo.createVacation(
        vacation: vacation,
        accountAllocations: _allocations,
      );

      ref.read(vacationRefreshTriggerProvider.notifier).state++;
      ref.read(homeRefreshTriggerProvider.notifier).state++;

      if (mounted) {
        Navigator.pop(context, newId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat liburan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accountsAsync = ref.watch(accountsWithBalanceProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.beach_access_rounded,
                        color: Color(0xFF0284C7),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Rencanakan Trip',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: accountsAsync.when(
              data: (accounts) {
                for (final acc in accounts) {
                  _amountControllers.putIfAbsent(
                    acc.id,
                    () => TextEditingController(),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  children: [
                    // Input Nama Trip
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Nama Trip / Liburan',
                        hintText: 'Misal: Liburan ke Bali 🌴',
                        prefixIcon: const Icon(Icons.flight_takeoff_rounded,
                            size: 20, color: Color(0xFF0284C7)),
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey.shade900
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Input Destinasi
                    TextField(
                      controller: _destController,
                      decoration: InputDecoration(
                        labelText: 'Tujuan (Opsional)',
                        hintText: 'Misal: Bali, Jogja, Jepang',
                        prefixIcon: const Icon(Icons.place_outlined,
                            size: 20, color: Color(0xFF0284C7)),
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey.shade900
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section Pemilihan Rekening
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ALOKASI REKENING',
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Total: Rp ${CurrencyFormatter.format(_totalBudget)}',
                          style: AppTypography.labelSmall.copyWith(
                            color: const Color(0xFF0284C7),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ...accounts.map((acc) {
                      final accColor = Color(int.parse(acc.colorHex));
                      final controller = _amountControllers[acc.id]!;
                      final isAllocated = (_allocations[acc.id] ?? 0) > 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade900 : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isAllocated
                                ? const Color(0xFF0284C7)
                                : (isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200),
                            width: isAllocated ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: accColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                IconData(acc.iconCodePoint,
                                    fontFamily: 'MaterialIcons'),
                                color: accColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    acc.name,
                                    style: AppTypography.titleSmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Bebas: Rp ${CurrencyFormatter.format(acc.balance)}',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondaryOf(context),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.end,
                                onChanged: (val) => _onAmountChanged(acc.id, val),
                                decoration: InputDecoration(
                                  prefixText: 'Rp ',
                                  hintText: '0',
                                  isDense: true,
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.grey.shade800.withValues(alpha: 0.4)
                                      : Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // Tombol Submit
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : () => _submit(accounts),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Mulai Trip (Rp ${CurrencyFormatter.format(_totalBudget)})',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
