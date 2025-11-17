import 'package:flutter/material.dart';
import 'package:pos_desktop/database/category_queries.dart';
import 'package:pos_desktop/database/product_queries.dart';
import 'package:pos_desktop/models/cart_item.dart';
import 'package:pos_desktop/models/category.dart';
import 'package:pos_desktop/models/product.dart';
import 'package:pos_desktop/services/sales_service.dart';
import './sales/barcode_reader.dart';
import './sales/products_grid.dart';
import './sales/shopping_cart.dart';
import '../widgets/top_alert.dart';
import './sales/payment_dialog.dart';
import '../../models/customer.dart';
import '../../database/customer_queries.dart';

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

  final CustomerQueries _customerQueries = CustomerQueries();
  List<Customer> _customers = []; // قائمة لتخزين العملاء

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
        _customerQueries.getAllCustomers(), // جلب العملاء أيضاً
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<Product>;
        _categories = results[1] as List<Category>;
        _customers = results[2] as List<Customer>; // تخزين العملاء
      });
    } catch (e) {
      // ... (معالجة الخطأ)
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

  // دالة مخصصة فقط لجلب العملاء
  Future<void> _refreshCustomers() async {
    try {
      final customersFromDb = await _customerQueries.getAllCustomers();
      if (!mounted) return;
      setState(() {
        _customers = customersFromDb;
      });
    } catch (e) {
      // يمكنك إظهار تنبيه هنا إذا أردت
      // ignore: avoid_print
      print("Failed to refresh customers: $e");
    }
  }

  // تحديث دالة handleCheckout
  Future<void> _handleCheckout() async {
    if (_cartItems.isEmpty) {
      TopAlert.showError(context: context, message: 'السلة فارغة');
      return;
    }

    await _refreshCustomers();
    if (_cartItems.isEmpty) {
      // ...
      return;
    }
    // حساب الإجمالي
    final total = _cartItems.fold(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    // 1. عرض شاشة الدفع وانتظار النتيجة
    final paymentResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => PaymentDialog(
            totalAmount: total,
            customers: _customers, // تمرير قائمة العملاء
          ),
    );

    // 2. التحقق من أن المستخدم لم يغلق الشاشة
    if (paymentResult == null) {
      return; // المستخدم ألغى العملية
    }

    // 3. استخراج البيانات من النتيجة
    final String paymentMethod = paymentResult['payment_method'];
    final double paidAmount = paymentResult['paid_amount'];
    final int? customerId = paymentResult['customer_id'];
    final double remainingAmount = total - paidAmount;

    // 4. بدء عملية الحفظ
    try {
      setState(() => _isProcessingSale = true);

      // 5. استدعاء خدمة المبيعات مع البيانات الجديدة
      final invoiceNumber = await _salesService.createSaleInvoice(
        cartItems: _cartItems,
        cashier: "كاشير",
        total: total,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        paymentMethod: paymentMethod,
        customerId: customerId,
      );

      TopAlert.showSuccess(
        // ignore: use_build_context_synchronously
        context: context,
        message: 'تمت عملية البيع بنجاح - رقم الفاتورة: $invoiceNumber',
      );

      setState(() {
        _cartItems.clear();
      });

      await _loadProducts(); // تحديث مخزون المنتجات
    } catch (e) {
      // ignore: use_build_context_synchronously
      TopAlert.showError(context: context, message: 'خطأ في إتمام البيع: $e');
    } finally {
      setState(() => _isProcessingSale = false);
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
