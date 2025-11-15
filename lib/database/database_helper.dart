import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // للحصول على مسار قاعدة البيانات على Desktop
    Directory documentsDirectory;
    try {
      documentsDirectory = await getApplicationDocumentsDirectory();
    } catch (e) {
      // إذا فشل getApplicationDocumentsDirectory، استخدم المسار الحالي
      documentsDirectory = Directory.current;
    }

    String path = join(documentsDirectory.path, 'pos_database.db');

    return await openDatabase(path, version: 1, onCreate: _createDatabase);
  }

  Future<void> _createDatabase(Database db, int version) async {
    await _createTables(db);
    await _insertInitialData(db);
  }

  Future<void> _createTables(Database db) async {
    // جدول الفئات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        color TEXT DEFAULT '#3B82F6',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // جدول المنتجات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        stock INTEGER DEFAULT 0,
        barcode TEXT UNIQUE,
        category_id INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // جدول فواتير المبيعات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        total REAL NOT NULL,
        cashier TEXT NOT NULL,
        customer_name TEXT,
        payment_method TEXT DEFAULT 'نقدي',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // جدول عناصر فواتير المبيعات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES sales_invoices (id) ON DELETE CASCADE
      )
    ''');

    // جدول فواتير الشراء
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        supplier TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        total REAL NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // جدول عناصر فواتير الشراء
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        barcode TEXT,
        category TEXT,
        quantity INTEGER NOT NULL,
        purchase_price REAL NOT NULL,
        sale_price REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES purchase_invoices (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _insertInitialData(Database db) async {
    // التحقق من وجود بيانات مسبقاً
    final categoriesCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categories'),
    );

    if (categoriesCount == 0) {
      // إضافة الفئات
      await db.insert('categories', {'name': 'مشروبات', 'color': '#3B82F6'});
      await db.insert('categories', {
        'name': 'وجبات خفيفة',
        'color': '#10B981',
      });
      await db.insert('categories', {'name': 'حلويات', 'color': '#F59E0B'});

      // الحصول على معرفات الفئات
      final categories = await db.query('categories');
      final categoryMap = {
        for (var category in categories) category['name']: category['id'],
      };

      // إضافة المنتجات
      await db.insert('products', {
        'name': 'كوكا كولا',
        'price': 2.5,
        'stock': 50,
        'barcode': '12345',
        'category_id': categoryMap['مشروبات'],
      });
      await db.insert('products', {
        'name': 'شيبس',
        'price': 1.5,
        'stock': 30,
        'barcode': '67890',
        'category_id': categoryMap['وجبات خفيفة'],
      });
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
