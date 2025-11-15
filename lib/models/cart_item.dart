// models/cart_item.dart
class CartItem {
  final int? id;
  final String name;
  final double price;
  int quantity;
  final String? barcode;
  final int stock;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.barcode,
    required this.stock,
  });

  double get total => price * quantity;

  CartItem copyWith({
    int? id,
    String? name,
    double? price,
    int? quantity,
    String? barcode,
    int? stock,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      barcode: barcode ?? this.barcode,
      stock: stock ?? this.stock,
    );
  }
}
