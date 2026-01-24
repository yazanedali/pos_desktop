import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_desktop/models/product.dart';
import 'package:pos_desktop/models/product_package.dart';
import '../../models/cart_item.dart';

class ShoppingCart extends StatefulWidget {
  final List<CartItem> cartItems;
  final List<Product> products;
  final Function(String, double) onQuantityUpdated;
  final Function(String, double) onPriceUpdated;
  final Function(String, ProductPackage, bool) onUnitChanged;
  final Function(String) onItemRemoved;
  final Function() onCheckout;
  final Function(double) onTotalUpdated;
  final bool isLoading;
  final GlobalKey<ShoppingCartState> cartKey;
  final double? customTotal;
  final int refreshKey;

  // --- الخصائص الجديدة ---
  final TextEditingController barcodeController;
  final FocusNode barcodeFocusNode;
  final Function(String) onBarcodeSubmit;

  const ShoppingCart({
    // super.key removed because we are passing key: cartKey to super
    required this.cartItems,
    required this.products,
    required this.onQuantityUpdated,
    required this.onPriceUpdated,
    required this.onUnitChanged,
    required this.onItemRemoved,
    required this.onCheckout,
    required this.onTotalUpdated,
    required this.cartKey,
    this.customTotal,
    this.isLoading = false,
    this.refreshKey = 0,

    // استقبال الخصائص
    required this.barcodeController,
    required this.barcodeFocusNode,
    required this.onBarcodeSubmit,
  }) : super(key: cartKey);

  @override
  State<ShoppingCart> createState() => ShoppingCartState();
}

class ShoppingCartState extends State<ShoppingCart> {
  final Color _primaryBlue = const Color(0xFF4A80F0);
  final Color _lightBlueBg = const Color(0xFFF0F5FF);

  // خريطة لتخزين عقد التركيز لكل عنصر في السلة (المفتاح هو cartItemId)
  final Map<String, FocusNode> _qtyFocusNodes = {};

