import 'package:flutter/material.dart';
import '../database/cash_queries.dart';
import '../services/cash_service.dart';
import '../widgets/top_alert.dart';
import '../models/cash_box.dart';

class CashManagementPage extends StatefulWidget {
  const CashManagementPage({super.key});

  @override
  State<CashManagementPage> createState() => _CashManagementPageState();
}

class _CashManagementPageState extends State<CashManagementPage> {
  final CashQueries _cashQueries = CashQueries();
  final CashService _cashService = CashService();

  List<CashBox> _boxes = [];
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  String _historyBoxFilter = 'الكل';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final boxes = await _cashQueries.getAllCashBoxes();
    final history = await _cashQueries.getMovementHistory(
      limit: 50,
      types: ['تحويل', 'سحب / مصاريف'],
    );

    setState(() {
      _boxes = boxes;
      _history = history;
      _isLoading = false;
    });
  }

  Future<void> _showTransferDialog() async {
    final amountController = TextEditingController();
    final dailyBox = _boxes.firstWhere(
      (b) => b.name == 'الصندوق اليومي',
      orElse: () => CashBox(name: ''),
    );

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("تحويل من اليومي إلى الرئيسي"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("المتوفر: ${dailyBox.balance.toStringAsFixed(2)} شيكل"),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "المبلغ",
                    border: OutlineInputBorder(),
                    suffixText: "شيكل",
                    isDense: true,
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
                      message: "مبلغ غير صحيح",
                    );
                    return;
                  }
                  if (amount > dailyBox.balance) {
                    TopAlert.showError(
                      context: context,
                      message: "الرصيد غير كاف",
                    );
                    return;
                  }
                  final success = await _cashService.transferDailyToMain(
                    amount,
                  );
                  if (success) {
                    if (mounted) Navigator.pop(context);
                    TopAlert.showSuccess(
                      context: context,
                      message: "تم التحويل",
                    );
                    _loadData();
                  }
                },
                child: const Text("تأكيد"),
              ),
            ],
          ),
    );
  }

  Future<void> _showWithdrawDialog() async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    String selectedBox = 'الصندوق الرئيسي';

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text("سحب / مصاريف"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedBox,
                        decoration: const InputDecoration(
                          labelText: "من صندوق",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items:
                            ['الصندوق اليومي', 'الصندوق الرئيسي']
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(b),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (val) => setDialogState(() => selectedBox = val!),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "المبلغ",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: reasonController,
                        decoration: const InputDecoration(
                          labelText: "السبب",
                          border: OutlineInputBorder(),
                          isDense: true,
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
                        final reason = reasonController.text.trim();
                        if (amount == null || amount <= 0 || reason.isEmpty)
                          return;

                        final box = _boxes.firstWhere(
                          (b) => b.name == selectedBox,
                        );
                        if (amount > box.balance) {
                          TopAlert.showError(
                            context: context,
                            message: "رصيد غير كاف",
                          );
                          return;
                        }

                        await _cashService.recordWithdrawal(
                          amount: amount,
                          boxName: selectedBox,
                          reason: reason,
                        );
                        if (mounted) Navigator.pop(context);
                        TopAlert.showSuccess(
                          context: context,
                          message: "تم السحب",
                        );
                        _loadData();
                      },
                      child: const Text("تأكيد"),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _deleteMovement(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("حذف الحركة"),
            content: const Text(
              "هل أنت متأكد من حذف هذه الحركة؟ لن يؤثر هذا على الرصيد الحالي.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("إلغاء"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("حذف"),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _cashQueries.deleteMovement(id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              _buildBalanceCards(),
              const SizedBox(height: 12),
              _buildActionButtons(),
              const SizedBox(height: 12),
              Expanded(child: _buildHistorySection()),
            ],
          ),
        );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showTransferDialog,
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text("تحويل للرئيسي"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade50,
              foregroundColor: Colors.blue.shade800,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.blue.shade200),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showWithdrawDialog,
            icon: const Icon(Icons.money_off, size: 18),
            label: const Text("سحب مصاريف"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade800,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.red.shade200),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCards() {
    return Row(
      children: [
        for (int i = 0; i < _boxes.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(
            child: Card(
              elevation: 1,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors:
                        _boxes[i].name.contains('اليومي')
                            ? [Colors.orange.shade300, Colors.orange.shade600]
                            : [Colors.green.shade300, Colors.green.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _boxes[i].name,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_boxes[i].balance.toStringAsFixed(1)} ش",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHistorySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "سجل الحركات",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(
                  height: 30,
                  child: DropdownButton<String>(
                    value: _historyBoxFilter,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.filter_list, size: 16),
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                    items:
                        ['الكل', 'الصندوق اليومي', 'الصندوق الرئيسي']
                            .map(
                              (b) => DropdownMenuItem(value: b, child: Text(b)),
                            )
                            .toList(),
                    onChanged:
                        (val) => setState(() => _historyBoxFilter = val!),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child:
                _history.isEmpty
                    ? const Center(
                      child: Text(
                        "لا توجد حركات",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )
                    : Builder(
                      builder: (context) {
                        final filteredHistory =
                            _historyBoxFilter == 'الكل'
                                ? _history
                                : _history
                                    .where(
                                      (h) => h['box_name'] == _historyBoxFilter,
                                    )
                                    .toList();

                        if (filteredHistory.isEmpty) {
                          return const Center(
                            child: Text(
                              "لا توجد نتائج",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: filteredHistory.length,
                          separatorBuilder:
                              (context, index) =>
                                  const Divider(height: 1, indent: 50),
                          itemBuilder: (context, index) {
                            final item = filteredHistory[index];
                            final isPositive = item['direction'] == 'داخل';
                            final hasNote =
                                item['notes'] != null &&
                                item['notes'].toString().trim().isNotEmpty;

                            return ListTile(
                              visualDensity: VisualDensity.compact,
                              dense: true,
                              contentPadding: const EdgeInsets.only(
                                left: 12,
                                right: 12,
                                top: 2,
                                bottom: 2,
                              ),
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    isPositive
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                child: Icon(
                                  isPositive
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: isPositive ? Colors.green : Colors.red,
                                  size: 14,
                                ),
                              ),
                              title: Text(
                                hasNote ? item['notes'] : item['type'],
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                "${item['box_name']} • ${item['date']}",
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              // -----------------------------------------------------
                              // هنا تم تعديل زر الحذف ليصبح أوضح وأسهل في الوصول
                              // -----------------------------------------------------
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${item['amount'].toStringAsFixed(1)}",
                                    style: TextStyle(
                                      color:
                                          isPositive
                                              ? Colors.green
                                              : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 12), // مسافة أكبر
                                  InkWell(
                                    onTap: () => _deleteMovement(item['id']),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        6,
                                      ), // مساحة للنقر
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(
                                          0.1,
                                        ), // خلفية واضحة
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        size: 20, // أيقونة أكبر
                                        color: Colors.red, // لون أحمر صريح
                                      ),
                                    ),
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
      ),
    );
  }
}
