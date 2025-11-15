// services/category_queries.dart
import 'package:sqflite/sqflite.dart';
import '../models/category.dart';
import 'database_helper.dart';

class CategoryQueries {
  final DatabaseHelper dbHelper = DatabaseHelper();

  // الحصول على جميع الفئات
  Future<List<Category>> getAllCategories() async {
    final db = await dbHelper.database;
    final results = await db.query('categories', orderBy: 'name ASC');
    return results.map((map) => Category.fromMap(map)).toList();
  }

  // الحصول على فئة بواسطة ID
  Future<Category?> getCategoryById(int id) async {
    final db = await dbHelper.database;
    final results = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? Category.fromMap(results.first) : null;
  }

  // إضافة فئة جديدة
  Future<int> insertCategory(Category category) async {
    final db = await dbHelper.database;
    final map = category.toMap();
    // إزالة id إذا كان null لتفعيل AUTOINCREMENT
    if (category.id != null) {
      map['id'] = category.id;
    }
    return await db.insert('categories', map);
  }

  // تحديث فئة موجودة
  Future<int> updateCategory(Category category) async {
    final db = await dbHelper.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  // حذف فئة
  Future<int> deleteCategory(int id) async {
    final db = await dbHelper.database;

    // التحقق من عدم وجود منتجات مرتبطة بهذه الفئة
    final productsCount = await getProductsCountInCategory(id);

    if (productsCount > 0) {
      throw Exception('لا يمكن حذف الفئة لأنها تحتوي على $productsCount منتج');
    }

    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // البحث في الفئات
  Future<List<Category>> searchCategories(String searchTerm) async {
    final db = await dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT * FROM categories 
      WHERE name LIKE ? OR description LIKE ?
      ORDER BY name ASC
      ''',
      ['%$searchTerm%', '%$searchTerm%'],
    );
    return results.map((map) => Category.fromMap(map)).toList();
  }

  // التحقق من وجود فئة بنفس الاسم
  Future<bool> isCategoryNameExists(String name, {int? excludeId}) async {
    final db = await dbHelper.database;
    final query =
        excludeId == null
            ? 'SELECT COUNT(*) as count FROM categories WHERE name = ?'
            : 'SELECT COUNT(*) as count FROM categories WHERE name = ? AND id != ?';

    final results = await db.rawQuery(
      query,
      excludeId == null ? [name] : [name, excludeId],
    );

    return (results.first['count'] as int) > 0;
  }

  // الحصول على عدد المنتجات في الفئة
  Future<int> getProductsCountInCategory(int categoryId) async {
    final db = await dbHelper.database;
    final results = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE category_id = ?',
      [categoryId],
    );
    return (results.first['count'] as int);
  }

  Future<List<Category>> getCategories() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    return List.generate(maps.length, (i) {
      return Category.fromMap(maps[i]); // افترض وجود fromMap في مودل Category
    });
  }

  Future<int> countProductsInCategory(int categoryId) async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM products WHERE category_id = ?',
      [categoryId],
    );
    // firstIntValue_sqflite هو أداة مساعدة لجلب القيمة العددية الأولى من نتيجة الاستعلام
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
