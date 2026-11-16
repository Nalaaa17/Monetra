import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/models/transaction.dart';
import 'package:monetra/data/models/vacation.dart';
import 'package:monetra/data/services/vacation_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('VacationPdfService produces valid PDF bytes with financial data', () async {
    final now = DateTime.now();

    final vacation = VacationModel(
      id: 1,
      name: 'Liburan Bali 🌴',
      destination: 'Denpasar & Ubud',
      targetBudget: 5000000,
      createdAt: now.subtract(const Duration(days: 3)),
      startDate: now.subtract(const Duration(days: 3)),
      endDate: now.add(const Duration(days: 2)),
    );

    final mockAccount = Account(
      id: 1,
      name: 'BCA Utama',
      type: 'bank',
      category: 'harian',
      colorHex: '0xFF005E9E',
      iconCodePoint: 0xe5e1,
      initialBalance: 10000000,
      createdAt: now,
    );

    final detail = VacationDetail(
      vacation: vacation,
      accounts: [
        VacationAccountBreakdown(
          account: mockAccount,
          allocatedAmount: 5000000,
          spentAmount: 2000000,
        ),
      ],
      transactions: [
        TransactionModel(
          id: 1,
          accountId: 1,
          categoryId: 1,
          vacationId: 1,
          amount: 1200000,
          type: 'expense',
          date: now.subtract(const Duration(days: 2)),
          note: 'Tiket Pesawat & Bagasi',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        TransactionModel(
          id: 2,
          accountId: 1,
          categoryId: 2,
          vacationId: 1,
          amount: 800000,
          type: 'expense',
          date: now.subtract(const Duration(days: 1)),
          note: 'Kuliner Seafood Jimbaran',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ],
    );

    expect(detail.totalBudget, 5000000);
    expect(detail.totalSpent, 2000000);
    expect(detail.remainingBudget, 3000000);

    // Generate PDF bytes
    final bytes = await VacationPdfService.generatePdfBytes(detail);
    expect(bytes, isNotNull);
    expect(bytes.length, greaterThan(100)); // Non-empty PDF payload
  });
}
