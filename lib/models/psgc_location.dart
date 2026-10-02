class PsgcLocation {
  const PsgcLocation({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;

  factory PsgcLocation.fromJson(
    Map<String, dynamic> json,
  ) {
    return PsgcLocation(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}