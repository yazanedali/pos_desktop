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
      );

      // الحصول على العدد الكلي للفواتير (مع الفلترة)
      final totalCount = await _purchaseQueries.getPurchaseInvoicesCount(
        searchTerm:
            _searchController.text.isNotEmpty ? _searchController.text : null,
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
    });
    _loadInvoices(reset: true);
  }

  void _addInvoice(PurchaseInvoice invoice) async {
    try {
      await _purchaseQueries.insertPurchaseInvoice(invoice);
      TopAlert.showSuccess(
        context: context,
        message: "تم إضافة فاتورة الشراء ${invoice.invoiceNumber} بنجاح",
      );
      _refreshData();
    } catch (e) {
      TopAlert.showError(context: context, message: "حدث خطأ: ${e.toString()}");
    }
  }

  void _updateInvoice(PurchaseInvoice invoice) async {
    try {
      await _purchaseQueries.updatePurchaseInvoice(invoice);
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
            onSave: (updatedInvoice) {
              _updateInvoice(updatedInvoice);
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
            onSave: (invoice) {
              _addInvoice(invoice);
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
              child: _buildSearchCard(),
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

  Widget _buildSearchCard() {
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
                          onPressed: _clearFilters,
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'فلترة مفعلة',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _clearFilters,
                    child: const Text('مسح الفلترة'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
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
      ],
    );
  }

  Widget _buildInvoiceCard(PurchaseInvoice invoice) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                        child: Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${invoice.items.length} منتج",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${invoice.date} - ${invoice.time}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.business, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        invoice.supplier,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${invoice.total.toStringAsFixed(2)} شيكل",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _showInvoiceDetails(invoice),
                      child: const Text("عرض التفاصيل"),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => _showEditInvoiceDialog(invoice),
                      tooltip: 'تعديل الفاتورة',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteInvoice(invoice.id!),
                    ),
                  ],
                ),
              ],
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
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "لا توجد فواتير شراء حتى الآن",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            "قم بإضافة فاتورة شراء جديدة لتظهر هنا",
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
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
