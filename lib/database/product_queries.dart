import '../models/product.dart';
import 'database_helper.dart';
import 'package:pos_desktop/models/product_package.dart';

class ProductQueries {
  final DatabaseHelper dbHelper = DatabaseHelper();

  // ---------------------------------------------------------------------------
  // دوال مساعدة (Helpers)
  // ---------------------------------------------------------------------------

  /// جلب الباركودات الإضافية لمنتج معين
  Future<List<String>> _getBarcodesForProduct(int productId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'product_barcodes',
      columns: ['barcode'],
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    return rows.map((r) => r['barcode'] as String).toList();
  }

  // دالة لحساب إجمالي سعر الشراء لجميع المنتجات (مع الفلاتر)
  Future<double> getTotalPurchaseValue({
    String? searchTerm,
    int? categoryId,
    String? stockFilter,
  }) async {
    final db = await dbHelper.database;

    final conditions = <String>[
      'p.is_active = 1',
    ]; // تأكدنا من حساب المنتجات النشطة فقط
    final args = <Object>[];

    if (searchTerm != null && searchTerm.isNotEmpty) {
      conditions.add(
        '(p.name LIKE ? OR p.barcode LIKE ? OR pb.barcode LIKE ? OR c.name LIKE ?)',
      );
      args.addAll([
        '%$searchTerm%',
        '%$searchTerm%',
        '%$searchTerm%',
        '%$searchTerm%',
      ]);
    }

    if (categoryId != null) {
      conditions.add('p.category_id = ?');
      args.add(categoryId);
    }

    if (stockFilter != null) {
      switch (stockFilter) {
        case 'out':
          conditions.add('p.stock <= 0');
          break;
        case 'low':
          conditions.add('p.stock > 0 AND p.stock < 10');
          break;
        case 'in':
          conditions.add('p.stock > 0');
          break;
      }
    }

    final whereClause = conditions.join(' AND ');

    // التعديل الجوهري هنا:
    // نستخدم استعلام فرعي مع GROUP BY لضمان عدم تكرار المنتج بسبب الـ JOIN مع جدول الباركود
    final result = await db.rawQuery('''
      SELECT SUM(sub.item_total) as total_purchase
      FROM (
        SELECT (p.purchase_price * p.stock) as item_total
        FROM products p 
        LEFT JOIN categories c ON p.category_id = c.id 
        LEFT JOIN product_barcodes pb ON pb.product_id = p.id
        WHERE $whereClause
        GROUP BY p.id 
      ) as sub
    ''', args);

    // ملاحظة: GROUP BY p.id تضمن أنه حتى لو ارتبط المنتج بـ 10 باركودات، سيتم إرجاع سطر واحد فقط للمنتج

    final total = result.first['total_purchase'];
    return total is double ? total : (total as num?)?.toDouble() ?? 0.0;
  }

