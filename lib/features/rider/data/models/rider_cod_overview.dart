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
    this.receivingFacility,
    this.remittanceBlockedReason,
    this.handoverDraft,
  });

  final String toCollect;
  final String collected;
  final String remitted;
  final String outstanding;
  final int discrepancies;
  final List<Map<String, dynamic>> collections;
  final List<Map<String, dynamic>> batches;
  final List<Map<String, dynamic>> facilities;
  final Map<String, dynamic>? receivingFacility;
  final String? remittanceBlockedReason;
  final Map<String, dynamic>? handoverDraft;
  bool get hasCashReference =>
      (handoverDraft?['reference']?.toString().isNotEmpty ?? false) &&
      (handoverDraft?['idempotency_key']?.toString().isNotEmpty ?? false);
  bool get hasAssignedBranch =>
      (int.tryParse('${receivingFacility?['id']}') ?? 0) > 0;

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
      receivingFacility: data['receiving_facility'] is Map
          ? Map<String, dynamic>.from(data['receiving_facility'] as Map)
          : null,
      remittanceBlockedReason: data['remittance_blocked_reason']?.toString(),
      handoverDraft: data['handover_draft'] is Map
          ? Map<String, dynamic>.from(data['handover_draft'] as Map)
          : null,
    );
  }

  static List<Map<String, dynamic>> rows(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
      : [];

  static String receiptStatus(Map<String, dynamic> cash) {
    final review = cash['discrepancy_case'];
    if (review is Map && review['status'] != 'resolved') return 'Under review';
    if (cash['status'] == 'discrepancy') return 'Under review';
    if (cash['receipt_verified'] == true || cash['status'] == 'reconciled') {
      return 'Receipt verified';
    }
    if (cash['status'] == 'remitted') return 'Awaiting verification';
    return 'With rider';
  }

  static String? caseDescription(Map<String, dynamic> cash) {
    final review = cash['discrepancy_case'];
    if (review is! Map) return null;
    final message = switch (review['status']) {
      'open' => 'Awaiting Logistics investigation.',
      'pending_approval' => 'Awaiting ShopHop Admin review.',
      'approved' =>
        'Excess return approved; Logistics must confirm the actual cash return.',
      'resolved' => 'Resolved after authorized review.',
      _ => 'Review in progress.',
    };
    return 'Case ${review['reference'] ?? ''}: $message';
  }

  static String batchReviewDescription(Map<String, dynamic> batch) {
    final cases = rows(batch['discrepancy_cases']);
    if (cases.isEmpty) {
      return 'Original cash difference recorded. Contact Logistics for review status.';
    }
    if (cases.isNotEmpty &&
        cases.every((review) => review['status'] == 'resolved')) {
      return 'Original discrepancy resolved. Original cash counts remain in history.';
    }
    return 'Under review. Shortages remain owed; overages require investigation.';
  }

  static String custodyDescription(Map<String, dynamic> batch) {
    final custody = batch['cash_custody'];
    if (custody is! Map) {
      return batch['verified_at'] != null
          ? 'Branch verified; awaiting onward remittance.'
          : 'Await Branch cash verification.';
    }
    return switch (custody['status']) {
      'branch_submitted' => 'Branch remitted; awaiting Main Hub receipt.',
      'treasury_received' =>
        'Main Hub received; awaiting Logistics remittance to Admin.',
      'admin_submitted' => 'Logistics remitted; awaiting Admin receipt.',
      'admin_received' => 'Cash custody complete: ShopHop Admin received.',
      'treasury_review' => 'Main Hub cash count is under review.',
      'admin_review' => 'ShopHop cash count is under review.',
      _ => 'Review cash custody status with Logistics.',
    };
  }

  static String platformReceiptDescription(Map<String, dynamic> cash) {
    switch (cash['platform_receipt_status']) {
      case 'under_review':
        return 'ShopHop: Cash discrepancy under review; settlement blocked.';
      case 'not_ready':
        return 'ShopHop: Awaiting verified branch cash receipt.';
      case 'with_logistics':
        return 'ShopHop: Logistics must remit the verified cash.';
      case 'awaiting_confirmation':
        return 'ShopHop: Remittance recorded; Admin must confirm actual receipt.';
      case 'confirmed':
        return 'ShopHop: Receipt confirmed. Seller and Logistics settlement is a separate approval.';
      default:
        return 'ShopHop receipt status unavailable.';
    }
  }

  static String receiverDescription(Map<String, dynamic> cash) {
    final facility = cash['receiving_facility']?.toString().trim() ?? '';
    return facility.isNotEmpty
        ? 'Receiving branch: $facility'
        : 'Receiving branch not recorded. Your logistics company must verify receipt.';
  }

  static String minorDisplay(dynamic value) {
    final minor = int.tryParse('$value');
    if (minor == null) return 'Pending';
    final absolute = minor.abs();
    return '${minor < 0 ? '-' : ''}${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
  }
}
