// pages/sales_invoices.dart
import 'package:flutter/material.dart';
import '../models/sales_invoice.dart';
import '../services/sales_invoice_service.dart';
import './sales_invoices/invoice_card.dart';
import './sales_invoices/invoice_details_dialog.dart';
import './sales_invoices/empty_state.dart';
import '../widgets/top_alert.dart';

class SalesInvoices extends StatefulWidget {
  const SalesInvoices({super.key});

  @override
  State<SalesInvoices> createState() => _SalesInvoicesState();
}

class _SalesInvoicesState extends State<SalesInvoices> {
  final SalesInvoiceService _invoiceService = SalesInvoiceService();
  List<SaleInvoice> _invoices = [];
  SaleInvoice? _selectedInvoice;
  bool _isLoading = true;
  bool _isDialogOpen = false;
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _loadInvoices();
    _loadStatistics();
  }

  Future<void> _loadInvoices() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final invoices = await _invoiceService.getAllSalesInvoices();
      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // استخدام البيانات الوهمية في حالة الخطأ
      setState(() {
        _invoices = SalesInvoiceService.getMockSalesInvoices();
        _isLoading = false;
      });

      TopAlert.showError(
        // ignore: use_build_context_synchronously
        context: context,
        message: 'حدث خطأ أثناء تحميل الفواتير. عرض بيانات وهمية.',
      );
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _invoiceService.getSalesStatistics();
      setState(() {
        _statistics = stats;
      });
    } catch (e) {
      // ignore: use_build_context_synchronously, avoid_print
      print('Error loading statistics: $e');
    }
  }

  void _showInvoiceDetails(SaleInvoice invoice) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return InvoiceDetailsDialog(
          invoice: invoice,
          onClose: () {
            Navigator.of(dialogContext).pop();
          },
          onPrint: () {
            Navigator.of(dialogContext).pop(); // أغلق النافذة أولاً
            _printInvoice(invoice); // ثم نفذ عملية الطباعة
          },
        );
      },
    );
  }

  void _closeDialog() {
    setState(() {
      _isDialogOpen = false;
      _selectedInvoice = null;
    });
  }

  void _printInvoice(SaleInvoice invoice) {
    TopAlert.showSuccess(
      context: context,
      message: 'تم إرسال فاتورة ${invoice.invoiceNumber} للطباعة',
    );
  }

  Future<void> _refreshData() async {
    await _loadInvoices();
    await _loadStatistics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with Statistics
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
                            "فواتير المبيعات",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _refreshData,
                            icon: const Icon(Icons.refresh),
                            tooltip: 'تحديث',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Statistics
                      _buildStatistics(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Invoices List Card
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
                          Icon(Icons.receipt, color: Colors.blue[800]),
                          const SizedBox(width: 8),
                          const Text(
                            "قائمة الفواتير",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "(${_invoices.length})",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _isLoading
                          ? _buildLoadingState()
                          : _invoices.isEmpty
                          ? const EmptyInvoicesState()
                          : _buildInvoicesList(),
                    ],
                  ),
                ),
              ),

              // Invoice Details Dialog
              if (_isDialogOpen && _selectedInvoice != null)
                InvoiceDetailsDialog(
                  invoice: _selectedInvoice!,
                  onClose: _closeDialog,
                  onPrint: () => _printInvoice(_selectedInvoice!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStatItem(
              'إجمالي الفواتير',
              '${_statistics['totalInvoices'] ?? 0}',
              Icons.receipt,
              Colors.blue,
            ),
            const SizedBox(width: 16),
            _buildStatItem(
              'إجمالي المبيعات',
              '${(_statistics['totalSales'] ?? 0.0).toStringAsFixed(2)} شيكل',
              Icons.attach_money,
              Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildStatItem(
              'متوسط الفاتورة',
              '${(_statistics['averageInvoice'] ?? 0.0).toStringAsFixed(2)} شيكل',
              Icons.analytics,
              Colors.orange,
            ),
            const SizedBox(width: 16),
            _buildStatItem(
              'مبيعات اليوم',
              '${(_statistics['todaySales'] ?? 0.0).toStringAsFixed(2)} شيكل',
              Icons.today,
              Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // ignore: deprecated_member_use
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          // ignore: deprecated_member_use
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تحميل الفواتير...'),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        return InvoiceCard(
          invoice: _invoices[index],
          onTap: () => _showInvoiceDetails(_invoices[index]),
        );
      },
    );
  }
}