  /// جلب الحزم (Packages) لمنتج معين
  Future<List<ProductPackage>> getPackagesForProduct(int productId) async {
    final db = await dbHelper.database;
    final results = await db.query(
      'product_packages',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    return results.map((map) => ProductPackage.fromMap(map)).toList();
  }

  // ---------------------------------------------------------------------------
  // دوال القراءة (Read / Get)
  // ---------------------------------------------------------------------------

  Future<Product?> getProductById(int id) async {
    final db = await dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        p.*,
        p.purchase_price,
        c.name as category,
        c.color as category_color
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      WHERE p.id = ?
    ''',
      [id],
    );

    if (results.isEmpty) return null;

    final product = Product.fromMap(results.first);
    // تحميل البيانات المرتبطة
    product.additionalBarcodes = await _getBarcodesForProduct(product.id!);
    product.packages = await getPackagesForProduct(product.id!);

    return product;
  }

  /// الدالة الأساسية لعملية البيع (Scan)
  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await dbHelper.database;

    // البحث بذكاء: هل الباركود يطابق العمود الرئيسي OR يطابق أي صف في الجدول الفرعي
    final results = await db.rawQuery(
      '''
      SELECT 
        p.*,
        p.purchase_price,
        c.name as category,
        c.color as category_color
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      LEFT JOIN product_barcodes pb ON p.id = pb.product_id 
      WHERE p.is_active = 1 
      AND (p.barcode = ? OR pb.barcode = ?)
      LIMIT 1
    ''',
      [barcode, barcode],
    );

    if (results.isNotEmpty) {
      final product = Product.fromMap(results.first);
      product.additionalBarcodes = await _getBarcodesForProduct(product.id!);
      product.packages = await getPackagesForProduct(product.id!);
      return product;
    }

    // إذا لم نجد المنتج، نبحث في الحزم (Packages)
    final packageResults = await db.rawQuery(
      '''
      SELECT product_id FROM product_packages WHERE barcode = ?
    ''',
      [barcode],
    );

    if (packageResults.isNotEmpty) {
      final productId = packageResults.first['product_id'] as int;
      return await getProductById(productId);
    }

    return null;
  }

  Future<Product?> getProductByName(String name) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'products',
      where: 'name = ? AND is_active = 1',
      whereArgs: [name],
    );
    if (maps.isNotEmpty) {
      final p = Product.fromMap(maps.first);
      if (p.id != null) {
        p.additionalBarcodes = await _getBarcodesForProduct(p.id!);
        p.packages = await getPackagesForProduct(p.id!);
      }
      return p;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // دوال الكتابة (Create / Update / Delete)
  // ---------------------------------------------------------------------------

  Future<Product> createProduct(Product product) async {
    final db = await dbHelper.database;
    int? productId;

    await db.transaction((txn) async {
      // 1. إضافة المنتج الأساسي
      productId = await txn.insert('products', {
        'name': product.name,
        'price': product.price,
        'purchase_price': product.purchasePrice,
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

      // 3. إضافة الباركودات الإضافية (إن وُجدت)
      if (product.additionalBarcodes.isNotEmpty) {
        for (var code in product.additionalBarcodes) {
          if (code.trim().isEmpty) continue;
          // لا نكرر الباركود الأساسي
          if (product.barcode != null && code == product.barcode) continue;
          try {
            await txn.insert('product_barcodes', {
              'product_id': productId,
              'barcode': code.trim(),
            });
          } catch (e) {
            // تجاهل الخطأ في حال تكرار الباركود
          }
        }
      }
    });

    return (await getProductById(productId!))!;
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
          'purchase_price': product.purchasePrice,
          'stock': product.stock,
          'barcode': product.barcode,
          'category_id': product.categoryId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // 2. تحديث الحزم (حذف القديم وإضافة الجديد)
      await txn.delete(
        'product_packages',
        where: 'product_id = ?',
        whereArgs: [id],
      );
      for (var package in product.packages) {
        await txn.insert('product_packages', {
          'product_id': id,
          'name': package.name,
          'contained_quantity': package.containedQuantity,
          'price': package.price,
          'barcode': package.barcode,
        });
      }

      // 3. تحديث الباركودات الإضافية (حذف القديم وإضافة الجديد)
      await txn.delete(
        'product_barcodes',
        where: 'product_id = ?',
        whereArgs: [id],
      );
      if (product.additionalBarcodes.isNotEmpty) {
        for (var code in product.additionalBarcodes) {
          if (code.trim().isEmpty) continue;
          if (product.barcode != null && code == product.barcode) continue;
          try {
            await txn.insert('product_barcodes', {
              'product_id': id,
              'barcode': code.trim(),
            });
          } catch (e) {
            // تجاهل التكرار
          }
        }
      }
    });

    return (await getProductById(id))!;
  }

  Future<void> deleteProduct(int id) async {
    final db = await dbHelper.database;
    // بسبب ON DELETE CASCADE في قاعدة البيانات، سيتم حذف الباركودات والحزم تلقائياً
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
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

  // ---------------------------------------------------------------------------
  // دوال القوائم والبحث (List & Search)
  // ---------------------------------------------------------------------------

  Future<List<Product>> getAllProducts() async {
    final db = await dbHelper.database;
    // نستخدم GROUP BY لضمان عدم تكرار المنتج في القائمة
    final results = await db.rawQuery('''
      SELECT 
        p.id,
        p.name,
        p.price,
        p.purchase_price,
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

    final products = results.map((map) => Product.fromMap(map)).toList();
    // تحميل الباركودات الإضافية لكل منتج
    for (var p in products) {
      if (p.id != null) {
        p.additionalBarcodes = await _getBarcodesForProduct(p.id!);
      }
    }
    return products;
  }

  Future<List<Product>> searchProducts(String searchTerm) async {
    final db = await dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        p.id,
        p.name,
        p.price,
        p.purchase_price,
        p.stock,
        p.barcode,
        p.created_at,
        c.name as category,
        c.color as category_color
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      LEFT JOIN product_barcodes pb ON pb.product_id = p.id
      WHERE p.is_active = 1 
        AND (
          p.name LIKE ? 
          OR p.barcode LIKE ? 
          OR pb.barcode LIKE ? -- ✅ البحث في الباركودات الإضافية
          OR c.name LIKE ?
        )
      GROUP BY p.id -- ✅ منع تكرار المنتج في النتائج
      ORDER BY p.created_at DESC
    ''',
      ['%$searchTerm%', '%$searchTerm%', '%$searchTerm%', '%$searchTerm%'],
    );

    final products = results.map((map) => Product.fromMap(map)).toList();
    for (var p in products) {
      if (p.id != null) {
        p.additionalBarcodes = await _getBarcodesForProduct(p.id!);
      }
    }
    return products;
  }

  // ---------------------------------------------------------------------------
  // Pagination (نظام الصفحات)
  // ---------------------------------------------------------------------------

  static const int pageSize = 20;

  Future<List<Product>> getProductsPaginated({
    required int page,
    String? searchTerm,
    int? categoryId,
    String? stockFilter, // 'out', 'low', 'in'
  }) async {
    final db = await dbHelper.database;
    final offset = (page - 1) * pageSize;

    final conditions = <String>['p.is_active = 1'];
    final args = <Object>[];

    if (searchTerm != null && searchTerm.isNotEmpty) {
      conditions.add(
        '(p.name LIKE ? OR p.barcode LIKE ? OR pb.barcode LIKE ? OR c.name LIKE ?)',
      );
      args.addAll([
        '%$searchTerm%',
        '%$searchTerm%',
        '%$searchTerm%',
        '%$searchTerm%',
      ]);
    }

    if (categoryId != null) {
      conditions.add('p.category_id = ?');
      args.add(categoryId);
    }

    // إضافة فلتر المخزون
    if (stockFilter != null) {
      switch (stockFilter) {
        case 'out':
          conditions.add('p.stock <= 0');
          break;
        case 'low':
          conditions.add('p.stock > 0 AND p.stock < 10');
          break;
        case 'in':
          conditions.add('p.stock > 0');
          break;
      }
    }

    final whereClause = conditions.join(' AND ');

    final results = await db.rawQuery('''
    SELECT 
      p.id,
      p.name,
      p.price,
      p.purchase_price,
      p.stock,
      p.barcode,
      p.created_at,
      c.name as category,
      c.color as category_color,
      c.id as category_id
    FROM products p 
    LEFT JOIN categories c ON p.category_id = c.id 
    LEFT JOIN product_barcodes pb ON pb.product_id = p.id
    WHERE $whereClause
    GROUP BY p.id
    ORDER BY p.created_at DESC
    LIMIT $pageSize OFFSET $offset
  ''', args);

    final products = results.map((map) => Product.fromMap(map)).toList();
    for (var p in products) {
      if (p.id != null) {
        p.additionalBarcodes = await _getBarcodesForProduct(p.id!);
      }
    }
    return products;
  }

  Future<int> getProductsCount({
    String? searchTerm,
    int? categoryId,
    String? stockFilter,
  }) async {
    final db = await dbHelper.database;

    final conditions = <String>['p.is_active = 1'];
    final args = <Object>[];

    if (searchTerm != null && searchTerm.isNotEmpty) {
      conditions.add(
        '(p.name LIKE ? OR p.barcode LIKE ? OR pb.barcode LIKE ? OR c.name LIKE ?)',
      );
      args.addAll([
        '%$searchTerm%',
        '%$searchTerm%',
        '%$searchTerm%',
        '%$searchTerm%',
      ]);
    }

    if (categoryId != null) {
      conditions.add('p.category_id = ?');
      args.add(categoryId);
    }

    // إضافة فلتر المخزون
    if (stockFilter != null) {
      switch (stockFilter) {
        case 'out':
          conditions.add('p.stock <= 0');
          break;
        case 'low':
          conditions.add('p.stock > 0 AND p.stock < 10');
          break;
        case 'in':
          conditions.add('p.stock > 0');
          break;
      }
    }

    final whereClause = conditions.join(' AND ');

    final result = await db.rawQuery('''
    SELECT 
      COUNT(DISTINCT p.id) AS count
    FROM products p 
    LEFT JOIN categories c ON p.category_id = c.id 
    LEFT JOIN product_barcodes pb ON pb.product_id = p.id
    WHERE $whereClause
  ''', args);

    return result.first['count'] as int? ?? 0;
  }

  // ---------------------------------------------------------------------------
  // دوال أخرى
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await dbHelper.database;
    return await db.query('categories', orderBy: 'name');
  }

  Future<List<Product>> getProductsForPurchase({
    String? searchTerm,
    int? categoryId,
  }) async {
    final db = await dbHelper.database;

    final conditions = <String>['p.is_active = 1'];
    final args = <Object>[];

    if (searchTerm != null && searchTerm.isNotEmpty) {
      conditions.add(
        '(p.name LIKE ? OR p.barcode LIKE ? OR pb.barcode LIKE ?)',
      );
      args.addAll(['%$searchTerm%', '%$searchTerm%', '%$searchTerm%']);
    }

    if (categoryId != null) {
      conditions.add('p.category_id = ?');
      args.add(categoryId);
    }

    final whereClause = conditions.join(' AND ');

    final results = await db.rawQuery('''
    SELECT 
      p.id,
      p.name,
      p.price,
      p.purchase_price,
      p.stock,
      p.barcode,
      p.category_id,
      c.name as category,
      c.color as category_color
    FROM products p 
    LEFT JOIN categories c ON p.category_id = c.id 
    LEFT JOIN product_barcodes pb ON pb.product_id = p.id
    WHERE $whereClause
    GROUP BY p.id -- ✅ منع التكرار
    ORDER BY p.name
    LIMIT 100
  ''', args);

    final products = results.map((map) => Product.fromMap(map)).toList();
    for (var p in products) {
      if (p.id != null) {
        p.additionalBarcodes = await _getBarcodesForProduct(p.id!);
      }
    }
    return products;
  }
}
