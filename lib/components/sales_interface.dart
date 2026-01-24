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
import '../widgets/product_category_filter.dart';
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
  int _refreshKey = 0;
  bool _showNoBarcode = false; // <-- New filter state

  // --- 1. متغيرات الباركود الجديدة (تمت إضافتها) ---
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();

  // مفتاح عالمي للوصول لحالة السلة (F3 للتنقل)
  final GlobalKey<ShoppingCartState> _shoppingCartKey =
      GlobalKey<ShoppingCartState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    // تنظيف الذاكرة
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
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

  final GlobalKey<ProductsTableState> _productsTableKey =
      GlobalKey<ProductsTableState>();

  final GlobalKey<ProductCategoryFilterState> _categoryFilterKey =
      GlobalKey<ProductCategoryFilterState>();

  void _focusSearch() {
    _productsTableKey.currentState?.focusSearch();
  }

  // --- 2. دالة معالجة الباركود (تمت إضافتها) ---
  Future<void> _onBarcodeScanned(String barcode) async {
    if (barcode.trim().isEmpty) return;

    final cleanBarcode = barcode.trim();

    try {
      // 1. استخدام دالة الاستعلام المباشر من قاعدة البيانات لضمان الدقة
      // هذه الدالة يفترض أنها تبحث في الباركود الرئيسي والبديل
      Product? foundProduct = await _productQueries.getProductByBarcode(
        cleanBarcode,
      );

      if (foundProduct != null) {
        // 2. إذا وجدنا المنتج، يجب جلب الوحدات/الحزم الخاصة به إذا لم تكن محملة
        // لأن getProductByBarcode قد ترجع المنتج الأساسي فقط
        if (foundProduct.id != null) {
          foundProduct.packages = await _productQueries.getPackagesForProduct(
            foundProduct.id!,
          );
        }

        // 3. إضافته للسلة
        _addToCart(foundProduct);

        // 4. مسح الحقل للعملية التالية
        _barcodeController.clear();
      } else {
        // إذا لم يتم العثور عليه
        TopAlert.showError(
          context: context,
          message: 'المنتج غير موجود: $cleanBarcode',
        );
        _barcodeController.clear();
      }
    } catch (e) {
      TopAlert.showError(context: context, message: 'حدث خطأ أثناء البحث: $e');
    }

    // إعادة التركيز دائماً
    _barcodeFocusNode.requestFocus();
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
        filterNoBarcode: _showNoBarcode, // <-- Pass filter
      );

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
        final currentUsedStock =
            existingItem.quantity * existingItem.unitQuantity;
        final remainingStock = product.stock - currentUsedStock;

        double quantityToAdd = 1.0;
        if (remainingStock < 1.0 && remainingStock > 0) {
          quantityToAdd = remainingStock;
        }

        final newQuantity = existingItem.quantity + quantityToAdd;

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
        double initialQuantity = 1.0;
        if (product.stock < 1.0 && product.stock > 0) {
          initialQuantity = product.stock;
        }

        if (!_checkStockAvailability(product, initialQuantity, 1.0)) {
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
            quantity: initialQuantity,
            stock: product.stock,
            purchasePrice: product.purchasePrice,
            unitName: 'حبة',
            unitQuantity: 1.0,
            availablePackages: availablePackages,
          ),
        );
      }
      _customTotal = null;
    });

    // إعادة التركيز للباركود بعد الإضافة
    // نستخدم addPostFrameCallback لضمان أن الواجهة قد انتهت من إعادة البناء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_barcodeFocusNode.canRequestFocus) {
        _barcodeFocusNode.requestFocus();
      }
    });
  }

  Product _SafeGetProduct(CartItem item) {
    try {
      return _products.firstWhere((p) => p.id == item.id);
    } catch (e) {
      return Product(
        id: item.id,
        name: item.name,
        price: item.price,
        purchasePrice: item.purchasePrice,
        stock: item.stock,
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
        final product = _SafeGetProduct(item);

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
        _customTotal = null;
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
        final product = _SafeGetProduct(item);

        final totalPieces = newQuantity * item.unitQuantity;
        if (totalPieces > product.stock) {
          TopAlert.showError(
            context: context,
            message: 'الكمية تتجاوز المخزون (${product.stock.toInt()})',
          );
          return;
        }
        item.quantity = newQuantity;
        _customTotal = null;
      }
    });
  }

  void _removeFromCart(String cartItemId) {
    setState(() {
      _cartItems.removeWhere((item) => item.cartItemId == cartItemId);
      _customTotal = null;
    });
  }

  void _updateCartItemPrice(String cartItemId, double newPrice) {
    setState(() {
      final itemIndex = _cartItems.indexWhere(
        (item) => item.cartItemId == cartItemId,
      );
      if (itemIndex != -1) {
        final item = _cartItems[itemIndex];
        final minAllowedPrice = item.purchasePrice * item.unitQuantity;

        if (newPrice < minAllowedPrice) {
          _refreshKey++;
          TopAlert.showError(
            context: context,
            message:
                'لا يمكن خفض السعر عن سعر الشراء (${minAllowedPrice.toStringAsFixed(2)})',
          );
          return;
        }

        item.price = newPrice;
        _customTotal = null;
      }
    });
  }

  void _updateCustomTotal(double newTotal) {
    setState(() {
      final totalPurchaseCost = _cartItems.fold(
        0.0,
        (sum, item) =>
            sum + (item.purchasePrice * item.unitQuantity * item.quantity),
      );

      if (newTotal < totalPurchaseCost) {
        _refreshKey++;
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
      final product = _SafeGetProduct(cartItem);

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
            print(
              'DEBUG: Processing Cart Item: ${cartItem.name}, Purchase Price: ${cartItem.purchasePrice}',
            );
            return SaleInvoiceItem(
              invoiceId: 0,
              productId: cartItem.id,
              productName: cartItem.name,
              price: cartItem.price,
              quantity: cartItem.quantity,
              total: cartItem.price * cartItem.quantity,
              unitQuantity: cartItem.unitQuantity,
              unitName: cartItem.unitName,
              costPrice:
                  cartItem
                      .purchasePrice, // <-- تخزين سعر الشراء الحالي كتكلفة ثابتة
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
      body: GestureDetector(
        onTap: () {
          // عند النقر في أي مكان فارغ، نعيد التركيز لحقل الباركود
          // إلا إذا كان المستخدم ينقر على حقل نصي آخر (هذا يتم التعامل معه تلقائياً بواسطة فلاتر)
          // ولكن هنا نريد التأكد من عدم ضياع التركيز
          if (_barcodeFocusNode.canRequestFocus) {
            _barcodeFocusNode.requestFocus();
          }
        },
        behavior:
            HitTestBehavior
                .translucent, // للسماح بالتقاط النقرات في الأماكن الفارغة
        child: CallbackShortcuts(
          bindings: {
            // F1: للبحث الرئيسي (باركود)
            const SingleActivator(LogicalKeyboardKey.f1):
                () => _barcodeFocusNode.requestFocus(),
            // F2: للبحث بالاسم (المنتجات)
            const SingleActivator(LogicalKeyboardKey.f2): _focusSearch,
            // F3: للتنقل بين كميات السلة
            const SingleActivator(LogicalKeyboardKey.f3): () {
              _shoppingCartKey.currentState?.focusNextQuantity();
            },
            // F4: للدفع وإتمام البيع
            const SingleActivator(LogicalKeyboardKey.f4): () {
              if (_cartItems.isNotEmpty) {
                _handleCheckout();
              }
            },
          },
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. قسم المنتجات
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
                        _showNoBarcode = false;
                      });
                      _loadProducts(reset: true);
                    },
                    showNoBarcodeFilter: _showNoBarcode,
                    onNoBarcodeFilterChanged: (val) {
                      setState(() => _showNoBarcode = val);
                      _loadProducts(reset: true);
                    },
                    categoryFilterKey: _categoryFilterKey,
                  ),
                ),

                const SizedBox(width: 16),

                // 2. قسم السلة (تم تحديثه لإصلاح الخطأ)
                Expanded(
                  flex: 8,
                  child: ShoppingCart(
                    cartKey: _shoppingCartKey, // تمرير المفتاح
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
                    // --- المعاملات المضافة حديثاً ---
                    barcodeController: _barcodeController,
                    barcodeFocusNode: _barcodeFocusNode,
                    onBarcodeSubmit: _onBarcodeScanned,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
