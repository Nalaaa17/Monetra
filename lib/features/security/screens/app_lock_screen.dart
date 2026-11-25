import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/bank_logo_helper.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../data/services/biometric_service.dart';
import '../../home/providers/home_providers.dart';
import '../../profile/providers/profile_provider.dart';
import '../../profile/widgets/profile_switcher_sheet.dart';
import '../providers/security_providers.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  final Future<void> Function(String route)? onQuickAction;

  const AppLockScreen({super.key, this.onQuickAction});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  bool _isChecking = false;
  bool _isBalancePeekOpen = false;
  bool _isBalanceMasked = false;
  double _dragDelta = 0.0;

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
    HapticFeedback.selectionClick();
    if (_isBalancePeekOpen) {
      setState(() => _isBalancePeekOpen = false);
    }
    if (widget.onQuickAction != null) {
      widget.onQuickAction!(route);
    } else {
      ref.read(isQuickAccessActiveProvider.notifier).state = true;
      AppRouter.router.push(route);
    }
  }

  void _setBalancePeekOpen(bool open) {
    if (_isBalancePeekOpen == open) return;
    HapticFeedback.lightImpact();
    setState(() => _isBalancePeekOpen = open);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _dragDelta += details.delta.dy;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    if (!_isBalancePeekOpen && (_dragDelta > 28 || velocity > 200)) {
      _setBalancePeekOpen(true);
    } else if (_isBalancePeekOpen && (_dragDelta < -28 || velocity < -200)) {
      _setBalancePeekOpen(false);
    }
    _dragDelta = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBiometricEnabled = ref.watch(biometricLockEnabledProvider);
    final activeProfile = ref.watch(activeProfileProvider).valueOrNull;
    final profileLabels = ref.watch(profileLabelsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_isBalancePeekOpen) {
            setState(() => _isBalancePeekOpen = false);
          }
        },
        child: Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Full-Bleed Background Illustration (Edge-to-Edge)
                Image.asset(
                  'assets/images/livin_doodle.jpg',
                  fit: BoxFit.cover,
                ),

                // 2. Top & Bottom Gradient Overlay untuk keterbacaan teks putih
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.24, 0.56, 0.80, 1.0],
                      colors: [
                        const Color(0xFF0A192F).withValues(alpha: 0.55),
                        const Color(0xFF0A192F).withValues(alpha: 0.12),
                        Colors.transparent,
                        const Color(0xFF0A192F).withValues(alpha: 0.68),
                        const Color(0xFF0A192F).withValues(alpha: 0.94),
                      ],
                    ),
                  ),
                ),

                // 3. Foreground Content
                SafeArea(
                  child: Column(
                    children: [
                      // Top Area: Geser untuk Intip Saldo + Panel Saldo
                      _buildPullDownBalanceArea(
                        context,
                        isDark,
                        activeProfileName: activeProfile?.name ?? 'Pribadi',
                        activeProfileColorHex:
                            activeProfile?.colorHex ?? '0xFF10B981',
                        profileIcon: profileLabels.iconData,
                      ),

                      // Brand Monetra di bagian atas (gaya logo Livin')
                      if (!_isBalancePeekOpen) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 28,
                                height: 28,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 9),
                            const Text(
                              'Monetra',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black38,
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Area Tengah Terbuka Penuh untuk Ilustrasi
                      const Spacer(),

                      // Dock Menu Catat Cepat (Lingkaran putih mengambang seperti Livin')
                      _buildFloatingQuickActions(),
                      const SizedBox(height: 22),

                      // Tombol Utama Masuk / Sidik Jari
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isChecking ? null : _handleLoginTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              elevation: 4,
                              shadowColor: Colors.black45,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
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
                              isBiometricEnabled ? 'Login' : 'Masuk',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPullDownBalanceArea(
    BuildContext context,
    bool isDark, {
    required String activeProfileName,
    required String activeProfileColorHex,
    required IconData profileIcon,
  }) {
    final summaryAsync = ref.watch(balanceSummaryProvider);
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final recentTxAsync = ref.watch(recentTransactionsProvider);
    final profileColor = ColorHelper.fromHex(activeProfileColorHex);

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: _isBalancePeekOpen
            ? Container(
                key: const ValueKey('balance_peek_open'),
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.58,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
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
                            Flexible(
                              child: Text(
                                'Saldo Tersisa',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => ProfileSwitcherSheet.show(context),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: profileColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: profileColor.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      profileIcon,
                                      size: 12,
                                      color: profileColor,
                                    ),
                                    const SizedBox(width: 4),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 72),
                                      child: Text(
                                        activeProfileName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: profileColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(
                                  () => _isBalanceMasked = !_isBalanceMasked);
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 22,
                              color: AppColors.textSecondaryOf(context),
                            ),
                            onPressed: () => _setBalancePeekOpen(false),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  summaryAsync.when(
                    data: (summary) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _isBalanceMasked
                                ? 'Rp ••••••••'
                                : CurrencyFormatter.format(
                                    summary.totalNetWorth),
                            style: AppTypography.headlineMedium.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryOf(context),
                            ),
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
                  accountsAsync.when(
                    data: (accounts) {
                      if (accounts.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'Belum ada rekening di profil ini',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11.5,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        );
                      }
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
                              final accColor =
                                  ColorHelper.parseHex(acc.colorHex);
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
                  // 2 Transaksi Terakhir
                  recentTxAsync.when(
                    data: (txs) {
                      final latest = txs.take(2).toList();
                      if (latest.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transaksi Terakhir',
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...latest.map((tx) {
                              final isIncome = tx.isIncome;
                              final sign = isIncome ? '+' : '-';
                              final amountColor = isIncome
                                  ? const Color(0xFF10B981)
                                  : AppColors.danger;
                              final catColor = tx.categoryColorHex != null
                                  ? ColorHelper.parseHex(tx.categoryColorHex!)
                                  : amountColor;
                              final catIcon = tx.categoryIconCodePoint != null
                                  ? IconHelper.getIcon(
                                      tx.categoryIconCodePoint!)
                                  : (isIncome
                                      ? Icons.savings_outlined
                                      : Icons.shopping_bag_outlined);
                              final title = tx.note?.isNotEmpty == true
                                  ? tx.note!
                                  : (tx.categoryName ??
                                      (isIncome ? 'Pemasukan' : 'Pengeluaran'));

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: catColor.withValues(
                                            alpha: isDark ? 0.18 : 0.12),
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Icon(catIcon,
                                          size: 15, color: catColor),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '${tx.accountName} • ${DateFormatter.formatShort(tx.date)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondaryOf(
                                                  context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isBalanceMasked
                                          ? '••••'
                                          : '$sign${CurrencyFormatter.format(tx.amount)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: amountColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: InkWell(
                      onTap: () => _setBalancePeekOpen(false),
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
              ),
            )
          : Padding(
              key: const ValueKey('balance_peek_closed'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Tengah: Geser untuk Intip Saldo (gaya Livin')
                  InkWell(
                    onTap: () => _setBalancePeekOpen(true),
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Geser untuk Intip Saldo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 6),
                              ],
                            ),
                          ),
                          SizedBox(height: 1),
                          Icon(
                            Icons.keyboard_double_arrow_down_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Kanan: Pil Profil Aktif
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () => ProfileSwitcherSheet.show(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.32),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              profileIcon,
                              size: 13,
                              color: ColorHelper.fromHex(activeProfileColorHex),
                            ),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 68),
                              child: Text(
                                activeProfileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
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

  Widget _buildFloatingQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _buildQuickActionCircle(
            label: 'Keluar',
            icon: Icons.arrow_upward_rounded,
            color: const Color(0xFFEF4444),
            onTap: () =>
                _openQuickAction('${AppRouter.addTransaction}?type=expense'),
          ),
          _buildQuickActionCircle(
            label: 'Masuk',
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF10B981),
            onTap: () =>
                _openQuickAction('${AppRouter.addTransaction}?type=income'),
          ),
          _buildQuickActionCircle(
            label: 'Transfer',
            icon: Icons.swap_horiz_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () => _openQuickAction(AppRouter.transfer),
          ),
          _buildQuickActionCircle(
            label: 'Utang',
            icon: Icons.handshake_outlined,
            color: const Color(0xFFF59E0B),
            onTap: () => _openQuickAction(AppRouter.utang),
          ),
          _buildQuickActionCircle(
            label: 'Hitung',
            icon: Icons.calculate_outlined,
            color: const Color(0xFF8B5CF6),
            onTap: () => _openQuickAction(AppRouter.calculator),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCircle({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 4),
                    ],
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
