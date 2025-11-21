import 'package:flutter/material.dart';
import 'package:pos_desktop/database/category_queries.dart';
import 'package:pos_desktop/database/product_queries.dart';
import 'package:pos_desktop/models/cart_item.dart';
import 'package:pos_desktop/models/category.dart';
import 'package:pos_desktop/models/product.dart';
import 'package:pos_desktop/models/product_package.dart';
import 'package:pos_desktop/models/sales_invoice.dart';
import 'package:pos_desktop/services/sales_invoice_service.dart';
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
  final SalesInvoiceService _invoiceService =
      SalesInvoiceService(); // <-- أضف هذا

  List<Product> _products = [];
  List<Category> _categories = [];
  List<Customer> _customers = [];
  final List<CartItem> _cartItems = [];

  bool _isLoading = true;
  bool _isProcessingSale = false;
  final Uuid _uuid = const Uuid();

  // متغيرات Lazy Loading
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String _searchTerm = "";
  int? _selectedCategoryId;

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
        _categories = results[1] as List<Category>;
        _customers = results[2] as List<Customer>;
        _isLoading = false;
      });
    } catch (e) {
      TopAlert.showError(
        context: context,
        message: 'خطأ في تحميل البيانات: $e',
      );
      if (mounted) setState(() => _isLoading = false);
    }
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

      // جلب الحزم لكل منتج
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
          _products.addAll(products);
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

    setState(() {
      _isLoadingMore = true;
    });

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

  // باقي الدوال تبقى كما هي بدون تغيير...
  bool _checkStockAvailability(
    Product product,
    double quantity,
    double unitQuantity,
  ) {
    final totalQuantityInPieces = quantity * unitQuantity;
    return totalQuantityInPieces <= product.stock;
  }

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
        if (!_checkStockAvailability(product, 1.0, 1.0)) {
          TopAlert.showError(
            context: context,
            message:
                'الكمية المطلوبة (1 قطعة) تتجاوز المخزون المتاح (${product.stock.toStringAsFixed(0)} قطعة)',
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
            unitName: 'حبة',
            unitQuantity: 1.0,
            availablePackages: availablePackages,
          ),
        );
      }
    });

    TopAlert.showSuccess(
      context: context,
      message: 'تمت إضافة ${product.name} إلى السلة',
    );
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
        final product = _products.firstWhere((p) => p.id == item.id);

        double newQuantity;
        if (resetQuantity) {
          newQuantity = 1.0;
        } else {
          final currentTotalPieces = item.quantity * item.unitQuantity;
          newQuantity = currentTotalPieces / newPackage.containedQuantity;
        }

        final totalPieces = newQuantity * newPackage.containedQuantity;

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

    final total = _cartItems.fold(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    final paymentResult = await showDialog<Map<String, dynamic>>(
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

      if (!_validateStockBeforeCheckout()) {
        setState(() => _isProcessingSale = false);
        return;
      }

      // تحويل CartItem إلى SaleInvoiceItem
      final List<SaleInvoiceItem> invoiceItems =
          _cartItems.map((cartItem) {
            return SaleInvoiceItem(
              invoiceId: 0, // سيتم تعبئته لاحقاً
              productId: cartItem.id,
              productName: cartItem.name,
              price: cartItem.price,
              quantity: cartItem.quantity,
              total: cartItem.price * cartItem.quantity,
            );
          }).toList();

      // إنشاء رقم فاتورة فريد
      final now = DateTime.now();
      final invoiceNumber =
          'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      // استدعاء الدالة بشكل صحيح
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
        cashier: "كاشير", // يمكنك تغيير هذا لاسم المستخدم الحالي
        customerId: customerId,
        paymentMethod: paymentMethod,
      );

      TopAlert.showSuccess(
        context: context,
        message:
            'تمت عملية البيع بنجاح - رقم الفاتورة: ${invoice.invoiceNumber}',
      );

      await _refreshData();
      setState(() {
        _cartItems.clear();
      });
    } catch (e) {
      TopAlert.showError(context: context, message: 'خطأ في إتمام البيع: $e');
      rethrow;
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
                    // إضافة خصائص Lazy Loading
                    hasMore: _hasMore,
                    isLoadingMore: _isLoadingMore,
                    onLoadMore: _loadMoreProducts,
                    onSearch: _onSearch,
                    onCategorySelected: _onCategorySelected,
                    selectedCategoryId: _selectedCategoryId,
                    searchTerm: _searchTerm,
                    onClearFilters: _clearFilters,
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
