import 'package:flutter/material.dart';
import 'package:pos_desktop/components/product_dialog.dart';
import 'package:pos_desktop/widgets/category_management_bar.dart';
import 'package:pos_desktop/widgets/empty_state_widget.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../database/category_queries.dart';
import '../../database/product_queries.dart';
import '../widgets/product_category_filter.dart';
import '../widgets/product_table_header.dart';
import '../widgets/product_table_row.dart';
import '../widgets/top_alert.dart';

enum StockFilterOption {
  all('الكل'),
  outOfStock('نفذ من المخزون'),
  lowStock('مخزون منخفض'),
  inStock('متوفر بالمخزون');

  final String label;
  const StockFilterOption(this.label);
}

class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({super.key});

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  final CategoryQueries _categoryQueries = CategoryQueries();
  final ProductQueries _productQueries = ProductQueries();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Category> _categories = [];
  List<Product> _products = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _totalProductsCount = 0;

  // متغيرات الفلترة
  int? _selectedCategoryId;
  StockFilterOption _selectedStockFilter = StockFilterOption.all;

  // متغيرات للإحصائيات
  double _totalPurchaseValue = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
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
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreProducts();
      }
    });
  }

  void _onCategorySelected(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _loadProducts(reset: true);
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _categoryQueries.getAllCategories(),
      _loadProducts(reset: true),
    ]);

    if (!mounted) return;
    setState(() {
      _categories = results[0] as List<Category>;
      _isLoading = false;
    });
  }

  Future<void> _loadProducts({bool reset = true}) async {
    try {
      if (reset) {
        setState(() {
          _currentPage = 1;
          _hasMore = true;
        });
      }

      // تحديد فلتر المخزون للاستعلام
      String? stockFilter;
      switch (_selectedStockFilter) {
        case StockFilterOption.outOfStock:
          stockFilter = 'out';
          break;
        case StockFilterOption.lowStock:
          stockFilter = 'low';
          break;
        case StockFilterOption.inStock:
          stockFilter = 'in';
          break;
        case StockFilterOption.all:
          stockFilter = null;
      }

      final products = await _productQueries.getProductsPaginated(
        page: _currentPage,
        searchTerm:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        categoryId: _selectedCategoryId,
        stockFilter: stockFilter,
      );

      // الحصول على العدد الكلي للمنتجات (مع الفلترة)
      final totalCount = await _productQueries.getProductsCount(
        searchTerm:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        categoryId: _selectedCategoryId,
        stockFilter: stockFilter,
      );

      // الحصول على إجمالي سعر الشراء لجميع المنتجات (مع الفلاتر)
      final totalPurchase = await _productQueries.getTotalPurchaseValue(
        searchTerm:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        categoryId: _selectedCategoryId,
        stockFilter: stockFilter,
      );

      if (!mounted) return;

      setState(() {
        if (reset) {
          _products = products;
        } else {
          _products.addAll(products);
        }
        _totalProductsCount = totalCount;
        _totalPurchaseValue = totalPurchase;
        _hasMore = products.length == ProductQueries.pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });

      TopAlert.showError(
        context: context,
        message: 'حدث خطأ أثناء تحميل المنتجات',
      );
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    _currentPage++;
    await _loadProducts(reset: false);
  }

  void _showProductDialog({Product? product}) async {
    Product productWithPackages = product ?? Product(name: '', price: 0.0);

    // إذا كان المنتج موجوداً، قم بجلب حزمه
    if (product != null && product.id != null) {
      final packages = await _productQueries.getPackagesForProduct(product.id!);
      productWithPackages.packages = packages;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (ctx) => ProductDialog(
            product: productWithPackages,
            categories: _categories,
            onSave: (Product productToSave) async {
              Navigator.of(ctx).pop();
              try {
                if (product != null) {
                  await _productQueries.updateProduct(
                    product.id!,
                    productToSave,
                  );
                  TopAlert.showSuccess(
                    context: context,
                    message: "تم تحديث المنتج '${productToSave.name}' بنجاح",
                  );
                } else {
                  await _productQueries.createProduct(productToSave);
                  TopAlert.showSuccess(
                    context: context,
                    message: "تم إضافة المنتج '${productToSave.name}' بنجاح",
                  );
                }
                await _loadProducts(reset: true);
              } catch (e) {
                TopAlert.showError(
                  context: context,
                  message: "حدث خطأ أثناء الحفظ: $e",
                );
              }
            },
            onCancel: () => Navigator.of(ctx).pop(),
          ),
    );
  }

  Future<void> _deleteProduct(int id) async {
    final productToDelete = _products.firstWhere((p) => p.id == id);
    final productName = productToDelete.name;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text("تأكيد الحذف"),
          content: Text(
            "هل أنت متأكد من رغبتك في حذف المنتج '$productName' بشكل نهائي؟\n\nلا يمكن التراجع عن هذا الإجراء.",
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("إلغاء"),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("نعم، قم بالحذف"),
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await _productQueries.deleteProduct(id);
                  TopAlert.showSuccess(
                    context: context,
                    message: "تم حذف المنتج '$productName' بنجاح",
                  );
                  await _loadProducts(reset: true);
                } catch (e) {
                  TopAlert.showError(
                    context: context,
                    message: "حدث خطأ أثناء الحذف: $e",
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _onSearch(String value) {
    _loadProducts(reset: true);
  }

  void _clearFilters() {
    setState(() {
      _selectedCategoryId = null;
      _selectedStockFilter = StockFilterOption.all;
      _searchController.clear();
    });
    _loadProducts(reset: true);
  }

  // دالة مساعدة للحصول على أيقونة فلتر المخزون
  IconData _getStockFilterIcon(StockFilterOption option) {
    switch (option) {
      case StockFilterOption.outOfStock:
        return Icons.error_outline;
      case StockFilterOption.lowStock:
        return Icons.warning_amber_outlined;
      case StockFilterOption.inStock:
        return Icons.check_circle_outline;
      default:
        return Icons.all_inbox;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadData,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 20),
                            CategoryManagementBar(
                              categories: _categories,
                              onCategoriesUpdate: _loadData,
                            ),
                            const SizedBox(height: 20),
                            _buildSearchCard(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // Products List Header & Filters
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            _buildProductsHeader(),
                            const SizedBox(height: 16),
                            ProductCategoryFilter(
                              categories: _categories,
                              selectedCategoryId: _selectedCategoryId,
                              onCategorySelected: _onCategorySelected,
                            ),
                            const SizedBox(height: 16),
                            // فلتر المخزون تحت فلتر الفئة
                            _buildStockFilterSection(),
                          ],
                        ),
                      ),
                    ),

                    // بطاقة سعر الشراء الصغيرة فوق الجدول
                    if (_products.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildPurchasePriceCard(),
                        ),
                      ),

                    // Table Header
                    if (_products.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            child: const ProductTableHeader(),
                          ),
                        ),
                      ),

                    // Products List (SliverList for Lazy Loading)
                    _products.isEmpty
                        ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _buildEmptyState(),
                          ),
                        )
                        : SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            if (index == _products.length) {
                              if (_isLoadingMore) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }
                            final product = _products[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: ProductTableRow(
                                product: product,
                                categories: _categories,
                                onEdit: (p) => _showProductDialog(product: p),
                                onDelete: (id) => _deleteProduct(id),
                                index: index,
                              ),
                            );
                          }, childCount: _products.length + 1),
                        ),

                    const SliverToBoxAdapter(child: SizedBox(height: 48)),
                  ],
                ),
              ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "إدارة المنتجات",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showProductDialog(),
          icon: const Icon(Icons.add),
          label: const Text("إضافة منتج جديد"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: "ابحث بالاسم, الباركود, أو الفئة...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearFilters,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsHeader() {
    return Column(
      children: [
        // بطاقة عدد المنتجات فقط
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.table_chart_outlined, color: Colors.blue[800]),
                const SizedBox(width: 8),
                const Text(
                  "قائمة المنتجات",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$_totalProductsCount",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // فلتر المخزون كقسم منفصل
  Widget _buildStockFilterSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'فلترة حسب المخزون',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  StockFilterOption.values.map((option) {
                    bool isSelected = _selectedStockFilter == option;
                    Color color;

                    switch (option) {
                      case StockFilterOption.outOfStock:
                        color = Colors.red;
                        break;
                      case StockFilterOption.lowStock:
                        color = Colors.orange;
                        break;
                      case StockFilterOption.inStock:
                        color = Colors.green;
                        break;
                      default:
                        color = Colors.blue;
                    }

                    return FilterChip(
                      label: Text(option.label),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedStockFilter = option;
                        });
                        _loadProducts(reset: true);
                      },
                      backgroundColor:
                          isSelected ? color.withOpacity(0.2) : Colors.white,
                      selectedColor: color.withOpacity(0.3),
                      checkmarkColor: color,
                      labelStyle: TextStyle(
                        color: isSelected ? color : Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? color : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      avatar: Icon(
                        _getStockFilterIcon(option),
                        size: 16,
                        color: isSelected ? color : Colors.grey,
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // بطاقة سعر الشراء الصغيرة فوق الجدول
  Widget _buildPurchasePriceCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.paid_outlined, size: 18, color: Colors.purple[700]),
          const SizedBox(width: 8),
          Text(
            "إجمالي سعر الشراء: ",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.purple[700],
            ),
          ),
          Text(
            "${_totalPurchaseValue.toStringAsFixed(2)} شيكل",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchController.text.isNotEmpty ||
        _selectedCategoryId != null ||
        _selectedStockFilter != StockFilterOption.all) {
      return const EmptyStateWidget(
        icon: Icons.search_off,
        title: "لا توجد نتائج مطابقة",
        message: "حاول استخدام كلمات بحث مختلفة أو مسح الفلترة.",
      );
    }

    return EmptyStateWidget(
      icon: Icons.inventory_2_outlined,
      title: "لا توجد منتجات بعد",
      message: "ابدأ بإضافة أول منتج لك لإدارة المخزون بسهولة.",
      actionButton: ElevatedButton.icon(
        onPressed: () => _showProductDialog(),
        icon: const Icon(Icons.add),
        label: const Text("إضافة أول منتج"),
      ),
    );
  }
}
