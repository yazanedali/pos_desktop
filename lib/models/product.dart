import 'package:pos_desktop/models/product_package.dart';

class Product {
  final int? id;
  final String name;
  final double price; // سعر البيع
  final double purchasePrice; // سعر الشراء - NEW
  double stock;
  final String? barcode;
  List<ProductPackage> packages;
  // Additional barcodes (alternative barcodes) for the same product
  List<String> additionalBarcodes;

  // --- === التعديل الرئيسي === ---
  final int? categoryId; // أضفنا هذا الحقل لتخزين رقم الفئة
  final String?
  category; // أبقينا على هذا الحقل لتسهيل عرض اسم الفئة في الواجهة
  // --- ======================= ---

  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  Product({
    this.id,
    required this.name,
    required this.price,
    this.purchasePrice = 0.0, // Default to 0
    this.stock = 0.0,
    this.barcode,
    this.categoryId, // تمت إضافته للمُنشئ
    this.category,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.packages = const [],
    this.additionalBarcodes = const [],
  });

  // Convert a Product to a Map for the database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'purchase_price': purchasePrice,
      'stock': stock,
      'barcode': barcode,
      'category_id': categoryId, // --- تعديل: إرسال الـ ID إلى قاعدة البيانات
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // Create a Product from a Map from the database
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      price:
          map['price'] is int ? (map['price'] as int).toDouble() : map['price'],
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num? ?? 0).toDouble(),
      barcode: map['barcode'],
      categoryId:
          map['category_id'], // --- تعديل: قراءة الـ ID من قاعدة البيانات
      category: map['category'], // هذا سيأتي من استعلام JOIN لاحقًا
      isActive: map['is_active'] == 1,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      additionalBarcodes: [], // populated by ProductQueries when needed
    );
  }

  // Copy with method
  Product copyWith({
    int? id,
    String? name,
    double? price,
    double? purchasePrice,
    double? stock,
    String? barcode,
    int? categoryId, // تمت إضافته هنا
    String? category,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    List<ProductPackage>? packages,
    List<String>? additionalBarcodes,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      stock: stock ?? this.stock,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId, // تمت إضافته هنا
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      packages: packages ?? this.packages,
      additionalBarcodes: additionalBarcodes ?? this.additionalBarcodes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
