import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/core/router/app_router.dart';
import 'package:monetra/core/theme/app_theme.dart';
import 'package:monetra/features/home/widgets/floating_bottom_bar.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
      'System Back on Goals/Reports/History ShellRoute tab returns to Home instead of exiting',
      (tester) async {
    final testRouter = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            final path = state.uri.path;
            int selectedIndex = 0;
            if (path == AppRouter.history) {
              selectedIndex = 1;
            } else if (path == AppRouter.reports) {
              selectedIndex = 2;
            } else if (path == AppRouter.goals) {
              selectedIndex = 3;
            }
            return PopScope(
              canPop: selectedIndex == 0,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                if (selectedIndex != 0) {
                  context.go(AppRouter.home);
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
              path: AppRouter.home,
              builder: (_, _) => const Scaffold(body: Center(child: Text('HOME_TAB'))),
            ),
            GoRoute(
              path: AppRouter.history,
              builder: (_, _) => const Scaffold(body: Center(child: Text('HISTORY_TAB'))),
            ),
            GoRoute(
              path: AppRouter.reports,
              builder: (_, _) => const Scaffold(body: Center(child: Text('REPORTS_TAB'))),
            ),
            GoRoute(
              path: AppRouter.goals,
              builder: (_, _) => const Scaffold(body: Center(child: Text('GOALS_TAB'))),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: testRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('HOME_TAB'), findsOneWidget);

    // Pindah ke tab Goals via context.go
    testRouter.go(AppRouter.goals);
    await tester.pumpAndSettle();
    expect(find.text('GOALS_TAB'), findsOneWidget);

    // Simulasi gestur/tombol Back Android -> harus kembali ke HOME_TAB, bukan keluar
    final handledOnGoals = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handledOnGoals, isTrue);
    expect(find.text('HOME_TAB'), findsOneWidget);
  });
}
