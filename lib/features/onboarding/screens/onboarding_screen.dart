import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../providers/onboarding_providers.dart';

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

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      icon: Icons.account_balance_wallet_rounded,
      accentColor: Color(0xFF00D09E),
      title: 'Kelola Banyak Dompet & Rekening',
      description:
          'Pisahkan Uang Harian dan Tabungan dengan mudah. Pantau saldo bank, e-wallet, hingga uang tunai dalam satu aplikasi yang rapi.',
      badges: [
        'Multi Bank & E-Wallet',
        'Pisah Uang Harian',
        'Saldo Real-Time',
      ],
    ),
    _OnboardingItem(
      icon: Icons.bolt_rounded,
      accentColor: Color(0xFFF59E0B),
      title: 'Catat Cepat & Riwayat Rapi',
      description:
          'Catat pengeluaran, pemasukan, atau transfer dalam hitungan detik. Temukan transaksi kapan pun dengan filter modern yang ringkas.',
      badges: [
        'Catat Super Cepat',
        'Filter Rapi & Praktis',
        'Swipe Hapus & Undo',
      ],
    ),
    _OnboardingItem(
      icon: Icons.track_changes_rounded,
      accentColor: Color(0xFF0284C7),
      title: 'Wujudkan Target & Kelola Utang',
      description:
          'Kumpulkan uang untuk impian finansialmu dan catat pinjaman serta utang piutang dengan alokasi rekening yang aman dan presisi.',
      badges: [
        'Target Tabungan Aman',
        'Catat Utang & Piutang',
        'Pengingat Jatuh Tempo',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _skipToName() {
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finishOnboarding() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final inputName = _nameController.text.trim();
    final chosenName = inputName.isNotEmpty ? inputName : 'Sahabat Monetra';

    await ref.read(userNameProvider.notifier).setUserName(chosenName);
    await OnboardingService.markCompleted(userName: chosenName);

    if (mounted) {
      try {
        context.go(AppRouter.home);
      } catch (_) {
        // Fallback jika ditest tanpa GoRouter
      }
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
            // Top Bar: Monetra Branding + Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Monetra',
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  if (_currentPage < 3)
                    TextButton(
                      onPressed: _skipToName,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondaryOf(context),
                      ),
                      child: const Text('Lewati'),
                    )
                  else
                    const SizedBox(height: 48),
                ],
              ),
            ),

            // Main Carousel
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  ..._items.map((item) => _buildFeatureSlide(context, item)),
                  _buildNameInputSlide(context, isDark),
                ],
              ),
            ),

            // Bottom Navigation & Indicators
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: _currentPage < 3
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Tombol Sebelumnya (atau spacer)
                        if (_currentPage > 0)
                          IconButton(
                            onPressed: _previousPage,
                            icon: const Icon(Icons.arrow_back_rounded),
                            tooltip: 'Sebelumnya',
                          )
                        else
                          const SizedBox(width: 48),

                        // Dots Indicator
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            4,
                            (index) => _buildDot(index, _currentPage == index),
                          ),
                        ),

                        // Tombol Lanjut
                        ElevatedButton.icon(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          icon: const Text(
                            'Lanjut',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          label: const Icon(Icons.arrow_forward_rounded, size: 18),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _finishOnboarding,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.black,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _nameController.text.trim().isNotEmpty
                                        ? 'Mulai sebagai ${_nameController.text.trim()} 🚀'
                                        : 'Mulai Sekarang 🚀',
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 6,
      width: isActive ? 22 : 6,
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary
            : Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildFeatureSlide(BuildContext context, _OnboardingItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Icon Showcase Card
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.accentColor.withValues(alpha: 0.12),
              border: Border.all(
                color: item.accentColor.withValues(alpha: 0.35),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: item.accentColor.withValues(alpha: 0.2),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                item.icon,
                size: 52,
                color: item.accentColor,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: AppTypography.headlineLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 23,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),

          // Description
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 14.5,
              height: 1.5,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 26),

          // Badges / Highlights
          Wrap(
            spacing: 8,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: item.badges.map((badge) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E222A)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: item.accentColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        badge,
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNameInputSlide(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Icon Avatar Wave
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.waving_hand_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Selamat Datang!',
            textAlign: TextAlign.center,
            style: AppTypography.headlineLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),

          Text(
            'Biar makin akrab, siapa nama panggilanmu? Monetra akan menyapamu setiap hari di dashboard.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 28),

          // Name Input Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nama Panggilan',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (val) => setState(() {}),
                  onSubmitted: (_) => _finishOnboarding(),
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    suffixIcon: _nameController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _nameController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    hintText: 'Misal: Nala, Alex, Budi...',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF262C36)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Nama ini bisa kamu ubah kapan saja melalui dashboard.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingItem {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;
  final List<String> badges;

  const _OnboardingItem({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
    required this.badges,
  });
}
