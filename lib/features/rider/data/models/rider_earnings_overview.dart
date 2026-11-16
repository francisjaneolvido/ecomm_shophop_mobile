/// Read-only earnings summary shared by Rider Home and the earnings screen.
/// Values come from the API; this model never changes COD cash or posts payouts.
class RiderEarningsOverview {
  const RiderEarningsOverview({
    required this.pending,
    required this.available,
    required this.paid,
    required this.entries,
  });

  final double pending;
  final double available;
  final double paid;
  final List<Map<String, dynamic>> entries;

  static String parcelBreakdown(Map<String, dynamic> entry) {
    if (entry['funding_source'] != 'order_distribution') return '';
    double number(dynamic value) => double.tryParse('$value') ?? 0;
    return '${number(entry['weight_kg']).toStringAsFixed(3)} kg · '
        'Base ₱${number(entry['base_amount']).toStringAsFixed(2)} + '
        '${entry['extra_kg'] ?? 0} extra kg × '
        '₱${number(entry['extra_kg_rate']).toStringAsFixed(2)}';
  }

  static String statusLabel(Map<String, dynamic> entry) {
    if (entry['funding_source'] == 'order_distribution' &&
        entry['status'] == 'pending') {
      return 'Pending Admin distribution';
    }
    return (entry['status'] ?? 'pending').toString().replaceAll('_', ' ');
  }

  factory RiderEarningsOverview.fromJson(Map<String, dynamic> data) {
    final partner = data['partner_compensation'] is Map
        ? data['partner_compensation'] as Map
        : const {};
    double amount(dynamic value) => double.tryParse('$value') ?? 0;
    List<Map<String, dynamic>> rows(dynamic value) => value is List
        ? value
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
        : [];

    return RiderEarningsOverview(
      pending: amount(data['pending']) + amount(partner['pending']),
      available: amount(data['available']) + amount(partner['available']),
      paid: amount(data['paid']) + amount(partner['paid']),
      entries: [...rows(data['entries']), ...rows(partner['entries'])],
    );
  }
}
