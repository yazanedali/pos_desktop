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

    final db = await openDatabase(
      path,
      version: 8, // غير من 7 إلى 8 لتعريف الصناديق
      onCreate: _createDatabase,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Migration path: v2 -> v3 add product_barcodes table
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS product_barcodes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              product_id INTEGER NOT NULL,
              barcode TEXT UNIQUE NOT NULL,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
            )
          ''');

          // Create index to speed up lookups
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_product_barcodes_barcode ON product_barcodes(barcode)',
          );
        }

        // Migration path: v7 -> v8 (Add Cash Boxes)
        if (oldVersion < 8) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cash_boxes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT UNIQUE NOT NULL,
              balance REAL DEFAULT 0,
              updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cash_movements (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              box_id INTEGER NOT NULL,
              amount REAL NOT NULL,
              type TEXT NOT NULL,
              direction TEXT NOT NULL,
              notes TEXT,
              date TEXT NOT NULL,
              time TEXT NOT NULL,
              related_id TEXT,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (box_id) REFERENCES cash_boxes (id)
            )
          ''');

          // إدخال الصناديق الافتراضية إذا لم تكن موجودة
          await db.insert('cash_boxes', {
            'name': 'الصندوق اليومي',
            'balance': 0.0,
            'updated_at': DateTime.now().toIso8601String(),
          });
          await db.insert('cash_boxes', {
            'name': 'الصندوق الرئيسي',
            'balance': 0.0,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }

        // Migration path: v3 -> v4 Add Suppliers and Wallet Balance
        if (oldVersion < 4) {
          // Logic intentionally left empty or same as original,
          // but we rely on the v6 catch-all block below to be safer.
        }

        // Migration path: v4 -> v5 (Was incomplete in previous attempts)
        if (oldVersion < 5) {
          // No specific migration, just ensuring upgrade path
        }

        // Migration path: v5 -> v6 (Existing migrations)
        if (oldVersion < 6) {
          // 1. Ensure Suppliers table exists
          await db.execute('''
            CREATE TABLE IF NOT EXISTS suppliers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              phone TEXT,
              address TEXT,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');

          // 2. Ensure purchase_price exists
          try {
            await db.execute(
              "ALTER TABLE products ADD COLUMN purchase_price REAL DEFAULT 0",
            );
          } catch (e) {
            // Column likely exists
          }

          // 3. Ensure wallet_balance exists
          try {
            await db.execute(
              "ALTER TABLE customers ADD COLUMN wallet_balance REAL DEFAULT 0",
            );
          } catch (e) {
            // Column likely exists
          }

          // 4. Ensure purchase_invoices columns exist
          try {
            await db.execute(
              "ALTER TABLE purchase_invoices ADD COLUMN supplier_id INTEGER",
            );
            await db.execute(
              "ALTER TABLE purchase_invoices ADD COLUMN payment_status TEXT DEFAULT 'مدفوع'",
            );
            await db.execute(
              "ALTER TABLE purchase_invoices ADD COLUMN paid_amount REAL DEFAULT 0",
            );
            await db.execute(
              "ALTER TABLE purchase_invoices ADD COLUMN remaining_amount REAL DEFAULT 0",
            );
            await db.execute(
              "ALTER TABLE purchase_invoices ADD COLUMN payment_type TEXT DEFAULT 'نقدي'",
            );
            await db.execute(
              "ALTER TABLE purchase_invoices ADD COLUMN notes TEXT",
            );
          } catch (e) {
            // Columns likely exist
          }

          await db.execute('''
            CREATE TABLE IF NOT EXISTS supplier_payments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              supplier_id INTEGER NOT NULL,
              payment_date TEXT NOT NULL,
              payment_time TEXT NOT NULL,
              amount REAL NOT NULL,
              payment_type TEXT DEFAULT 'نقدي',
              notes TEXT,
              invoice_id INTEGER,
              is_opening_balance INTEGER DEFAULT 0,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE,
              FOREIGN KEY (invoice_id) REFERENCES purchase_invoices (id) ON DELETE SET NULL
            )
          ''');

          // جدول معاملات رصيد الموردين
          await db.execute('''
            CREATE TABLE IF NOT EXISTS supplier_balance_transactions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              supplier_id INTEGER NOT NULL,
              transaction_date TEXT NOT NULL,
              transaction_time TEXT NOT NULL,
              description TEXT NOT NULL,
              debit REAL DEFAULT 0,
              credit REAL DEFAULT 0,
              balance REAL NOT NULL,
              invoice_id INTEGER,
              payment_id INTEGER,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE,
              FOREIGN KEY (invoice_id) REFERENCES purchase_invoices (id) ON DELETE SET NULL,
              FOREIGN KEY (payment_id) REFERENCES supplier_payments (id) ON DELETE SET NULL
            )
          ''');
        }

        // Migration path: v6 -> v7 (NEW - Add tables to existing users)
        if (oldVersion < 7) {
          // تأكد من إنشاء الجداول للمستخدمين القدامى الذين نسوا إنشاءها
          await db.execute('''
            CREATE TABLE IF NOT EXISTS suppliers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              phone TEXT,
              address TEXT,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS supplier_payments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              supplier_id INTEGER NOT NULL,
              payment_date TEXT NOT NULL,
              payment_time TEXT NOT NULL,
              amount REAL NOT NULL,
              payment_type TEXT DEFAULT 'نقدي',
              notes TEXT,
              invoice_id INTEGER,
              is_opening_balance INTEGER DEFAULT 0,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE,
              FOREIGN KEY (invoice_id) REFERENCES purchase_invoices (id) ON DELETE SET NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS supplier_balance_transactions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              supplier_id INTEGER NOT NULL,
              transaction_date TEXT NOT NULL,
              transaction_time TEXT NOT NULL,
              description TEXT NOT NULL,
              debit REAL DEFAULT 0,
              credit REAL DEFAULT 0,
              balance REAL NOT NULL,
              invoice_id INTEGER,
              payment_id INTEGER,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE,
              FOREIGN KEY (invoice_id) REFERENCES purchase_invoices (id) ON DELETE SET NULL,
              FOREIGN KEY (payment_id) REFERENCES supplier_payments (id) ON DELETE SET NULL
            )
          ''');
        }
      },
    );

    return db;
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

    // جدول العملاء (يجب إنشاؤه قبل sales_invoices)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        wallet_balance REAL DEFAULT 0
      )
    ''');

    // جدول المنتجات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        price REAL NOT NULL,
        purchase_price REAL DEFAULT 0,
        stock REAL DEFAULT 0,
        barcode TEXT UNIQUE,
        category_id INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // جدول الموردين (جديد - قبل supplier_payments)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // جدول فواتير المبيعات (بعد إنشاء customers)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        total REAL NOT NULL,
        paid_amount REAL NOT NULL,
        remaining_amount REAL NOT NULL,
        cashier TEXT NOT NULL,
        customer_id INTEGER,
        customer_name TEXT,
        payment_method TEXT DEFAULT 'نقدي',
        payment_status TEXT DEFAULT 'مدفوع',
        payment_type TEXT DEFAULT 'نقدي',
        original_total REAL NOT NULL DEFAULT 0,
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    // جدول عناصر فواتير المبيعات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity REAL NOT NULL,
        total REAL NOT NULL,
        unit_quantity REAL NOT NULL DEFAULT 1.0,
        unit_name TEXT NOT NULL DEFAULT 'حبة',
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
        quantity REAL NOT NULL,
        purchase_price REAL NOT NULL,
        sale_price REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES purchase_invoices (id) ON DELETE CASCADE
      )
    ''');

    // جدول دفعات الموردين (جديد)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        payment_date TEXT NOT NULL,
        payment_time TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_type TEXT DEFAULT 'نقدي',
        notes TEXT,
        invoice_id INTEGER,
        is_opening_balance INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE,
        FOREIGN KEY (invoice_id) REFERENCES purchase_invoices (id) ON DELETE SET NULL
      )
    ''');

    // جدول معاملات رصيد الموردين (جديد)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_balance_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        transaction_date TEXT NOT NULL,
        transaction_time TEXT NOT NULL,
        description TEXT NOT NULL,
        debit REAL DEFAULT 0,
        credit REAL DEFAULT 0,
        balance REAL NOT NULL,
        invoice_id INTEGER,
        payment_id INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE,
        FOREIGN KEY (invoice_id) REFERENCES purchase_invoices (id) ON DELETE SET NULL,
        FOREIGN KEY (payment_id) REFERENCES supplier_payments (id) ON DELETE SET NULL
      )
    ''');

    // جدول حزم المنتجات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_packages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        contained_quantity REAL NOT NULL,
        price REAL NOT NULL,
        barcode TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    // جدول باركودات بديلة لكل منتج
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_barcodes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        barcode TEXT UNIQUE NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_product_barcodes_barcode ON product_barcodes(barcode)',
    );

    // جدول سجلات السداد
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        payment_date TEXT NOT NULL,
        payment_time TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT DEFAULT 'نقدي',
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (invoice_id) REFERENCES sales_invoices (id) ON DELETE CASCADE
      )
    ''');
    // جدول حركات المخزون
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        transaction_date TEXT NOT NULL,
        transaction_type TEXT NOT NULL,
        invoice_id INTEGER,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        total_cost REAL NOT NULL,
        remaining_quantity REAL NOT NULL,
        average_cost REAL NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // جدول الصناديق
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_boxes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        balance REAL DEFAULT 0,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // جدول حركات الصناديق
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        box_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        direction TEXT NOT NULL,
        notes TEXT,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        related_id TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (box_id) REFERENCES cash_boxes (id)
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

      // إضافة عملاء افتراضيين
      await db.insert('customers', {
        'name': 'عميل نقدي',
        'phone': '0000000000',
      });
      await db.insert('customers', {'name': 'عميل آجل', 'phone': '1111111111'});

      // إضافة الصناديق الافتراضية
      await db.insert('cash_boxes', {
        'name': 'الصندوق اليومي',
        'balance': 0.0,
        'updated_at': DateTime.now().toIso8601String(),
      });
      await db.insert('cash_boxes', {
        'name': 'الصندوق الرئيسي',
        'balance': 0.0,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // دالة مساعدة للتحقق من وجود جدول
  Future<bool> tableExists(String tableName) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      return result.isNotEmpty;
    } catch (e) {
      print('Error checking table $tableName: $e');
      return false;
    }
  }

  // دالة طارئة لإنشاء الجداول إذا لم تكن موجودة
  Future<void> ensureTablesExist() async {
    final db = await database;

    final tablesToCheck = [
      'suppliers',
      'supplier_payments',
      'supplier_balance_transactions',
    ];

    for (var table in tablesToCheck) {
      if (!await tableExists(table)) {
        print('Table $table not found, creating it...');

        if (table == 'suppliers') {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS suppliers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              phone TEXT,
              address TEXT,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');
        } else if (table == 'supplier_payments') {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS supplier_payments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              supplier_id INTEGER NOT NULL,
              payment_date TEXT NOT NULL,
              payment_time TEXT NOT NULL,
              amount REAL NOT NULL,
              payment_type TEXT DEFAULT 'نقدي',
              notes TEXT,
              invoice_id INTEGER,
              is_opening_balance INTEGER DEFAULT 0,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE,
              FOREIGN KEY (invoice_id) REFERENCES purchase_invoices (id) ON DELETE SET NULL
            )
          ''');
        } else if (table == 'supplier_balance_transactions') {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS supplier_balance_transactions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              supplier_id INTEGER NOT NULL,
              transaction_date TEXT NOT NULL,
              transaction_time TEXT NOT NULL,
              description TEXT NOT NULL,
              debit REAL DEFAULT 0,
              credit REAL DEFAULT 0,
              balance REAL NOT NULL,
              invoice_id INTEGER,
              payment_id INTEGER,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE,
              FOREIGN KEY (invoice_id) REFERENCES purchase_invoices (id) ON DELETE SET NULL,
              FOREIGN KEY (payment_id) REFERENCES supplier_payments (id) ON DELETE SET NULL
            )
          ''');
        }
      }
    }
  }

  double _convertToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // دالة لتحديث متوسط سعر الشراء لمنتج
  Future<void> updateProductAveragePurchasePrice(String productName) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT 
        AVG(purchase_price) as avg_price,
        SUM(quantity) as total_quantity
      FROM purchase_invoice_items
      WHERE product_name = ?
      GROUP BY product_name
    ''',
      [productName],
    );

    if (result.isNotEmpty) {
      final avgPrice = _convertToDouble(result.first['avg_price']);
      await db.update(
        'products',
        {'purchase_price': avgPrice},
        where: 'name = ?',
        whereArgs: [productName],
      );
    }
  }

  // دالة لتحديث متوسط أسعار جميع المنتجات
  Future<void> updateAllProductsAveragePrices() async {
    final db = await database;

    final products = await db.query('products');

    for (var product in products) {
      final productName = product['name'] as String;
      await updateProductAveragePurchasePrice(productName);
    }
  }

  Future<String> getDatabasePath() async {
    Directory documentsDirectory;
    try {
      documentsDirectory = await getApplicationDocumentsDirectory();
    } catch (e) {
      documentsDirectory = Directory.current;
    }
    return join(documentsDirectory.path, 'pos_database.db');
  }
}
