import '../models/product.dart';
import 'database_helper.dart';
import 'package:pos_desktop/models/product_package.dart';

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
    int? productId;

    await db.transaction((txn) async {
      // 1. إضافة المنتج الأساسي
      productId = await txn.insert('products', {
        'name': product.name,
        'price': product.price,
        'stock': product.stock,
        'barcode': product.barcode,
        'category_id': product.categoryId,
      });

      // 2. إضافة الحزم المرتبطة به
      for (var package in product.packages) {
        await txn.insert('product_packages', {
          'product_id': productId,
          'name': package.name,
          'contained_quantity': package.containedQuantity,
          'price': package.price,
          'barcode': package.barcode,
        });
      }
    });

    final newProduct = (await getProductById(productId!))!;
    newProduct.packages = await getPackagesForProduct(productId!);
    return newProduct;
  }

  Future<Product> updateProduct(int id, Product product) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // 1. تحديث بيانات المنتج الأساسي
      await txn.update(
        'products',
        {
          'name': product.name,
          'price': product.price,
          'stock': product.stock,
          'barcode': product.barcode,
          'category_id': product.categoryId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // 2. حذف كل الحزم القديمة (أسهل طريقة للتعامل مع التعديلات والحذف)
      await txn.delete(
        'product_packages',
        where: 'product_id = ?',
        whereArgs: [id],
      );

      // 3. إضافة الحزم الجديدة
      for (var package in product.packages) {
        await txn.insert('product_packages', {
          'product_id': id,
          'name': package.name,
          'contained_quantity': package.containedQuantity,
          'price': package.price,
          'barcode': package.barcode,
        });
      }
    });

    final updatedProduct = (await getProductById(id))!;
    updatedProduct.packages = await getPackagesForProduct(id);
    return updatedProduct;
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

  Future<List<ProductPackage>> getPackagesForProduct(int productId) async {
    final db = await dbHelper.database;
    final results = await db.query(
      'product_packages',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    return results.map((map) => ProductPackage.fromMap(map)).toList();
  }
}
