import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/core/theme/app_theme.dart';
import 'package:monetra/shared/widgets/app_shimmer.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('All shimmer skeletons render cleanly in light mode at 320px',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: const [
                HeroCardSkeleton(),
                SizedBox(height: 12),
                HorizontalAccountsSkeleton(),
                SizedBox(height: 12),
                TransactionListSkeleton(count: 2),
                SizedBox(height: 12),
                SpendingProgressCardSkeleton(),
                SizedBox(height: 12),
                BudgetCategoriesSkeleton(),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 650));

    expect(find.byType(AppShimmer), findsWidgets);
    expect(find.byType(SkeletonBox), findsWidgets);
  });

  testWidgets('Full-page skeletons render cleanly in dark mode at 320px',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final skeleton in const [
      HistoryListSkeleton(),
      ReportsSkeleton(),
      ManageAccountsSkeleton(),
      GoalsScreenSkeleton(),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: skeleton),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AppShimmer), findsWidgets);
    }
  });
}
