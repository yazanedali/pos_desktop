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
  final ScrollController _scrollController = ScrollController();

  List<SaleInvoice> _invoices = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  Map<String, dynamic> _statistics = {};

  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  int _totalInvoicesCount = 0;
  @override
  void initState() {
    super.initState();
    _loadInvoices();
    _loadStatistics();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _loadMoreInvoices();
      }
    });
  }

  Future<void> _loadInvoices({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
      });
    }

    try {
      // استخدام الدالة الموحدة لجلب البيانات، وتمرير قيمة البحث
      final invoices = await _invoiceService.getSalesInvoicesPaginated(
        page: _currentPage,
        startDate:
            _dateFromController.text.isNotEmpty
                ? _dateFromController.text
                : null,
        endDate:
            _dateToController.text.isNotEmpty ? _dateToController.text : null,
        searchTerm:
            _searchController.text.isNotEmpty
                ? _searchController.text
                : null, // <-- أضف هذا
      );

      final totalCount = await _invoiceService.getInvoicesCount(
        startDate:
            _dateFromController.text.isNotEmpty
                ? _dateFromController.text
                : null,
        endDate:
            _dateToController.text.isNotEmpty ? _dateToController.text : null,
        searchTerm:
            _searchController.text.isNotEmpty
                ? _searchController.text
                : null, // <-- أضف هذا
      );

      setState(() {
        if (reset) {
          _invoices = invoices;
        } else {
          _invoices.addAll(invoices);
        }
        _totalInvoicesCount = totalCount;
        _hasMore = invoices.length == SalesInvoiceService.pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });

      TopAlert.showError(
        context: context,
        message:
            'حدث خطأ أثناء تحميل الفواتير. ${reset ? 'عرض بيانات وهمية.' : ''}',
      );
    }
  }

  Future<void> _loadMoreInvoices() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    setState(() {
      _isLoadingMore = true;
    });

    _currentPage++;
    await _loadInvoices(reset: false);
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _invoiceService.getSalesStatistics();
      setState(() {
        _statistics = stats;
      });
    } catch (e) {
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
            Navigator.of(dialogContext).pop();
            _printInvoice(invoice);
          },
          coustomerName: invoice.customerName ?? 'عميل نقدي',
        );
      },
    );
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

  String _getFormattedDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _clearFilters() {
    setState(() {
      _dateFromController.clear();
      _dateToController.clear();
      _searchController.clear();
    });
    _loadInvoices();
  }

  void _searchInvoices() {
    _loadInvoices(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
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
                                Icon(
                                  Icons.description,
                                  color: Colors.blue[800],
                                ),
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
                            _buildStatistics(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filters Card
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
                            const Text(
                              "فلترة الفواتير",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildFilters(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Invoices List
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
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
                              "($_totalInvoicesCount)", // استخدام العدد الكلي بدلاً من length
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            _isLoading
                ? SliverToBoxAdapter(child: _buildLoadingState())
                : _invoices.isEmpty
                ? SliverToBoxAdapter(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: EmptyInvoicesState(),
                  ),
                )
                : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index == _invoices.length) {
                      return _buildLoadMoreIndicator();
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: InvoiceCard(
                        invoice: _invoices[index],
                        onTap: () => _showInvoiceDetails(_invoices[index]),
                        customerName:
                            _invoices[index].customerName ?? 'عميل نقدي',
                      ),
                    );
                  }, childCount: _invoices.length + (_hasMore ? 1 : 0)),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText:
                'ابحث برقم الفاتورة، اسم الكاشير، أو اسم العميل...', // <-- عدل النص
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _loadInvoices();
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onSubmitted: (_) => _searchInvoices(),
        ),
        const SizedBox(height: 12),

        // Date Range Filter
        Row(
          children: [
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
                    setState(() {
                      _dateFromController.text = _getFormattedDate(date);
                    });
                    _loadInvoices();
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
                    setState(() {
                      _dateToController.text = _getFormattedDate(date);
                    });
                    _loadInvoices();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _searchInvoices,
                icon: const Icon(Icons.search),
                label: const Text('بحث'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('مسح الكل'),
              ),
            ),
          ],
        ),
      ],
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
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
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('جاري تحميل الفواتير...'),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return _isLoadingMore
        ? const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        )
        : const SizedBox.shrink();
  }
}
