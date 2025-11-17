// database/sales_invoice_queries.dart
import 'package:pos_desktop/database/database_helper.dart';

class SalesInvoiceQueries {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getInvoicesForCustomer(
    int customerId,
  ) async {
    final db = await _dbHelper.database;
    return await db.query(
      'sales_invoices',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC, time DESC',
    );
  }
}
