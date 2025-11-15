import 'package:flutter/material.dart';
import 'package:pos_desktop/database/category_queries.dart'; // 1. استيراد كويري الفئات
import 'package:pos_desktop/database/product_queries.dart';
import 'package:pos_desktop/models/cart_item.dart';
import 'package:pos_desktop/models/category.dart'; // 2. استيراد مودل الفئة
import 'package:pos_desktop/models/product.dart';
import 'package:pos_desktop/services/sales_service.dart';
import './sales/barcode_reader.dart';
import './sales/products_grid.dart';
import './sales/shopping_cart.dart';
import '../widgets/top_alert.dart';

class SalesInterface extends StatefulWidget {
  const SalesInterface({super.key});

  @override
  State<SalesInterface> createState() => _SalesInterfaceState();
}

class _SalesInterfaceState extends State<SalesInterface> {
  final ProductQueries _productQueries = ProductQueries();
  final CategoryQueries _categoryQueries =
      CategoryQueries(); // 3. إضافة كويري الفئات
  final SalesService _salesService = SalesService();

  List<Product> _products = [];
  List<Category> _categories = []; // 4. إضافة قائمة لتخزين الفئات
  final List<CartItem> _cartItems = [];

  bool _isLoading = true;
  bool _isProcessingSale = false;

