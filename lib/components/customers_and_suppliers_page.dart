import 'package:flutter/material.dart';
import 'package:pos_desktop/database/cash_queries.dart';
import 'package:pos_desktop/database/customer_queries.dart';
import 'package:pos_desktop/database/supplier_queries.dart';
import 'package:pos_desktop/dialogs/add_customer_dialog.dart';
import 'package:pos_desktop/dialogs/customer_dialog.dart';
import 'package:pos_desktop/dialogs/customer_statement_dialog.dart';
import 'package:pos_desktop/dialogs/supplier_dialog.dart';
import 'package:pos_desktop/dialogs/supplier_statement_dialog.dart';
import 'package:pos_desktop/models/cash_movement.dart';
import 'package:pos_desktop/models/debtor_info.dart';
import 'package:pos_desktop/models/supplier.dart';
import 'package:pos_desktop/services/cash_service.dart';
import 'package:pos_desktop/widgets/top_alert.dart';

class CustomersAndSuppliersPage extends StatefulWidget {
  const CustomersAndSuppliersPage({super.key});

  @override
  State<CustomersAndSuppliersPage> createState() =>
      _CustomersAndSuppliersPageState();
}

class _CustomersAndSuppliersPageState extends State<CustomersAndSuppliersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header & Tabs
        Container(
          color: Colors.white,
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                tabs: const [
                  Tab(text: "الزبائن والديون", icon: Icon(Icons.person)),
                  Tab(text: "الموردين", icon: Icon(Icons.local_shipping)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [CustomersTab(), SuppliersTab()],
          ),
        ),
      ],
    );
  }
}

// ------------------- Customers Tab (تم التعديل جذرياً) -------------------

