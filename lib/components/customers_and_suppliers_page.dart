import 'package:flutter/material.dart';
import 'package:pos_desktop/database/customer_queries.dart';
import 'package:pos_desktop/database/supplier_queries.dart';
import 'package:pos_desktop/dialogs/add_customer_dialog.dart';
import 'package:pos_desktop/dialogs/customer_dialog.dart';
import 'package:pos_desktop/models/debtor_info.dart';
import 'package:pos_desktop/models/supplier.dart';
import 'package:pos_desktop/widgets/top_alert.dart';
import 'package:pos_desktop/dialogs/supplier_dialog.dart';

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

// ------------------- Customers Tab (Refactored logic from DebtorsPage) -------------------

class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  final CustomerQueries _customerQueries = CustomerQueries();
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

  // دالة لسداد دين عميل
  Future<void> _showPaymentDialog(DebtorInfo debtor) async {
    if (debtor.totalDebt <= 0) {
      TopAlert.showSuccess(
        context: context,
        message: "هذا العميل ليس عليه ديون.",
      );
      return;
    }
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.payment, color: Colors.green),
                SizedBox(width: 8),
                Text("سداد دفعة"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("العميل: ${debtor.customerName}"),
                const SizedBox(height: 8),
                Text(
                  "إجمالي الدين: ${debtor.totalDebt.toStringAsFixed(2)} شيكل",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "المبلغ المدفوع",
                    border: OutlineInputBorder(),
                    suffixText: "شيكل",
                  ),
                  autofocus: true,
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

                  // نسمح بدفع أكثر من الدين ويتحول لرصيد
                  if (amount > debtor.totalDebt) {
                    final surplus = amount - debtor.totalDebt;
                    // نسدد الدين كاملا
                    await _customerQueries.settleCustomerDebt(
                      debtor.customerId,
                      debtor.totalDebt,
                    );
                    // ونضيف الباقي للمحفظة
                    await _customerQueries.updateCustomerWallet(
                      debtor.customerId,
                      surplus,
                      isDeposit: true,
                    );
                  } else {
                    await _customerQueries.settleCustomerDebt(
                      debtor.customerId,
                      amount,
                    );
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    TopAlert.showSuccess(
                      context: context,
                      message: 'تم تسجيل الدفعة بنجاح',
                    );
                    _loadData();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text("تأكيد السداد"),
              ),
            ],
          ),
    );
  }

  // إضافة رصيد للمحفظة
  Future<void> _showAddWalletBalance(DebtorInfo debtor) async {
    final amountController = TextEditingController();
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("إيداع في المحفظة"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("العميل: ${debtor.customerName}"),
                Text(
                  "الرصيد الحالي: ${debtor.walletBalance}",
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "المبلغ للإيداع",
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
                  if (amount == null || amount <= 0) return;
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
                      message: "تم إضافة الرصيد",
                    );
                  }
                },
                child: const Text("إيداع"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Controls
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: "بحث عن عميل...",
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
              IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _addCustomer,
                icon: const Icon(Icons.add),
                label: const Text("عميل جديد"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // List
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
                itemCount: debtors.length,
                separatorBuilder: (c, i) => const Divider(),
                itemBuilder: (context, index) {
                  final debtor = debtors[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text(debtor.customerName[0])),
                    title: Text(debtor.customerName),
                    subtitle: Row(
                      children: [
                        Text(
                          "عليه: ${debtor.totalDebt.toStringAsFixed(1)}",
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(width: 15),
                        Text(
                          "له (رصيد): ${debtor.walletBalance.toStringAsFixed(1)}",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.orange,
                          ),
                          tooltip: "إيداع رصيد",
                          onPressed: () => _showAddWalletBalance(debtor),
                        ),
                        IconButton(
                          icon: const Icon(Icons.payment, color: Colors.green),
                          tooltip: "سداد دين",
                          onPressed: () => _showPaymentDialog(debtor),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.visibility,
                            color: Colors.blue,
                          ),
                          onPressed: () async {
                            final fullCustomer = await _customerQueries
                                .getCustomerById(debtor.customerId);
                            if (fullCustomer != null && mounted) {
                              showDialog(
                                context: context,
                                builder:
                                    (c) => CustomerDialog(
                                      customer: fullCustomer,
                                      debtorInfo: debtor,
                                      onEdit: () {
                                        Navigator.pop(c);
                                      },
                                    ),
                              );
                            }
                          },
                        ),
                      ],
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

// ------------------- Suppliers Tab -------------------

class SuppliersTab extends StatefulWidget {
  const SuppliersTab({super.key});

  @override
  State<SuppliersTab> createState() => _SuppliersTabState();
}

class _SuppliersTabState extends State<SuppliersTab> {
  final SupplierQueries _supplierQueries = SupplierQueries();
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
    // التحقق إذا كان للمورد فواتير أو معاملات
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
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