  @override
  void initState() {
    super.initState();
    // طلب التركيز على الباركود فور بدء الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    // تنظيف جميع عقد التركيز عند التخلص من الواجهة
    for (var node in _qtyFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  // --- دالة عامة (Public) للتنقل بين حقول الكمية ---
  void focusNextQuantity() {
    if (widget.cartItems.isEmpty) return;

    // البحث عن الفهرس الحالي للكائن الذي لديه التركيز
    int currentFocusIndex = -1;
    for (int i = 0; i < widget.cartItems.length; i++) {
      final itemId = widget.cartItems[i].cartItemId;
      if (_qtyFocusNodes[itemId]?.hasFocus ?? false) {
        currentFocusIndex = i;
        break;
      }
    }

    // تحديد العنصر التالي (دائري)
    int nextIndex = (currentFocusIndex + 1) % widget.cartItems.length;
    final nextItemId = widget.cartItems[nextIndex].cartItemId;

    // طلب التركيز للعنصر التالي
    _qtyFocusNodes[nextItemId]?.requestFocus();
  }

  // دالة مساعدة للحصول على أو إنشاء عقدة تركيز لعنصر معين
  FocusNode _getQtyFocusNode(String cartItemId) {
    if (!_qtyFocusNodes.containsKey(cartItemId)) {
      _qtyFocusNodes[cartItemId] = FocusNode();
    }
    return _qtyFocusNodes[cartItemId]!;
  }

  double _calculateTotal() {
    return widget.cartItems.fold(
      0,
      (total, item) => total + (item.price * item.quantity),
    );
  }

  @override
  Widget build(BuildContext context) {
    // تنظيف العقد للعناصر المحذوفة لضمان عدم تسريب الذاكرة
    _qtyFocusNodes.removeWhere(
      (key, value) => !widget.cartItems.any((item) => item.cartItemId == key),
    );

    final totalAmount = widget.customTotal ?? _calculateTotal();

    return GestureDetector(
      // عند النقر في أي مكان فارغ داخل السلة، إعادة التركيز للباركود
      onTap: () {
        if (widget.barcodeFocusNode.canRequestFocus) {
          widget.barcodeFocusNode.requestFocus();
        }
      },
      behavior: HitTestBehavior.translucent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _primaryBlue.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: _primaryBlue.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. ترويسة السلة (تم استبدال العنوان بحقل بحث الباركود الكبير)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A80F0), Color(0xFF9355F4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(
                children: [
                  // حقل الباركود الكبير
                  Expanded(
                    child: Container(
                      height: 50, // ارتفاع كبير ومناسب
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: TextField(
                          controller: widget.barcodeController,
                          focusNode: widget.barcodeFocusNode,
                          autofocus: true, // التركيز التلقائي
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: "امسح الباركود هنا... (F1)",
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                            ),
                            prefixIcon: const Icon(
                              Icons.qr_code_scanner,
                              color: Color(0xFF4A80F0),
                              size: 28,
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                widget.barcodeController.clear();
                                widget.barcodeFocusNode.requestFocus();
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          textInputAction: TextInputAction.go, // زر Enter
                          onSubmitted: (value) {
                            widget.onBarcodeSubmit(value);
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // زر تفريغ السلة (نقلناه هنا بجانب البحث)
                  if (widget.cartItems.isNotEmpty)
                    Tooltip(
                      message: "تفريغ السلة",
                      child: InkWell(
                        onTap: () {
                          // يمكن إضافة منطق التفريغ لاحقاً
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_sweep,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 2. عناوين الأعمدة (كما هي)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: _lightBlueBg,
                border: Border(
                  bottom: BorderSide(color: _primaryBlue.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text("تفاصيل المنتج", style: _headerStyle()),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text("السعر / الوحدة", style: _headerStyle()),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      "الكمية (F3)",
                      style: _headerStyle(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "الإجمالي",
                      style: _headerStyle(),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(width: 30),
                ],
              ),
            ),

            // 3. القائمة
            Expanded(
              child:
                  widget.cartItems.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: widget.cartItems.length,
                        separatorBuilder:
                            (context, index) => Divider(
                              height: 1,
                              color: _primaryBlue.withOpacity(0.05),
                              indent: 20,
                              endIndent: 20,
                            ),
                        itemBuilder: (context, index) {
                          // عكس الترتيب (الأحدث في الأعلى) لإظهار آخر مضاف أولاً
                          // ولكن في التنقل (TAB/F3) قد يكون الترتيب البصري هو المطلوب
                          // سنحافظ على ترتيب المصفوفة العكسي هنا
                          final item =
                              widget.cartItems[widget.cartItems.length -
                                  1 -
                                  index];

                          // استخدام عنصر منفصل للحالة (StatefulWidget)
                          return _CartRowItem(
                            key: ValueKey(item.cartItemId),
                            item: item,
                            index: index,
                            products: widget.products,
                            onQuantityUpdated: widget.onQuantityUpdated,
                            onPriceUpdated: widget.onPriceUpdated,
                            onUnitChanged: widget.onUnitChanged,
                            onItemRemoved: widget.onItemRemoved,
                            refreshKey: widget.refreshKey,
                            // تمرير عقدة التركيز الخاصة بالكمية
                            qtyFocusNode: _getQtyFocusNode(item.cartItemId),
                            // دالة العودة للباركود
                            onReturnToBarcode: () {
                              widget.barcodeFocusNode.requestFocus();
                            },
                          );
                        },
                      ),
            ),

            // 4. الفوتر
            if (widget.cartItems.isNotEmpty) _buildFooter(context, totalAmount),
          ],
        ),
      ),
    );
  }

  TextStyle _headerStyle() =>
      TextStyle(color: _primaryBlue, fontSize: 12, fontWeight: FontWeight.bold);

  Widget _buildEmptyState() {
    return GestureDetector(
      // حتى في الحالة الفارغة، النقر يعيد التركيز
      onTap: () => widget.barcodeFocusNode.requestFocus(),
      behavior: HitTestBehavior.translucent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: _primaryBlue.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "السلة فارغة",
            style: TextStyle(
              color: _primaryBlue.withOpacity(0.4),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _primaryBlue.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "الإجمالي النهائي",
                  style: TextStyle(fontSize: 11, color: _primaryBlue),
                ),
                SizedBox(
                  width: 200,
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(999),
                    child: TextFormField(
                      key: ValueKey(
                        '${total.toStringAsFixed(2)}_${widget.refreshKey}',
                      ),
                      initialValue: total.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4A80F0),
                        letterSpacing: 1,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        suffixText: "ش",
                        suffixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (value) {
                        final newTotal = double.tryParse(value);
                        if (newTotal != null) {
                          widget.onTotalUpdated(newTotal);
                        }
                        // العودة للباركود بعد تعديل الإجمالي
                        widget.barcodeFocusNode.requestFocus();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 3,
            child: FocusTraversalOrder(
              order: const NumericFocusOrder(1000),
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: widget.isLoading ? null : widget.onCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shadowColor: const Color(0xFF10B981).withOpacity(0.4),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child:
                      widget.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payment, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "دفع F4",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartRowItem extends StatefulWidget {
  final CartItem item;
  final int index;
  final List<Product> products;
  final Function(String, double) onQuantityUpdated;
  final Function(String, double) onPriceUpdated;
  final Function(String, ProductPackage, bool) onUnitChanged;
  final Function(String) onItemRemoved;
  final int refreshKey;
  // إضافات التركيز
  final FocusNode qtyFocusNode;
  final VoidCallback onReturnToBarcode;

  const _CartRowItem({
    super.key,
    required this.item,
    required this.index,
    required this.products,
    required this.onQuantityUpdated,
    required this.onPriceUpdated,
    required this.onUnitChanged,
    required this.onItemRemoved,
    required this.refreshKey,
    required this.qtyFocusNode,
    required this.onReturnToBarcode,
  });

  @override
  State<_CartRowItem> createState() => _CartRowItemState();
}

class _CartRowItemState extends State<_CartRowItem> {
  late TextEditingController _qtyController;
  late TextEditingController _priceController;
  final Color _primaryBlue = const Color(0xFF4A80F0);
  final Color _lightBlueBg = const Color(0xFFF0F5FF);

  // إضافة هذا المتغير لتتبع ما إذا كان قد تم التخلص من الـ State
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();

    // تهيئة المتحكمات بالقيم الحالية
    _qtyController = TextEditingController(
      text: _formatQuantity(widget.item.quantity),
    );
    _priceController = TextEditingController(
      text: widget.item.price.toStringAsFixed(2),
    );

    // إضافة مستمع للتركيز مع التحقق من حالة التخلص
    widget.qtyFocusNode.addListener(_onQtyFocusChange);
  }

  void _onQtyFocusChange() {
    // التحقق مما إذا كان الـ State مازال موجوداً
    if (!mounted || _isDisposed) return;

    if (widget.qtyFocusNode.hasFocus) {
      // عند التركيز (Focus Gain): تحديد النص بالكامل
      if (_qtyController.text.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && !_isDisposed) {
            _qtyController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _qtyController.text.length,
            );
          }
        });
      }
    } else {
      // عند فقدان التركيز (Focus Loss / Blur): حفظ القيمة
      // هذا يغطي حالة الانتقال بـ F3 أو النقر في مكان آخر
      if (_qtyController.text.isNotEmpty) {
        final val = double.tryParse(_qtyController.text);
        if (val != null && val != widget.item.quantity) {
          widget.onQuantityUpdated(widget.item.cartItemId, val);
        } else if (val == null) {
          // استعادة القيمة الأصلية في حالة الإدخال غير الصالح
          _qtyController.text = _formatQuantity(widget.item.quantity);
        }
      }
    }
  }

  String _formatQuantity(double qty) {
    return qty % 1 == 0 ? qty.toStringAsFixed(0) : qty.toString();
  }

  @override
  void didUpdateWidget(_CartRowItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newQtyText = _formatQuantity(widget.item.quantity);

    // التحقق من mounted قبل تحديث المتحكم
    if (mounted && !_isDisposed) {
      // إذا كان النص في المتحكم لا يطابق الكمية الفعلية القادمة من السلة
      if (_qtyController.text != newQtyText) {
        _qtyController.text = newQtyText;
        // لا نغير مكان المؤشر إذا كان المستخدم يكتب حالياً
        if (!widget.qtyFocusNode.hasFocus) {
          _qtyController.selection = TextSelection.fromPosition(
            TextPosition(offset: _qtyController.text.length),
          );
        }
      }

      // تحديث السعر بنفس المنطق
      final newPriceText = widget.item.price.toStringAsFixed(2);
      if (_priceController.text != newPriceText) {
        _priceController.text = newPriceText;
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    // إزالة المستمع من FocusNode قبل التخلص
    widget.qtyFocusNode.removeListener(_onQtyFocusChange);

    // التخلص من المتحكمات
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Product _getProductForCartItem(CartItem item) {
    try {
      return widget.products.firstWhere((p) => p.id == item.id);
    } catch (e) {
      return Product(
        id: item.id,
        name: item.name,
        price: item.price,
        stock: item.stock,
        packages:
            item.availablePackages
                .where((p) => p.containedQuantity != 1.0)
                .toList(),
      );
    }
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, {bool isPlus = false}) {
    return InkWell(
      onTap: () {
        onTap();
        // إعادة التركيز على الباركود بعد النقر على أزرار + -
        widget.onReturnToBarcode();
      },
      canRequestFocus: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Icon(
          icon,
          size: 14,
          color: isPlus ? _primaryBlue : Colors.black54,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = _getProductForCartItem(widget.item);
    final availablePackages =
        widget.item.availablePackages.isNotEmpty
            ? widget.item.availablePackages
            : [
              ProductPackage(
                name: 'حبة',
                price: product.price,
                containedQuantity: 1.0,
              ),
              ...product.packages,
            ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // 1. الاسم
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: widget.onReturnToBarcode, // النقر على الاسم يعيد التركيز
              child: Text(
                widget.item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF2D3748),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 2. السعر والوحدة
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // قائمة الوحدات
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _lightBlueBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.item.unitName,
                      isExpanded: true,
                      focusNode: FocusNode(canRequestFocus: false),
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: _primaryBlue,
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: _primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                      items:
                          availablePackages
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.name,
                                  enabled: product.stock >= p.containedQuantity,
                                  child: Text(p.name),
                                ),
                              )
                              .toList(),
                      onChanged: (val) {
                        if (val != null && val != widget.item.unitName) {
                          widget.onUnitChanged(
                            widget.item.cartItemId,
                            availablePackages.firstWhere((p) => p.name == val),
                            false,
                          );
                          // إعادة التركيز بعد تغيير الوحدة
                          widget.onReturnToBarcode();
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 2),

                // حقل السعر (يعمل فقط عند الضغط على Enter)
                SizedBox(
                  width: 80,
                  height: 20,
                  child: FocusTraversalOrder(
                    order: NumericFocusOrder(2.5 + widget.index),
                    child: TextField(
                      controller: _priceController,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        suffixText: " ₪",
                        suffixStyle: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      // هذا يضمن أن السعر يتحدث فقط عند ضغط Enter
                      onSubmitted: (v) {
                        widget.onPriceUpdated(
                          widget.item.cartItemId,
                          double.tryParse(v) ?? widget.item.price,
                        );
                        // إعادة التركيز للباركود عند الانتهاء
                        widget.onReturnToBarcode();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 3. الكمية (يعمل فقط عند الضغط على Enter أو الأزرار)
          Expanded(
            flex: 3,
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  _qtyBtn(
                    Icons.remove,
                    () => widget.onQuantityUpdated(
                      widget.item.cartItemId,
                      widget.item.quantity - 1,
                    ),
                  ),
                  Expanded(
                    child: FocusTraversalOrder(
                      order: NumericFocusOrder(2.0 + widget.index),
                      child: TextField(
                        controller: _qtyController,
                        focusNode:
                            widget.qtyFocusNode, // استخدام العقدة الممررة
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (v) {
                          final val = double.tryParse(v);
                          if (val != null) {
                            widget.onQuantityUpdated(
                              widget.item.cartItemId,
                              val,
                            );
                          }
                          // إعادة التركيز للباركود فور ضغط إنتر
                          widget.onReturnToBarcode();
                        },
                      ),
                    ),
                  ),
                  _qtyBtn(
                    Icons.add,
                    () => widget.onQuantityUpdated(
                      widget.item.cartItemId,
                      widget.item.quantity + 1,
                    ),
                    isPlus: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 4. المجموع
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  (widget.item.price * widget.item.quantity).toStringAsFixed(2),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // زر الحذف
          Focus(
            descendantsAreFocusable: false,
            skipTraversal: true,
            child: InkWell(
              onTap: () {
                widget.onItemRemoved(widget.item.cartItemId);
                widget.onReturnToBarcode();
              },
              canRequestFocus: false,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
