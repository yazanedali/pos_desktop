import 'package:flutter/material.dart';
import 'package:pos_desktop/models/report_models_new.dart';
import 'package:pos_desktop/services/reports_service.dart';
import 'widgets/summary_card.dart';
import 'widgets/real_profit_card.dart';
import 'widgets/debts_wallets_section.dart';
import 'widgets/sales_breakdown_section.dart';
import 'package:intl/intl.dart' as intl;

class NewReportsPage extends StatefulWidget {
  const NewReportsPage({Key? key}) : super(key: key);

  @override
  State<NewReportsPage> createState() => _NewReportsPageState();
}

enum DateFilterType { daily, monthly, custom }

class _NewReportsPageState extends State<NewReportsPage> {
  final ReportsService _service = ReportsService();
  bool _isLoading = true;

  // 1. التغيير هنا: التاريخ الافتراضي هو اليوم فقط
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

  DateFilterType _selectedFilter = DateFilterType.daily;

  FinancialSummary? _financialSummary;
  List<PaymentMethodStat> _paymentStats = [];
  List<DebtorStat> _debtors = [];
  List<WalletStat> _wallets = [];
  RealProfitStat? _realProfit;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 2. دالة مساعدة لتنسيق العملة (منزلتين + شيكل)
  String _formatMoney(double amount) {
    final formatter = intl.NumberFormat('#,##0.00', 'en_US');
    return '${formatter.format(amount)} شيكل';
  }

  // دوال لتغيير التاريخ بسرعة
  void _setDaily() {
    setState(() {
      final now = DateTime.now();
      _dateRange = DateTimeRange(start: now, end: now);
      _selectedFilter = DateFilterType.daily;
    });
    _loadData();
  }

  void _setMonthly() {
    setState(() {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      // للحصول على آخر يوم في الشهر الحالي (نأخذ اليوم 0 من الشهر القادم)
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      _dateRange = DateTimeRange(start: startOfMonth, end: endOfMonth);
      _selectedFilter = DateFilterType.monthly;
    });
    _loadData();
  }

  Future<void> _selectCustomDate() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _selectedFilter = DateFilterType.custom;
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final from = intl.DateFormat('yyyy-MM-dd').format(_dateRange.start);
      final to = intl.DateFormat('yyyy-MM-dd').format(_dateRange.end);

      final results = await Future.wait([
        _service.getFinancialSummary(from, to),
        _service.getSalesByPaymentMethod(from, to),
        _service.getTopDebtors(),
        _service.getTopWallets(),
        _service.getRealProfit(from, to),
      ]);

      setState(() {
        _financialSummary = results[0] as FinancialSummary;
        _paymentStats = results[1] as List<PaymentMethodStat>;
        _debtors = results[2] as List<DebtorStat>;
        _wallets = results[3] as List<WalletStat>;
        _realProfit = results[4] as RealProfitStat;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reports: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في تحميل البيانات: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // تنسيق عرض التاريخ في العنوان
    String dateLabel = '';
    if (_selectedFilter == DateFilterType.daily) {
      dateLabel =
          'اليوم: ${intl.DateFormat('yyyy-MM-dd').format(_dateRange.start)}';
    } else if (_selectedFilter == DateFilterType.monthly) {
      dateLabel =
          'شهر: ${intl.DateFormat('MMMM yyyy').format(_dateRange.start)}';
    } else {
      dateLabel =
          '${intl.DateFormat('MM-dd').format(_dateRange.start)} إلى ${intl.DateFormat('MM-dd').format(_dateRange.end)}';
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'التقارير المالية',
              style: TextStyle(color: Colors.black, fontSize: 18),
            ),
            Text(
              dateLabel,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // 3. أزرار الفلاتر السريعة
          _buildFilterButton('يومي', DateFilterType.daily, _setDaily),
          const SizedBox(width: 8),
          _buildFilterButton('شهري', DateFilterType.monthly, _setMonthly),
          const SizedBox(width: 8),

          // زر اختيار تاريخ مخصص
          OutlinedButton.icon(
            onPressed: _selectCustomDate,
            icon: Icon(
              Icons.calendar_month,
              size: 18,
              color:
                  _selectedFilter == DateFilterType.custom
                      ? Colors.white
                      : Colors.blue,
            ),
            label: Text(
              'تخصيص',
              style: TextStyle(
                color:
                    _selectedFilter == DateFilterType.custom
                        ? Colors.white
                        : Colors.blue,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  _selectedFilter == DateFilterType.custom
                      ? Colors.blue
                      : Colors.transparent,
              side: const BorderSide(color: Colors.blue),
            ),
          ),

          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'تحديث البيانات',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. الملخص المالي (Cards)
            if (_financialSummary != null)
              GridView.count(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                childAspectRatio: 1.6,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ReportSummaryCard(
                    title: 'إجمالي المبيعات',
                    // 4. استخدام دالة التنسيق الجديدة
                    value: _formatMoney(_financialSummary!.totalSales),
                    icon: Icons.shopping_bag,
                    color: Colors.blue,
                    subtitle: 'في الفترة المحددة',
                  ),
                  ReportSummaryCard(
                    title: 'الكاش المستلم',
                    value: _formatMoney(_financialSummary!.totalCollected),
                    icon: Icons.attach_money,
                    color: Colors.green,
                    subtitle: 'نقدي + سداد ديون',
                  ),
                  ReportSummaryCard(
                    title: 'الديون الخارجية',
                    value: _formatMoney(_financialSummary!.totalReceivables),
                    icon: Icons.account_balance_wallet,
                    color: Colors.red,
                    subtitle: 'إجمالي المستحقات',
                  ),
                  ReportSummaryCard(
                    title: 'قيمة المخزون',
                    value: _formatMoney(_financialSummary!.totalStockValue),
                    icon: Icons.inventory_2,
                    color: Colors.orange,
                    subtitle: 'بسعر الشراء',
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // 2. كرت الربح الحقيقي
            if (_realProfit != null) ...[
              const Text(
                'تحليل الربحية',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // ملاحظة: إذا كان كرت الربح يعرض الأرقام بداخله، ستحتاج لتعديل الكرت نفسه
              // لإضافة "شيكل" والكسور، أو تمرير البيانات كنصوص من هنا إذا كان يدعم ذلك
              RealProfitCard(data: _realProfit!),
            ],

            const SizedBox(height: 24),

            // 3. قسم الديون والمحافظ
            const Text(
              'متابعة الذمم والزبائن',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DebtsWalletsSection(debtors: _debtors, wallets: _wallets),

            const SizedBox(height: 24),

            // 4. تحليل طرق الدفع
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SalesBreakdownSection(stats: _paymentStats)),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bar_chart,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'إحصائيات إضافية قريباً',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ودجت مساعد لزر الفلتر
  Widget _buildFilterButton(
    String label,
    DateFilterType type,
    VoidCallback onPressed,
  ) {
    final isSelected = _selectedFilter == type;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: isSelected ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      ),
      child: Text(label),
    );
  }
}
