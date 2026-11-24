import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/bank_logo_helper.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/services/biometric_service.dart';
import '../../home/providers/home_providers.dart';
import '../../profile/providers/profile_provider.dart';
import '../../profile/widgets/profile_switcher_sheet.dart';
import '../providers/security_providers.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _floatAnimation;
  bool _isChecking = false;
  bool _isBalancePeekOpen = false;
  bool _isBalanceMasked = false;
  double _dragDelta = 0.0;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnimation = Tween<Offset>(
      begin: const Offset(0, -0.02),
      end: const Offset(0, 0.02),
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  Future<void> _handleLoginTap() async {
    final isBiometricEnabled = ref.read(biometricLockEnabledProvider);
    if (!isBiometricEnabled) {
      ref.read(isAppLockedProvider.notifier).state = false;
      return;
    }

    if (_isChecking) return;
    setState(() => _isChecking = true);

    final success = await BiometricService.authenticate(
      localizedReason: 'Buka Monetra dengan sidik jari, wajah, atau PIN',
    );

    if (mounted) {
      setState(() => _isChecking = false);
      if (success) {
        ref.read(isAppLockedProvider.notifier).state = false;
      }
    }
  }

  void _openQuickAction(String route) {
    ref.read(isQuickAccessActiveProvider.notifier).state = true;
    AppRouter.router.push(route);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _dragDelta += details.delta.dy;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    if (!_isBalancePeekOpen && (_dragDelta > 28 || velocity > 200)) {
      setState(() => _isBalancePeekOpen = true);
    } else if (_isBalancePeekOpen && (_dragDelta < -28 || velocity < -200)) {
      setState(() => _isBalancePeekOpen = false);
    }
    _dragDelta = 0.0;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBiometricEnabled = ref.watch(biometricLockEnabledProvider);
    final activeProfile = ref.watch(activeProfileProvider).valueOrNull;
    final profileLabels = ref.watch(profileLabelsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isBalancePeekOpen) {
          setState(() => _isBalancePeekOpen = false);
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: SafeArea(
            child: Column(
              children: [
                // 1. Area Tarik dari Atas untuk Intip Saldo + Tombol Ganti Tema
                SizedBox(
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      _buildPullDownBalanceArea(context, isDark),
                      if (!_isBalancePeekOpen)
                        Positioned(
                          top: 4,
                          right: 12,
                          child: IconButton(
                            icon: Icon(
                              isDark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_outlined,
                              size: 20,
                              color: isDark
                                  ? AppColors.primary
                                  : AppColors.textSecondaryOf(context),
                            ),
                            tooltip: isDark ? 'Mode Cerah' : 'Mode Gelap',
                            onPressed: () {
                              ref.read(themeModeProvider.notifier).state =
                                  isDark ? ThemeMode.light : ThemeMode.dark;
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. Konten Tengah: Header + Profil Aktif + Doodle Kartun Unik (Overflow-Safe)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxImgSize = _isBalancePeekOpen
                          ? (constraints.maxHeight * 0.55).clamp(100.0, 150.0)
                          : (constraints.maxHeight * 0.58).clamp(140.0, 250.0);

                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Brand & Active Profile Row
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/images/logo.png',
                                        width: 28,
                                        height: 28,
                                        fit: BoxFit.contain,
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        'Monetra',
                                        style: AppTypography.titleLarge.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Pil Profil Aktif (klik untuk ganti profil sebelum catat cepat)
                                  InkWell(
                                    onTap: () => ProfileSwitcherSheet.show(context),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.08)
                                            : Colors.black.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .dividerColor
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            profileLabels.iconData,
                                            size: 13,
                                            color: ColorHelper.fromHex(
                                              activeProfile?.colorHex ?? '0xFF10B981',
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                                maxWidth: 100),
                                            child: Text(
                                              activeProfile?.name ?? 'Pribadi',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimaryOf(
                                                    context),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(
                                            Icons.arrow_drop_down_rounded,
                                            size: 16,
                                            color: AppColors.textSecondaryOf(
                                                context),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isBiometricEnabled)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Icon(
                                        Icons.lock_outline_rounded,
                                        size: 12,
                                        color: isDark
                                            ? AppColors.primary
                                            : AppColors.primaryDark,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Gambar Doodle / Kartun Unik di Tengah Layar
                              SlideTransition(
                                position: _floatAnimation,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: maxImgSize,
                                    maxHeight: maxImgSize,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(36),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(
                                            alpha: isDark ? 0.28 : 0.2),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                              alpha: isDark ? 0.10 : 0.14),
                                          blurRadius: 26,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(30),
                                      child: ColorFiltered(
                                        colorFilter: isDark
                                            ? const ColorFilter.mode(
                                                Color(0x140F172A),
                                                BlendMode.darken,
                                              )
                                            : const ColorFilter.mode(
                                                Colors.transparent,
                                                BlendMode.dst,
                                              ),
                                        child: Image.asset(
                                          'assets/images/livin_doodle.jpg',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              if (!_isBalancePeekOpen) ...[
                                const SizedBox(height: 14),
                                Text(
                                  'Catat keuangan lebih cepat',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimaryOf(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tarik layar dari atas untuk intip saldo tersisa',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondaryOf(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 3. Dock Menu Catat Cepat (Akses Langsung Tanpa Fingerprint)
                _buildQuickRecordSection(context, isDark),
                const SizedBox(height: 16),

                // 4. Tombol Utama Masuk / Sidik Jari
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isChecking ? null : _handleLoginTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Icon(
                              isBiometricEnabled
                                  ? Icons.fingerprint_rounded
                                  : Icons.login_rounded,
                              size: 22,
                            ),
                      label: Text(
                        isBiometricEnabled
                            ? 'Masuk dengan Sidik Jari'
                            : 'Masuk ke Beranda',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPullDownBalanceArea(BuildContext context, bool isDark) {
    final summaryAsync = ref.watch(balanceSummaryProvider);
    final accountsAsync = ref.watch(accountsWithBalanceProvider);

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _isBalancePeekOpen
          ? Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Kartu Intip Saldo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 16,
                              color: isDark
                                  ? AppColors.primary
                                  : AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Saldo Tersisa',
                            style: AppTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              _isBalanceMasked
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                              color: AppColors.textSecondaryOf(context),
                            ),
                            onPressed: () => setState(
                                () => _isBalanceMasked = !_isBalanceMasked),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 22,
                              color: AppColors.textSecondaryOf(context),
                            ),
                            onPressed: () =>
                                setState(() => _isBalancePeekOpen = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Nominal Saldo Utama
                  summaryAsync.when(
                    data: (summary) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isBalanceMasked
                              ? 'Rp ••••••••'
                              : CurrencyFormatter.format(summary.totalNetWorth),
                          style: AppTypography.headlineMedium.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildBalanceChip(
                              context,
                              'Harian',
                              _isBalanceMasked
                                  ? '••••'
                                  : CurrencyFormatter.format(
                                      summary.dailySpendingBalance),
                              AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            _buildBalanceChip(
                              context,
                              'Tabungan',
                              _isBalanceMasked
                                  ? '••••'
                                  : CurrencyFormatter.format(
                                      summary.savingsBalance),
                              const Color(0xFF3B82F6),
                            ),
                          ],
                        ),
                      ],
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                    error: (_, _) => const Text('Gagal memuat saldo'),
                  ),

                  // Daftar Akun Ringkas
                  accountsAsync.when(
                    data: (accounts) {
                      if (accounts.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: accounts.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final acc = accounts[index];
                              final accColor = ColorHelper.parseHex(acc.colorHex);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceOf(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .dividerColor
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    BankLogoHelper.buildAccountBadge(
                                      context: context,
                                      accountName: acc.name,
                                      accountColor: accColor,
                                      logoKey: acc.logoKey,
                                      size: 22,
                                      borderRadius: 6,
                                    ),
                                    const SizedBox(width: 7),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          acc.name,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          _isBalanceMasked
                                              ? 'Rp ••••'
                                              : CurrencyFormatter.format(
                                                  acc.balance),
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? AppColors.primary
                                                : AppColors.primaryDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 8),
                  Center(
                    child: InkWell(
                      onTap: () => setState(() => _isBalancePeekOpen = false),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : InkWell(
              onTap: () => setState(() => _isBalancePeekOpen = true),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.045),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context)
                        .dividerColor
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isDark ? AppColors.primary : AppColors.primaryDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Intip Saldo',
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceChip(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickRecordSection(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Catat Cepat',
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                Text(
                  'Tanpa Login',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.primary : AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildQuickActionItem(
                  context: context,
                  label: 'Keluar',
                  icon: Icons.arrow_upward_rounded,
                  color: const Color(0xFFEF4444),
                  onTap: () =>
                      _openQuickAction('${AppRouter.addTransaction}?type=expense'),
                ),
                _buildQuickActionItem(
                  context: context,
                  label: 'Masuk',
                  icon: Icons.arrow_downward_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () =>
                      _openQuickAction('${AppRouter.addTransaction}?type=income'),
                ),
                _buildQuickActionItem(
                  context: context,
                  label: 'Transfer',
                  icon: Icons.swap_horiz_rounded,
                  color: const Color(0xFF3B82F6),
                  onTap: () => _openQuickAction(AppRouter.transfer),
                ),
                _buildQuickActionItem(
                  context: context,
                  label: 'Utang',
                  icon: Icons.handshake_outlined,
                  color: const Color(0xFFF59E0B),
                  onTap: () => _openQuickAction(AppRouter.utang),
                ),
                _buildQuickActionItem(
                  context: context,
                  label: 'Hitung',
                  icon: Icons.calculate_outlined,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => _openQuickAction(AppRouter.calculator),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionItem({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
