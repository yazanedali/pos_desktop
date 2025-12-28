import 'package:flutter/material.dart';
import 'package:pos_desktop/database/category_queries.dart';
import 'package:pos_desktop/database/product_queries.dart';
import 'package:pos_desktop/models/cart_item.dart';
import 'package:pos_desktop/models/category.dart';
import 'package:pos_desktop/models/product.dart';
import 'package:pos_desktop/models/product_package.dart';
import 'package:pos_desktop/models/sales_invoice.dart';
import 'package:pos_desktop/services/sales_invoice_service.dart';
import '../services/cash_service.dart';

import './sales/products_grid.dart';
import './sales/shopping_cart.dart';
import '../widgets/top_alert.dart';
import './sales/payment_dialog.dart';
import 'package:flutter/services.dart';
import '../../models/customer.dart';
import '../../database/customer_queries.dart';
import 'package:uuid/uuid.dart';

class SalesInterface extends StatefulWidget {
  const SalesInterface({super.key});

  @override
  State<SalesInterface> createState() => _SalesInterfaceState();
}

class _SalesInterfaceState extends State<SalesInterface>
    with AutomaticKeepAliveClientMixin {
  final ProductQueries _productQueries = ProductQueries();
  final CategoryQueries _categoryQueries = CategoryQueries();
  final CustomerQueries _customerQueries = CustomerQueries();
  final SalesInvoiceService _invoiceService = SalesInvoiceService();
  final CashService _cashService = CashService();

  List<Product> _products = [];
  List<Category> _categories = [];
  List<Customer> _customers = [];
  final List<CartItem> _cartItems = [];

  bool _isLoading = true;
  bool _isProcessingSale = false;
  final Uuid _uuid = const Uuid();
  double? _customTotal;

  // Pagination & Filter Variables
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String _searchTerm = "";
  int? _selectedCategoryId;
  int _refreshKey = 0; // مفتاح لتجربة إعادة بناء الحقول عند حدوث خطأ في السعر

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _loadProducts(reset: true),
        _categoryQueries.getAllCategories(),
        _customerQueries.getAllCustomers(),
      ]);

      if (!mounted) return;

      setState(() {
        // النتيجة الأولى هي void لأن _loadProducts تحدث الـ State داخلياً
        // لذا نأخذ الفئات والعملاء من النتائج التالية
        _categories = results[1] as List<Category>;
        _customers = results[2] as List<Customer>;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        TopAlert.showError(
          context: context,
          message: 'خطأ في تحميل البيانات: $e',
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // --- دوال البحث والفلترة ---
  final GlobalKey<ProductsTableState> _productsTableKey =
      GlobalKey<ProductsTableState>();

  void _focusSearch() {
    _productsTableKey.currentState?.focusSearch();
  }

  Future<void> _loadProducts({bool reset = true}) async {
    try {
      if (reset) {
        setState(() {
          _currentPage = 1;
          _hasMore = true;
          if (_isLoadingMore) _isLoadingMore = false;
        });
      }

      final products = await _productQueries.getProductsPaginated(
        page: _currentPage,
        searchTerm: _searchTerm.isNotEmpty ? _searchTerm : null,
        categoryId: _selectedCategoryId,
      );

      // تحميل الحزم للمنتجات
      for (var product in products) {
        if (product.id != null) {
          product.packages = await _productQueries.getPackagesForProduct(
            product.id!,
          );
        }
      }

      if (!mounted) return;

      setState(() {
        if (reset) {
          _products = products;
        } else {
          // دمج القوائم مع التحقق من عدم التكرار
          final existingIds = _products.map((p) => p.id).toSet();
          for (var newProduct in products) {
            if (!existingIds.contains(newProduct.id)) {
              _products.add(newProduct);
            }
          }
        }
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
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadProducts(reset: false);
  }

  void _onSearch(String searchTerm) {
    setState(() {
      _searchTerm = searchTerm;
    });
    _loadProducts(reset: true);
  }

  void _onCategorySelected(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      // يمكنك تصفير البحث هنا إذا أردت أن يكون الفلتر منفصلاً
      // _searchTerm = "";
    });
    _loadProducts(reset: true);
  }

  void _clearFilters() {
    setState(() {
      _searchTerm = "";
      _selectedCategoryId = null;
    });
    _loadProducts(reset: true);
  }

  // --- دوال السلة والباركود ---

  void _handleProductFromBarcode(Product product) {
    if (product.id == null) return;

    // إضافة المنتج للقائمة المعروضة إذا لم يكن موجوداً (لتحسين تجربة المستخدم)
    final existsInList = _products.any((p) => p.id == product.id);
    if (!existsInList) {
      setState(() {
        _products.insert(0, product);
      });
    }

    _addToCart(product);
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
      final existingItemIndex = _cartItems.indexWhere(
        (item) => item.id == product.id && item.unitQuantity == 1.0,
      );

      if (existingItemIndex != -1) {
        final existingItem = _cartItems[existingItemIndex];
        final newQuantity = existingItem.quantity + 1;

        if (!_checkStockAvailability(
          product,
          newQuantity,
          existingItem.unitQuantity,
        )) {
          TopAlert.showError(
            context: context,
            message: 'الكمية المطلوبة تتجاوز المخزون المتاح',
          );
          return;
        }
        existingItem.quantity = newQuantity;
      } else {
        if (!_checkStockAvailability(product, 1.0, 1.0)) {
          TopAlert.showError(
            context: context,
            message: 'الكمية المطلوبة تتجاوز المخزون المتاح',
          );
          return;
        }

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
            purchasePrice: product.purchasePrice,
            unitName: 'حبة',
            unitQuantity: 1.0,
            availablePackages: availablePackages,
          ),
        );
      }
      _customTotal = null; // إعادة تعيين الإجمالي المخصص عند إضافة منتج جديد
    });
  }

  // دالة مساعدة للحصول على المنتج بأمان (سواء من القائمة أو من السلة كاحتياط)
  Product _SafeGetProduct(CartItem item) {
    try {
      return _products.firstWhere((p) => p.id == item.id);
    } catch (e) {
      // إذا لم يكن المنتج في القائمة الحالية (بسبب الفلترة مثلاً)، ننشئ كائناً من بيانات السلة
      return Product(
        id: item.id,
        name: item.name,
        price: item.price,
        purchasePrice: item.purchasePrice,
        stock: item.stock, // نعتمد على المخزون المسجل لحظة الإضافة
        // يمكن هنا إضافة استعلام قاعدة بيانات للحصول على المخزون المحدث إذا لزم الأمر
      );
    }
  }

  bool _checkStockAvailability(
    Product product,
    double quantity,
    double unitQuantity,
  ) {
    final totalQuantityInPieces = quantity * unitQuantity;
    return totalQuantityInPieces <= product.stock;
  }

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
        final product = _SafeGetProduct(item); // استخدام الدالة الآمنة

        double newQuantity;
        if (resetQuantity) {
          newQuantity = 1.0;
        } else {
          final currentTotalPieces = item.quantity * item.unitQuantity;
          newQuantity = currentTotalPieces / newPackage.containedQuantity;
          if (newQuantity != newQuantity.roundToDouble()) {
            newQuantity = newQuantity.ceilToDouble();
          }
        }

        final totalPieces = newQuantity * newPackage.containedQuantity;
        if (totalPieces > product.stock) {
          TopAlert.showError(
            context: context,
            message: 'الكمية تتجاوز المخزون (${product.stock.toInt()})',
          );
          return;
        }

        item.name = product.name;
        item.unitName = newPackage.name;
        item.price = newPackage.price;
        item.unitQuantity = newPackage.containedQuantity;
        item.quantity = newQuantity;
        _customTotal = null; // إعادة تعيين الإجمالي المخصص عند تغيير الوحدة
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
        final product = _SafeGetProduct(item); // استخدام الدالة الآمنة

        final totalPieces = newQuantity * item.unitQuantity;
        if (totalPieces > product.stock) {
          TopAlert.showError(
            context: context,
            message: 'الكمية تتجاوز المخزون (${product.stock.toInt()})',
          );
          return;
        }
        item.quantity = newQuantity;
        _customTotal = null; // إعادة تعيين الإجمالي المخصص عند تغيير الكمية
      }
    });
  }

  void _removeFromCart(String cartItemId) {
    setState(() {
      _cartItems.removeWhere((item) => item.cartItemId == cartItemId);
      _customTotal = null; // إعادة تعيين الإجمالي المخصص عند الحذف
    });
  }

  void _updateCartItemPrice(String cartItemId, double newPrice) {
    setState(() {
      final itemIndex = _cartItems.indexWhere(
        (item) => item.cartItemId == cartItemId,
      );
      if (itemIndex != -1) {
        final item = _cartItems[itemIndex];
        // حساب سعر الشراء للوحدة المختارة
        final minAllowedPrice = item.purchasePrice * item.unitQuantity;

        if (newPrice < minAllowedPrice) {
          _refreshKey++; // زيادة المفتاح لإجبار الحقول على إعادة البناء والعودة للسعر الأصلي
          TopAlert.showError(
            context: context,
            message:
                'لا يمكن خفض السعر عن سعر الشراء (${minAllowedPrice.toStringAsFixed(2)})',
          );
          return;
        }

        item.price = newPrice;
        _customTotal = null; // إعادة تعيين الإجمالي المخصص عند تعديل سعر منتج
      }
    });
  }

  void _updateCustomTotal(double newTotal) {
    setState(() {
      // التحقق من أن الإجمالي الجديد لا يقل عن إجمالي سعر الشراء لكل العناصر
      final totalPurchaseCost = _cartItems.fold(
        0.0,
        (sum, item) =>
            sum + (item.purchasePrice * item.unitQuantity * item.quantity),
      );

      if (newTotal < totalPurchaseCost) {
        _refreshKey++; // زيادة المفتاح لإجبار الحقول على إعادة البناء والعودة للإجمالي الأصلي
        TopAlert.showError(
          context: context,
          message:
              'لا يمكن خفض الإجمالي عن إجمالي التكلفة (${totalPurchaseCost.toStringAsFixed(2)})',
        );
        return;
      }
      _customTotal = newTotal;
    });
  }

  bool _validateStockBeforeCheckout() {
    for (final cartItem in _cartItems) {
      final product = _SafeGetProduct(cartItem); // استخدام الدالة الآمنة

      final totalPieces = cartItem.quantity * cartItem.unitQuantity;
      if (totalPieces > product.stock) {
        TopAlert.showError(
          context: context,
          message: 'الكمية لـ ${product.name} تتجاوز المخزون المتاح',
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

    if (!_validateStockBeforeCheckout()) return;

    try {
      // تحديث قائمة العملاء (اختياري)
      final updatedCustomers = await _customerQueries.getAllCustomers();
      if (mounted) setState(() => _customers = updatedCustomers);
    } catch (_) {}

    final totalBeforeAdjustment = _cartItems.fold(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    final total = _customTotal ?? totalBeforeAdjustment;

    final paymentResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => PaymentDialog(totalAmount: total, customers: _customers),
    );

    if (paymentResult == null) return;

    try {
      setState(() => _isProcessingSale = true);

      final String paymentMethod = paymentResult['payment_method'];
      final double paidAmount = paymentResult['paid_amount'];
      final int? customerId = paymentResult['customer_id'];
      final double remainingAmount = total - paidAmount;

      if (!_validateStockBeforeCheckout()) {
        setState(() => _isProcessingSale = false);
        return;
      }

      final List<SaleInvoiceItem> invoiceItems =
          _cartItems.map((cartItem) {
            return SaleInvoiceItem(
              invoiceId: 0,
              productId: cartItem.id,
              productName: cartItem.name,
              price: cartItem.price,
              quantity: cartItem.quantity,
              total: cartItem.price * cartItem.quantity,
              unitQuantity: cartItem.unitQuantity,
              unitName: cartItem.unitName,
            );
          }).toList();

      final now = DateTime.now();
      final invoiceNumber = 'INV-${now.millisecondsSinceEpoch}';

      final invoice = await _invoiceService.createInvoice(
        invoiceNumber: invoiceNumber,
        date:
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        time:
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
        items: invoiceItems,
        total: total,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        cashier: "Admin",
        customerId: customerId,
        paymentMethod: paymentMethod,
        originalTotal: totalBeforeAdjustment,
      );

      // تسجيل الدفع في الصندوق اليومي إذا كان هناك مبلغ مدفوع
      if (paidAmount > 0) {
        await _cashService.recordSaleIncome(
          amount: paidAmount,
          invoiceNumber: invoiceNumber,
        );
      }

      TopAlert.showSuccess(
        context: context,
        message: 'تم البيع بنجاح - ${invoice.invoiceNumber}',
      );

      // إعادة تحميل البيانات وتفريغ السلة
      await _refreshData();
      setState(() => _cartItems.clear());
    } catch (e) {
      TopAlert.showError(context: context, message: 'خطأ: $e');
    } finally {
      if (mounted) setState(() => _isProcessingSale = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f1): _focusSearch,
          const SingleActivator(LogicalKeyboardKey.space): () {
            // تنفيذ البيع بالمسافة فقط إذا لم يكن هناك تركيز على حقل نصي
            if (FocusManager.instance.primaryFocus?.context?.widget
                is! EditableText) {
              if (_cartItems.isNotEmpty && !_isProcessingSale) {
                _handleCheckout();
              }
            }
          },
        },
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. قسم المنتجات (صار أصغر - الثلث تقريباً)
              Expanded(
                flex: 4,
                child: ProductsTable(
                  key: _productsTableKey,
                  products: _products,
                  categories: _categories,
                  onProductAdded: _addToCart,
                  hasMore: _hasMore,
                  isLoadingMore: _isLoadingMore,
                  onLoadMore: _loadMoreProducts,
                  onSearch: (val) {
                    setState(() => _searchTerm = val);
                    _loadProducts(reset: true);
                  },
                  onCategorySelected: (val) {
                    setState(() => _selectedCategoryId = val);
                    _loadProducts(reset: true);
                  },
                  selectedCategoryId: _selectedCategoryId,
                  searchTerm: _searchTerm,
                  onClearFilters: () {
                    setState(() {
                      _searchTerm = "";
                      _selectedCategoryId = null;
                    });
                    _loadProducts(reset: true);
                  },
                ),
              ),

              const SizedBox(width: 16),

              // 2. قسم السلة (صار أكبر - الثلثين تقريباً)
              Expanded(
                flex: 8, // نسبة 8 من 12 (حوالي 66%)
                child: ShoppingCart(
                  cartItems: _cartItems,
                  products: _products,
                  onQuantityUpdated: _updateCartItemQuantity,
                  onPriceUpdated: _updateCartItemPrice,
                  onUnitChanged: _updateCartItemUnit,
                  onItemRemoved: _removeFromCart,
                  onCheckout: _handleCheckout,
                  onTotalUpdated: _updateCustomTotal,
                  customTotal: _customTotal,
                  isLoading: _isProcessingSale,
                  refreshKey: _refreshKey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