class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  final CustomerQueries _customerQueries = CustomerQueries();
  final CashQueries _cashQueries =
      CashQueries(); // نستخدم CashQueries للتحكم الدقيق
  late Future<List<DebtorInfo>> _debtorsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _debtorsFuture = _customerQueries.getAllCustomersWithDebt(
        searchTerm: _searchTerm,
      );
    });
  }

  void _search(String term) {
    setState(() => _searchTerm = term);
    _loadData();
  }

  void _refresh() {
    _loadData();
    TopAlert.showSuccess(context: context, message: 'تم تحديث بيانات العملاء');
  }

  Future<void> _addCustomer() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddCustomerDialog(),
    );

    if (result != null && mounted) {
      try {
        await _customerQueries.insertCustomerWithOpeningBalance(result);
        _loadData();
        TopAlert.showSuccess(
          context: context,
          message: "تمت إضافة العميل بنجاح",
        );
      } catch (e) {
        TopAlert.showError(context: context, message: "فشل إضافة العميل: $e");
      }
    }
  }

  // ===================== العمليات الجديدة المنفصلة =====================

  /// 1. سداد دين (العميل يدفع -> الصندوق اليومي)
  Future<void> _showDebtPaymentDialog(DebtorInfo debtor) async {
    final amountController = TextEditingController();

    if (debtor.totalDebt <= 0) {
      TopAlert.showError(
        context: context,
        message: "العميل ليس عليه ديون للسداد",
      );
      return;
    }

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.payment, color: Colors.green),
                SizedBox(width: 8),
                Text("استلام دفعة (سداد دين)"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "العميل: ${debtor.customerName}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  "إجمالي الدين الحالي: ${debtor.totalDebt.toStringAsFixed(2)} شيكل",
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 15),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "سيتم إيداع المبلغ تلقائياً في الصندوق اليومي",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: "المبلغ المستلم",
                    border: OutlineInputBorder(),
                    suffixText: "شيكل",
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    TopAlert.showError(
                      context: context,
                      message: "أدخل مبلغ صحيح",
                    );
                    return;
                  }

                  final dailyBox = await _cashQueries.getCashBoxByName(
                    'الصندوق اليومي',
                  );
                  if (dailyBox == null) {
                    TopAlert.showError(
                      context: context,
                      message: "الصندوق اليومي غير موجود!",
                    );
                    return;
                  }

                  // --- التصحيح هنا ---
                  await _cashQueries.addCashMovement(
                    CashMovement(
                      boxId: dailyBox.id!,
                      amount: amount,
                      direction: 'داخل', // تمت إضافتها
                      type: 'سداد دين', // وضعنا السبب هنا بدلاً من reason
                      notes:
                          'سداد دين من العميل: ${debtor.customerName}', // وضعنا الوصف هنا بدلاً من description
                      date: DateTime.now().toString().split(' ')[0],
                      time: TimeOfDay.now().format(context),
                      relatedId:
                          debtor.customerId
                              .toString(), // ربطنا المعاملة بالعميل
                    ),
                  );

                  await _customerQueries.updateCustomerWallet(
                    debtor.customerId,
                    amount,
                    isDeposit: true,
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    _loadData();
                    TopAlert.showSuccess(
                      context: context,
                      message: "تم استلام الدفعة بنجاح",
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text("تأكيد الاستلام"),
              ),
            ],
          ),
    );
  }

  /// 2. إيداع في المحفظة (العميل يضع رصيد -> الصندوق اليومي)
  Future<void> _showWalletDepositDialog(DebtorInfo debtor) async {
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.orange),
                SizedBox(width: 8),
                Text("إيداع رصيد للمحفظة"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "العميل: ${debtor.customerName}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  "رصيد المحفظة الحالي: ${debtor.walletBalance.toStringAsFixed(2)} شيكل",
                  style: const TextStyle(color: Colors.green),
                ),
                const SizedBox(height: 15),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.deepOrange,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "المبلغ سيضاف للصندوق اليومي ورصيد العميل",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: "المبلغ المودع",
                    border: OutlineInputBorder(),
                    suffixText: "شيكل",
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    TopAlert.showError(
                      context: context,
                      message: "أدخل مبلغ صحيح",
                    );
                    return;
                  }

                  final dailyBox = await _cashQueries.getCashBoxByName(
                    'الصندوق اليومي',
                  );
                  if (dailyBox == null) {
                    TopAlert.showError(
                      context: context,
                      message: "الصندوق اليومي غير موجود!",
                    );
                    return;
                  }

                  // --- التصحيح هنا ---
                  await _cashQueries.addCashMovement(
                    CashMovement(
                      boxId: dailyBox.id!,
                      amount: amount,
                      direction: 'داخل', // تمت إضافتها
                      type: 'إيداع محفظة', // وضعنا السبب هنا
                      notes:
                          'رصيد مقدم من العميل: ${debtor.customerName}', // وضعنا الوصف في الملاحظات
                      date: DateTime.now().toString().split(' ')[0],
                      time: TimeOfDay.now().format(context),
                      relatedId: debtor.customerId.toString(),
                    ),
                  );

                  await _customerQueries.updateCustomerWallet(
                    debtor.customerId,
                    amount,
                    isDeposit: true,
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    _loadData();
                    TopAlert.showSuccess(
                      context: context,
                      message: "تم الإيداع بنجاح",
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text("تأكيد الإيداع"),
              ),
            ],
          ),
    );
  }

  /// 3. دفع للعميل (أنت تدفع له -> اختيار الصندوق)
  Future<void> _showPayToCustomerDialog(DebtorInfo debtor) async {
    final amountController = TextEditingController();
    String selectedBoxName = 'الصندوق اليومي';

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.outbond, color: Colors.blue),
                    SizedBox(width: 8),
                    Text("دفع للعميل (صرف)"),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "العميل: ${debtor.customerName}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "له في المحفظة: ${debtor.walletBalance.toStringAsFixed(2)} شيكل",
                      style: const TextStyle(color: Colors.green),
                    ),
                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: selectedBoxName,
                      decoration: const InputDecoration(
                        labelText: "خصم من الصندوق",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.money_off),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'الصندوق اليومي',
                          child: Text("الصندوق اليومي"),
                        ),
                        DropdownMenuItem(
                          value: 'الصندوق الرئيسي',
                          child: Text("الصندوق الرئيسي"),
                        ),
                      ],
                      onChanged: (val) {
                        setStateDialog(() => selectedBoxName = val!);
                      },
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: "المبلغ المدفوع للعميل",
                        border: OutlineInputBorder(),
                        suffixText: "شيكل",
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("إلغاء"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        TopAlert.showError(
                          context: context,
                          message: "أدخل مبلغ صحيح",
                        );
                        return;
                      }

                      final box = await _cashQueries.getCashBoxByName(
                        selectedBoxName,
                      );
                      if (box == null) return;

                      if (box.balance < amount) {
                        TopAlert.showError(
                          context: context,
                          message: "رصيد $selectedBoxName غير كافٍ!",
                        );
                        return;
                      }

                      // --- التصحيح هنا ---
                      await _cashQueries.addCashMovement(
                        CashMovement(
                          boxId: box.id!,
                          amount: amount,
                          direction: 'خارج', // تمت إضافتها
                          type: 'صرف للعميل', // السبب
                          notes:
                              'سداد للعميل أو إرجاع رصيد: ${debtor.customerName}', // الوصف
                          date: DateTime.now().toString().split(' ')[0],
                          time: TimeOfDay.now().format(context),
                          relatedId: debtor.customerId.toString(),
                        ),
                      );

                      await _customerQueries.updateCustomerWallet(
                        debtor.customerId,
                        amount,
                        isDeposit: false,
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        _loadData();
                        TopAlert.showSuccess(
                          context: context,
                          message: "تم الدفع للعميل بنجاح",
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("تأكيد الدفع"),
                  ),
                ],
              );
            },
          ),
    );
  }

  // ---------------------------------------------------------------------------

  Future<void> _showCustomerDetails(DebtorInfo debtor) async {
    final fullCustomer = await _customerQueries.getCustomerById(
      debtor.customerId,
    );
    if (fullCustomer != null && mounted) {
      showDialog(
        context: context,
        builder:
            (c) => CustomerDialog(
              customer: fullCustomer,
              debtorInfo: debtor,
              onEdit: () {
                Navigator.pop(c);
                _loadData();
              },
            ),
      );
    }
  }

  Future<void> _showCustomerStatement(DebtorInfo debtor) async {
    final fullCustomer = await _customerQueries.getCustomerById(
      debtor.customerId,
    );
    if (fullCustomer != null && mounted) {
      showDialog(
        context: context,
        builder: (context) => CustomerStatementDialog(customer: fullCustomer),
      );
    }
  }

  Future<void> _deleteCustomer(DebtorInfo debtor) async {
    final canDelete = await _customerQueries.canDeleteCustomer(
      debtor.customerId,
    );
    if (!canDelete) {
      TopAlert.showError(
        context: context,
        message: "لا يمكن حذف العميل، عليه ديون!",
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("تأكيد الحذف"),
            content: Text("حذف العميل '${debtor.customerName}'؟"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text("حذف"),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      await _customerQueries.deleteCustomer(debtor.customerId);
      _loadData();
      TopAlert.showSuccess(context: context, message: "تم حذف العميل");
    }
  }

  // ... (الإستدعاءات والمتغيرات في الأعلى كما هي)

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Controls (البحث والأزرار) - كما هي
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: "ابحث عن عميل...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    suffixIcon:
                        _searchTerm.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _search('');
                              },
                            )
                            : null,
                  ),
                  onChanged: _search,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                tooltip: "تحديث",
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue.shade100,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _addCustomer,
                icon: const Icon(Icons.add),
                label: const Text("عميل جديد"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ================== تعديل الترويسة (Headers) ==================
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade200, // لون خلفية أوضح للترويسة
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: const Row(
            children: [
              // 1. العميل (مساحة أكبر)
              Expanded(
                flex: 4,
                child: Text(
                  "العميل",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              // 2. عليه (دين)
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    "عليه (دين)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              // 3. له (محفظة)
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    "له (محفظة)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              // 4. إجراءات
              Expanded(
                flex: 1, // مساحة أقل للإجراءات
                child: Center(
                  child: Text(
                    "إجراءات",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ================== تعديل القائمة (List) ==================
        Expanded(
          child: FutureBuilder<List<DebtorInfo>>(
            future: _debtorsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("لا يوجد بيانات"));
              }

              final debtors = snapshot.data!;

              return ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: debtors.length,
                separatorBuilder:
                    (c, i) =>
                        const SizedBox(height: 4), // مسافة بسيطة بين الكروت
                itemBuilder: (context, index) {
                  final debtor = debtors[index];
                  final hasDebt = debtor.totalDebt > 0;
                  final hasWallet = debtor.walletBalance > 0;

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      // استخدام Padding و Row بدلاً من ListTile لضمان المحاذاة
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          // 1. العميل (نفس الـ Flex: 4)
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  debtor.customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (debtor.phone != null &&
                                    debtor.phone!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      debtor.phone!,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // 2. عليه (دين) (نفس الـ Flex: 2)
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      hasDebt
                                          ? Colors.red.shade50
                                          : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color:
                                        hasDebt
                                            ? Colors.red.shade100
                                            : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  debtor.totalDebt.toStringAsFixed(2),
                                  style: TextStyle(
                                    color:
                                        hasDebt ? Colors.red : Colors.black45,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 3. له (محفظة) (نفس الـ Flex: 2)
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      hasWallet
                                          ? Colors.green.shade50
                                          : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color:
                                        hasWallet
                                            ? Colors.green.shade100
                                            : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  debtor.walletBalance.toStringAsFixed(2),
                                  style: TextStyle(
                                    color:
                                        hasWallet
                                            ? Colors.green
                                            : Colors.black45,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 4. إجراءات (نفس الـ Flex: 1)
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.grey,
                                ),
                                tooltip: "خيارات",
                                onSelected: (value) {
                                  switch (value) {
                                    case 'pay_debt':
                                      _showDebtPaymentDialog(debtor);
                                      break;
                                    case 'deposit_wallet':
                                      _showWalletDepositDialog(debtor);
                                      break;
                                    case 'pay_customer':
                                      _showPayToCustomerDialog(debtor);
                                      break;
                                    case 'view':
                                      _showCustomerDetails(debtor);
                                      break;
                                    case 'statement':
                                      _showCustomerStatement(debtor);
                                      break;
                                    case 'delete':
                                      _deleteCustomer(debtor);
                                      break;
                                  }
                                },
                                itemBuilder:
                                    (context) => [
                                      if (debtor.totalDebt > 0)
                                        const PopupMenuItem(
                                          value: 'pay_debt',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.payment,
                                                color: Colors.green,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text("سداد دفعة"),
                                            ],
                                          ),
                                        ),
                                      const PopupMenuItem(
                                        value: 'deposit_wallet',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.add_card,
                                              color: Colors.orange,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text("إيداع للمحفظة"),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'pay_customer',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.outbond,
                                              color: Colors.blue,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text("دفع للعميل"),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'view',
                                        child: Row(
                                          children: [
                                            Icon(Icons.visibility, size: 20),
                                            SizedBox(width: 8),
                                            Text("التفاصيل"),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'statement',
                                        child: Row(
                                          children: [
                                            Icon(Icons.receipt_long, size: 20),
                                            SizedBox(width: 8),
                                            Text("كشف حساب"),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text("حذف"),
                                          ],
                                        ),
                                      ),
                                    ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ------------------- Suppliers Tab (كما هو دون تغيير) -------------------
// ... (بقيت الكود للـ SuppliersTab كما أرسلته سابقاً) ...
class SuppliersTab extends StatefulWidget {
  const SuppliersTab({super.key});

  @override
  State<SuppliersTab> createState() => _SuppliersTabState();
}

class _SuppliersTabState extends State<SuppliersTab> {
  final SupplierQueries _supplierQueries = SupplierQueries();
  final CashService _cashService = CashService();
  late Future<List<Supplier>> _suppliersFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _suppliersFuture = _supplierQueries.searchSuppliers(
        searchTerm: _searchTerm.isNotEmpty ? _searchTerm : null,
      );
    });
  }

  void _search(String term) {
    setState(() => _searchTerm = term);
    _loadData();
  }

  void _refresh() {
    _loadData();
    TopAlert.showSuccess(context: context, message: 'تم تحديث بيانات الموردين');
  }

  Future<void> _addSupplier() async {
    await showDialog(
      context: context,
      builder: (context) => const SupplierDialog(),
    );
    _loadData();
  }

  Future<void> _editSupplier(Supplier supplier) async {
    await showDialog(
      context: context,
      builder: (context) => SupplierDialog(supplier: supplier),
    );
    _loadData();
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final hasTransactions = await _supplierQueries.hasSupplierTransactions(
      supplier.id!,
    );

    if (hasTransactions) {
      TopAlert.showError(
        context: context,
        message: "لا يمكن حذف المورد لأنه لديه فواتير مرتبطة",
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("تأكيد الحذف"),
            content: Text("هل أنت متأكد من حذف المورد '${supplier.name}'؟"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text("حذف"),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      await _supplierQueries.deleteSupplier(supplier.id!);
      _loadData();
      TopAlert.showSuccess(context: context, message: "تم حذف المورد بنجاح");
    }
  }

  Future<void> _paySupplier(Supplier supplier) async {
    if ((supplier.balance ?? 0) <= 0) {
      TopAlert.showSuccess(
        context: context,
        message: "لا يوجد مستحقات لهذا المورد",
      );
      return;
    }

    final amountController = TextEditingController();
    String selectedBox = 'الصندوق الرئيسي';

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text("سداد للمورد"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("المورد: ${supplier.name}"),
                      Text(
                        "المبلغ المستحق له: ${supplier.balance!.toStringAsFixed(2)} شيكل",
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "المبلغ المدفوع",
                          hintText: "أدخل المبلغ",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedBox,
                        decoration: const InputDecoration(
                          labelText: "الدفع من صندوق",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.account_balance_wallet_outlined,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'الصندوق الرئيسي',
                            child: Text("الصندوق الرئيسي"),
                          ),
                          DropdownMenuItem(
                            value: 'الصندوق اليومي',
                            child: Text("الصندوق اليومي"),
                          ),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            selectedBox = val!;
                          });
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("إلغاء"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text);
                        if (amount == null || amount <= 0) {
                          TopAlert.showError(
                            context: context,
                            message: "يرجى إدخال مبلغ صحيح",
                          );
                          return;
                        }

                        if (amount > supplier.balance!) {
                          TopAlert.showError(
                            context: context,
                            message: "المبلغ المدخل أكبر من المستحق",
                          );
                          return;
                        }

                        await _supplierQueries.paySupplier(
                          supplier.id!,
                          amount,
                          "سداد يدوي",
                        );

                        // تسجيل الدفع في الصندوق المختار
                        await _cashService.recordPurchasePayment(
                          amount: amount,
                          boxName: selectedBox,
                          invoiceNumber:
                              'MANUAL-${DateTime.now().millisecondsSinceEpoch}',
                          supplierName: supplier.name,
                        );

                        if (mounted) {
                          Navigator.pop(context);
                          _loadData();
                          TopAlert.showSuccess(
                            context: context,
                            message: "تم تسجيل السداد بنجاح",
                          );
                        }
                      },
                      child: const Text("تسجيل سداد"),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _showSupplierStatement(Supplier supplier) async {
    showDialog(
      context: context,
      builder: (context) => SupplierStatementDialog(supplier: supplier),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Controls with Search
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: "بحث عن مورد بالاسم أو الهاتف أو العنوان...",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                  ),
                  onChanged: _search,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                tooltip: "تحديث القائمة",
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _addSupplier,
                icon: const Icon(Icons.add),
                label: const Text("مورد جديد"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Search Results Info
        if (_searchTerm.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.search, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  "نتائج البحث عن: '$_searchTerm'",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    _search('');
                  },
                  child: const Text(
                    "مسح البحث",
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        // List
        Expanded(
          child: FutureBuilder<List<Supplier>>(
            future: _suppliersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) {
                return const Center(child: Text("حدث خطأ في تحميل البيانات"));
              }

              final suppliers = snapshot.data!;

              if (suppliers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchTerm.isEmpty
                            ? Icons.business_outlined
                            : Icons.search_off,
                        size: 60,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchTerm.isEmpty
                            ? "لا يوجد موردين"
                            : "لم يتم العثور على موردين تطابق بحثك",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      if (_searchTerm.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton(
                            onPressed: () {
                              _searchController.clear();
                              _search('');
                            },
                            child: const Text("عرض جميع الموردين"),
                          ),
                        ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: suppliers.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final supplier = suppliers[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    elevation: 1,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: const Icon(Icons.business, color: Colors.orange),
                      ),
                      title: Text(
                        supplier.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (supplier.phone != null &&
                              supplier.phone!.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  supplier.phone!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          if (supplier.address != null &&
                              supplier.address!.isNotEmpty)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    supplier.address!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Balance
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (supplier.balance ?? 0) > 0
                                      ? Colors.red.shade50
                                      : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    (supplier.balance ?? 0) > 0
                                        ? Colors.red.shade100
                                        : Colors.green.shade100,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  "له عندنا",
                                  style: TextStyle(fontSize: 10),
                                ),
                                Text(
                                  "${supplier.balance?.toStringAsFixed(2) ?? "0.00"} شيكل",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        (supplier.balance ?? 0) > 0
                                            ? Colors.red
                                            : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Actions (بدون Column)
                          IconButton(
                            icon: const Icon(
                              Icons.receipt_long,
                              color: Colors.orange,
                              size: 20,
                            ),
                            tooltip: "كشف حساب",
                            onPressed: () => _showSupplierStatement(supplier),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.payment,
                              color: Colors.green,
                              size: 20,
                            ),
                            tooltip: "سداد",
                            onPressed:
                                (supplier.balance ?? 0) > 0
                                    ? () => _paySupplier(supplier)
                                    : null,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blue,
                              size: 20,
                            ),
                            onPressed: () => _editSupplier(supplier),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () => _deleteSupplier(supplier),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
