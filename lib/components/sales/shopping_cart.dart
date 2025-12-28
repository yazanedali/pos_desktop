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
  final double? customTotal;

  const ShoppingCart({
    super.key,
    required this.cartItems,
    required this.products,
    required this.onQuantityUpdated,
    required this.onPriceUpdated,
    required this.onUnitChanged,
    required this.onItemRemoved,
    required this.onCheckout,
    required this.onTotalUpdated,
    this.customTotal,
    this.isLoading = false,
  });

  @override
  State<ShoppingCart> createState() => _ShoppingCartState();
}

class _ShoppingCartState extends State<ShoppingCart> {
  // الألوان الأساسية
  final Color _primaryBlue = const Color(0xFF4A80F0);
  final Color _lightBlueBg = const Color(0xFFF0F5FF);

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

  double _calculateTotal() {
    return widget.cartItems.fold(
      0,
      (total, item) => total + (item.price * item.quantity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = widget.customTotal ?? _calculateTotal();

    return Container(
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
          // 1. ترويسة السلة
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ), // تقليل الارتفاع قليلاً هنا أيضاً
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A80F0), Color(0xFF9355F4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "سلة المشتريات (${widget.cartItems.length})",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                if (widget.cartItems.isNotEmpty)
                  Focus(
                    descendantsAreFocusable: false,
                    skipTraversal: true,
                    child: InkWell(
                      onTap: () {}, // إضافة كود التفريغ هنا
                      canRequestFocus: false,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.delete_sweep,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "تفريغ",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 2. عناوين الأعمدة
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ), // تقليل الارتفاع
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
                    "الكمية",
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
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                      ), // تقليل الحاشية العلوية والسفلية للقائمة
                      itemCount: widget.cartItems.length,
                      separatorBuilder:
                          (context, index) => Divider(
                            height: 1,
                            color: _primaryBlue.withOpacity(0.05),
                            indent: 20,
                            endIndent: 20,
                          ),
                      itemBuilder: (context, index) {
                        final item =
                            widget.cartItems[widget.cartItems.length -
                                1 -
                                index];
                        return _buildCartRow(item, Key(item.cartItemId), index);
                      },
                    ),
          ),

          // 4. الفوتر
          if (widget.cartItems.isNotEmpty) _buildFooter(context, totalAmount),
        ],
      ),
    );
  }

  TextStyle _headerStyle() =>
      TextStyle(color: _primaryBlue, fontSize: 12, fontWeight: FontWeight.bold);

  Widget _buildEmptyState() {
    return Column(
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
          style: TextStyle(color: _primaryBlue.withOpacity(0.4), fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildCartRow(CartItem item, Key key, int index) {
    final product = _getProductForCartItem(item);
    final availablePackages =
        item.availablePackages.isNotEmpty
            ? item.availablePackages
            : [
              ProductPackage(
                name: 'حبة',
                price: product.price,
                containedQuantity: 1.0,
              ),
              ...product.packages,
            ];

    return Container(
      key: key,
      // ✅ تم تقليل الـ Padding العمودي من 14 إلى 8 لتقليل ارتفاع السطر
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // 1. الاسم
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF2D3748),
                  ),
                  maxLines: 1, // جعلته سطر واحد لتوفير المساحة
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 2. السعر والوحدة
          Expanded(
            flex: 3,
            child: Focus(
              descendantsAreFocusable: false,
              skipTraversal: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // قائمة الوحدات (ارتفاع أقل)
                  Container(
                    height: 26, // ✅ تم التقليل من 30 إلى 26
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: _lightBlueBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: item.unitName,
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
                                    enabled:
                                        product.stock >= p.containedQuantity,
                                    child: Text(p.name),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          if (val != null && val != item.unitName) {
                            widget.onUnitChanged(
                              item.cartItemId,
                              availablePackages.firstWhere(
                                (p) => p.name == val,
                              ),
                              false,
                            );
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 2), // مسافة صغيرة جداً
                  // حقل السعر
                  SizedBox(
                    width: 80,
                    height: 20, // ✅ ارتفاع صغير للسعر
                    child: TextFormField(
                      initialValue: item.price.toStringAsFixed(2),
                      focusNode: FocusNode(canRequestFocus: false),
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
                      onFieldSubmitted:
                          (v) => widget.onPriceUpdated(
                            item.cartItemId,
                            double.tryParse(v) ?? item.price,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 3. الكمية
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
                      item.cartItemId,
                      item.quantity - 1,
                    ),
                  ),
                  Expanded(
                    child: FocusTraversalOrder(
                      order: NumericFocusOrder(2.0 + index),
                      child: TextFormField(
                        initialValue:
                            item.quantity % 1 == 0
                                ? item.quantity.toStringAsFixed(0)
                                : item.quantity.toString(),
                        textAlign: TextAlign.center,
                        // Removed FocusNode(skipTraversal: false, canRequestFocus: true)
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onFieldSubmitted: (v) {
                          final val = double.tryParse(v);
                          if (val != null) {
                            widget.onQuantityUpdated(item.cartItemId, val);
                          }
                        },
                      ),
                    ),
                  ),
                  _qtyBtn(
                    Icons.add,
                    () => widget.onQuantityUpdated(
                      item.cartItemId,
                      item.quantity + 1,
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
                  (item.price * item.quantity).toStringAsFixed(2),
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
              onTap: () => widget.onItemRemoved(item.cartItemId),
              canRequestFocus: false,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(4), // تصغير مساحة اللمس قليلاً
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

  Widget _qtyBtn(IconData icon, VoidCallback onTap, {bool isPlus = false}) {
    return InkWell(
      onTap: onTap,
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

  Widget _buildFooter(BuildContext context, double total) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 16,
      ), // تقليل البادينغ العمودي للفوتر
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
                  child: Focus(
                    descendantsAreFocusable: false,
                    skipTraversal: true,
                    child: TextFormField(
                      key: ValueKey(total),
                      initialValue: total.toStringAsFixed(2),
                      focusNode: FocusNode(canRequestFocus: false),
                      style: const TextStyle(
                        fontSize: 24, // تصغير الخط قليلاً
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4A80F0),
                        letterSpacing: 1,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        suffixText: " ₪",
                        suffixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onFieldSubmitted: (value) {
                        final newTotal = double.tryParse(value);
                        if (newTotal != null) {
                          widget.onTotalUpdated(newTotal);
                        }
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
                height: 48, // تقليل ارتفاع زر الدفع قليلاً
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
                                "دفع (Space)",
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
