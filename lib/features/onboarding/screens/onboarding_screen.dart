import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/account.dart';
import '../../home/providers/home_providers.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/onboarding_providers.dart';

class OnboardingAccountOption {
  final String id;
  final String name;
  final String type; // 'bank', 'ewallet', 'cash'
  final String category; // 'harian', 'tabungan'
  final String colorHex;
  final IconData icon;
  final String description;
  final bool isBusiness;

  const OnboardingAccountOption({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.colorHex,
    required this.icon,
    required this.description,
    this.isBusiness = false,
  });
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  int _currentPage = 0;
  bool _isSubmitting = false;

  // Step 1: Pilihan Profil
  // 'personal' | 'business' | 'both'
  String _selectedProfileMode = 'personal';

  // Step 2: Akun Pilihan Pengguna (menggantikan Seabank/Mandiri default yang kaku)
  late List<OnboardingAccountOption> _availableAccounts;
  late Set<String> _selectedAccountIds;

  @override
  void initState() {
    super.initState();
    _availableAccounts = _buildInitialAccountOptions();
    // Default terpilih: BCA & Uang Tunai (atau yang paling umum di Indonesia)
    _selectedAccountIds = {'bca', 'cash'};
  }

  List<OnboardingAccountOption> _buildInitialAccountOptions() {
    return const [
      OnboardingAccountOption(
        id: 'bca',
        name: 'BCA',
        type: 'bank',
        category: 'harian',
        colorHex: '0xFF005E9E',
        icon: Icons.account_balance_rounded,
        description: 'Bank Central Asia',
      ),
      OnboardingAccountOption(
        id: 'mandiri',
        name: 'Mandiri',
        type: 'bank',
        category: 'harian',
        colorHex: '0xFF003087',
        icon: Icons.account_balance_rounded,
        description: 'Bank Mandiri (Livin)',
      ),
      OnboardingAccountOption(
        id: 'bri',
        name: 'BRI',
        type: 'bank',
        category: 'harian',
        colorHex: '0xFF00529C',
        icon: Icons.account_balance_rounded,
        description: 'Bank Rakyat Indonesia',
      ),
      OnboardingAccountOption(
        id: 'bni',
        name: 'BNI',
        type: 'bank',
        category: 'harian',
        colorHex: '0xFF005E6A',
        icon: Icons.account_balance_rounded,
        description: 'Bank Negara Indonesia',
      ),
      OnboardingAccountOption(
        id: 'jago',
        name: 'Bank Jago',
        type: 'bank',
        category: 'tabungan',
        colorHex: '0xFFFF5C00',
        icon: Icons.savings_rounded,
        description: 'Kantong Digital & Tabungan',
      ),
      OnboardingAccountOption(
        id: 'seabank',
        name: 'SeaBank',
        type: 'bank',
        category: 'tabungan',
        colorHex: '0xFFFF6600',
        icon: Icons.account_balance_rounded,
        description: 'Tabungan Bunga Harian',
      ),
      OnboardingAccountOption(
        id: 'gopay',
        name: 'GoPay',
        type: 'ewallet',
        category: 'harian',
        colorHex: '0xFF00AED6',
        icon: Icons.account_balance_wallet_rounded,
        description: 'E-Wallet Gojek & Belanja',
      ),
      OnboardingAccountOption(
        id: 'ovo',
        name: 'OVO',
        type: 'ewallet',
        category: 'harian',
        colorHex: '0xFF4C3494',
        icon: Icons.account_balance_wallet_rounded,
        description: 'E-Wallet Grab & Tokopedia',
      ),
      OnboardingAccountOption(
        id: 'dana',
        name: 'DANA',
        type: 'ewallet',
        category: 'harian',
        colorHex: '0xFF118EEA',
        icon: Icons.account_balance_wallet_rounded,
        description: 'Dompet Digital DANA',
      ),
      OnboardingAccountOption(
        id: 'shopeepay',
        name: 'ShopeePay',
        type: 'ewallet',
        category: 'harian',
        colorHex: '0xFFEE4D2D',
        icon: Icons.account_balance_wallet_rounded,
        description: 'Belanja & Transaksi QRIS',
      ),
      OnboardingAccountOption(
        id: 'cash',
        name: 'Uang Tunai',
        type: 'cash',
        category: 'harian',
        colorHex: '0xFF10B981',
        icon: Icons.payments_rounded,
        description: 'Uang Tunai di Dompet / Saku',
      ),
      OnboardingAccountOption(
        id: 'kas_toko',
        name: 'Kas Usaha',
        type: 'cash',
        category: 'harian',
        colorHex: '0xFF059669',
        icon: Icons.point_of_sale_rounded,
        description: 'Kasir & Uang Laci Toko',
        isBusiness: true,
      ),
      OnboardingAccountOption(
        id: 'qris_toko',
        name: 'QRIS Usaha',
        type: 'ewallet',
        category: 'harian',
        colorHex: '0xFF8B5CF6',
        icon: Icons.qr_code_2_rounded,
        description: 'Penerimaan QRIS Toko',
        isBusiness: true,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _toggleAccount(String id) {
    setState(() {
      if (_selectedAccountIds.contains(id)) {
        if (_selectedAccountIds.length > 1) {
          _selectedAccountIds.remove(id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pilih minimal 1 akun untuk memulai Monetra'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        _selectedAccountIds.add(id);
      }
    });
  }

  void _openAddCustomAccountDialog() {
    final customNameController = TextEditingController();
    String customType = 'bank';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tambah Akun / Bank Lain',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customNameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Nama Bank / E-Wallet (misal: BSI, Jenius)',
                      prefixIcon: const Icon(Icons.account_balance_rounded),
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildTypeChip('Bank', 'bank', customType, () {
                        setSheetState(() => customType = 'bank');
                      }),
                      const SizedBox(width: 8),
                      _buildTypeChip('E-Wallet', 'ewallet', customType, () {
                        setSheetState(() => customType = 'ewallet');
                      }),
                      const SizedBox(width: 8),
                      _buildTypeChip('Tunai', 'cash', customType, () {
                        setSheetState(() => customType = 'cash');
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = customNameController.text.trim();
                        if (name.isNotEmpty) {
                          final newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
                          final newOption = OnboardingAccountOption(
                            id: newId,
                            name: name,
                            type: customType,
                            category: 'harian',
                            colorHex: '0xFF3B82F6',
                            icon: customType == 'bank'
                                ? Icons.account_balance_rounded
                                : (customType == 'ewallet'
                                    ? Icons.account_balance_wallet_rounded
                                    : Icons.payments_rounded),
                            description: 'Akun Kustom',
                          );
                          setState(() {
                            _availableAccounts.insert(0, newOption);
                            _selectedAccountIds.add(newId);
                          });
                          Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Tambahkan Akun',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTypeChip(
      String label, String value, String current, VoidCallback onTap) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade400,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : null,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Future<void> _finishOnboarding() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final inputName = _nameController.text.trim();
    final chosenName = inputName.isNotEmpty ? inputName : 'Sahabat Monetra';

    // Buat daftar Akun dari pilihan pengguna
    final chosenAccounts = _availableAccounts
        .where((opt) => _selectedAccountIds.contains(opt.id))
        .map((opt) => Account(
              name: opt.name,
              type: opt.type,
              category: opt.category,
              colorHex: opt.colorHex,
              iconCodePoint: opt.icon.codePoint,
              initialBalance: 0,
              createdAt: DateTime.now(),
            ))
        .toList();

    // Fallback jika tidak ada akun terpilih sama sekali
    if (chosenAccounts.isEmpty) {
      chosenAccounts.add(Account(
        name: 'Uang Tunai',
        type: 'cash',
        category: 'harian',
        colorHex: '0xFF10B981',
        iconCodePoint: Icons.payments_rounded.codePoint,
        initialBalance: 0,
        createdAt: DateTime.now(),
      ));
    }

    try {
      // Setup Meta Database, Akun Pilihan, Profil, dan Nama Pengguna
      await AppDatabase.completeOnboardingSetup(
        profileChoice: _selectedProfileMode,
        chosenAccounts: chosenAccounts,
        userName: chosenName,
      );

      await ref.read(userNameProvider.notifier).setUserName(chosenName);
      ref.read(profileRefreshTriggerProvider.notifier).state++;
      ref.read(homeRefreshTriggerProvider.notifier).state++;
    } catch (e) {
      debugPrint('Error finishing onboarding: $e');
    }

    if (mounted) {
      try {
        context.go(AppRouter.home);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Kredivo-Style Top Bar (Back Button + Step Indicator)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Back button (hanya tampil di step 2 & 3)
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: _previousPage,
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.grey.shade900
                            : Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  const SizedBox(width: 14),

                  // Segmented Progress Bar (3 Langkah Kredivo-Style)
                  Expanded(
                    child: Row(
                      children: List.generate(3, (index) {
                        final isFilled = index <= _currentPage;
                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: isFilled
                                  ? AppColors.primary
                                  : (isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Label Step
                  Text(
                    '${_currentPage + 1}/3',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // Content Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Kontrol via tombol Kredivo-style
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildProfileModePage(isDark),
                  _buildAccountSelectionPage(isDark),
                  _buildNameInputPage(isDark),
                ],
              ),
            ),

            // Kredivo-Style Fixed Bottom Action Bar
            _buildBottomActionBar(isDark),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 1: Fokus Finansial / Mode Profil
  // ---------------------------------------------------------------------------
  Widget _buildProfileModePage(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'LANGKAH 1 DARI 3',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pilih Fokus Finansialmu',
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Monetra menyesuaikan pembukuan sesuai kebutuhanmu. Bisa diubah kapan saja.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondaryOf(context),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),

          // Option 1: Keuangan Pribadi
          _buildSelectionCard(
            title: 'Keuangan Pribadi',
            subtitle: 'Kelola dompet harian, alokasi tabungan, & utang piutang.',
            badge: 'Paling Populer',
            badgeColor: AppColors.primary,
            icon: Icons.person_rounded,
            iconColor: AppColors.primary,
            isSelected: _selectedProfileMode == 'personal',
            onTap: () {
              setState(() {
                _selectedProfileMode = 'personal';
                // Pastikan akun default personal aktif
                _selectedAccountIds.remove('kas_toko');
                _selectedAccountIds.remove('qris_toko');
                _selectedAccountIds.add('bca');
                _selectedAccountIds.add('cash');
              });
            },
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Option 2: Bisnis / UMKM
          _buildSelectionCard(
            title: 'Bisnis & Toko (UMKM)',
            subtitle: 'Catat omzet penjualan, laba kotor, HPP, & biaya operasional.',
            badge: 'Usaha / Toko',
            badgeColor: const Color(0xFF3B82F6),
            icon: Icons.storefront_rounded,
            iconColor: const Color(0xFF3B82F6),
            isSelected: _selectedProfileMode == 'business',
            onTap: () {
              setState(() {
                _selectedProfileMode = 'business';
                _selectedAccountIds.add('kas_toko');
                _selectedAccountIds.add('qris_toko');
              });
            },
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Option 3: Keduanya (Pribadi & Bisnis)
          _buildSelectionCard(
            title: 'Keduanya (Pribadi & Bisnis)',
            subtitle: 'Buku kas terpisah otomatis dengan jembatan Transfer Prive & Modal.',
            badge: 'Paling Lengkap ⚡',
            badgeColor: const Color(0xFF8B5CF6),
            icon: Icons.all_inclusive_rounded,
            iconColor: const Color(0xFF8B5CF6),
            isSelected: _selectedProfileMode == 'both',
            onTap: () {
              setState(() {
                _selectedProfileMode = 'both';
                _selectedAccountIds.add('bca');
                _selectedAccountIds.add('cash');
              });
            },
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08)
              : (isDark ? Colors.grey.shade900 : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: AppTypography.labelSmall.copyWith(
                            color: badgeColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: Pemilihan Dompet / Rekening Pengguna
  // ---------------------------------------------------------------------------
  Widget _buildAccountSelectionPage(bool isDark) {
    // Saring akun yang relevan (tampilkan akun bisnis jika bisnis / both dipilih)
    final filteredAccounts = _availableAccounts.where((opt) {
      if (opt.isBusiness && _selectedProfileMode == 'personal') return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'LANGKAH 2 DARI 3',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pilih Dompet & Bank Kamu',
                    style: AppTypography.headlineMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedAccountIds.length} Terpilih',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Pilih akun yang kamu gunakan. Kamu bisa menambah atau mengubahnya nanti.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // List Grid Dompet / Rekening
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: filteredAccounts.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == filteredAccounts.length) {
                // Tombol Tambah Akun Kustom
                return OutlinedButton.icon(
                  onPressed: _openAddCustomAccountDialog,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Tambah Bank / Dompet Lain'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }

              final acc = filteredAccounts[index];
              final isSelected = _selectedAccountIds.contains(acc.id);
              final accColor = Color(int.parse(acc.colorHex));

              return GestureDetector(
                onTap: () => _toggleAccount(acc.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08)
                        : (isDark ? Colors.grey.shade900 : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(acc.icon, color: accColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              acc.name,
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              acc.description,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                            width: 1.8,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 3: Nama Panggilan & Konfirmasi
  // ---------------------------------------------------------------------------
  Widget _buildNameInputPage(bool isDark) {
    final chosenAccountNames = _availableAccounts
        .where((opt) => _selectedAccountIds.contains(opt.id))
        .map((e) => e.name)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'LANGKAH TERAKHIR',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Selamat Datang!',
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Siapa nama panggilanmu? Monetra akan menyapamu setiap hari.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondaryOf(context),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),

          // Input Nama
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Nama Panggilan',
              hintText: 'Contoh: Nala, Budi, Admin Toko',
              prefixIcon: const Icon(Icons.badge_rounded, color: AppColors.primary),
              filled: true,
              fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Ringkasan Setup Kredivo-Style Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Ringkasan Konfigurasi',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mode Finansial',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    Text(
                      _selectedProfileMode == 'personal'
                          ? '👤 Keuangan Pribadi'
                          : (_selectedProfileMode == 'business'
                              ? '💼 Bisnis & Toko'
                              : '🚀 Pribadi & Bisnis'),
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dompet Awal',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        chosenAccountNames.join(', '),
                        textAlign: TextAlign.end,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '100% Offline-First. Seluruh data keuangan tersimpan aman di HP kamu.',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Kredivo-Style Fixed Bottom Action Bar
  // ---------------------------------------------------------------------------
  Widget _buildBottomActionBar(bool isDark) {
    final inputName = _nameController.text.trim();
    final buttonLabel = _currentPage < 2
        ? 'Lanjut'
        : (inputName.isNotEmpty
            ? 'Mulai sebagai $inputName 🚀'
            : 'Mulai Pakai Monetra 🚀');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      buttonLabel,
                      style: AppTypography.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (_currentPage < 2) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
