import 'package:pos_desktop/database/database_helper.dart';
import 'package:pos_desktop/models/daily_closing.dart';

class ClosingService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Calculate the summary for the current shift (since last closing or start of day)
  Future<DailyClosing> calculateShiftTotals() async {
    final db = await _dbHelper.database;

    // 1. Get Last Closing to determine start time
    final lastClosingData = await db.query(
      'daily_closings',
      orderBy: 'created_at DESC',
      limit: 1,
    );

    DateTime startTime;

    if (lastClosingData.isNotEmpty) {
      final lastClosing = DailyClosing.fromMap(lastClosingData.first);
      startTime = DateTime.parse(lastClosing.createdAt);
    } else {
      // Fallback: Start of today
      final now = DateTime.now();
      startTime = DateTime(now.year, now.month, now.day);
    }

    final String startDateStr = startTime.toIso8601String();

    // 2. Sum Cash Sales (Sales Invoices where payment_type = 'نقدي' or methods handled as cash)
    // Note: payment_method might be 'نقدي' or 'بطاقة'. We usually resolve 'Daily Box' for Cash only.
    // Assuming 'الصندوق اليومي' tracks CASH only.
    // We can query `cash_movements` for exact box impact, which is more reliable than summing invoices directly if we have mixed payments.
    // However, the requirement asks to breakdown "Sales", "Expenses".

    // Method A: Sum `sales_invoices` for sales details
    // We need to verify if `is_return` is 0.
    final salesResult = await db.rawQuery(
      '''
      SELECT SUM(paid_amount) as total 
      FROM sales_invoices 
      WHERE created_at > ? 
      AND is_return = 0 
      AND (payment_method = 'نقدي' OR paid_amount > 0) -- Assuming paid_amount refers to Cash paid
    ''',
      [startDateStr],
    );
    double totalSalesCash =
        (salesResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // 3. Sum Cash Returns
    final returnsResult = await db.rawQuery(
      '''
      SELECT SUM(ABS(paid_amount)) as total 
      FROM sales_invoices 
      WHERE created_at > ? 
      AND is_return = 1 
      AND paid_amount != 0 -- Returns involving cash
    ''',
      [startDateStr],
    );
    double totalReturnsCash =
        (returnsResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // Net Sales Cash (Sales - Returns)
    // Actually, usually we report them separately or net.
    // Let's assume totalSalesCash should be "Net" or we list "Sales" and "Returns" implicitly reduced.
    // The previous logic was: Sales (positive) + Returns (negative paid_amount).
    // Let's use `cash_movements` to get the *Actual* flow into the box.

    // Better Approach: Query `cash_movements` linked to the 'الصندوق اليومي'
    // We assume Box ID 1 or find by name 'الصندوق اليومي'.
    final boxResult = await db.query(
      'cash_boxes',
      where: "name = ?",
      whereArgs: ['الصندوق اليومي'],
    );
    int boxId = 1; // Default
    double currentBoxBalance = 0.0;
    if (boxResult.isNotEmpty) {
      boxId = boxResult.first['id'] as int;
      currentBoxBalance = boxResult.first['balance'] as double;
    }

    // Expenses (OUT direction, type != 'تعديل فاتورة / قبض' usually)
    // We look for movements in this box since startTime
    final expensesResult = await db.rawQuery(
      '''
      SELECT SUM(amount) as total
      FROM cash_movements
      WHERE box_id = ? 
      AND created_at > ?
      AND direction = 'خارج'
    ''',
      [boxId, startDateStr],
    );
    double totalExpenses =
        (expensesResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // Collections/Other Income (IN direction, NOT from normal Sales if possible to distinguish?)
    // If our `Sales` logic above sums up Invoices, we should match it with movements.
    // Usually, "Sales" movement type is logged.
    // Let's rely on Invoices for "Sales" figure, and Movements for "Expenses".

    // But `currentBoxBalance` is the definitive "Expected Cash".
    // So:
    // Expected = currentBoxBalance
    // Opening (calculated) = Expected - (Sales(Net) - Expenses + OtherIn)
    // Where Sales(Net) = totalSalesCash - totalReturnsCash.

    // We need to be careful: "totalSalesCash" above includes only *Invoices*.
    // Does it include *Debt Collections*? Likely not, if Debt Collection is a separate movement.
    // Let's sum "Debt Collections" separately if possible.
    // Assuming `type` in `cash_movements` helps.

    // Let's refine:
    // Sales Cash = Invoices (Cash)
    // Returns Cash = Return Invoices (Cash)
    // Expenses = Manual Withdrawals (Cash Movements 'خارج')
    // Debt Collected = Cash Movements 'داخل' AND type = 'تسديد ذمم' (example)

    // For simplicity validation:
    // Expected Cash IS the box balance.
    // We will display Sales, Expenses as info.

    final double netSales = totalSalesCash - totalReturnsCash;

    // Check for other cash added manually (Opening balance addition? Or Debt collection?)
    // For now, let's treat "Debt Collected" as part of Sales or separate?
    // Let's just create the object.

    // Calculate theoretical opening to display
    // Current - NetFlow = Opening
    // NetFlow = (Total IN) - (Total OUT) in movements
    final movementsResult = await db.rawQuery(
      '''
      SELECT 
        SUM(CASE WHEN direction = 'داخل' THEN amount ELSE 0 END) as total_in,
        SUM(CASE WHEN direction = 'خارج' THEN amount ELSE 0 END) as total_out
      FROM cash_movements
      WHERE box_id = ? AND created_at > ?
    ''',
      [boxId, startDateStr],
    );

    double totalIn =
        (movementsResult.first['total_in'] as num?)?.toDouble() ?? 0.0;
    double totalOut =
        (movementsResult.first['total_out'] as num?)?.toDouble() ?? 0.0;

    double netFlow = totalIn - totalOut;
    double calculatedOpening = currentBoxBalance - netFlow;

    // Use the last closing actual cash as opening if available and consistent?
    // If we closed yesterday with 100, and opened today, box should have 100.
    // If `calculatedOpening` differs from `lastClosingActualCash`, it means money moved without tracking?
    // Or `currentBoxBalance` is correct.

    // Let's trust `calculatedOpening` derived from `currentBoxBalance` - `transactions`.

    return DailyClosing(
      closingDate: DateTime.now().toString().split(' ')[0],
      closingTime:
          '${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}',
      openingCash: calculatedOpening,
      totalSalesCash: netSales, // Display Net Sales
      totalExpenses: totalExpenses, // Display Expenses
      expectedCash: currentBoxBalance,
      actualCash: 0.0, // To be filled by user
      difference: 0.0,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  Future<void> saveClosing(DailyClosing closing) async {
    final db = await _dbHelper.database;
    await db.insert('daily_closings', closing.toMap());

    // Optional: We could "reset" the box balance here if "Closing" implies emptying the drawer.
    // But usually for Shift Closing we just record.
    // If the user physically takes money out, they should record a "Withdrawal" movement separate from Closing,
    // OR we ask here "Transfer to Safe?".
    // For now, simple recording.
  }

  Future<List<DailyClosing>> getClosingsHistory({int limit = 20}) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'daily_closings',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return results.map((map) => DailyClosing.fromMap(map)).toList();
  }

  Future<void> deleteClosing(int id) async {
    final db = await _dbHelper.database;
    await db.delete('daily_closings', where: 'id = ?', whereArgs: [id]);
  }
}
