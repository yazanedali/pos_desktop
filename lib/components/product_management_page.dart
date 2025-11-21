import 'package:flutter/material.dart';
import 'package:pos_desktop/components/product_dialog.dart';
import 'package:pos_desktop/widgets/category_management_bar.dart';
import 'package:pos_desktop/widgets/empty_state_widget.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../database/category_queries.dart';
import '../../database/product_queries.dart';
import '../widgets/product_grid.dart';
import '../widgets/top_alert.dart';

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
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
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

      final products = await _productQueries.getProductsPaginated(
        page: _currentPage,
        searchTerm:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        categoryId: _selectedCategoryId,
      );

      // الحصول على العدد الكلي للمنتجات (مع الفلترة)
      final totalCount = await _productQueries.getProductsCount(
        searchTerm:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        categoryId: _selectedCategoryId,
      );

      if (!mounted) return;

      setState(() {
        if (reset) {
          _products = products;
        } else {
          _products.addAll(products);
        }
        _totalProductsCount = totalCount;
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
      _searchController.clear();
    });
    _loadProducts(reset: true);
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
                  controller: _scrollController, // مهم!
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

                    // Products List Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildProductsHeader(),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 18)),

                    // Products Grid
                    _products.isEmpty
                        ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _buildEmptyState(),
                          ),
                        )
                        : SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: ProductGrid(
                              products: _products,
                              categories: _categories,
                              onEdit:
                                  (product) =>
                                      _showProductDialog(product: product),
                              onDelete: _deleteProduct,
                              hasMore: _hasMore,
                              isLoadingMore: _isLoadingMore,
                              onCategorySelected:
                                  _onCategorySelected, // دالة التعامل مع اختيار الفئة
                              selectedCategoryId:
                                  _selectedCategoryId, // الفئة المحددة حالياً
                            ),
                          ),
                        ),
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
            const SizedBox(height: 12),
            if (_selectedCategoryId != null ||
                _searchController.text.isNotEmpty)
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
        ),
      ),
    );
  }

  Widget _buildProductsHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.inventory_2, color: Colors.blue[800]),
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
            Text(
              "($_totalProductsCount)",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const Spacer(),
            if (_selectedCategoryId != null)
              Chip(
                label: Text(
                  'فئة: ${_categories.firstWhere((cat) => cat.id == _selectedCategoryId).name}',
                ),
                backgroundColor: Colors.blue[100],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchController.text.isNotEmpty || _selectedCategoryId != null) {
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
