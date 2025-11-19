import 'package:flutter/material.dart';
import 'package:pos_desktop/database/category_queries.dart';
import 'package:pos_desktop/database/product_queries.dart';
import 'package:pos_desktop/models/cart_item.dart';
import 'package:pos_desktop/models/category.dart';
import 'package:pos_desktop/models/product.dart';
import 'package:pos_desktop/models/product_package.dart';
import 'package:pos_desktop/services/sales_service.dart';
import './sales/barcode_reader.dart';
import './sales/products_grid.dart';
import './sales/shopping_cart.dart';
import '../widgets/top_alert.dart';
import './sales/payment_dialog.dart';
import '../../models/customer.dart';
import '../../database/customer_queries.dart';
import 'package:uuid/uuid.dart';

class SalesInterface extends StatefulWidget {
  const SalesInterface({super.key});

  @override
  State<SalesInterface> createState() => _SalesInterfaceState();
}

class _SalesInterfaceState extends State<SalesInterface> {
  final ProductQueries _productQueries = ProductQueries();
  final CategoryQueries _categoryQueries = CategoryQueries();
  final SalesService _salesService = SalesService();
  final CustomerQueries _customerQueries = CustomerQueries();

  List<Product> _products = [];
  List<Category> _categories = [];
  List<Customer> _customers = [];
  final List<CartItem> _cartItems = [];

