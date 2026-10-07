class RiderAssignment {
  const RiderAssignment({
    required this.id,
    required this.trackingCode,
    required this.status,
    required this.statusLabel,
    required this.assignmentType,
    required this.canAcceptPickup,
    required this.canConfirmPickup,
    required this.canStartDelivery,
    required this.canCompleteDelivery,
    required this.canFailDelivery,
    required this.deliveryAttempts,
    required this.orderId,
    required this.totalAmount,
    required this.paymentMethod,
    required this.deliveryName,
    required this.deliveryPhone,
    required this.deliveryAddress,
    required this.sellerName,
    required this.sellerBusinessName,
    required this.sellerContact,
    required this.sellerAddress,
    required this.items,
    required this.centerTransfers,
    this.destinationArea,
    this.failureReason,
    this.originSortingCenter,
    this.currentSortingCenter,
    this.destinationSortingCenter,
    this.pickupDropoffCenter,
    this.deliveryPickupCenter,
  });

  final int id;
  final String trackingCode;
  final String status;
  final String statusLabel;
  final String assignmentType;
  final bool canAcceptPickup;
  final bool canConfirmPickup;
  final bool canStartDelivery;
  final bool canCompleteDelivery;
  final bool canFailDelivery;
  final int deliveryAttempts;
  final int orderId;
  final String totalAmount;
  final String paymentMethod;
  final String deliveryName;
  final String deliveryPhone;
  final String deliveryAddress;
  final String sellerName;
  final String sellerBusinessName;
  final String sellerContact;
  final String sellerAddress;
  final List<RiderAssignmentItem> items;
  final List<RiderCenterTransfer> centerTransfers;
  final String? destinationArea;
  final String? failureReason;
  final RiderSortingCenter? originSortingCenter;
  final RiderSortingCenter? currentSortingCenter;
  final RiderSortingCenter? destinationSortingCenter;
  final RiderSortingCenter? pickupDropoffCenter;
  final RiderSortingCenter? deliveryPickupCenter;

  bool get isCod => paymentMethod.toLowerCase() == 'cod';

  bool get isTask => canAcceptPickup ||
      canConfirmPickup ||
      canStartDelivery ||
      canCompleteDelivery ||
      status == 'picked_up';

  factory RiderAssignment.fromJson(Map<String, dynamic> json) {
    final order = json['order'] is Map
        ? Map<String, dynamic>.from(json['order'] as Map)
        : <String, dynamic>{};
    final seller = order['seller'] is Map
        ? Map<String, dynamic>.from(order['seller'] as Map)
        : <String, dynamic>{};
    final rawItems = order['items'] is List ? order['items'] as List : const [];
    final rawTransfers =
        json['center_transfers'] is List ? json['center_transfers'] as List : const [];

    RiderSortingCenter? center(String key) {
      final raw = json[key];
      if (raw is! Map) return null;
      return RiderSortingCenter.fromJson(Map<String, dynamic>.from(raw));
    }

    return RiderAssignment(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      trackingCode: json['tracking_code']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      statusLabel: json['status_label']?.toString() ?? 'Assignment',
      assignmentType: json['assignment_type']?.toString() ?? 'history',
      canAcceptPickup: json['can_accept_pickup'] == true,
      canConfirmPickup: json['can_confirm_pickup'] == true,
      canStartDelivery: json['can_start_delivery'] == true,
      canCompleteDelivery: json['can_complete_delivery'] == true,
      canFailDelivery: json['can_fail_delivery'] == true,
      deliveryAttempts:
          int.tryParse(json['delivery_attempts']?.toString() ?? '') ?? 0,
      orderId: int.tryParse(order['id']?.toString() ?? '') ?? 0,
      totalAmount: order['total_amount']?.toString() ?? '0.00',
      paymentMethod: order['payment_method']?.toString() ?? '',
      deliveryName: order['delivery_name']?.toString() ?? '',
      deliveryPhone: order['delivery_phone']?.toString() ?? '',
      deliveryAddress: order['delivery_address']?.toString() ?? '',
      sellerName: seller['name']?.toString() ?? '',
      sellerBusinessName: seller['business_name']?.toString() ?? '',
      sellerContact: seller['contact_no']?.toString() ?? '',
      sellerAddress: seller['address']?.toString() ?? '',
      items: rawItems
          .whereType<Map>()
          .map((value) =>
              RiderAssignmentItem.fromJson(Map<String, dynamic>.from(value)))
          .toList(),
      centerTransfers: rawTransfers
          .whereType<Map>()
          .map((value) =>
              RiderCenterTransfer.fromJson(Map<String, dynamic>.from(value)))
          .toList(),
      destinationArea: json['destination_area']?.toString(),
      failureReason: json['failure_reason']?.toString(),
      originSortingCenter: center('origin_sorting_center'),
      currentSortingCenter: center('current_sorting_center'),
      destinationSortingCenter: center('destination_sorting_center'),
      pickupDropoffCenter: center('pickup_dropoff_center'),
      deliveryPickupCenter: center('delivery_pickup_center'),
    );
  }
}

class RiderSortingCenter {
  const RiderSortingCenter({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.isMain,
  });

  final int id;
  final String name;
  final String code;
  final String address;
  final bool isMain;

  factory RiderSortingCenter.fromJson(Map<String, dynamic> json) {
    return RiderSortingCenter(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? 'Sorting Center',
      code: json['code']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      isMain: json['is_main'] == true,
    );
  }
}

class RiderCenterTransfer {
  const RiderCenterTransfer({
    required this.id,
    required this.status,
    this.from,
    this.to,
    this.dispatchedAt,
    this.receivedAt,
  });

  final int id;
  final String status;
  final RiderSortingCenter? from;
  final RiderSortingCenter? to;
  final String? dispatchedAt;
  final String? receivedAt;

  factory RiderCenterTransfer.fromJson(Map<String, dynamic> json) {
    RiderSortingCenter? parseCenter(dynamic value) {
      if (value is! Map) return null;
      return RiderSortingCenter.fromJson(Map<String, dynamic>.from(value));
    }

    return RiderCenterTransfer(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? '',
      from: parseCenter(json['from']),
      to: parseCenter(json['to']),
      dispatchedAt: json['dispatched_at']?.toString(),
      receivedAt: json['received_at']?.toString(),
    );
  }
}

class RiderAssignmentItem {
  const RiderAssignmentItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.variant,
  });

  final String name;
  final int quantity;
  final String price;
  final String variant;

  factory RiderAssignmentItem.fromJson(Map<String, dynamic> json) {
    return RiderAssignmentItem(
      name: json['name']?.toString() ?? 'Product',
      quantity: int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      price: json['price']?.toString() ?? '0.00',
      variant: json['variant']?.toString() ?? 'Standard',
    );
  }
}
