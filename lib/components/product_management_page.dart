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

  List<Category> _categories = [];
  List<Product> _products = [];
  String _searchTerm = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _categoryQueries.getAllCategories(),
      _productQueries.getAllProducts(),
    ]);
    if (!mounted) return;
    setState(() {
      _categories = results[0] as List<Category>;
      _products = results[1] as List<Product>;
      _isLoading = false;
    });
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
            product: productWithPackages, // تمرير المنتج مع حزمه
            categories: _categories,
            onSave: (Product productToSave) async {
              Navigator.of(ctx).pop();
              try {
                if (product != null) {
                  await _productQueries.updateProduct(
                    product.id!,
                    productToSave,
                  );
                  // ... (رسالة النجاح)
                  TopAlert.showSuccess(
                    // ignore: use_build_context_synchronously
                    context: context,
                    message: "تم تحديث المنتج '${productToSave.name}' بنجاح",
                  );
                } else {
                  await _productQueries.createProduct(productToSave);
                  // ... (رسالة النجاح)
                  TopAlert.showSuccess(
                    // ignore: use_build_context_synchronously
                    context: context,
                    message: "تم إضافة المنتج '${productToSave.name}' بنجاح",
                  );
                }
                await _loadData();
              } catch (e) {
                TopAlert.showError(
                  // ignore: use_build_context_synchronously
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
                    // ignore: use_build_context_synchronously
                    context: context,
                    message: "تم حذف المنتج '$productName' بنجاح",
                  );
                  await _loadData();
                } catch (e) {
                  TopAlert.showError(
                    // ignore: use_build_context_synchronously
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

  // --- === 1. تعديل منطق البحث ليشمل الباركود والفئة === ---
  List<Product> get _filteredProducts {
    if (_searchTerm.isEmpty) return _products;

    final lowerCaseSearchTerm = _searchTerm.toLowerCase();

    return _products.where((product) {
      // البحث في اسم المنتج
      final nameMatch = product.name.toLowerCase().contains(
        lowerCaseSearchTerm,
      );

      // البحث في الباركود (مع التحقق من أنه ليس null)
      final barcodeMatch = (product.barcode ?? '').toLowerCase().contains(
        lowerCaseSearchTerm,
      );

      // البحث في اسم الفئة
      // أولاً، نجد الفئة المرتبطة بالمنتج
      final category = _categories.firstWhere(
        (cat) => cat.id == product.categoryId,
        orElse:
            () => Category(
              id: 0,
              name: '',
              color: '',
            ), // fallback آمن في حال لم يتم العثور على الفئة
      );
      // ثانياً، نقارن اسم الفئة
      final categoryMatch = category.name.toLowerCase().contains(
        lowerCaseSearchTerm,
      );

      // إرجاع المنتج إذا تطابق أي من الشروط الثلاثة
      return nameMatch || barcodeMatch || categoryMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(24.0),
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
                  _buildProductsContent(),
                ],
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

  // --- === 2. تعديل النص الإرشادي في مربع البحث === ---
  Widget _buildSearchCard() {
    return TextField(
      onChanged: (value) => setState(() => _searchTerm = value),
      decoration: InputDecoration(
        hintText: "ابحث بالاسم, الباركود, أو الفئة...",
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[200],
      ),
    );
  }

  Widget _buildProductsContent() {
    if (_products.isEmpty) {
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

    if (_filteredProducts.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.search_off,
        title: "لا توجد نتائج مطابقة",
        message: "حاول استخدام كلمات بحث مختلفة للعثور على ما تبحث عنه.",
      );
    }
    return ProductGrid(
      products: _filteredProducts,
      categories: _categories,
      onEdit: (product) => _showProductDialog(product: product),
      onDelete: _deleteProduct,
    );
  }
}
