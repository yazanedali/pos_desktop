import '../database/database_helper.dart';
import '../models/report_models.dart';
import '../../database/customer_queries.dart';

class ReportQueries {
  final CustomerQueries _customerQueries = CustomerQueries();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // دالة مساعدة لتحويل أي نوع إلى double
  double _convertToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // دالة لجلب تقرير المبيعات مجمّع حسب اليوم
  Future<List<SalesReportData>> getSalesReport(String from, String to) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT 
        date, 
        COUNT(id) as invoices, 
        SUM(total) as total,
        SUM(CASE WHEN payment_type = 'نقدي' THEN total ELSE 0 END) as cash_total,
        SUM(CASE WHEN payment_type = 'آجل' THEN total ELSE 0 END) as credit_total,
        COUNT(CASE WHEN payment_type = 'نقدي' THEN 1 END) as cash_invoices,
        COUNT(CASE WHEN payment_type = 'آجل' THEN 1 END) as credit_invoices
      FROM sales_invoices 
      WHERE date BETWEEN ? AND ? 
      GROUP BY date 
      ORDER BY date
    ''',
      [from, to],
    );

    return List.generate(maps.length, (i) {
      return SalesReportData(
        date: maps[i]['date'] as String,
        invoices: (maps[i]['invoices'] as int?) ?? 0,
        total: _convertToDouble(maps[i]['total']),
        cashTotal: _convertToDouble(maps[i]['cash_total']),
        creditTotal: _convertToDouble(maps[i]['credit_total']),
        cashInvoices: (maps[i]['cash_invoices'] as int?) ?? 0,
        creditInvoices: (maps[i]['credit_invoices'] as int?) ?? 0,
      );
    });
  }

  Future<List<OutstandingDebtData>> getOutstandingDebts() async {
    final db = await DatabaseHelper().database;

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        c.id as customer_id,
        c.name as customer_name,
        c.phone as customer_phone,
        COUNT(si.id) as invoices_count,
        SUM(si.total) as total_debt,
        SUM(si.paid_amount) as total_paid,
        SUM(si.remaining_amount) as total_remaining
      FROM customers c
      LEFT JOIN sales_invoices si ON c.id = si.customer_id AND si.remaining_amount > 0
      GROUP BY c.id, c.name, c.phone
      HAVING total_remaining > 0
      ORDER BY total_remaining DESC
    ''');

    return await Future.wait(
      maps.map((map) async {
        final customerId = map['customer_id'];
        final debtDetails = await _customerQueries.getCustomerDebtDetails(
          customerId,
        );

        return OutstandingDebtData(
          customerId: customerId,
          customerName: map['customer_name'],
          customerPhone: map['customer_phone'],
          invoicesCount: map['invoices_count'] ?? 0,
          totalDebt: (map['total_debt'] as num?)?.toDouble() ?? 0.0,
          totalPaid: (map['total_paid'] as num?)?.toDouble() ?? 0.0,
          totalRemaining: (map['total_remaining'] as num?)?.toDouble() ?? 0.0,
          debtDetails: debtDetails,
        );
      }),
    );
  }

  // دالة لجلب تقرير المبيعات حسب نوع الدفع
  Future<List<PaymentTypeReportData>> getSalesByPaymentType(
    String from,
    String to,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
    SELECT 
      date, 
      COUNT(id) as invoices, 
      SUM(total) as total,
      
      -- المبلغ النقدي: مجموع paid_amount (المبلغ المدفوع فعلياً)
      SUM(paid_amount) as cash_total,
      
      -- المبلغ المتبقي: مجموع remaining_amount
      SUM(remaining_amount) as credit_total,
      
      -- عدد الفواتير النقدية (التي دفع منها أي مبلغ)
      COUNT(CASE 
        WHEN paid_amount > 0 THEN 1 
        ELSE NULL 
      END) as cash_invoices,
      
      -- عدد الفواتير التي لها دين
      COUNT(CASE 
        WHEN remaining_amount > 0 THEN 1 
        ELSE NULL 
      END) as credit_invoices
      
    FROM sales_invoices 
    WHERE date BETWEEN ? AND ? 
    GROUP BY date 
    ORDER BY date
    ''',
      [from, to],
    );

    return List.generate(maps.length, (i) {
      return PaymentTypeReportData(
        date: maps[i]['date'] as String,
        invoices: (maps[i]['invoices'] as int?) ?? 0,
        total: _convertToDouble(maps[i]['total']),
        cashTotal: _convertToDouble(maps[i]['cash_total']),
        creditTotal: _convertToDouble(maps[i]['credit_total']),
        cashInvoices: (maps[i]['cash_invoices'] as int?) ?? 0,
        creditInvoices: (maps[i]['credit_invoices'] as int?) ?? 0,
      );
    });
  }

  // دالة لجلب تقرير حالة السداد
  Future<List<PaymentStatusReportData>> getPaymentStatusReport(
    String from,
    String to,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT 
        payment_status,
        COUNT(id) as invoices_count,
        SUM(total) as total_amount,
        SUM(paid_amount) as paid_amount,
        SUM(remaining_amount) as remaining_amount
      FROM sales_invoices 
      WHERE date BETWEEN ? AND ? 
      GROUP BY payment_status 
      ORDER BY total_amount DESC
    ''',
      [from, to],
    );

    return List.generate(maps.length, (i) {
      return PaymentStatusReportData(
        paymentStatus: maps[i]['payment_status'] as String? ?? 'مدفوع',
        invoicesCount: (maps[i]['invoices_count'] as int?) ?? 0,
        totalAmount: _convertToDouble(maps[i]['total_amount']),
        paidAmount: _convertToDouble(maps[i]['paid_amount']),
        remainingAmount: _convertToDouble(maps[i]['remaining_amount']),
      );
    });
  }

  Future<List<PaymentRecordData>> getPaymentRecords(
    String from,
    String to,
  ) async {
    final db = await DatabaseHelper().database;

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT 
        pr.*,
        si.invoice_number,
        c.name as customer_name,
        c.phone as customer_phone
      FROM payment_records pr
      LEFT JOIN sales_invoices si ON pr.invoice_id = si.id
      LEFT JOIN customers c ON si.customer_id = c.id
      WHERE pr.payment_date BETWEEN ? AND ? 
      ORDER BY pr.payment_date DESC, pr.payment_time DESC
    ''',
      [from, to],
    );

    return List.generate(maps.length, (i) {
      return PaymentRecordData(
        id: maps[i]['id'],
        invoiceId: maps[i]['invoice_id'],
        invoiceNumber: maps[i]['invoice_number'],
        customerName: maps[i]['customer_name'],
        paymentDate: maps[i]['payment_date'],
        paymentTime: maps[i]['payment_time'],
        amount: maps[i]['amount'] ?? 0.0,
        paymentMethod: maps[i]['payment_method'] ?? 'نقدي',
        notes: maps[i]['notes'],
        createdAt: maps[i]['created_at'],
      );
    });
  }

  // دالة لجلب تقرير المشتريات مجمّع حسب اليوم
  Future<List<PurchaseReportData>> getPurchaseReport(
    String from,
    String to,
  ) async {
    final db = await _dbHelper.database;
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
        date: maps[i]['date'] as String,
        invoices: (maps[i]['invoices'] as int?) ?? 0,
        items: _convertToDouble(maps[i]['items']),
        total: _convertToDouble(maps[i]['total']),
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
