// dialogs/customer_statement_dialog.dart
import 'package:flutter/material.dart';
import 'package:pos_desktop/models/customer.dart';
import 'package:pos_desktop/services/sales_invoice_service.dart';
import 'package:pos_desktop/services/printing_service.dart';
import 'package:pos_desktop/models/statement_item.dart';
import 'invoice_details_dialog.dart';

class CustomerStatementDialog extends StatefulWidget {
  final Customer customer;

  const CustomerStatementDialog({super.key, required this.customer});

  @override
  State<CustomerStatementDialog> createState() =>
      _CustomerStatementDialogState();
}

class _CustomerStatementDialogState extends State<CustomerStatementDialog> {
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final SalesInvoiceService _invoiceService = SalesInvoiceService();

  List<StatementItem> _statementItems = [];
  bool _isLoading = false;

  // Statistics
  double _totalSales = 0.0;
  double _totalPaid = 0.0;
  double _finalBalance = 0.0;
  int _invoiceCount = 0;

  @override
  void initState() {
    super.initState();
    _setDefaultDates();
  }

  void _setDefaultDates() {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);

    _dateFromController.text = _formatDate(firstOfMonth);
    _dateToController.text = _formatDate(now);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadCustomerStatement() async {
    if (_dateFromController.text.isEmpty || _dateToController.text.isEmpty) {
      _showError('يرجى تحديد تاريخ البداية والنهاية');
      return;
    }

    setState(() {
      _isLoading = true;
      _statementItems = [];
    });

    try {
      final items = await _invoiceService.getCustomerDetailedStatement(
        customerId: widget.customer.id!,
        startDate: _dateFromController.text,
        endDate: _dateToController.text,
      );

      double sales = 0;
      double paid = 0;
      int count = 0;

      for (var item in items) {
        if (item.isReturn) {
          // المرتجع يعتبر تخفيض للمبيعات أو زيادة في المدفوعات (حسب المنظور)
          // هنا سنعتبره عملية عكسية للمبيعات
          // لكن للعرض كإحصائيات:
          // totalSales = Sum of invoices
          // totalPaid = Sum of payments + Returns ?
          // الأبسط: لا نجمع المرتجعات مع المبيعات.
        } else if (!item.isCredit) {
          // فاتورة مبيعات
          if (item.type.contains("فاتورة")) {
            sales += item.amount;
            count++;
          }
        } else {
          // سداد
          paid += item.amount;
        }
      }

      setState(() {
        _statementItems = items;
        _totalSales = sales;
        _totalPaid = paid;
        _finalBalance = items.isNotEmpty ? items.last.balance : 0.0;
        _invoiceCount = count;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('خطأ في تحميل كشف الحساب: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _printStatement() async {
    if (_statementItems.isEmpty) {
      _showError("لا توجد بيانات للطباعة");
      return;
    }

    try {
      await PrintingService().printStatement(
        title: "كشف حساب عميل تفصيلي",
        entityName: widget.customer.name,
        dateRange:
            "من ${_dateFromController.text} إلى ${_dateToController.text}",
        items: _statementItems,
      );
    } catch (e) {
      _showError("حدث خطأ أثناء الطباعة: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "كشف حساب مفصل - ${widget.customer.name}",
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // فلاتر التاريخ
              _buildDateFilters(),
              const SizedBox(height: 16),

              // زر التحميل
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadCustomerStatement,
                  icon:
                      _isLoading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.search),
                  label: Text(
                    _isLoading ? 'جاري التحميل...' : 'عرض الكشف المفصل',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // الإحصائيات
              if (_statementItems.isNotEmpty) _buildStatistics(),
              const SizedBox(height: 16),

              // قائمة البنود
              Expanded(child: _buildContentSection()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
          if (_statementItems.isNotEmpty)
            ElevatedButton.icon(
              onPressed: _printStatement,
              icon: const Icon(Icons.print),
              label: const Text('طباعة الكشف'),
            ),
        ],
      ),
    );
  }

  Widget _buildDateFilters() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'الفترة الزمنية',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateFromController,
                    decoration: const InputDecoration(
                      labelText: 'من تاريخ',
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
                        setState(() {
                          _dateFromController.text = _formatDate(date);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _dateToController,
                    decoration: const InputDecoration(
                      labelText: 'إلى تاريخ',
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
                        setState(() {
                          _dateToController.text = _formatDate(date);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_statementItems.isEmpty && _dateFromController.text.isNotEmpty) {
      return _buildEmptyState();
    }

    if (_statementItems.isNotEmpty) {
      return _buildTransactionsList();
    }

    return const SizedBox();
  }

  Widget _buildStatistics() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _buildStatItem('إجمالي الفواتير', _totalSales, Colors.blue),
            _buildStatItem('إجمالي السدادات', _totalPaid, Colors.green),
            _buildStatItem(
              'الرصيد النهائي',
              _finalBalance,
              _finalBalance > 0
                  ? Colors.red
                  : Colors.green, // أحمر يعني عليه دين
            ),
            _buildStatItem(
              'عدد الحركات',
              _invoiceCount.toDouble(),
              Colors.purple,
              isInteger: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    double value,
    Color color, {
    bool isInteger = false,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isInteger ? value.toInt().toString() : value.toStringAsFixed(2),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'لا توجد حركات في الفترة المحددة',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    return Column(
      children: [
        // Header Row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'التاريخ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'البيان',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'مدين (عليه)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'دائن (له)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'الرصيد',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: ListView.separated(
            itemCount: _statementItems.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _statementItems[index];
              final bool isDebit = !item.isCredit && !item.isReturn; // فاتورة
              final bool isCredit =
                  item.isCredit || item.isReturn; // سداد أو مرتجع

              return Container(
                color:
                    index % 2 == 0
                        ? Colors.white
                        : Colors.grey[50], // Striped rows
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                child: Row(
                  children: [
                    // Date
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.date, style: const TextStyle(fontSize: 12)),
                          if (item.invoiceNumber != null)
                            Text(
                              "#${item.invoiceNumber}",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Description
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.type,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item.description.isNotEmpty)
                            Text(
                              item.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Debit (Invoice Amount)
                    Expanded(
                      flex: 2,
                      child: Text(
                        isDebit ? item.amount.toStringAsFixed(2) : "-",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    // Credit (Payment Amount)
                    Expanded(
                      flex: 2,
                      child: Text(
                        isCredit ? item.amount.toStringAsFixed(2) : "-",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    // Balance
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.balance.toStringAsFixed(2),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: item.balance > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                    // Actions
                    if (isDebit && item.items != null && item.items!.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.receipt_long,
                          size: 20,
                          color: Colors.blue,
                        ),
                        tooltip: "تفاصيل الفاتورة",
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => InvoiceDetailsDialog(item: item),
                          );
                        },
                      )
                    else
                      const SizedBox(width: 48), // Spacing placeholder
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