  // void _showTopAlert(String message, {bool isError = false}) {
  //   // إنشاء OverlayEntry
  //   OverlayEntry? overlayEntry;
  //   overlayEntry = OverlayEntry(
  //     builder:
  //         (context) => Positioned(
  //           top: 50, // المسافة من الأعلى
  //           left: MediaQuery.of(context).size.width * 0.3, // لجعلها في المنتصف
  //           right: MediaQuery.of(context).size.width * 0.3,
  //           child: Material(
  //             color: Colors.transparent,
  //             child: Container(
  //               padding: const EdgeInsets.symmetric(
  //                 horizontal: 16,
  //                 vertical: 12,
  //               ),
  //               decoration: BoxDecoration(
  //                 color: isError ? Colors.red : Colors.green,
  //                 borderRadius: BorderRadius.circular(8),
  //                 boxShadow: [
  //                   BoxShadow(
  //                     color: Colors.black26,
  //                     blurRadius: 10,
  //                     offset: Offset(0, 2),
  //                   ),
  //                 ],
  //               ),
  //               child: Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   Expanded(
  //                     child: Text(
  //                       message,
  //                       style: TextStyle(color: Colors.white, fontSize: 14),
  //                       overflow: TextOverflow.ellipsis,
  //                     ),
  //                   ),
  //                   IconButton(
  //                     icon: Icon(Icons.close, color: Colors.white, size: 18),
  //                     onPressed: () {
  //                       overlayEntry?.remove();
  //                     },
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ),
  //   );

  //   // إضافة الـ Overlay
  //   Overlay.of(context).insert(overlayEntry);

  //   // إزالة التلقائية بعد مدة قصيرة
  //   Future.delayed(Duration(seconds: 2), () {
  //     if (overlayEntry?.mounted == true) {
  //       overlayEntry?.remove();
  //     }
  //   });
  // }

  @override
  void initState() {
    super.initState();
    _refreshData(); // استدعاء دالة واحدة لتحميل كل البيانات
  }

  // 5. دالة محدثة لتحميل المنتجات والفئات معًا
  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _productQueries.getAllProducts(),
        _categoryQueries.getAllCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<Product>;
        _categories = results[1] as List<Category>;
      });
    } catch (e) {
      TopAlert.showError(
        context: context,
        message: 'خطأ في تحميل البيانات: $e',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final productsFromDb = await _productQueries.getAllProducts();
    if (!mounted) return;
    setState(() {
      _products = productsFromDb;
      _isLoading = false;
    });
  }

  void _addToCart(Product product) {
    // التحقق من المخزون قبل الإضافة
    if (product.stock <= 0) {
      TopAlert.showError(
        context: context,
        message: 'لا يوجد مخزون كافي لـ ${product.name}',
      );

      return;
    }

    setState(() {
      final existingItemIndex = _cartItems.indexWhere(
        (item) => item.id == product.id,
      );

      if (existingItemIndex != -1) {
        final existingItem = _cartItems[existingItemIndex];
        // التحقق من أن الكمية الجديدة لا تتجاوز المخزون
        if (existingItem.quantity + 1 > product.stock) {
          TopAlert.showError(
            context: context,
            message: 'الكمية المطلوبة تتجاوز المخزون المتاح لـ ${product.name}',
          );
          return;
        }
        _cartItems[existingItemIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + 1,
        );
      } else {
        _cartItems.add(
          CartItem(
            id: product.id,
            name: product.name,
            price: product.price,
            quantity: 1,
            barcode: product.barcode,
            stock: product.stock,
          ),
        );
      }
    });

    TopAlert.showSuccess(
      context: context,
      message: 'تم إضافة ${product.name} إلى السلة',
    );
  }

  void _updateQuantity(int productId, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        _cartItems.removeWhere((item) => item.id == productId);
      } else {
        final itemIndex = _cartItems.indexWhere((item) => item.id == productId);
        if (itemIndex != -1) {
          final item = _cartItems[itemIndex];
          final product = _products.firstWhere((p) => p.id == productId);

          // التحقق من أن الكمية الجديدة لا تتجاوز المخزون
          if (newQuantity > product.stock) {
            TopAlert.showError(
              context: context,
              message:
                  'الكمية المطلوبة تتجاوز المخزون المتاح لـ ${product.name}',
            );
            return;
          }

          _cartItems[itemIndex] = item.copyWith(quantity: newQuantity);
        }
      }
    });
  }

  void _removeFromCart(int productId) {
    setState(() {
      _cartItems.removeWhere((item) => item.id == productId);
    });
  }

  // تحديث دالة handleCheckout
  Future<void> _handleCheckout() async {
    if (_cartItems.isEmpty) {
      TopAlert.showError(context: context, message: 'السلة فارغة');

      return;
    }

    try {
      setState(() {
        _isProcessingSale = true;
      });

      // إنشاء الفاتورة في قاعدة البيانات
      final invoiceNumber = await _salesService.createSaleInvoice(
        cartItems: _cartItems,
        cashier: "كاشير", // يمكنك تغيير هذا ليكون ديناميكي
      );

      final total = _cartItems.fold(
        0.0,
        (sum, item) => sum + (item.price * item.quantity),
      );

      TopAlert.showSuccess(
        // ignore: use_build_context_synchronously
        context: context,
        message:
            'تمت عملية البيع بنجاح - رقم الفاتورة: $invoiceNumber - المبلغ: ${total.toStringAsFixed(2)} شيكل',
      );
      // تفريغ السلة
      setState(() {
        _cartItems.clear();
        _isProcessingSale = false;
      });

      // إعادة تحميل المنتجات لتحديث المخزون
      await _loadProducts();
    } catch (e) {
      setState(() {
        _isProcessingSale = false;
      });

      // ignore: use_build_context_synchronously
      TopAlert.showError(context: context, message: 'خطأ في إتمام البيع: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      // تم نقل الـ Padding إلى هنا ليكون حول كل العناصر
      padding: const EdgeInsets.fromLTRB(8, 24, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- القسم الأيسر (المنتجات) ---
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // قارئ الباركود أصبح داخل حاوية خاصة به
                BarcodeReader(
                  onProductScanned: _addToCart,
                  products: _products,
                ),
                const SizedBox(height: 16),
                // شبكة المنتجات
                Expanded(
                  child: ProductsGrid(
                    products: _products,
                    categories: _categories, // 7. تمرير قائمة الفئات
                    onProductAdded: _addToCart,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // --- القسم الأيمن (سلة المشتريات) ---
          Expanded(
            flex: 1,
            child: ShoppingCart(
              cartItems: _cartItems,
              onQuantityUpdated: _updateQuantity,
              onItemRemoved: _removeFromCart,
              onCheckout: _handleCheckout,
              isLoading: _isProcessingSale,
            ),
          ),
        ],
      ),
    );
  }
}
