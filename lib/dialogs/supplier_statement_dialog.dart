// dialogs/supplier_statement_dialog.dart
import 'package:flutter/material.dart';
import 'package:pos_desktop/models/supplier.dart';
import 'package:pos_desktop/database/purchase_queries.dart';
import 'package:pos_desktop/models/purchase_invoice.dart';
import 'package:pos_desktop/widgets/top_alert.dart';

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
  final PurchaseQueries _purchaseQueries = PurchaseQueries();

  List<PurchaseInvoice> _invoices = [];
  bool _isLoading = false;
  double _totalPurchases = 0.0;
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

  Future<void> _loadSupplierStatement() async {
    if (_dateFromController.text.isEmpty || _dateToController.text.isEmpty) {
      _showError('يرجى تحديد تاريخ البداية والنهاية');
      return;
    }

    setState(() {
      _isLoading = true;
      _invoices = [];
    });

    try {
      final invoices = await _purchaseQueries.getSupplierStatement(
        supplierId: widget.supplier.id!,
        startDate: _dateFromController.text,
        endDate: _dateToController.text,
      );

      double totalPurchases = 0.0;
      double totalPaid = 0.0;
      double totalRemaining = 0.0;

      for (final invoice in invoices) {
        totalPurchases += invoice.total;
        totalPaid += invoice.paidAmount;
        totalRemaining += invoice.remainingAmount;
      }

      setState(() {
        _invoices = invoices;
        _totalPurchases = totalPurchases;
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
      message: "تم إرسال كشف حساب ${widget.supplier.name} للطباعة",
    );
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
          width: MediaQuery.of(context).size.width * 0.8,
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
              if (_invoices.isNotEmpty) _buildStatistics(),
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
                "إجمالي الرصيد المستحق: ${_totalRemaining.toStringAsFixed(2)} شيكل",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _totalRemaining > 0 ? Colors.red : Colors.green,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إغلاق'),
                  ),
                  if (_invoices.isNotEmpty)
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

    if (_invoices.isEmpty && _dateFromController.text.isNotEmpty) {
      return _buildEmptyState();
    }

    if (_invoices.isNotEmpty) {
      return _buildDetailedInvoicesList();
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
          _buildStatCard('إجمالي المتبقي', _totalRemaining, Colors.red),
          _buildStatCard(
            'عدد الفواتير',
            _invoices.length.toDouble(),
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
            'لا توجد فواتير مشتريات في الفترة المحددة',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedInvoicesList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final invoice = _invoices[index];
        return _buildDetailedInvoiceItem(invoice);
      },
    );
  }

  Widget _buildDetailedInvoiceItem(PurchaseInvoice invoice) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.receipt,
                color: Colors.orange.shade800,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'فاتورة #${invoice.invoiceNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${invoice.date} | ${invoice.time}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            _buildStatusBadge(invoice.paymentStatus),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${invoice.total.toStringAsFixed(2)} شيكل',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                if (invoice.remainingAmount > 0)
                  Text(
                    'باقي: ${invoice.remainingAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const Text(
                  'تفاصيل المنتجات:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                _buildProductsList(invoice.items),
                if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "ملاحظات: ${invoice.notes}",
                      style: const TextStyle(
                        fontSize: 12,
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
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'مدفوع':
        color = Colors.green;
        break;
      case 'جزئي':
        color = Colors.orange;
        break;
      case 'غير مدفوع':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProductsList(List<PurchaseInvoiceItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    item.productName,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(
                    'x${item.quantity}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    item.purchasePrice.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${item.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
