import '../database/cash_queries.dart';
import '../models/cash_movement.dart';

class CashService {
  final CashQueries _cashQueries = CashQueries();

  // مبيعات جديدة آلياً إلى الصندوق اليومي
  Future<void> recordSaleIncome({
    required double amount,
    required String invoiceNumber,
    String notes = 'مبيعات فاتورة',
  }) async {
    final dailyBox = await _cashQueries.getCashBoxByName('الصندوق اليومي');
    if (dailyBox == null) return;

    final now = DateTime.now();
    final movement = CashMovement(
      boxId: dailyBox.id!,
      amount: amount,
      type: 'مبيعات',
      direction: 'داخل',
      notes: '$notes #$invoiceNumber',
      date: _formatDate(now),
      time: _formatTime(now),
      relatedId: invoiceNumber,
    );

    await _cashQueries.addCashMovement(movement);
  }

  // تسجيل دفعة مشتريات
  Future<void> recordPurchasePayment({
    required double amount,
    required String boxName, // "الصندوق اليومي" أو "الصندوق الرئيسي"
    required String invoiceNumber,
    String? supplierName,
  }) async {
    final box = await _cashQueries.getCashBoxByName(boxName);
    if (box == null) return;

    final now = DateTime.now();
    final movement = CashMovement(
      boxId: box.id!,
      amount: amount,
      type: 'مشتريات',
      direction: 'خارج',
      notes:
          'دفع فاتورة شراء #$invoiceNumber${supplierName != null ? " لـ $supplierName" : ""}',
      date: _formatDate(now),
      time: _formatTime(now),
      relatedId: invoiceNumber,
    );

    await _cashQueries.addCashMovement(movement);
  }

  // تسديد ديون زبائن إلى الصندوق اليومي
  Future<void> recordCustomerDebtPayment({
    required double amount,
    required String customerName,
    int? customerId,
  }) async {
    final dailyBox = await _cashQueries.getCashBoxByName('الصندوق اليومي');
    if (dailyBox == null) return;

    final now = DateTime.now();
    final movement = CashMovement(
      boxId: dailyBox.id!,
      amount: amount,
      type: 'سداد ديون زبائن',
      direction: 'داخل',
      notes: 'استلام دفعة من العميل: $customerName',
      date: _formatDate(now),
      time: _formatTime(now),
      relatedId: customerId?.toString(),
    );

    await _cashQueries.addCashMovement(movement);
  }

  // تحويل أموال من اليومي إلى الرئيسي
  Future<bool> transferDailyToMain(double amount, {String? notes}) async {
    final dailyBox = await _cashQueries.getCashBoxByName('الصندوق اليومي');
    final mainBox = await _cashQueries.getCashBoxByName('الصندوق الرئيسي');

    if (dailyBox == null || mainBox == null) return false;
    if (dailyBox.balance < amount) return false;

    final now = DateTime.now();
    final date = _formatDate(now);
    final time = _formatTime(now);

    // 1. حركة خروج من اليومي
    await _cashQueries.addCashMovement(
      CashMovement(
        boxId: dailyBox.id!,
        amount: amount,
        type: 'تحويل',
        direction: 'خارج',
        notes: notes ?? 'تحويل إلى الصندوق الرئيسي',
        date: date,
        time: time,
      ),
    );

    // 2. حركة دخول إلى الرئيسي
    await _cashQueries.addCashMovement(
      CashMovement(
        boxId: mainBox.id!,
        amount: amount,
        type: 'تحويل',
        direction: 'داخل',
        notes: notes ?? 'تحويل من الصندوق اليومي',
        date: date,
        time: time,
      ),
    );

    return true;
  }

  // تسجيل سحب (مصاريف)
  Future<void> recordWithdrawal({
    required double amount,
    required String boxName,
    required String reason,
  }) async {
    final box = await _cashQueries.getCashBoxByName(boxName);
    if (box == null) return;

    final now = DateTime.now();
    final movement = CashMovement(
      boxId: box.id!,
      amount: amount,
      type: 'سحب / مصاريف',
      direction: 'خارج',
      notes: reason,
      date: _formatDate(now),
      time: _formatTime(now),
    );

    await _cashQueries.addCashMovement(movement);
  }

  // تسجيل إيداع / تغذية للصندوق (رصيد افتتاحي، تمويل خارجي...)
  Future<void> recordDeposit({
    required double amount,
    required String boxName,
    required String source, // المصدر أو الملاحظات
  }) async {
    final box = await _cashQueries.getCashBoxByName(boxName);
    if (box == null) return;

    final now = DateTime.now();
    final movement = CashMovement(
      boxId: box.id!,
      amount: amount,
      type: 'إيداع / تغذية', // نوع الحركة الجديد
      direction: 'داخل', // يزيد الرصيد
      notes: source,
      date: _formatDate(now),
      time: _formatTime(now),
    );

    await _cashQueries.addCashMovement(movement);
  }

  // في services/cash_service.dart
  Future<void> recordPaymentToCustomer({
    required double amount,
    required String boxName,
    required String customerName,
    String? notes,
  }) async {
    final box = await _cashQueries.getCashBoxByName(boxName);
    if (box == null) return;

    final now = DateTime.now();
    final movement = CashMovement(
      boxId: box.id!,
      amount: amount,
      type: 'دفع للعميل',
      direction: 'خارج', // لأن المبلغ يخرج من الصندوق
      notes: 'دفع للعميل: $customerName${notes != null ? " - $notes" : ""}',
      date: _formatDate(now),
      time: _formatTime(now),
    );

    await _cashQueries.addCashMovement(movement);
  }

  String _formatDate(DateTime dt) =>
      "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

  String _formatTime(DateTime dt) =>
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
}
