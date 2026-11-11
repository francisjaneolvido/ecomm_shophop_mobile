/// Authoritative backend amounts are decimal strings; mobile does not post calculations.
class RiderCodOverview {
  const RiderCodOverview({
    this.toCollect = '0.00',
    required this.collected,
    required this.remitted,
    required this.outstanding,
    required this.discrepancies,
    required this.collections,
    required this.batches,
    required this.facilities,
  });

  final String toCollect;
  final String collected;
  final String remitted;
  final String outstanding;
  final int discrepancies;
  final List<Map<String, dynamic>> collections;
  final List<Map<String, dynamic>> batches;
  final List<Map<String, dynamic>> facilities;

  factory RiderCodOverview.fromJson(Map<String, dynamic> data) {
    final summary = data['summary'] is Map ? data['summary'] as Map : {};
    return RiderCodOverview(
      toCollect: '${summary['to_collect'] ?? '0.00'}',
      collected: '${summary['collected'] ?? '0.00'}',
      remitted: '${summary['remitted'] ?? '0.00'}',
      outstanding: '${summary['outstanding'] ?? '0.00'}',
      discrepancies: int.tryParse('${summary['discrepancies']}') ?? 0,
      collections: rows(data['collections']),
      batches: rows(data['batches']),
      facilities: rows(data['facilities']),
    );
  }

  static List<Map<String, dynamic>> rows(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
      : [];

  static String minorDisplay(dynamic value) {
    final minor = int.tryParse('$value');
    if (minor == null) return 'Pending';
    final absolute = minor.abs();
    return '${minor < 0 ? '-' : ''}${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
  }
}
