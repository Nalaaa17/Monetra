import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/accounts/screens/manage_accounts_screen.dart';
import '../../features/accounts/screens/manage_categories_screen.dart';
import '../../features/budget/screens/budget_screen.dart';
import '../../features/debts/screens/debt_screen.dart';
import '../../features/goals/screens/goals_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/home/screens/all_features_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/investasi/screens/investasi_screen.dart';
import '../../features/recurring/screens/recurring_transactions_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/backup_screen.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../features/tools/screens/money_calculator_screen.dart';
import '../../features/transaction/providers/transaction_form_provider.dart';
import '../../features/transaction/screens/add_transaction_screen.dart';
import '../../features/transaction/screens/transfer_screen.dart';

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

class AppRouter {
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

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const SplashScreen(), state),
      ),
      GoRoute(
        path: home,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const HomeScreen(), state),
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
        path: history,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const HistoryScreen(), state),
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
        path: reports,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const ReportsScreen(), state),
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
        path: goals,
        pageBuilder: (context, state) =>
            _buildTransitionPage(const GoalsScreen(), state),
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
    ],
  );
}
