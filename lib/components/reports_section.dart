import 'package:flutter/material.dart';
import '../database/report_queries.dart'; // استيراد الملف الجديد
import '../models/report_models.dart';
import './reports/sales_report.dart';
import './reports/purchases_report.dart';
import './reports/profits_report.dart';
import './reports/top_selling_report.dart';
import './reports/purchased_items_report.dart';
import './reports/sold_items_report.dart';
import '../widgets/top_alert.dart';

class ReportsSection extends StatefulWidget {
  const ReportsSection({super.key});

  @override
  State<ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends State<ReportsSection> {
  String _selectedReport = "sales";
  // --- تعديل: استخدام controllers لتسهيل التحكم ---
  late TextEditingController _dateFromController;
  late TextEditingController _dateToController;
  final ReportQueries _reportQueries = ReportQueries();

  // --- الحالة الجديدة للواجهة ---
  bool _isLoading = false;
  dynamic _reportData; // سيحتوي على بيانات التقرير بعد جلبها

  final List<Map<String, String>> _reportTypes = [
    {"value": "sales", "label": "تقرير المبيعات"},
    {"value": "purchases", "label": "تقرير المشتريات"},
    {"value": "profits", "label": "تقرير الأرباح"},
    {"value": "top-selling", "label": "المنتجات الأكثر مبيعاً"},
    {"value": "purchased-items", "label": "المنتجات المشتراة"},
    {"value": "sold-items", "label": "المنتجات المباعة"},
  ];

  @override
  void initState() {
    super.initState();
    final today = _getFormattedDate(DateTime.now());
    _dateFromController = TextEditingController(text: today);
    _dateToController = TextEditingController(text: today);
    // جلب التقرير الافتراضي عند فتح الصفحة
    _generateReport();
  }

  @override
  void dispose() {
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  String _getFormattedDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _generateReport() async {
    if (_dateFromController.text.isEmpty || _dateToController.text.isEmpty) {
      TopAlert.showError(
        context: context,
        message: 'يرجى تحديد تاريخ البداية والنهاية',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _reportData = null; // تفريغ البيانات القديمة
    });

    try {
      dynamic data;
      final from = _dateFromController.text;
      final to = _dateToController.text;

      switch (_selectedReport) {
        case "sales":
          data = await _reportQueries.getSalesReport(from, to);
          break;
        case "purchases":
          data = await _reportQueries.getPurchaseReport(from, to);
          break;
        case "profits":
          data = await _reportQueries.getProfitReport(from, to);
          break;
        case "top-selling":
          data = await _reportQueries.getTopSellingProducts(from, to);
          break;
        case "purchased-items":
          data = await _reportQueries.getPurchasedItems(from, to);
          break;
        case "sold-items":
          data = await _reportQueries.getSoldItems(from, to);
          break;
      }
      setState(() {
        _reportData = data;
      });
    } catch (e) {
      // ignore: use_build_context_synchronously
      TopAlert.showError(context: context, message: 'حدث خطأ: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _renderReportContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reportData == null) {
      return const Center(
        child: Text("الرجاء الضغط على 'إنشاء التقرير' لعرض البيانات."),
      );
    }

    if (_reportData.isEmpty) {
      return const Center(child: Text("لا توجد بيانات لهذه الفترة المحددة."));
    }

    switch (_selectedReport) {
      case "sales":
        return SalesReport(data: _reportData as List<SalesReportData>);
      case "purchases":
        return PurchasesReport(data: _reportData as List<PurchaseReportData>);
      case "profits":
        return ProfitsReport(data: _reportData as List<ProfitReportData>);
      case "top-selling":
        return TopSellingReport(data: _reportData as List<ProductReportData>);
      case "purchased-items":
        return PurchasedItemsReport(
          data: _reportData as List<ProductReportData>,
        );
      case "sold-items":
        return SoldItemsReport(data: _reportData as List<ProductReportData>);
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Text(
          "التقارير والإحصائيات",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 16),

        // Report Settings
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.blue[100]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.description, color: Colors.blue[800]),
                    const SizedBox(width: 8),
                    const Text(
                      "إعدادات التقرير",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Report Type
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedReport,
                        decoration: const InputDecoration(
                          labelText: "نوع التقرير",
                          border: OutlineInputBorder(),
                        ),
                        items:
                            _reportTypes.map((type) {
                              return DropdownMenuItem(
                                value: type['value'],
                                child: Text(type['label']!),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null && value != _selectedReport) {
                            setState(() {
                              _selectedReport = value;
                              _reportData =
                                  null; // تفريغ البيانات القديمة عند تغيير التقرير
                              _isLoading = false; // إعادة تعيين حالة التحميل
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Date From
                    Expanded(
                      child: TextField(
                        controller: _dateFromController,
                        decoration: const InputDecoration(
                          labelText: "من تاريخ",
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            _dateFromController.text = _getFormattedDate(date);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Date To
                    Expanded(
                      child: TextField(
                        controller: _dateToController,
                        decoration: const InputDecoration(
                          labelText: "إلى تاريخ",
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            _dateToController.text = _getFormattedDate(date);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Generate Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _generateReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today, size: 18),
                            SizedBox(width: 8),
                            Text("إنشاء التقرير"),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Report Content
        Expanded(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blue[100]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _renderReportContent(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
