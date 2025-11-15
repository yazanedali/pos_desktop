// services/sales_invoice_service.dart
import 'package:pos_desktop/database/database_helper.dart';

import '../models/sales_invoice.dart';

class SalesInvoiceService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // الحصول على جميع فواتير المبيعات
  Future<List<SaleInvoice>> getAllSalesInvoices() async {
    final db = await _dbHelper.database;

    try {
      // الحصول على الفواتير الرئيسية
      final invoices = await db.query(
        'sales_invoices',
        orderBy: 'created_at DESC',
      );

      // تحويل النتائج إلى كائنات SaleInvoice
      final List<SaleInvoice> result = [];

      for (final invoiceMap in invoices) {
        final invoice = SaleInvoice.fromMap(invoiceMap);

        // الحصول على عناصر الفاتورة
        final items = await getInvoiceItems(invoice.id);

        result.add(
          SaleInvoice(
            id: invoice.id,
            invoiceNumber: invoice.invoiceNumber,
            date: invoice.date,
            time: invoice.time,
            total: invoice.total,
            cashier: invoice.cashier,
            customerName: invoice.customerName,
            paymentMethod: invoice.paymentMethod,
            createdAt: invoice.createdAt,
            items: items,
          ),
        );
      }

      return result;
    } catch (e) {
      throw Exception('فشل في تحميل فواتير المبيعات: $e');
    }
  }

  // الحصول على عناصر فاتورة محددة
  Future<List<SaleInvoiceItem>> getInvoiceItems(int invoiceId) async {
    final db = await _dbHelper.database;

    try {
      final items = await db.query(
        'sales_invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      return items.map((itemMap) => SaleInvoiceItem.fromMap(itemMap)).toList();
    } catch (e) {
      return [];
    }
  }

  // الحصول على فاتورة بواسطة ID
  Future<SaleInvoice?> getInvoiceById(int id) async {
    final db = await _dbHelper.database;

    try {
      final invoices = await db.query(
        'sales_invoices',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (invoices.isEmpty) return null;

      final invoice = SaleInvoice.fromMap(invoices.first);
      final items = await getInvoiceItems(invoice.id);

      return SaleInvoice(
        id: invoice.id,
        invoiceNumber: invoice.invoiceNumber,
        date: invoice.date,
        time: invoice.time,
        total: invoice.total,
        cashier: invoice.cashier,
        customerName: invoice.customerName,
        paymentMethod: invoice.paymentMethod,
        createdAt: invoice.createdAt,
        items: items,
      );
    } catch (e) {
      return null;
    }
  }

  // البحث في فواتير المبيعات
  Future<List<SaleInvoice>> searchInvoices(String searchTerm) async {
    final db = await _dbHelper.database;

    try {
      final invoices = await db.rawQuery(
        '''
        SELECT * FROM sales_invoices 
        WHERE invoice_number LIKE ? OR cashier LIKE ? OR customer_name LIKE ?
        ORDER BY created_at DESC
      ''',
        ['%$searchTerm%', '%$searchTerm%', '%$searchTerm%'],
      );

      final List<SaleInvoice> result = [];

      for (final invoiceMap in invoices) {
        final invoice = SaleInvoice.fromMap(invoiceMap);
        final items = await getInvoiceItems(invoice.id);

        result.add(
          SaleInvoice(
            id: invoice.id,
            invoiceNumber: invoice.invoiceNumber,
            date: invoice.date,
            time: invoice.time,
            total: invoice.total,
            cashier: invoice.cashier,
            customerName: invoice.customerName,
            paymentMethod: invoice.paymentMethod,
            createdAt: invoice.createdAt,
            items: items,
          ),
        );
      }

      return result;
    } catch (e) {
      throw Exception('فشل في البحث: $e');
    }
  }

  // الحصول على إحصائيات المبيعات
  Future<Map<String, dynamic>> getSalesStatistics() async {
    final db = await _dbHelper.database;

    try {
      // إجمالي عدد الفواتير
      final totalInvoicesResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sales_invoices',
      );
      final totalInvoices = totalInvoicesResult.first['count'] as int? ?? 0;

      // إجمالي المبيعات
      final totalSalesResult = await db.rawQuery(
        'SELECT SUM(total) as sum FROM sales_invoices',
      );
      final totalSales =
          (totalSalesResult.first['sum'] as num?)?.toDouble() ?? 0.0;

      // متوسط قيمة الفاتورة
      final averageInvoice =
          totalInvoices > 0 ? totalSales / totalInvoices : 0.0;

      // المبيعات اليوم
      final today = DateTime.now();
      final todayFormatted =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final todaySalesResult = await db.rawQuery(
        'SELECT SUM(total) as sum FROM sales_invoices WHERE date = ?',
        [todayFormatted],
      );
      final todaySales =
          (todaySalesResult.first['sum'] as num?)?.toDouble() ?? 0.0;

      return {
        'totalInvoices': totalInvoices,
        'totalSales': totalSales,
        'averageInvoice': averageInvoice,
        'todaySales': todaySales,
      };
    } catch (e) {
      return {
        'totalInvoices': 0,
        'totalSales': 0.0,
        'averageInvoice': 0.0,
        'todaySales': 0.0,
      };
    }
  }

  // حذف فاتورة
  Future<bool> deleteInvoice(int id) async {
    final db = await _dbHelper.database;

    try {
      final result = await db.delete(
        'sales_invoices',
        where: 'id = ?',
        whereArgs: [id],
      );

      return result > 0;
    } catch (e) {
      throw Exception('فشل في حذف الفاتورة: $e');
    }
  }

  // البيانات الوهمية (للطوارئ فقط)
  static List<SaleInvoice> getMockSalesInvoices() {
    return [
      SaleInvoice(
        id: 1,
        invoiceNumber: "INV-20241202-1234",
        date: "2024-12-02",
        time: "14:30",
        total: 6.5,
        cashier: "البائع الرئيسي",
        items: [
          SaleInvoiceItem(
            id: 1,
            invoiceId: 1,
            productId: 1,
            productName: "كوكا كولا",
            price: 2.5,
            quantity: 2,
            total: 5.0,
          ),
          SaleInvoiceItem(
            id: 2,
            invoiceId: 1,
            productId: 2,
            productName: "شيبس",
            price: 1.5,
            quantity: 1,
            total: 1.5,
          ),
        ],
      ),
    ];
  }
}
