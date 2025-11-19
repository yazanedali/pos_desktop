// components/sales/shopping_cart.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_desktop/models/product.dart';
import 'package:pos_desktop/models/product_package.dart';
import '../../models/cart_item.dart';
import '/widgets/top_alert.dart';

// 1. تحويل إلى StatefulWidget للسماح بإدارة الـ Controllers
class ShoppingCart extends StatefulWidget {
  final List<CartItem> cartItems;
  final List<Product> products;
  final Function(String, double) onQuantityUpdated;
  final Function(String, ProductPackage, bool) onUnitChanged;
  final Function(String) onItemRemoved;
  final Function() onCheckout;
  final bool isLoading;

  const ShoppingCart({
    super.key,
    required this.cartItems,
    required this.products,
    required this.onQuantityUpdated,
    required this.onUnitChanged,
    required this.onItemRemoved,
    required this.onCheckout,
    this.isLoading = false,
  });

  @override
  State<ShoppingCart> createState() => _ShoppingCartState();
}

class _ShoppingCartState extends State<ShoppingCart> {
  // دالة مساعدة للعثور على المنتج الأصلي
  Product _getProductForCartItem(CartItem item) {
    return widget.products.firstWhere((p) => p.id == item.id);
  }

  // دالة لحساب الإجمالي
  double _calculateTotal() {
    return widget.cartItems.fold(
      0,
      (total, item) => total + (item.price * item.quantity),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child:
                widget.cartItems.isEmpty
                    ? _buildEmptyCart()
                    : _buildCartItems(),
          ),
          if (widget.cartItems.isNotEmpty) _buildCartFooter(context),
        ],
      ),
    );
  }

  // ودجت رأس السلة
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_cart, color: Colors.blue[800]),
          const SizedBox(width: 8),
          const Text(
            "سلة المشتريات",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const Spacer(),
          if (widget.isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  // ودجت السلة الفارغة
  Widget _buildEmptyCart() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "السلة فارغة",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ودجت قائمة عناصر السلة
  Widget _buildCartItems() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.cartItems.length,
      itemBuilder: (context, index) {
        return _buildCartItem(widget.cartItems[index]);
      },
    );
  }

  // 2. ودجت بناء عنصر السلة (الكود الجديد والمحسّن)
  Widget _buildCartItem(CartItem item) {
    final product = _getProductForCartItem(item);
    final availablePackages = [
      ProductPackage(name: 'حبة', price: product.price, containedQuantity: 1.0),
      ...product.packages,
    ];

    final quantityController = TextEditingController(
      text: item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 3),
    );
    quantityController.selection = TextSelection.fromPosition(
      TextPosition(offset: quantityController.text.length),
    );

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  "${(item.price * item.quantity).toStringAsFixed(2)} شيكل",
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: item.unitName,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    items:
                        availablePackages.map((package) {
                          final bool isEnabled =
                              product.stock >= package.containedQuantity;
                          return DropdownMenuItem(
                            value: package.name,
                            enabled: isEnabled,
                            child: Text(
                              package.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: isEnabled ? Colors.black87 : Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null && value != item.unitName) {
                        final selectedPackage = availablePackages.firstWhere(
                          (p) => p.name == value,
                        );
                        widget.onUnitChanged(
                          item.cartItemId,
                          selectedPackage,
                          false,
                        );
                        item.quantity = 1.0;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      _buildQuantityButton(
                        Icons.remove,
                        () => widget.onQuantityUpdated(
                          item.cartItemId,
                          item.quantity - 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: SizedBox(
                          height: 34,
                          child: TextFormField(
                            controller: quantityController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.zero,
                            ),
                            onFieldSubmitted: (value) {
                              final newQuantity =
                                  double.tryParse(value) ?? item.quantity;
                              widget.onQuantityUpdated(
                                item.cartItemId,
                                newQuantity,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildQuantityButton(
                        Icons.add,
                        () => widget.onQuantityUpdated(
                          item.cartItemId,
                          item.quantity + 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildQuantityButton(
                        Icons.delete,
                        () => widget.onItemRemoved(item.cartItemId),
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 3. ودجت مساعد لبناء الأزرار بشكل متناسق
  Widget _buildQuantityButton(
    IconData icon,
    VoidCallback onPressed, {
    Color color = Colors.black87,
  }) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: color),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor:
              color == Colors.red ? Colors.red.shade50 : Colors.grey[200],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }

  // ودجت تذييل السلة
  Widget _buildCartFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "الإجمالي:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "${_calculateTotal().toStringAsFixed(2)} شيكل",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      widget.isLoading
                          ? null
                          : () => TopAlert.showSuccess(
                            context: context,
                            message: 'تم إرسال الفاتورة للطباعة',
                          ),
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text("طباعة"),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blue.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.isLoading ? null : widget.onCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child:
                      widget.isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text("إتمام البيع"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
