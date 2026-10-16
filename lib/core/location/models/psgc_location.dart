class PsgcLocation {
  const PsgcLocation({required this.code, required this.name, this.regionCode, this.regionLabel});
  final String code;
  final String name;
  final String? regionCode;
  final String? regionLabel;
  factory PsgcLocation.fromJson(Map<String, dynamic> json) => PsgcLocation(
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        regionCode: (json['regionCode'] ?? json['region_code'])?.toString(),
        regionLabel: json['regionName']?.toString(),
      );
}
