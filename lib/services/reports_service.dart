import 'package:pos_desktop/database/database_helper.dart';
import 'package:pos_desktop/models/report_models_new.dart';

class ReportsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 1. الملخص المالي العام
  Future<FinancialSummary> getFinancialSummary(String from, String to) async {
    final db = await _dbHelper.database;

    // A. المبيعات (Total Sales) - تبقى كما هي (تشمل كل شيء)
    final salesResult = await db.rawQuery(
      '''
      SELECT SUM(total) as total_sales
      FROM sales_invoices
      WHERE date BETWEEN ? AND ?
    ''',
      [from, to],
    );
    final totalSales =
        (salesResult.first['total_sales'] as num?)?.toDouble() ?? 0.0;

    // B. التحصيلات (Total Collected)
    // التعديل هنا: استثناء الفواتير المدفوعة "من الرصيد"

    // 1. الدفعات المباشرة عند البيع (Walk-in payments)
    final directPaymentsResult = await db.rawQuery(
      '''
      SELECT SUM(paid_amount) as direct_cash
      FROM sales_invoices
      WHERE date BETWEEN ? AND ?
      AND payment_method != 'من الرصيد' -- ✅ تم الاستثناء هنا
    ''',
      [from, to],
    );
    final directCash =
        (directPaymentsResult.first['direct_cash'] as num?)?.toDouble() ?? 0.0;

    // 2. سداد الديون (Debt payments)
    double debtPayments = 0.0;
    try {
      final debtPaymentsResult = await db.rawQuery(
        '''
        SELECT SUM(pr.amount) as debt_cash
        FROM payment_records pr
        LEFT JOIN sales_invoices si ON pr.invoice_id = si.id
        WHERE pr.payment_date BETWEEN ? AND ?
        AND pr.payment_method != 'من الرصيد'
        AND (si.date < ? OR si.date > ?) -- ✅ استثناء الفواتير التي أنشئت في نفس فترة التقرير
      ''',
        [from, to, from, to],
      );
      debtPayments =
          (debtPaymentsResult.first['debt_cash'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      // في حال حدوث خطأ، نعود للطريقة القديمة (مع خطر التكرار ولكن لضمان عدم توقف التطبيق)
      print('Warning: debt payment query issue: $e');
      try {
        final debtPaymentsResultOld = await db.rawQuery(
          '''
          SELECT SUM(amount) as debt_cash
          FROM payment_records
          WHERE payment_date BETWEEN ? AND ?
          ''',
          [from, to],
        );
        debtPayments =
            (debtPaymentsResultOld.first['debt_cash'] as num?)?.toDouble() ??
            0.0;
      } catch (e2) {
        print('Critical: payment_records issue: $e2');
      }
    }

    final totalCollected = directCash + debtPayments;

    // C. الذمم المدينة (Money Outside)
    final receivablesResult = await db.rawQuery('''
      SELECT SUM(remaining_amount) as total_receivables
      FROM sales_invoices
      WHERE remaining_amount > 0
    ''');
    final totalReceivables =
        (receivablesResult.first['total_receivables'] as num?)?.toDouble() ??
        0.0;

    // D. المحافظ (Money We Owe)
    double totalPayables = 0.0;
    try {
      final walletsResult = await db.rawQuery('''
        SELECT SUM(wallet_balance) as total_wallets
        FROM customers
        WHERE wallet_balance > 0
      ''');
      totalPayables =
          (walletsResult.first['total_wallets'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      // Column might not exist
    }

    // E. قيمة المخزون الحالي
    final stockResult = await db.rawQuery('''
      SELECT SUM(stock * purchase_price) as stock_value
      FROM products
      WHERE is_active = 1 
    ''');
    final totalStockValue =
        (stockResult.first['stock_value'] as num?)?.toDouble() ?? 0.0;

    return FinancialSummary(
      totalSales: totalSales,
      totalCollected: totalCollected,
      totalReceivables: totalReceivables,
      totalPayables: totalPayables,
      totalStockValue: totalStockValue,
      netCashFlow: totalCollected,
    );
  }

  // 2. المبيعات حسب طريقة الدفع
  Future<List<PaymentMethodStat>> getSalesByPaymentMethod(
    String from,
    String to,
  ) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        payment_method,
        COUNT(id) as count,
        SUM(total) as total
      FROM sales_invoices
      WHERE date BETWEEN ? AND ?
      GROUP BY payment_method
      ORDER BY total DESC
    ''',
      [from, to],
    );

    return results
        .map(
          (row) => PaymentMethodStat(
            method: row['payment_method'] as String? ?? 'غير محدد',
            count: (row['count'] as num?)?.toInt() ?? 0,
            totalAmount: (row['total'] as num?)?.toDouble() ?? 0.0,
          ),
        )
        .toList();
  }

  // 3. أعلى المدينين
  Future<List<DebtorStat>> getTopDebtors({int limit = 5}) async {
    final db = await _dbHelper.database;

    final results = await db.rawQuery(
      '''
      SELECT 
        c.id,
        c.name,
        SUM(si.remaining_amount) as total_debt,
        MAX(si.date) as last_date
      FROM sales_invoices si
      JOIN customers c ON si.customer_id = c.id
      WHERE si.remaining_amount > 0
      GROUP BY c.id, c.name
      ORDER BY total_debt DESC
      LIMIT ?
    ''',
      [limit],
    );

    return results
        .map(
          (row) => DebtorStat(
            customerId: row['id'] as int,
            customerName: row['name'] as String,
            totalDebt: (row['total_debt'] as num).toDouble(),
            lastTransactionDate: row['last_date'] as String? ?? '',
          ),
        )
        .toList();
  }

  // 4. المحافظ
  Future<List<WalletStat>> getTopWallets({int limit = 5}) async {
    final db = await _dbHelper.database;
    try {
      final results = await db.rawQuery(
        '''
        SELECT id, name, wallet_balance
        FROM customers
        WHERE wallet_balance > 0
        ORDER BY wallet_balance DESC
        LIMIT ?
      ''',
        [limit],
      );

      return results
          .map(
            (row) => WalletStat(
              customerId: row['id'] as int,
              customerName: row['name'] as String,
              balance: (row['wallet_balance'] as num).toDouble(),
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  // 5. الربح الحقيقي
  Future<RealProfitStat> getRealProfit(String from, String to) async {
    final db = await _dbHelper.database;

    // A. المبيعات الإجمالية
    final salesResult = await db.rawQuery(
      '''
      SELECT SUM(total) as val FROM sales_invoices WHERE date BETWEEN ? AND ?
    ''',
      [from, to],
    );
    final totalSales = (salesResult.first['val'] as num?)?.toDouble() ?? 0.0;

    if (totalSales == 0) {
      return RealProfitStat(
        totalSales: 0,
        totalCostOfGoods: 0,
        grossProfit: 0,
        collectionRatio: 0,
        realizedProfit: 0,
      );
    }

    // B. تكلفة البضاعة المباعة (COGS)
    // نستخدم sii.cost_price (التي تخزن التكلفة لحظة البيع) إذا توفرت
    // وإلا نعود لـ p.purchase_price (التكلفة الحالية) كحل احتياطي
    final cogsResult = await db.rawQuery(
      '''
      SELECT SUM(sii.quantity * sii.unit_quantity * COALESCE(NULLIF(sii.cost_price, 0), p.purchase_price, 0)) as cogs
      FROM sales_invoice_items sii
      JOIN sales_invoices si ON sii.invoice_id = si.id
      LEFT JOIN products p ON sii.product_id = p.id
      WHERE si.date BETWEEN ? AND ?
    ''',
      [from, to],
    );

    final totalCOGS = (cogsResult.first['cogs'] as num?)?.toDouble() ?? 0.0;
    final grossProfit = totalSales - totalCOGS;

    // C. نسبة التحصيل في هذه الفترة (الكاش فقط)
    // التعديل هنا أيضاً: نحسب فقط ما تم تحصيله كاش، ونستثني ما دفع من الرصيد
    // لأن الدفع من الرصيد هو تدوير التزام وليس ربحاً نقدياً جديداً يدخل الجيب
    final collectedFromCurrentSalesResult = await db.rawQuery(
      '''
      SELECT SUM(paid_amount) as val
      FROM sales_invoices
      WHERE date BETWEEN ? AND ?
      AND payment_method != 'من الرصيد' -- ✅ استثناء الرصيد من حساب نسبة التحصيل النقدي
    ''',
      [from, to],
    );
    final collectedFromCurrentSales =
        (collectedFromCurrentSalesResult.first['val'] as num?)?.toDouble() ??
        0.0;

    double collectionRatio = 0.0;
    if (totalSales > 0) {
      collectionRatio = collectedFromCurrentSales / totalSales;
    }

    // الربح المحقق (نقداً)
    final realizedProfit = grossProfit * collectionRatio;

    return RealProfitStat(
      totalSales: totalSales,
      totalCostOfGoods: totalCOGS,
      grossProfit: grossProfit,
      collectionRatio: collectionRatio,
      realizedProfit: realizedProfit,
    );
  }
}
