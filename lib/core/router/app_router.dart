import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/accounts/screens/manage_accounts_screen.dart';
import '../../features/accounts/screens/manage_categories_screen.dart';
import '../../features/budget/screens/budget_screen.dart';
import '../../features/business_tools/screens/promo_calculator_screen.dart';
import '../../features/business_tools/screens/tax_calculator_screen.dart';
import '../../features/debts/screens/debt_screen.dart';
import '../../features/goals/screens/goals_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/hpp/screens/hpp_calculator_screen.dart';
import '../../features/hpp/screens/menu_catalog_screen.dart';
import '../../features/home/screens/all_features_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/widgets/floating_bottom_bar.dart';
import '../../features/investasi/screens/investasi_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/profile/screens/manage_profiles_screen.dart';
import '../../features/recurring/screens/recurring_transactions_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/backup_screen.dart';
import '../../features/settings/screens/security_settings_screen.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../features/tools/screens/money_calculator_screen.dart';
import '../../features/transaction/providers/transaction_form_provider.dart';
import '../../features/transaction/screens/add_transaction_screen.dart';
import '../../features/transaction/screens/transfer_screen.dart';
import '../../features/vacation/screens/vacation_detail_screen.dart';
import '../../features/vacation/screens/vacations_screen.dart';

CustomTransitionPage<void> _buildTransitionPage(
    Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0.0),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: FadeTransition(
          opacity: curvedAnimation,
          child: child,
        ),
      );
    },
  );
}

int _lastTabIndex = 0;

CustomTransitionPage<void> _buildTabTransitionPage(
    Widget child, GoRouterState state, int tabIndex) {
  final direction = tabIndex >= _lastTabIndex ? 1.0 : -1.0;
  _lastTabIndex = tabIndex;

  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0.05 * direction, 0.0),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: FadeTransition(
          opacity: curvedAnimation,
          child: child,
        ),
      );
    },
  );
}

class AppRouter {
  static Route<T> buildSmoothRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0.0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  static const String splash = '/splash';
  static const String home = '/';
  static const String addTransaction = '/add';
  static const String history = '/history';
  static const String transfer = '/transfer';
  static const String goals = '/goals';
  static const String reports = '/reports';
  static const String backup = '/backup';
  static const String calculator = '/calculator';
  static const String recurring = '/recurring';
  static const String manageAccounts = '/settings/accounts';
  static const String manageCategories = '/settings/categories';
  static const String allFeatures = '/all-features';
  static const String budget = '/budget';
  static const String investasi = '/investasi';
  static const String utang = '/utang';
  static const String onboarding = '/onboarding';
  static const String profiles = '/profiles';
  static const String hppCalculator = '/hpp';
  static const String menuCatalog = '/catalog';
  static const String promoCalculator = '/promo-calculator';
  static const String taxCalculator = '/tax-calculator';
  static const String securitySettings = '/settings/security';
  static const String vacations = '/vacations';
  static const String vacationDetail = '/vacations/detail';

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const SplashScreen(), state),
      ),
      GoRoute(
        path: onboarding,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const OnboardingScreen(), state),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          final path = state.uri.path;
          int selectedIndex = 0;
          if (path == history) {
            selectedIndex = 1;
          } else if (path == reports) {
            selectedIndex = 2;
          } else if (path == goals) {
            selectedIndex = 3;
          }
          return PopScope(
            canPop: selectedIndex == 0,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (selectedIndex != 0) {
                context.go(home);
              }
            },
            child: Scaffold(
              extendBody: true,
              body: child,
              bottomNavigationBar:
                  FloatingBottomBar(selectedIndex: selectedIndex),
            ),
          );
        },
        routes: [
          GoRoute(
            path: home,
            pageBuilder: (context, state) =>
                _buildTabTransitionPage(const HomeScreen(), state, 0),
          ),
          GoRoute(
            path: history,
            pageBuilder: (context, state) =>
                _buildTabTransitionPage(const HistoryScreen(), state, 1),
          ),
          GoRoute(
            path: reports,
            pageBuilder: (context, state) =>
                _buildTabTransitionPage(const ReportsScreen(), state, 2),
          ),
          GoRoute(
            path: goals,
            pageBuilder: (context, state) =>
                _buildTabTransitionPage(const GoalsScreen(), state, 3),
          ),
        ],
      ),
      GoRoute(
        path: addTransaction,
        pageBuilder: (context, state) {
          String? type = state.uri.queryParameters['type'];
          if (type == null && state.extra != null) {
            if (state.extra is Map) {
              type = (state.extra as Map)['type']?.toString();
            } else if (state.extra is String) {
              type = state.extra as String;
            }
          }
          final resolvedType = (type == 'income') ? 'income' : 'expense';
          return _buildTransitionPage(
            ProviderScope(
              overrides: [
                initialTransactionTypeProvider
                    .overrideWith((ref) => resolvedType),
              ],
              child: AddTransactionScreen(initialType: resolvedType),
            ),
            state,
          );
        },
      ),
      GoRoute(
        path: transfer,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const TransferScreen(), state),
      ),
      GoRoute(
        path: backup,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const BackupScreen(), state),
      ),
      GoRoute(
        path: calculator,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const MoneyCalculatorScreen(), state),
      ),
      GoRoute(
        path: recurring,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const RecurringTransactionsScreen(), state),
      ),
      GoRoute(
        path: manageAccounts,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const ManageAccountsScreen(), state),
      ),
      GoRoute(
        path: manageCategories,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const ManageCategoriesScreen(), state),
      ),
      GoRoute(
        path: allFeatures,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const AllFeaturesScreen(), state),
      ),
      GoRoute(
        path: budget,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const BudgetScreen(), state),
      ),
      GoRoute(
        path: investasi,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const InvestasiScreen(), state),
      ),
      GoRoute(
        path: utang,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const DebtScreen(), state),
      ),
      GoRoute(
        path: profiles,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const ManageProfilesScreen(), state),
      ),
      GoRoute(
        path: hppCalculator,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const HppCalculatorScreen(), state),
      ),
      GoRoute(
        path: menuCatalog,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const MenuCatalogScreen(), state),
      ),
      GoRoute(
        path: promoCalculator,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const PromoCalculatorScreen(), state),
      ),
      GoRoute(
        path: taxCalculator,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const TaxCalculatorScreen(), state),
      ),
      GoRoute(
        path: securitySettings,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const SecuritySettingsScreen(), state),
      ),
      GoRoute(
        path: vacations,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const VacationsScreen(), state),
      ),
      GoRoute(
        path: vacationDetail,
        pageBuilder: (context, state) {
          final idStr = state.uri.queryParameters['id'] ?? '0';
          final id = int.tryParse(idStr) ?? 0;
          return _buildTransitionPage(VacationDetailScreen(vacationId: id), state);
        },
      ),
    ],
  );
}
