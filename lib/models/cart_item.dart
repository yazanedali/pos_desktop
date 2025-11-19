// models/cart_item.dart
import 'package:pos_desktop/models/product_package.dart';

class CartItem {
  final String cartItemId; // <-- معرّف فريد لكل عنصر في السلة
  final int? id;
  String name;
  double price;
  double quantity;
  final String? barcode;
  final double stock;
  String unitName;
  double unitQuantity;
  final List<ProductPackage> availablePackages;

  CartItem({
    required this.cartItemId,
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.barcode,
    required this.stock,
    required this.unitName,
    required this.unitQuantity,
    this.availablePackages = const [],
  });

  double get total => price * quantity;

  CartItem copyWith({
    int? id,
    String? name,
    double? price,
    double? quantity,
    String? barcode,
    double? stock,
    List<ProductPackage>? availablePackages,
  }) {
    return CartItem(
      cartItemId: cartItemId,
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      barcode: barcode ?? this.barcode,
      stock: stock ?? this.stock,
      unitName: unitName,
      unitQuantity: unitQuantity,
      availablePackages: availablePackages ?? this.availablePackages,
    );
  }
}
