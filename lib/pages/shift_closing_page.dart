import 'package:flutter/material.dart';
import 'package:pos_desktop/models/daily_closing.dart';
import 'package:pos_desktop/services/closing_service.dart';
import 'package:pos_desktop/services/printing_service.dart';
import 'package:pos_desktop/widgets/top_alert.dart';

class ShiftClosingPage extends StatefulWidget {
  const ShiftClosingPage({super.key});

  @override
  State<ShiftClosingPage> createState() => _ShiftClosingPageState();
}

class _ShiftClosingPageState extends State<ShiftClosingPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Colors.black),
          title: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(
                icon: Icon(Icons.lock_clock, size: 20),
                text: "الوردية الحالية",
                height: 50,
              ),
              Tab(
                icon: Icon(Icons.history, size: 20),
                text: "سجل الورديات",
                height: 50,
              ),
            ],
          ),
        ),
        body: const TabBarView(children: [CurrentClosingTab(), HistoryTab()]),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Tab 1: Current Closing (The original page content)
// -----------------------------------------------------------------------------
class CurrentClosingTab extends StatefulWidget {
  const CurrentClosingTab({super.key});

  @override
  State<CurrentClosingTab> createState() => _CurrentClosingTabState();
}

class _CurrentClosingTabState extends State<CurrentClosingTab> {
  final ClosingService _closingService = ClosingService();
  DailyClosing? _closingData;
  bool _isLoading = true;
  final TextEditingController _actualCashController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _closingService.calculateShiftTotals();
      if (mounted) {
        setState(() {
          _closingData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        TopAlert.showError(
          context: context,
          message: "خطأ في تحميل البيانات: $e",
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _submitClosing() async {
    if (_closingData == null) return;

    final actualCash = double.tryParse(_actualCashController.text);
    if (actualCash == null) {
      TopAlert.showError(
        context: context,
        message: "الرجاء إدخال المبلغ الفعلي",
      );
      return;
    }

    final difference = actualCash - _closingData!.expectedCash;

    final finalClosing = DailyClosing(
      closingDate: _closingData!.closingDate,
      closingTime: DateTime.now().toString().split(' ')[1].split('.')[0],
      openingCash: _closingData!.openingCash,
      totalSalesCash: _closingData!.totalSalesCash,
      totalExpenses: _closingData!.totalExpenses,
      expectedCash: _closingData!.expectedCash,
      actualCash: actualCash,
      difference: difference,
      notes: _notesController.text,
      createdAt: DateTime.now().toIso8601String(),
    );

    try {
      await _closingService.saveClosing(finalClosing);
      if (mounted) {
        TopAlert.showSuccess(
          context: context,
          message: "تم إغلاق الوردية بنجاح",
        );
        _actualCashController.clear();
        _notesController.clear();
        _loadData();

        await PrintingService().printShiftClosing(finalClosing);
      }
    } catch (e) {
      if (mounted) {
        TopAlert.showError(context: context, message: "فشل الحفظ: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_closingData == null) {
      return const Center(child: Text("لا توجد بيانات"));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "ملخص الوردية الحالية",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 32),

              _buildRow(
                "تاريخ ووقت الإغلاق المتوقع",
                "${_closingData!.closingDate}  ${_closingData!.closingTime}",
              ),
              _buildRow(
                "رصيد الافتتاح",
                "${_closingData!.openingCash.toStringAsFixed(2)}",
              ),
              const SizedBox(height: 16),

              _buildRow(
                "المبيعات النقدية (Net)",
                "${_closingData!.totalSalesCash.toStringAsFixed(2)}",
                isBold: true,
                color: Colors.green,
              ),
              _buildRow(
                "المصروفات/السحوبات",
                "-${_closingData!.totalExpenses.toStringAsFixed(2)}",
                isBold: true,
                color: Colors.red,
              ),

              const Divider(height: 32),

              _buildRow(
                "المبلغ المتوقع في الدرج",
                "${_closingData!.expectedCash.toStringAsFixed(2)}",
                isBold: true,
                fontSize: 18,
              ),

              const SizedBox(height: 32),

              const Text(
                "المبلغ الفعلي (جرد الدرج)",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _actualCashController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "أدخل المبلغ الموجود في الصندوق",
                  suffixText: "شيكل",
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                onChanged: (val) => setState(() {}),
              ),

              if (_actualCashController.text.isNotEmpty) ...[
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final actual =
                        double.tryParse(_actualCashController.text) ?? 0.0;
                    final diff = actual - _closingData!.expectedCash;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            diff == 0
                                ? Colors.green[50]
                                : (diff > 0 ? Colors.blue[50] : Colors.red[50]),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              diff == 0
                                  ? Colors.green
                                  : (diff > 0 ? Colors.blue : Colors.red),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "الفارق (العجز/الزيادة):",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "${diff.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  diff == 0
                                      ? Colors.green
                                      : (diff > 0 ? Colors.blue : Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 24),
              const Text("ملاحظات"),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _submitClosing,
                  icon: const Icon(Icons.check_circle),
                  label: const Text(
                    "تأكيد وإغلاق الوردية",
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 16,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: fontSize, color: Colors.grey[800]),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Tab 2: History (New Feature)
// -----------------------------------------------------------------------------
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final ClosingService _closingService = ClosingService();
  List<DailyClosing> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await _closingService.getClosingsHistory();
      if (mounted) {
        setState(() {
          _history = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reprint(DailyClosing closing) async {
    try {
      await PrintingService().printShiftClosing(closing);
      if (mounted) {
        TopAlert.showSuccess(
          context: context,
          message: "تم إرسال التقرير للطباعة",
        );
      }
    } catch (e) {
      if (mounted) {
        TopAlert.showError(context: context, message: "فشل الطباعة: $e");
      }
    }
  }

  Future<void> _deleteClosing(DailyClosing closing) async {
    if (closing.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("حذف الحركة"),
            content: const Text(
              "هل أنت متأكد من حذف هذا السجل؟ لا يمكن التراجع عن هذا الإجراء.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("إلغاء"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("حذف"),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _closingService.deleteClosing(closing.id!);
        if (mounted) {
          TopAlert.showSuccess(context: context, message: "تم حذف السجل بنجاح");
          _loadHistory();
        }
      } catch (e) {
        if (mounted) {
          TopAlert.showError(context: context, message: "فشل الحذف: $e");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "لا يوجد سجل إغلاقات سابقة",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        final isBalanced = item.difference == 0;
        final isShortage = item.difference < 0;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor:
                  isBalanced
                      ? Colors.green[100]
                      : (isShortage ? Colors.red[100] : Colors.blue[100]),
              child: Icon(
                isBalanced
                    ? Icons.check
                    : (isShortage ? Icons.warning : Icons.add),
                color:
                    isBalanced
                        ? Colors.green
                        : (isShortage ? Colors.red : Colors.blue),
              ),
            ),
            title: Text(
              "${item.closingDate} - ${item.closingTime}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "المتوقع: ${item.expectedCash.toStringAsFixed(1)} | الفعلي: ${item.actualCash.toStringAsFixed(1)}",
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => _reprint(item),
                  tooltip: "إعادة طباعة",
                  color: Colors.blue,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteClosing(item),
                  tooltip: "حذف الحركة",
                  color: Colors.red,
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDetailRow("رصيد الافتتاح", item.openingCash),
                    _buildDetailRow("المبيعات النقدية", item.totalSalesCash),
                    _buildDetailRow("المصروفات", item.totalExpenses),
                    const Divider(),
                    _buildDetailRow("الفارق", item.difference, isBold: true),
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "ملاحظات: ${item.notes}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color:
                  (isBold && value != 0)
                      ? (value < 0 ? Colors.red : Colors.blue)
                      : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
