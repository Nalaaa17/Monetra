import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_router.dart';
import '../../../data/services/biometric_service.dart';
import '../../onboarding/providers/onboarding_providers.dart';
import '../providers/security_providers.dart';
import '../screens/app_lock_screen.dart';

class AppLockWrapper extends ConsumerStatefulWidget {
  final Widget? child;

  const AppLockWrapper({super.key, this.child});

  @override
  ConsumerState<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends ConsumerState<AppLockWrapper>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppRouter.router.routerDelegate.addListener(_onRouteChanged);

    // Tampilkan halaman awal bergaya Livin saat cold launch setelah onboarding selesai
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialLockState();
    });
  }

  void _onRouteChanged() {
    final isQuickAccess = ref.read(isQuickAccessActiveProvider);
    if (!isQuickAccess) return;

    final location =
        AppRouter.router.routerDelegate.currentConfiguration.uri.path;
    if (location == AppRouter.home || location == AppRouter.splash) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(isQuickAccessActiveProvider.notifier).state = false;
        }
      });
    }
  }

  Future<void> _checkInitialLockState() async {
    final isDone = await OnboardingService.isCompleted();
    if (!isDone) return; // Jangan kunci jika masih onboarding

    if (mounted) {
      ref.read(isAppLockedProvider.notifier).state = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // Jika resume terjadi karena dialog biometrik sistem sedang aktif, jangan kunci ulang
      if (BiometricService.isAuthenticating) return;

      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!);
        // Kunci jika aplikasi berada di background lebih dari 1 detik
        if (elapsed > const Duration(seconds: 1)) {
          _handleAppResumed();
        }
      }
      _pausedAt = null;
    }
  }

  Future<void> _handleAppResumed() async {
    final isDone = await OnboardingService.isCompleted();
    if (!isDone) return;

    final isBiometricEnabled = await BiometricService.isBiometricLockEnabled();
    final isLockOnResume = await BiometricService.isLockOnResumeEnabled();

    if (isBiometricEnabled && isLockOnResume && mounted) {
      ref.read(isQuickAccessActiveProvider.notifier).state = false;
      ref.read(isAppLockedProvider.notifier).state = true;
    }
  }

  @override
  void dispose() {
    AppRouter.router.routerDelegate.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = ref.watch(isAppLockedProvider);
    final isQuickAccessActive = ref.watch(isQuickAccessActiveProvider);

    return Stack(
      children: [
        widget.child ?? const SizedBox.shrink(),
        if (isLocked && !isQuickAccessActive) const AppLockScreen(),
      ],
    );
  }
}
