class ProductPackage {
  int? id;
  int? productId;
  String name;
  double containedQuantity;
  double price;
  String? barcode;

  ProductPackage({
    this.id,
    this.productId,
    required this.name,
    required this.containedQuantity,
    required this.price,
    this.barcode,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'name': name,
      'contained_quantity': containedQuantity,
      'price': price,
      'barcode': barcode,
    };
  }

  factory ProductPackage.fromMap(Map<String, dynamic> map) {
    return ProductPackage(
      id: map['id'],
      productId: map['product_id'],
      name: map['name'],
      containedQuantity: (map['contained_quantity'] as num).toDouble(),
      price: (map['price'] as num).toDouble(),
      barcode: map['barcode'],
    );
  }
}
