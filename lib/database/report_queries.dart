import '../database/database_helper.dart';
import '../models/report_models.dart';

class ReportQueries {
  // دالة لجلب تقرير المبيعات مجمّع حسب اليوم
  Future<List<SalesReportData>> getSalesReport(String from, String to) async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT 
        date, 
        COUNT(id) as invoices, 
        SUM(total) as total 
      FROM sales_invoices 
      WHERE date BETWEEN ? AND ? 
      GROUP BY date 
      ORDER BY date
    ''',
      [from, to],
    );

    return List.generate(maps.length, (i) {
      return SalesReportData(
        date: maps[i]['date'],
        invoices: maps[i]['invoices'],
        total: maps[i]['total'] ?? 0.0,
      );
    });
  }

  // دالة لجلب تقرير المشتريات مجمّع حسب اليوم
  Future<List<PurchaseReportData>> getPurchaseReport(
    String from,
    String to,
  ) async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT 
        pi.date, 
        COUNT(DISTINCT pi.id) as invoices, 
        SUM(pii.quantity) as items, 
        SUM(pi.total) as total 
      FROM purchase_invoices pi
      JOIN purchase_invoice_items pii ON pi.id = pii.invoice_id
      WHERE pi.date BETWEEN ? AND ? 
      GROUP BY pi.date 
      ORDER BY pi.date
    ''',
      [from, to],
    );

    return List.generate(maps.length, (i) {
      return PurchaseReportData(
        date: maps[i]['date'],
        invoices: maps[i]['invoices'],
        items: maps[i]['items'] ?? 0,
        total: maps[i]['total'] ?? 0.0,
      );
    });
  }

  // دالة لجلب تقرير الأرباح (الأكثر تعقيدًا)
  Future<List<ProfitReportData>> getProfitReport(String from, String to) async {
    final sales = await getSalesReport(from, to);
    final purchases = await getPurchaseReport(from, to);

    // استخدام Map لتسهيل دمج البيانات حسب التاريخ
    final Map<String, double> salesByDate = {
      for (var s in sales) s.date: s.total,
    };
    final Map<String, double> purchasesByDate = {
      for (var p in purchases) p.date: p.total,
    };

    // جمع كل التواريخ الفريدة
    final allDates =
        {...salesByDate.keys, ...purchasesByDate.keys}.toList()..sort();

    List<ProfitReportData> profitData = [];
    for (String date in allDates) {
      final salesTotal = salesByDate[date] ?? 0.0;
      final purchasesTotal = purchasesByDate[date] ?? 0.0;
      profitData.add(
        ProfitReportData(
          date: date,
          sales: salesTotal,
          purchases: purchasesTotal,
          profit: salesTotal - purchasesTotal,
        ),
      );
    }
    return profitData;
  }

  // دالة لجلب تقرير المنتجات (تستخدم لعدة تقارير)
  Future<List<ProductReportData>> _getProductReport({
    required String from,
    required String to,
    required String
    itemTable, // 'sales_invoice_items' or 'purchase_invoice_items'
    required String invoiceTable, // 'sales_invoices' or 'purchase_invoices'
    String orderBy = 'quantity',
    int limit = 20,
  }) async {
    final db = await DatabaseHelper().database;

    // --- === هذا هو التعديل الرئيسي === ---
    // تحديد جملة الربط بناءً على نوع الجدول
    String joinCondition;
    if (itemTable == 'sales_invoice_items') {
      // جدول المبيعات يُربط بـ product_id
      joinCondition = 'LEFT JOIN products p ON items.product_id = p.id';
    } else {
      // جدول المشتريات يُربط بـ barcode
      joinCondition = 'LEFT JOIN products p ON items.barcode = p.barcode';
    }
    // --- === نهاية التعديل الرئيسي === ---

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
        SELECT 
          items.product_name as name,
          SUM(items.quantity) as quantity,
          SUM(items.total) as revenue,
          p.stock as remaining
        FROM $itemTable items
        JOIN $invoiceTable invoices ON items.invoice_id = invoices.id
        $joinCondition  -- <-- استخدام جملة الربط الديناميكية هنا
        WHERE invoices.date BETWEEN ? AND ?
        GROUP BY items.product_name
        ORDER BY $orderBy DESC
        LIMIT ?
      ''',
      [from, to, limit],
    );

    return List.generate(maps.length, (i) {
      return ProductReportData(
        name: maps[i]['name'],
        quantity: maps[i]['quantity'] ?? 0,
        revenue: maps[i]['revenue'] ?? 0.0,
        remaining: maps[i]['remaining'],
      );
    });
  }

  // التقارير المتخصصة التي تستخدم الدالة العامة السابقة
  Future<List<ProductReportData>> getTopSellingProducts(
    String from,
    String to,
  ) async {
    return _getProductReport(
      from: from,
      to: to,
      itemTable: 'sales_invoice_items',
      invoiceTable: 'sales_invoices',
      orderBy: 'quantity',
    );
  }

  Future<List<ProductReportData>> getSoldItems(String from, String to) async {
    return _getProductReport(
      from: from,
      to: to,
      itemTable: 'sales_invoice_items',
      invoiceTable: 'sales_invoices',
      orderBy: 'quantity',
      limit: 100,
    ); // حد أكبر
  }

  Future<List<ProductReportData>> getPurchasedItems(
    String from,
    String to,
  ) async {
    return _getProductReport(
      from: from,
      to: to,
      itemTable: 'purchase_invoice_items',
      invoiceTable: 'purchase_invoices',
      orderBy: 'quantity',
      limit: 100,
    );
  }
}
