class Denomination {
  const Denomination({
    required this.id,
    required this.currencyCode,
    required this.value,
    required this.label,
    required this.sortOrder,
  });

  final String id;
  final String currencyCode;
  final double value;
  final String label;
  final int sortOrder;

  factory Denomination.fromJson(Map<String, dynamic> json) {
    return Denomination(
      id: json['id'] as String,
      currencyCode: json['currency_code'] as String,
      value: (json['value'] as num).toDouble(),
      label: json['label'] as String,
      sortOrder: json['sort_order'] as int,
    );
  }
}
