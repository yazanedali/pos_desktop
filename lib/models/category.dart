// models/category.dart
class Category {
  final int? id;
  final String name;
  final String? description;
  final String color;
  final String? createdAt; // أصبح String بدلاً من DateTime

  Category({
    this.id,
    required this.name,
    this.description,
    required this.color,
    this.createdAt,
  });

  // تحويل من Map إلى Category
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      color: map['color'] ?? '#3B82F6',
      createdAt: map['created_at'],
    );
  }

  // تحويل من Category إلى Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      // لا نرسل created_at لأنه مضبوط تلقائياً في قاعدة البيانات
    };
  }

  // نسخ الكائن مع تحديث بعض الخصائص
  Category copyWith({
    int? id,
    String? name,
    String? description,
    String? color,
    String? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category && other.id == id && other.name == name;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
