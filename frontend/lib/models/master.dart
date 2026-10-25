class Master {
  const Master({
    required this.id,
    required this.code,
    required this.name,
    required this.active,
    this.unit,
  });
  final int id;
  final String code, name;
  final String? unit;
  final bool active;

  factory Master.fromJson(Map<String, dynamic> json) => Master(
    id: json['id'] as int,
    code: json['code'] as String,
    name: json['name'] as String,
    unit: json['unit'] as String?,
    active: json['is_active'] == true || json['is_active'] == 1,
  );
}

class MasterPageData {
  const MasterPageData(this.rows, this.total);
  final List<Master> rows;
  final int total;
}
