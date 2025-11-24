// dialogs/customer_statement_dialog.dart
import 'package:flutter/material.dart';
import 'package:pos_desktop/models/customer.dart';
import 'package:pos_desktop/services/sales_invoice_service.dart';
import 'package:pos_desktop/models/sales_invoice.dart';
import 'package:pos_desktop/widgets/top_alert.dart';

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

  List<SaleInvoice> _invoices = [];
  bool _isLoading = false;
  double _totalSales = 0.0;
  double _totalPaid = 0.0;
  double _totalRemaining = 0.0;

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
      _invoices = [];
    });

    try {
      final invoices = await _invoiceService.getCustomerStatement(
        customerId: widget.customer.id!,
        startDate: _dateFromController.text,
        endDate: _dateToController.text,
      );

      double totalSales = 0.0;
      double totalPaid = 0.0;
      double totalRemaining = 0.0;

      for (final invoice in invoices) {
        totalSales += invoice.total;
        totalPaid += invoice.paidAmount;
        totalRemaining += invoice.remainingAmount;
      }

      setState(() {
        _invoices = invoices;
        _totalSales = totalSales;
        _totalPaid = totalPaid;
        _totalRemaining = totalRemaining;
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

  void _printStatement() {
    TopAlert.showSuccess(
      // ignore: use_build_context_synchronously
      context: context,
      message: "تم إرسال كشف حساب ${widget.customer.name} للطباعة",
    );
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
          width: MediaQuery.of(context).size.width * 0.95, // عرض أكبر
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
              if (_invoices.isNotEmpty) _buildStatistics(),
              const SizedBox(height: 16),

              // قائمة الفواتير المفصلة
              Expanded(child: _buildContentSection()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
          if (_invoices.isNotEmpty)
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

    if (_invoices.isEmpty && _dateFromController.text.isNotEmpty) {
      return _buildEmptyState();
    }

    if (_invoices.isNotEmpty) {
      return _buildDetailedInvoicesList();
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
          children: [
            _buildStatItem('إجمالي المبيعات', _totalSales, Colors.blue),
            _buildStatItem('إجمالي المدفوع', _totalPaid, Colors.green),
            _buildStatItem(
              'إجمالي المتبقي',
              _totalRemaining,
              _totalRemaining > 0 ? Colors.orange : Colors.grey,
            ),
            _buildStatItem(
              'عدد الفواتير',
              _invoices.length.toDouble(),
              Colors.purple,
            ),
            _buildStatItem(
              'إجمالي المنتجات',
              _getTotalProductsCount().toDouble(),
              Colors.teal,
            ),
          ],
        ),
      ),
    );
  }

  int _getTotalProductsCount() {
    int total = 0;
    for (final invoice in _invoices) {
      total += invoice.items.length;
    }
    return total;
  }

  Widget _buildStatItem(String title, double value, Color color) {
    return Container(
      width: 150,
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
            value % 1 == 0
                ? value.toInt().toString()
                : value.toStringAsFixed(2),
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
              Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'لا توجد فواتير في الفترة المحددة',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedInvoicesList() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final invoice = _invoices[index];
        return _buildDetailedInvoiceItem(invoice);
      },
    );
  }

  Widget _buildDetailedInvoiceItem(SaleInvoice invoice) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس الفاتورة
            _buildInvoiceHeader(invoice),
            const SizedBox(height: 16),

            // جدول المنتجات
            _buildProductsTable(invoice.items),
            const SizedBox(height: 16),

            // ملخص الفاتورة
            _buildInvoiceSummary(invoice),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceHeader(SaleInvoice invoice) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'فاتورة رقم: ${invoice.invoiceNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'التاريخ: ${invoice.date} - الوقت: ${invoice.time}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  'الكاشير: ${invoice.cashier}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(invoice.paymentStatus),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              invoice.paymentStatus,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTable(List<SaleInvoiceItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المنتجات المشتراة:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // رأس الجدول
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'اسم المنتج',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'الوحدة',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'السعر',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'الكمية',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'الإجمالي',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),

              // جسم الجدول
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border:
                          index < items.length - 1
                              ? Border(
                                bottom: BorderSide(color: Colors.grey[200]!),
                              )
                              : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            item.productName,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.unitName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${item.price.toStringAsFixed(2)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${item.quantity.toStringAsFixed(2)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${item.total.toStringAsFixed(2)} شيكل',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceSummary(SaleInvoice invoice) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'عدد المنتجات: ${invoice.items.length}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                'طريقة الدفع: ${invoice.paymentMethod}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Text(
                    'المبلغ الإجمالي:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${invoice.total.toStringAsFixed(2)} شيكل',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'المبلغ المدفوع:',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          invoice.paidAmount == invoice.total
                              ? Colors.green
                              : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${invoice.paidAmount.toStringAsFixed(2)} شيكل',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color:
                          invoice.paidAmount == invoice.total
                              ? Colors.green
                              : Colors.orange,
                    ),
                  ),
                ],
              ),
              if (invoice.remainingAmount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text(
                      'المبلغ المتبقي:',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${invoice.remainingAmount.toStringAsFixed(2)} شيكل',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'مدفوع':
        return Colors.green;
      case 'جزئي':
        return Colors.orange;
      case 'غير مدفوع':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
