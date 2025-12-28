class CashMovement {
  final int? id;
  final int boxId;
  final double amount;
  final String type; // المبيعات، مشتريات، تحويل، سحب، إيداع، سداد دين
  final String direction; // "داخل" (In) أو "خارج" (Out)
  final String? notes;
  final String date;
  final String time;
  final String? relatedId; // ID الفاتورة أو العميل أو المورد المرتبط
  final String? createdAt;

  CashMovement({
    this.id,
    required this.boxId,
    required this.amount,
    required this.type,
    required this.direction,
    this.notes,
    required this.date,
    required this.time,
    this.relatedId,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'box_id': boxId,
      'amount': amount,
      'type': type,
      'direction': direction,
      'notes': notes,
      'date': date,
      'time': time,
      'related_id': relatedId,
      'created_at': createdAt,
    };
  }

  factory CashMovement.fromMap(Map<String, dynamic> map) {
    return CashMovement(
      id: map['id'],
      boxId: map['box_id'],
      amount: (map['amount'] as num).toDouble(),
      type: map['type'],
      direction: map['direction'],
      notes: map['notes'],
      date: map['date'],
      time: map['time'],
      relatedId: map['related_id']?.toString(),
      createdAt: map['created_at'],
    );
  }
}
