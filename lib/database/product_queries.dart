import '../models/product.dart';
import 'database_helper.dart';

class ProductQueries {
  final DatabaseHelper dbHelper = DatabaseHelper();

  Future<List<Product>> getAllProducts() async {
    final db = await dbHelper.database;
    final results = await db.rawQuery('''
      SELECT 
        p.id,
        p.name,
        p.price,
        p.stock,
        p.barcode,
        p.created_at,
        c.name as category,
        c.color as category_color,
        c.id as category_id
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      WHERE p.is_active = 1
      ORDER BY p.created_at DESC
    ''');

    return results.map((map) => Product.fromMap(map)).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        p.*,
        c.name as category,
        c.color as category_color
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      WHERE p.id = ?
    ''',
      [id],
    );

    return results.isNotEmpty ? Product.fromMap(results.first) : null;
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        p.*,
        c.name as category,
        c.color as category_color
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      WHERE p.barcode = ? AND p.is_active = 1
    ''',
      [barcode],
    );

    return results.isNotEmpty ? Product.fromMap(results.first) : null;
  }

  Future<Product> createProduct(Product product) async {
    final db = await dbHelper.database;

    // الحصول على category_id إذا تم تحديد فئة
    int? categoryId;
    if (product.category != null) {
      final categoryResults = await db.query(
        'categories',
        where: 'name = ?',
        whereArgs: [product.category],
      );
      categoryId =
          categoryResults.isNotEmpty
              ? categoryResults.first['id'] as int?
              : null;
    }

    final id = await db.insert('products', {
      'name': product.name,
      'price': product.price,
      'stock': product.stock,
      'barcode': product.barcode,
      'category_id': categoryId,
    });

    return (await getProductById(id))!;
  }

  Future<Product> updateProduct(int id, Product product) async {
    final db = await dbHelper.database;

    final Map<String, dynamic> updateData = {};

    if (product.name.isNotEmpty) updateData['name'] = product.name;
    if (product.price > 0) updateData['price'] = product.price;
    if (product.stock >= 0) updateData['stock'] = product.stock;
    if (product.barcode != null) updateData['barcode'] = product.barcode;

    if (product.category != null) {
      final categoryResults = await db.query(
        'categories',
        where: 'name = ?',
        whereArgs: [product.category],
      );
      updateData['category_id'] =
          categoryResults.isNotEmpty ? categoryResults.first['id'] : null;
    }

    updateData['updated_at'] = DateTime.now().toIso8601String();

    await db.update('products', updateData, where: 'id = ?', whereArgs: [id]);

    return (await getProductById(id))!;
  }

  Future<void> deleteProduct(int id) async {
    final db = await dbHelper.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> searchProducts(String searchTerm) async {
    final db = await dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        p.id,
        p.name,
        p.price,
        p.stock,
        p.barcode,
        p.created_at,
        c.name as category,
        c.color as category_color
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      WHERE p.is_active = 1 
        AND (p.name LIKE ? OR p.barcode LIKE ? OR c.name LIKE ?)
      ORDER BY p.created_at DESC
    ''',
      ['%$searchTerm%', '%$searchTerm%', '%$searchTerm%'],
    );

    return results.map((map) => Product.fromMap(map)).toList();
  }

  Future<void> updateProductStock(int productId, int newStock) async {
    final db = await dbHelper.database;
    await db.update(
      'products',
      {'stock': newStock, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }
}
