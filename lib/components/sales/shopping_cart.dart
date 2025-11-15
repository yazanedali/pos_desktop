// components/sales/shopping_cart.dart
import 'package:flutter/material.dart';
import '../../models/cart_item.dart';
import '/widgets/top_alert.dart';

class ShoppingCart extends StatelessWidget {
  final List<CartItem> cartItems;
  final Function(int, int) onQuantityUpdated;
  final Function(int) onItemRemoved;
  final Function() onCheckout;
  final bool isLoading; // أضف هذا

  const ShoppingCart({
    super.key,
    required this.cartItems,
    required this.onQuantityUpdated,
    required this.onItemRemoved,
    required this.onCheckout,
    this.isLoading = false, // قيمة افتراضية
  });

  double _calculateTotal() {
    return cartItems.fold(
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
          // Header
          Container(
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
                if (isLoading) // أضف هذا
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          // Cart Content
          Expanded(
            child: cartItems.isEmpty ? _buildEmptyCart() : _buildCartItems(),
          ),
          // Footer
          if (cartItems.isNotEmpty) _buildCartFooter(context),
        ],
      ),
    );
  }

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

  Widget _buildCartItems() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cartItems.length,
      itemBuilder: (context, index) {
        return _buildCartItem(cartItems[index]);
      },
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${item.price.toStringAsFixed(2)} شيكل",
                  style: const TextStyle(color: Colors.blue, fontSize: 12),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                // التأكد من أن item.id ليس null
                onPressed: () => onQuantityUpdated(item.id!, item.quantity - 1),
                icon: const Icon(Icons.remove, size: 16),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(4),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                alignment: Alignment.center,
                child: Text(
                  item.quantity.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => onQuantityUpdated(item.id!, item.quantity + 1),
                icon: const Icon(Icons.add, size: 16),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(4),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => onItemRemoved(item.id!),
                icon: const Icon(Icons.delete, size: 16),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.all(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
                child: OutlinedButton(
                  onPressed:
                      isLoading
                          ? null
                          : () {
                            // أضف التحقق من isLoading
                            TopAlert.showSuccess(
                              context: context,
                              message: 'تم إرسال الفاتورة للطباعة',
                            );
                          },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blue.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.print, size: 18),
                      SizedBox(width: 8),
                      Text("طباعة"),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      isLoading ? null : onCheckout, // أضف التحقق من isLoading
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child:
                      isLoading
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
