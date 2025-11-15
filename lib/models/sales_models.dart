class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
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
}

class Product {
  final String id;
  final String name;
  final double price;
  final String? barcode;
  final int stock;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.barcode,
    required this.stock,
  });
}
