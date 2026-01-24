// dialogs/supplier_statement_dialog.dart
import 'package:flutter/material.dart';
import 'package:pos_desktop/models/supplier.dart';
import 'package:pos_desktop/database/supplier_queries.dart';
import 'package:pos_desktop/services/printing_service.dart';
import 'package:pos_desktop/models/statement_item.dart';
import 'package:pos_desktop/dialogs/invoice_details_dialog.dart';

class SupplierStatementDialog extends StatefulWidget {
  final Supplier supplier;

  const SupplierStatementDialog({super.key, required this.supplier});

  @override
  State<SupplierStatementDialog> createState() =>
      _SupplierStatementDialogState();
}

class _SupplierStatementDialogState extends State<SupplierStatementDialog> {
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final SupplierQueries _supplierQueries = SupplierQueries();

  List<StatementItem> _statementItems = [];
  bool _isLoading = false;

  // Statistics
  double _totalPurchases = 0.0;
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

  Future<void> _loadSupplierStatement() async {
    if (_dateFromController.text.isEmpty || _dateToController.text.isEmpty) {
      _showError('يرجى تحديد تاريخ البداية والنهاية');
      return;
    }

    setState(() {
      _isLoading = true;
      _statementItems = [];
    });

    try {
      final items = await _supplierQueries.getSupplierDetailedStatement(
        supplierId: widget.supplier.id!,
        startDate: _dateFromController.text,
        endDate: _dateToController.text,
      );

      double purchases = 0;
      double paid = 0;
      int count = 0;

      for (var item in items) {
        if (item.type == "رصيد سابق") {
          // لا يضاف للمجاميع لعدم الازدواجية، إلا إذا أردنا عرض "مجموع الفترة"
        } else if (item.isCredit) {
          // مشتريات (دين علينا)
          // ولكن قد يكون "رصيد افتتاحي"
          if (item.type != "رصيد افتتاحي" && item.type != "رصيد سابق") {
            purchases += item.amount;
            count++;
          }
        } else {
          // سداد
          paid += item.amount;
        }
      }

      setState(() {
        _statementItems = items;
        _totalPurchases = purchases;
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
        title: "كشف حساب مورد مفصل",
        entityName: widget.supplier.name,
        dateRange:
            "من ${_dateFromController.text} إلى ${_dateToController.text}",
        items: _statementItems,
        isSupplier: true,
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
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.orange.shade700,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "كشف حساب المورد - ${widget.supplier.name}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              // فلاتر التاريخ
              _buildDateFilters(),
              const SizedBox(height: 16),

              // زر التحميل
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadSupplierStatement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon:
                      _isLoading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.search),
                  label: Text(
                    _isLoading ? 'جاري التحميل...' : 'عرض كشف الحساب',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // الإحصائيات
              if (_statementItems.isNotEmpty) _buildStatistics(),
              const SizedBox(height: 16),

              // قائمة الفواتير المفصلة
              Expanded(child: _buildContentSection()),
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "الرصيد النهائي: ${_finalBalance.toStringAsFixed(2)} شيكل",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      _finalBalance > 0
                          ? Colors.red
                          : Colors.green, // أحمر = دين علينا
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إغلاق'),
                  ),
                  if (_statementItems.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _printStatement,
                      icon: const Icon(Icons.print),
                      label: const Text('طباعة الكشف'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تحديد الفترة الزمنية',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dateFromController,
                  decoration: InputDecoration(
                    labelText: 'من تاريخ',
                    labelStyle: const TextStyle(fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.calendar_today, size: 18),
                    isDense: true,
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
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _dateToController,
                  decoration: InputDecoration(
                    labelText: 'إلى تاريخ',
                    labelStyle: const TextStyle(fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.calendar_today, size: 18),
                    isDense: true,
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

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          const Text(
            "حدد التاريخ واضغط ع لى زر عرض كشف الحساب",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard('إجمالي المشتريات', _totalPurchases, Colors.blue),
          _buildStatCard('إجمالي المدفوع', _totalPaid, Colors.green),
          _buildStatCard('الرصيد النهائي', _finalBalance, Colors.red),
          _buildStatCard(
            'عدد الفواتير',
            _invoiceCount.toDouble(),
            Colors.purple,
            isCurrency: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    double value,
    Color color, {
    bool isCurrency = true,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          isCurrency
              ? "${value.toStringAsFixed(2)} شيكل"
              : value.toInt().toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'لا توجد حركات في الفترة المحددة',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
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
                  'مدين (سداد)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'دائن (شراء)',
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

              // في الموردين:
              // isCredit = True => دائن (دين علينا) => يظهر في عمود الدائن (شراء)
              // isCredit = False => مدين (سداد منا) => يظهر في عمود المدين (سداد)

              final bool isPurchase = item.isCredit;
              final bool isPayment = !item.isCredit;

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
                    // Debut (Payment)
                    Expanded(
                      flex: 2,
                      child: Text(
                        isPayment ? item.amount.toStringAsFixed(2) : "-",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    // Credit (Purchase)
                    Expanded(
                      flex: 2,
                      child: Text(
                        isPurchase ? item.amount.toStringAsFixed(2) : "-",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black, // or Red based on preference
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
                          color:
                              item.balance > 0
                                  ? Colors.red
                                  : Colors.green, // أحمر = مديونية علينا
                        ),
                      ),
                    ),
                    // Actions
                    if (isPurchase &&
                        item.items != null &&
                        item.items!.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.receipt_long,
                          size: 20,
                          color: Colors.blue,
                        ),
                        tooltip: "تفاصيل الفاتورة",
                        // Note: InvoiceDetailsDialog handles SalesInvoiceItem.
                        // We mapped Purchase items to SaleInvoiceItem, so this might work
                        // IF InvoiceDetailsDialog doesn't depend on other fields too much.
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
