import 'package:flutter/material.dart';
import 'package:pos_desktop/dialogs/add_customer_dialog.dart';
import 'package:pos_desktop/database/customer_queries.dart';
import 'package:pos_desktop/models/customer.dart';
import 'package:pos_desktop/models/debtor_info.dart';
import 'package:pos_desktop/widgets/top_alert.dart';
import 'package:pos_desktop/dialogs/customer_details_dialog.dart';

class DebtorsPage extends StatefulWidget {
  const DebtorsPage({super.key});

  @override
  State<DebtorsPage> createState() => _DebtorsPageState();
}

class _DebtorsPageState extends State<DebtorsPage> {
  final CustomerQueries _customerQueries = CustomerQueries();
  late Future<List<DebtorInfo>> _debtorsFuture;

  @override
  void initState() {
    super.initState();
    _loadDebtorsData();
  }

  // دالة منفصلة لتحميل البيانات يمكن استدعاؤها من عدة أماكن
  void _loadDebtorsData() {
    setState(() {
      _debtorsFuture = _customerQueries.getAllCustomersWithDebt();
    });
  }

  // دالة للتحديث اليدوي (يمكن استدعاؤها من زر تحديث إذا أردت)
  void _refreshDebtorsList() {
    _loadDebtorsData();
    TopAlert.showSuccess(context: context, message: 'تم تحديث البيانات بنجاح');
  }

  Future<void> _showAddCustomerDialog() async {
    final newCustomer = await showDialog<Customer>(
      context: context,
      builder: (context) => const AddCustomerDialog(),
    );

    if (newCustomer != null && mounted) {
      try {
        await _customerQueries.insertCustomer(newCustomer);

        TopAlert.showSuccess(
          context: context,
          message: 'تمت إضافة العميل "${newCustomer.name}" بنجاح',
        );

        // تحديث القائمة بعد الإضافة
        _loadDebtorsData();
      } catch (e) {
        TopAlert.showError(
          context: context,
          message: 'فشل في إضافة العميل: $e',
        );
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

                  if (amount > debtor.totalDebt) {
                    TopAlert.showError(
                      context: context,
                      message: "المبلغ أكبر من الدين المتبقي",
                    );
                    return;
                  }

                  await _customerQueries.settleCustomerDebt(
                    debtor.customerId,
                    amount,
                  );

                  Navigator.pop(context);
                  TopAlert.showSuccess(
                    context: context,
                    message: 'تم تسديد ${amount.toStringAsFixed(2)} شيكل بنجاح',
                  );

                  // تحديث البيانات بعد السداد
                  _loadDebtorsData();
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

  // دالة لعرض تفاصيل العميل
  void _showCustomerDetails(DebtorInfo debtor) {
    showDialog(
      context: context,
      builder:
          (context) => CustomerDetailsDialog(
            customerId: debtor.customerId,
            customerName: debtor.customerName,
            totalDebt: debtor.totalDebt,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          _buildPageHeader(),
          _buildTableHeader(),
          Expanded(
            child: FutureBuilder<List<DebtorInfo>>(
              future: _debtorsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text('حدث خطأ في جلب البيانات: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDebtorsData,
                          child: const Text("إعادة المحاولة"),
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }
                final debtors = snapshot.data!;
                return _buildDebtorsList(debtors);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.people_alt_outlined, color: Colors.blue[800]),
              const SizedBox(width: 8),
              const Text(
                "إدارة العملاء والديون",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // زر التحديث
              IconButton(
                onPressed: _refreshDebtorsList,
                icon: const Icon(Icons.refresh),
                tooltip: "تحديث البيانات",
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue.shade100,
                ),
              ),
              const SizedBox(width: 8),
              // زر إضافة عميل
              ElevatedButton.icon(
                onPressed: _showAddCustomerDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("إضافة عميل"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        color: Colors.grey.shade100,
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              "اسم العميل",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "قيمة الدين الإجمالية",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "إجراءات",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtorsList(List<DebtorInfo> debtors) {
    return RefreshIndicator(
      onRefresh: () async {
        _loadDebtorsData();
      },
      child: ListView.builder(
        itemCount: debtors.length,
        itemBuilder: (context, index) {
          final debtor = debtors[index];
          final bool hasDebt = debtor.totalDebt > 0;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text(debtor.customerName)),
                Expanded(
                  flex: 3,
                  child: Text(
                    "${debtor.totalDebt.toStringAsFixed(2)} شيكل",
                    style: TextStyle(
                      color: hasDebt ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // زر سداد الدين
                      IconButton(
                        onPressed: () => _showPaymentDialog(debtor),
                        icon: const Icon(
                          Icons.payment,
                          size: 20,
                          color: Colors.green,
                        ),
                        tooltip: "سداد دفعة",
                      ),
                      // زر عرض التفاصيل
                      IconButton(
                        onPressed: () => _showCustomerDetails(debtor),
                        icon: const Icon(
                          Icons.visibility,
                          size: 20,
                          color: Colors.blue,
                        ),
                        tooltip: "عرض التفاصيل",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadDebtorsData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                SizedBox(height: 16),
                Text(
                  "لا يوجد أي ديون حالية",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
