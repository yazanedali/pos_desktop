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
      version: 15, // changed from 14 to 15 for Purchase Returns
      onConfigure: (db) async {
        await db.execute('PRAGMA journal_mode=WAL;');
      },
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

        // Migration path: v8 -> v9 (Add cost_price to sales_invoice_items)
        if (oldVersion < 9) {
          // 1. إضافة العمود cost_price
          try {
            await db.execute(
              "ALTER TABLE sales_invoice_items ADD COLUMN cost_price REAL DEFAULT 0",
            );
          } catch (e) {
            // Column might already exist
          }

          // 2. تحديث السجلات القديمة: جلب سعر الشراء الحالي للمنتج وتخزينه كـ cost_price
          // هذا إجراء تقريبي للمبيعات السابقة، لكنه أفضل من الصفر
          await db.transaction((txn) async {
            // نقوم بتحديث السجلات دفعة واحدة باستخدام join (SQLite يدعم update مع join في بعض الحالات،
            // ولكن الأضمن هو عمل loop أو subquery).
            // سنستخدم Subquery للتحديث:
            await txn.rawUpdate('''
               UPDATE sales_invoice_items
               SET cost_price = (
                 SELECT purchase_price 
                 FROM products 
                 WHERE products.id = sales_invoice_items.product_id
               )
               WHERE cost_price = 0 OR cost_price IS NULL
             ''');

            // في حال لم يكن product_id متاحاً (نادر)، نحاول بالاسم
            await txn.rawUpdate('''
               UPDATE sales_invoice_items
               SET cost_price = (
                 SELECT purchase_price 
                 FROM products 
                 WHERE products.name = sales_invoice_items.product_name
               )
               WHERE (cost_price = 0 OR cost_price IS NULL)
             ''');
          });
        }

        // Migration path: v9 -> v10 (Retry/Force backfill cost_price)
        if (oldVersion < 10) {
          // إعادة محاولة تحديث الأسعار الصفرية للتأكد من تثبيت التكلفة
          await db.transaction((txn) async {
            // طباعة للتأكد من تشغيل الترحيل
            print('Creating v10 migration: Backfilling cost_price...');

            // التأكد من وجود العمود أولاً
            try {
              await db.execute(
                "ALTER TABLE sales_invoice_items ADD COLUMN cost_price REAL DEFAULT 0",
              );
            } catch (e) {
              // تجاهل الخطأ إذا العمود موجود
            }

            // التحديث القوي: نحدث أي سجل تكلفته 0
            // ملاحظة: نستخدم COALESCE(purchase_price, 0) لتجنب null
            await txn.rawUpdate('''
               UPDATE sales_invoice_items
               SET cost_price = (
                 SELECT COALESCE(purchase_price, 0)
                 FROM products 
                 WHERE products.id = sales_invoice_items.product_id
               )
               WHERE (cost_price IS NULL OR cost_price = 0)
             ''');

            // محاولة ثانية بالاسم للمنتجات التي قد يكون رابط الـ id فيها مكسوراً
            await txn.rawUpdate('''
               UPDATE sales_invoice_items
               SET cost_price = (
                 SELECT COALESCE(purchase_price, 0)
                 FROM products 
                 WHERE products.name = sales_invoice_items.product_name
               )
               WHERE (cost_price IS NULL OR cost_price = 0)
             ''');
          });
        }
        if (oldVersion < 11) {
          try {
            await db.execute(
              "ALTER TABLE purchase_invoices ADD COLUMN discount REAL DEFAULT 0",
            );
          } catch (e) {}

          try {
            await db.execute(
              "ALTER TABLE purchase_invoice_items ADD COLUMN discount REAL DEFAULT 0",
            );
          } catch (e) {}
        }
        // Migration path: v11 -> v12 (New Features: Stock Alerts, Returns, Shift Closing)
        if (oldVersion < 12) {
          // 1. Stock Alerts: Add min_stock to products
          try {
            await db.execute(
              "ALTER TABLE products ADD COLUMN min_stock REAL DEFAULT 0",
            );
          } catch (e) {
            // Column might already exist
          }

          // 2. Returns: Add fields to sales_invoices
          try {
            await db.execute(
              "ALTER TABLE sales_invoices ADD COLUMN is_return INTEGER DEFAULT 0",
            );
            await db.execute(
              "ALTER TABLE sales_invoices ADD COLUMN parent_invoice_id INTEGER",
            );
          } catch (e) {
            // Columns might already exist
          }

          // 3. Shift Closing: Create daily_closings table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS daily_closings (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              closing_date TEXT NOT NULL, -- Date string YYYY-MM-DD
              closing_time TEXT NOT NULL, -- Time string HH:MM:SS
              cashier_name TEXT,
              opening_cash REAL DEFAULT 0,
              total_sales_cash REAL DEFAULT 0, -- Cash sales in this shift
              total_expenses REAL DEFAULT 0,
              total_debt_collected REAL DEFAULT 0, -- Debt payments collected
              expected_cash REAL DEFAULT 0, -- Calculated
              actual_cash REAL DEFAULT 0, -- Input by user
              difference REAL DEFAULT 0,
            notes TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        }

        // Migration path: v12 -> v13 (Default Min Stock 9)
        if (oldVersion < 13) {
          // تحديث الحد الأدنى للمخزون لكل المنتجات ليصبح 9 (حسب طلب المستخدم)
          // نطبق هذا التغيير على المنتجات التي ليس لها قيمة محددة (0)
          await db.rawUpdate(
            'UPDATE products SET min_stock = 9 WHERE min_stock IS NULL OR min_stock = 0',
          );
        }

        // Migration path: v13 -> v14 (Performance Indexes for Stock Alerts)
        if (oldVersion < 14) {
          // إضافة Indexes لتحسين أداء استعلامات تنبيهات المخزون
          // Index مركب على (is_active, stock, min_stock) لتسريع استعلام getLowStockCount
          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_products_stock_alert 
            ON products(is_active, stock, min_stock)
          ''');

          // Index على stock فقط لاستعلامات أخرى
          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_products_stock 
            ON products(stock)
          ''');

          // Index على category_id لتسريع الفلترة حسب الفئة
          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_products_category 
            ON products(category_id)
          ''');

          print('✅ Performance indexes created successfully');
        }

        // Migration path: v14 -> v15 (Purchase Returns)
        if (oldVersion < 15) {
          // إضافة أعمدة مرتجعات الشراء
          try {
            await db.execute(
              "ALTER TABLE purchase_invoices ADD COLUMN is_return INTEGER DEFAULT 0",
            );
            await db.execute(
              "ALTER TABLE purchase_invoices ADD COLUMN parent_invoice_id INTEGER",
            );
            print('✅ Added Purchase Return columns successfully');
          } catch (e) {
            print(
              '⚠️ Error adding purchase return columns (might already exist): $e',
            );
          }
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
        min_stock REAL DEFAULT 9, -- Default to 9 as user request
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
        cost_price REAL DEFAULT 0,
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
        discount REAL DEFAULT 0,  -- <--- تمت الإضافة
        supplier_id INTEGER,      -- تأكدنا من إضافتها هنا أيضاً لتجنب المشاكل
        payment_status TEXT DEFAULT 'مدفوع',
        paid_amount REAL DEFAULT 0,
        remaining_amount REAL DEFAULT 0,
        payment_type TEXT DEFAULT 'نقدي',
        notes TEXT,
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
        discount REAL DEFAULT 0, -- <--- تمت الإضافة
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

    // ========== Performance Indexes ==========
    // Indexes لتحسين أداء الاستعلامات الشائعة

    // Index مركب لتنبيهات المخزون (يسرع استعلام getLowStockCount بشكل كبير)
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_products_stock_alert 
      ON products(is_active, stock, min_stock)
    ''');

    // Index على stock لاستعلامات المخزون العامة
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_products_stock 
      ON products(stock)
    ''');

    // Index على category_id لتسريع الفلترة حسب الفئة
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_products_category 
      ON products(category_id)
    ''');

    // Index على name للبحث السريع بالاسم
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_products_name 
      ON products(name)
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