  bool _isLoading = true;
  bool _isProcessingSale = false;
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _productQueries.getAllProducts(),
        _categoryQueries.getAllCategories(),
        _customerQueries.getAllCustomers(),
      ]);

      List<Product> productsFromDb = results[0] as List<Product>;

      for (var product in productsFromDb) {
        if (product.id != null) {
          product.packages = await _productQueries.getPackagesForProduct(
            product.id!,
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _products = productsFromDb;
        _categories = results[1] as List<Category>;
        _customers = results[2] as List<Customer>;
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

  // ***** دالة مساعدة للتحقق من المخزون *****
  bool _checkStockAvailability(
    Product product,
    double quantity,
    double unitQuantity,
  ) {
    final totalQuantityInPieces = quantity * unitQuantity;
    return totalQuantityInPieces <= product.stock;
  }

  // ***** دالة مساعدة لحساب الكمية الإجمالية بالقطع *****
  double _getTotalQuantityInPieces(double quantity, double unitQuantity) {
    return quantity * unitQuantity;
  }

  void _addToCart(Product product) {
    if (product.stock <= 0) {
      TopAlert.showError(
        context: context,
        message: 'لا يوجد مخزون كافي لـ ${product.name}',
      );
      return;
    }

    setState(() {
      // البحث عن المنتج بالوحدة الأساسية
      final existingItemIndex = _cartItems.indexWhere(
        (item) => item.id == product.id && item.unitQuantity == 1.0,
      );

      if (existingItemIndex != -1) {
        final existingItem = _cartItems[existingItemIndex];
        final newQuantity = existingItem.quantity + 1;
        final totalPieces = _getTotalQuantityInPieces(
          newQuantity,
          existingItem.unitQuantity,
        );

        if (totalPieces > product.stock) {
          TopAlert.showError(
            context: context,
            message:
                'الكمية المطلوبة (${totalPieces.toStringAsFixed(0)} قطعة) تتجاوز المخزون المتاح (${product.stock.toStringAsFixed(0)} قطعة)',
          );
          return;
        }
        existingItem.quantity = newQuantity;
      } else {
        // التحقق من المخزون قبل الإضافة
        if (!_checkStockAvailability(product, 1.0, 1.0)) {
          TopAlert.showError(
            context: context,
            message:
                'الكمية المطلوبة (1 قطعة) تتجاوز المخزون المتاح (${product.stock.toStringAsFixed(0)} قطعة)',
          );
          return;
        }

        // إنشاء قائمة الحزم المتاحة
        final List<ProductPackage> availablePackages = [
          ProductPackage(
            name: 'حبة',
            price: product.price,
            containedQuantity: 1.0,
          ),
          ...product.packages,
        ];

        _cartItems.add(
          CartItem(
            cartItemId: _uuid.v4(),
            id: product.id!,
            name: product.name,
            price: product.price,
            quantity: 1.0,
            stock: product.stock,
            unitName: 'حبة',
            unitQuantity: 1.0,
            availablePackages: availablePackages, // <-- تمرير الحزم المتاحة
          ),
        );
      }
    });

    TopAlert.showSuccess(
      context: context,
      message: 'تمت إضافة ${product.name} إلى السلة',
    );
  }

  // في SalesInterface
  void _updateCartItemUnit(
    String cartItemId,
    ProductPackage newPackage,
    bool resetQuantity,
  ) {
    setState(() {
      final itemIndex = _cartItems.indexWhere(
        (item) => item.cartItemId == cartItemId,
      );
      if (itemIndex != -1) {
        final item = _cartItems[itemIndex];
        final product = _products.firstWhere((p) => p.id == item.id);

        // حساب الكمية الإجمالية بالقطع
        double newQuantity;
        if (resetQuantity) {
          newQuantity = 1.0; // كمية جديدة = 1 من الوحدة الجديدة
        } else {
          // الحفاظ على نفس الكمية الإجمالية بالقطع
          final currentTotalPieces = item.quantity * item.unitQuantity;
          newQuantity = currentTotalPieces / newPackage.containedQuantity;
        }

        final totalPieces = newQuantity * newPackage.containedQuantity;

        // التحقق من المخزون
        if (totalPieces > product.stock) {
          TopAlert.showError(
            context: context,
            message:
                'الكمية المطلوبة (${totalPieces.toStringAsFixed(0)} قطعة) تتجاوز المخزون المتاح (${product.stock.toStringAsFixed(0)} قطعة)',
          );
          return;
        }

        item.name = product.name;
        item.unitName = newPackage.name;
        item.price = newPackage.price;
        item.unitQuantity = newPackage.containedQuantity;
        item.quantity = newQuantity;
      }
    });
  }

  void _updateCartItemQuantity(String cartItemId, double newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        _cartItems.removeWhere((item) => item.cartItemId == cartItemId);
        return;
      }

      final itemIndex = _cartItems.indexWhere(
        (item) => item.cartItemId == cartItemId,
      );
      if (itemIndex != -1) {
        final item = _cartItems[itemIndex];
        final product = _products.firstWhere((p) => p.id == item.id);

        // التحقق من المخزون مع مراعاة الوحدة
        final totalPieces = _getTotalQuantityInPieces(
          newQuantity,
          item.unitQuantity,
        );

        if (totalPieces > product.stock) {
          TopAlert.showError(
            context: context,
            message:
                'الكمية المطلوبة (${totalPieces.toStringAsFixed(0)} قطعة) تتجاوز المخزون المتاح (${product.stock.toStringAsFixed(0)} قطعة)',
          );
          return;
        }
        item.quantity = newQuantity;
      }
    });
  }

  void _removeFromCart(String cartItemId) {
    setState(() {
      _cartItems.removeWhere((item) => item.cartItemId == cartItemId);
    });
  }

  // ***** التحقق النهائي من المخزون قبل إتمام البيع *****
  bool _validateStockBeforeCheckout() {
    for (final cartItem in _cartItems) {
      final product = _products.firstWhere((p) => p.id == cartItem.id);
      final totalPieces = _getTotalQuantityInPieces(
        cartItem.quantity,
        cartItem.unitQuantity,
      );

      if (totalPieces > product.stock) {
        TopAlert.showError(
          context: context,
          message:
              'الكمية المطلوبة لـ ${product.name} (${totalPieces.toStringAsFixed(0)} قطعة) تتجاوز المخزون المتاح (${product.stock.toStringAsFixed(0)} قطعة)',
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _handleCheckout() async {
    if (_cartItems.isEmpty) {
      TopAlert.showError(context: context, message: 'السلة فارغة');
      return;
    }

    // ***** التحقق النهائي من المخزون قبل المتابعة *****
    if (!_validateStockBeforeCheckout()) {
      return;
    }

    try {
      final updatedCustomers = await _customerQueries.getAllCustomers();
      if (mounted) {
        setState(() {
          _customers = updatedCustomers;
        });
      }
    } catch (e) {
      // تجاهل الخطأ مؤقتاً والمتابعة
    }

    // حساب الإجمالي
    final total = _cartItems.fold(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    // عرض شاشة الدفع
    final paymentResult = await showDialog<Map<String, dynamic>>(
      // ignore: use_build_context_synchronously
      context: context,
      builder:
          (context) => PaymentDialog(totalAmount: total, customers: _customers),
    );

    if (paymentResult == null) {
      return;
    }

    try {
      setState(() => _isProcessingSale = true);

      final String paymentMethod = paymentResult['payment_method'];
      final double paidAmount = paymentResult['paid_amount'];
      final int? customerId = paymentResult['customer_id'];
      final double remainingAmount = total - paidAmount;

      // ***** التحقق النهائي من المخزون قبل الحفظ في قاعدة البيانات *****
      if (!_validateStockBeforeCheckout()) {
        setState(() => _isProcessingSale = false);
        return;
      }

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

      await _refreshData();
      setState(() {
        _cartItems.clear();
      });
    } catch (e) {
      // ignore: use_build_context_synchronously
      TopAlert.showError(context: context, message: 'خطأ في إتمام البيع: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessingSale = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                BarcodeReader(
                  onProductScanned: _addToCart,
                  products: _products,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ProductsGrid(
                    products: _products,
                    categories: _categories,
                    onProductAdded: _addToCart,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: ShoppingCart(
              cartItems: _cartItems,
              products: _products,
              onQuantityUpdated: _updateCartItemQuantity,
              onUnitChanged: _updateCartItemUnit,
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
