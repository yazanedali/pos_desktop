class CashBox {
  final int? id;
  final String name;
  final double balance;
  final String? updatedAt;

  CashBox({this.id, required this.name, this.balance = 0.0, this.updatedAt});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'updated_at': updatedAt,
    };
  }

  factory CashBox.fromMap(Map<String, dynamic> map) {
    return CashBox(
      id: map['id'],
      name: map['name'],
      balance: (map['balance'] as num).toDouble(),
      updatedAt: map['updated_at'],
    );
  }

  CashBox copyWith({
    int? id,
    String? name,
    double? balance,
    String? updatedAt,
  }) {
    return CashBox(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
