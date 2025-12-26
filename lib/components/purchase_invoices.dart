import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/purchase_invoice.dart';
import 'purchase_invoice_dialog.dart';
import 'purchase_invoice_details_dialog.dart';
import '../database/purchase_queries.dart';
import '../database/category_queries.dart';
import '../widgets/top_alert.dart';

class PurchaseInvoices extends StatefulWidget {
  const PurchaseInvoices({super.key});

  @override
  State<PurchaseInvoices> createState() => _PurchaseInvoicesState();
}

class _PurchaseInvoicesState extends State<PurchaseInvoices> {
  final PurchaseQueries _purchaseQueries = PurchaseQueries();
  final CategoryQueries _categoryQueries = CategoryQueries();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<PurchaseInvoice> _invoices = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _totalInvoicesCount = 0;

  // فلتر حالة الدفع
  String _paymentStatusFilter = 'الكل';
  final List<String> _paymentStatusOptions = [
    'الكل',
    'مدفوع',
    'مدفوع جزئي',
    'غير مدفوع',
  ];

  @override
  void initState() {
    super.initState();
    _refreshData();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _loadInvoices(reset: true),
        _categoryQueries.getCategories(),
      ]);

      setState(() {
        _categories = results[1] as List<Category>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      TopAlert.showError(
        context: context,
        message: 'خطأ في تحميل البيانات: $e',
      );
    }
  }

  Future<void> _loadInvoices({bool reset = true}) async {
    try {
      if (reset) {
        setState(() {
          _currentPage = 1;
          _hasMore = true;
        });
      }

      final invoices = await _purchaseQueries.getPurchaseInvoicesPaginated(
        page: _currentPage,
        searchTerm:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        paymentStatus:
            _paymentStatusFilter != 'الكل' ? _paymentStatusFilter : null,
      );

      // الحصول على العدد الكلي للفواتير (مع الفلترة)
      final totalCount = await _purchaseQueries.getPurchaseInvoicesCount(
        searchTerm:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        paymentStatus:
            _paymentStatusFilter != 'الكل' ? _paymentStatusFilter : null,
      );

      if (!mounted) return;

      setState(() {
        if (reset) {
          _invoices = invoices;
        } else {
          _invoices.addAll(invoices);
        }
        _totalInvoicesCount = totalCount;
        _hasMore = invoices.length == PurchaseQueries.pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreInvoices() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    _currentPage++;
    await _loadInvoices(reset: false);
  }

  void _onSearch(String searchTerm) {
    _loadInvoices(reset: true);
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _paymentStatusFilter = 'الكل';
    });
    _loadInvoices(reset: true);
  }

  void _onPaymentStatusFilterChanged(String? newValue) {
    if (newValue != null) {
      setState(() {
        _paymentStatusFilter = newValue;
      });
      _loadInvoices(reset: true);
    }
  }

  void _addInvoice(PurchaseInvoice invoice, String updateMethod) async {
    // ← تحديث
    try {
      await _purchaseQueries.insertPurchaseInvoice(
        invoice,
        purchasePriceUpdateMethod: updateMethod, // ← تمرير الخيار
      );
      TopAlert.showSuccess(
        context: context,
        message: "تم إضافة فاتورة الشراء ${invoice.invoiceNumber} بنجاح",
      );
      _refreshData();
    } catch (e) {
      TopAlert.showError(context: context, message: "حدث خطأ: ${e.toString()}");
    }
  }

  void _updateInvoice(PurchaseInvoice invoice, String updateMethod) async {
    // ← تحديث
    try {
      await _purchaseQueries.updatePurchaseInvoice(
        invoice,
        purchasePriceUpdateMethod: updateMethod,
      );
      TopAlert.showSuccess(
        context: context,
        message: "تم تعديل الفاتورة ${invoice.invoiceNumber} بنجاح",
      );
      _refreshData();
    } catch (e) {
      TopAlert.showError(
        context: context,
        message: "حدث خطأ أثناء التعديل: ${e.toString()}",
      );
    }
  }

  void _showEditInvoiceDialog(PurchaseInvoice invoice) {
    showDialog(
      context: context,
      builder:
          (context) => PurchaseInvoiceDialog(
            categories: _categories,
            invoiceToEdit: invoice,
            onSave: (updatedInvoice, updateMethod) {
              // ← تحديث
              _updateInvoice(updatedInvoice, updateMethod);
              Navigator.of(context).pop();
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
    );
  }

  void _deleteInvoice(int id) async {
    try {
      await _purchaseQueries.deletePurchaseInvoice(id);
      TopAlert.showSuccess(context: context, message: "تم حذف الفاتورة بنجاح");
      _refreshData();
    } catch (e) {
      TopAlert.showError(
        context: context,
        message: "حدث خطأ أثناء الحذف: ${e.toString()}",
      );
    }
  }

  void _showInvoiceDetails(PurchaseInvoice invoice) {
    showDialog(
      context: context,
      builder:
          (context) => PurchaseInvoiceDetailsDialog(
            invoice: invoice,
            categories: _categories,
            onClose: () => Navigator.of(context).pop(),
          ),
    );
  }

  void _showAddInvoiceDialog() {
    showDialog(
      context: context,
      builder:
          (context) => PurchaseInvoiceDialog(
            categories: _categories,
            onSave: (invoice, updateMethod) {
              // ← تحديث هنا
              _addInvoice(invoice, updateMethod);
              Navigator.of(context).pop();
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_buildHeader(), const SizedBox(height: 16)],
            ),
          ),

          // Filters Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildFiltersCard(),
            ),
          ),

          // Invoices List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildListHeader(),
            ),
          ),

          // Invoices List
          _isLoading
              ? SliverToBoxAdapter(child: _buildLoadingState())
              : _invoices.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptyState())
              : SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index == _invoices.length) {
                    return _buildLoadMoreIndicator();
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildInvoiceCard(_invoices[index]),
                  );
                }, childCount: _invoices.length + (_hasMore ? 1 : 0)),
              ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue[100]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.blue[800]),
                const SizedBox(width: 8),
                const Text(
                  "فواتير المشتريات",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showAddInvoiceDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text("إضافة فاتورة شراء"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue[100]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // حقل البحث
            TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: "ابحث برقم الفاتورة أو اسم المورد...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // فلتر حالة الدفع
            Row(
              children: [
                const Icon(Icons.payment, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                const Text(
                  'حالة الدفع:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _paymentStatusFilter,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items:
                        _paymentStatusOptions.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                    onChanged: _onPaymentStatusFilterChanged,
                  ),
                ),
              ],
            ),

            // إظهار الفلاتر النشطة
            if (_searchController.text.isNotEmpty ||
                _paymentStatusFilter != 'الكل') ...[
              const SizedBox(height: 12),
              _buildActiveFilters(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilters() {
    final List<String> activeFilters = [];

    if (_searchController.text.isNotEmpty) {
      activeFilters.add('بحث: ${_searchController.text}');
    }

    if (_paymentStatusFilter != 'الكل') {
      activeFilters.add('حالة: $_paymentStatusFilter');
    }

    return Row(
      children: [
        Icon(Icons.filter_alt, size: 16, color: Colors.orange[700]),
        const SizedBox(width: 8),
        Text(
          'فلتر مفعل (${activeFilters.join('، ')})',
          style: TextStyle(
            color: Colors.orange[700],
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: _clearFilters,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: const Text('مسح الكل'),
        ),
      ],
    );
  }

  Widget _buildListHeader() {
    return Row(
      children: [
        Icon(Icons.receipt, color: Colors.blue[800]),
        const SizedBox(width: 8),
        const Text(
          "قائمة فواتير الشراء",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "($_totalInvoicesCount)",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const Spacer(),
        // إظهار ملخص الحالات
        _buildStatusSummary(),
      ],
    );
  }

  Widget _buildStatusSummary() {
    // حساب عدد الفواتير لكل حالة (من القائمة المرشحة)
    int paidCount =
        _invoices.where((inv) => inv.paymentStatus == 'مدفوع').length;
    int partialCount =
        _invoices
            .where(
              (inv) =>
                  inv.paymentStatus == 'مدفوع جزئي' ||
                  inv.paymentStatus == 'جزئي',
            )
            .length;
    int unpaidCount =
        _invoices.where((inv) => inv.paymentStatus == 'غير مدفوع').length;

    return Row(
      children: [
        _buildStatusBadge('مدفوعة', paidCount, Colors.green),
        const SizedBox(width: 8),
        _buildStatusBadge('جزئية', partialCount, Colors.orange),
        const SizedBox(width: 8),
        _buildStatusBadge('غير مدفوعة', unpaidCount, Colors.red),
      ],
    );
  }

  Widget _buildStatusBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(PurchaseInvoice invoice) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    // تحديد لون ونص حسب حالة الدفع
    switch (invoice.paymentStatus) {
      case 'مدفوع':
        statusColor = Colors.green;
        statusText = 'مدفوع كامل';
        statusIcon = Icons.check_circle;
        break;
      case 'جزئي':
      case 'مدفوع جزئي':
        statusColor = Colors.orange;
        statusText = 'مدفوع جزئي';
        statusIcon = Icons.paid;
        break;
      case 'غير مدفوع':
        statusColor = Colors.red;
        statusText = 'غير مدفوع';
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'غير معروف';
        statusIcon = Icons.help_outline;
    }

    // حساب نسبة الدفع
    double paymentPercentage =
        invoice.total > 0 ? (invoice.paidAmount / invoice.total) * 100 : 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصف العلوي: رقم الفاتورة والحالة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        invoice.invoiceNumber,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // بطاقة حالة الدفع
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // معلومات الفاتورة
            Row(
              children: [
                // معلومات المورد والتاريخ
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.business,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            invoice.supplier,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${invoice.date} - ${invoice.time}",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.inventory_2, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            "${invoice.items.length} منتج",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // المبالغ المالية
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${invoice.total.toStringAsFixed(2)} ش",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // عرض تفاصيل الدفع
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (invoice.paymentStatus == 'مدفوع')
                          Text(
                            'مدفوع بالكامل',
                            style: TextStyle(color: statusColor, fontSize: 12),
                          ),

                        if (invoice.paymentStatus == 'مدفوع جزئي' ||
                            invoice.paymentStatus == 'جزئي')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'مدفوع: ',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    "${invoice.paidAmount.toStringAsFixed(2)} ش",
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'باقي: ',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    "${invoice.remainingAmount.toStringAsFixed(2)} ش",
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              // شريط تقدم نسبة الدفع
                              Container(
                                width: 100,
                                height: 6,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: paymentPercentage / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                '${paymentPercentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),

                        if (invoice.paymentStatus == 'غير مدفوع')
                          Text(
                            'مديونية: ${invoice.total.toStringAsFixed(2)} ش',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),

            // أزرار التحكم
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showInvoiceDetails(invoice),
                    icon: const Icon(Icons.remove_red_eye, size: 18),
                    label: const Text("التفاصيل"),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showEditInvoiceDialog(invoice),
                    color: Colors.orange,
                    tooltip: 'تعديل الفاتورة',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () => _deleteInvoice(invoice.id!),
                    color: Colors.red,
                    tooltip: 'حذف الفاتورة',
                  ),
                ],
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
      child: Center(
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

  Widget _buildEmptyState() {
    IconData emptyIcon;
    String emptyMessage;
    String emptySubMessage;

    if (_paymentStatusFilter != 'الكل') {
      emptyIcon = Icons.filter_alt_off;
      emptyMessage = "لا توجد فواتير بحالة '$_paymentStatusFilter'";
      emptySubMessage = "حاول تغيير فلتر حالة الدفع";
    } else if (_searchController.text.isNotEmpty) {
      emptyIcon = Icons.search_off;
      emptyMessage = "لا توجد نتائج للبحث";
      emptySubMessage = "حاول البحث بكلمة أخرى";
    } else {
      emptyIcon = Icons.receipt;
      emptyMessage = "لا توجد فواتير شراء حتى الآن";
      emptySubMessage = "قم بإضافة فاتورة شراء جديدة لتظهر هنا";
    }

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(emptyIcon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            emptyMessage,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            emptySubMessage,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (_paymentStatusFilter != 'الكل' ||
              _searchController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearFilters,
              child: const Text('مسح الفلاتر'),
            ),
          ],
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
