import 'package:shophop/features/rider/presentation/widgets/rider_delivery_completion.dart';
import 'package:shophop/features/rider/presentation/screens/rider_application_status_screen.dart';
import 'package:shophop/features/rider/presentation/screens/rider_cod_remittance_screen.dart';
import 'package:shophop/features/rider/data/models/rider_cod_overview.dart';
import 'package:shophop/features/rider/data/models/rider_earnings_overview.dart';
import 'package:shophop/features/rider/data/services/rider_batch_service.dart';
import 'package:shophop/features/rider/presentation/screens/rider_batch_detail_screen.dart';
import 'package:shophop/shared/widgets/shop_hop_role_layout.dart';
import 'package:shophop/shared/realtime/foreground_refresh.dart';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';
import 'package:shophop/features/rider/data/models/rider_assignment.dart';
import 'package:shophop/features/rider/data/services/rider_delivery_service.dart';
import 'package:shophop/features/rider/data/services/rider_return_service.dart';
import 'package:shophop/features/rider/data/services/rider_transit_service.dart';
import 'package:shophop/features/rider/presentation/screens/rider_custody_scanner.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';
import 'package:shophop/shared/widgets/shop_hop_navigation.dart';

enum _RiderTaskKind { pickup, transfer, delivery, returnTask }

class _RiderTask {
  const _RiderTask({
    required this.key,
    required this.kind,
    required this.title,
    required this.trackingCode,
    required this.status,
    required this.from,
    required this.to,
    required this.nextStep,
    required this.priority,
    this.assignment,
    this.raw,
  });

  final String key;
  final _RiderTaskKind kind;
  final String title;
  final String trackingCode;
  final String status;
  final String from;
  final String to;
  final String nextStep;
  final int priority;
  final RiderAssignment? assignment;
  final Map<String, dynamic>? raw;
}

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  final List<Map<String, dynamic>> _batches = [];
  final Set<int> _batchedDeliveryIds = {};
  final Set<int> _failedBatchPickupIds = {};
  int _batchPages = 1;
  bool _batchMore = false;
  bool _batchesEnabled = false;
  final List<RiderAssignment> _assignments = [];
  final List<Map<String, dynamic>> _transfers = [];
  final List<Map<String, dynamic>> _returns = [];
  final List<Map<String, dynamic>> _codCollections = [];
  final List<Map<String, dynamic>> _earnings = [];

  late final ForegroundRefresh _liveRefresh;
  String _taskSearch = '';
  bool _loading = true;
  bool _profileLoaded = false;
  int? _busyDeliveryId;
  bool _deliveryFormOpen = false;
  int? _busyReturnId;
  int? _busyCodDeliveryId;
  int _tab = 0;
  String _taskFilter = 'all';
  bool _tasksCompleted = false;
  bool _walletCod = true;
  RiderCodOverview _codOverview = RiderCodOverview.fromJson({});
  String? _error;
  String? _token;
  String _name = 'Rider';
  String _logisticsCenter = 'Logistics / Sorting Center';
  String? _sortingCenterName;
  String? _sortingCenterCode;
  String? _sortingCenterAddress;
  String? _coverageArea;
  String _operationalAreaSummary = '';
  String _operationalAreaMode = 'legacy';
  double _pendingEarnings = 0;
  double _availableEarnings = 0;
  double _paidEarnings = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _liveRefresh = ForegroundRefresh(
      refresh: () => _load(showLoader: false, silent: true),
      canRefresh: () =>
          mounted &&
          _requestFuture == null &&
          _tab != 2 &&
          _busyDeliveryId == null &&
          _busyReturnId == null &&
          _busyCodDeliveryId == null &&
          (ModalRoute.of(context)?.isCurrent ?? true),
    );
  }

  @override
  void dispose() {
    _liveRefresh.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic source) => source is List
      ? source
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
      : <Map<String, dynamic>>[];

  double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  int? _id(dynamic value) => int.tryParse(value?.toString() ?? '');

  Future<void>? _requestFuture;

  Future<void> _load({bool showLoader = true, bool silent = false}) {
    final pending = _requestFuture;
    if (pending != null) {
      if (silent) return pending;
      return pending.then(
        (_) => mounted
            ? _load(showLoader: showLoader, silent: silent)
            : Future<void>.value(),
      );
    }
    final request = _fetch(showLoader: showLoader, silent: silent).whenComplete(
      () {
        if (mounted) setState(() => _requestFuture = null);
      },
    );
    _requestFuture = request;
    return request;
  }

  Future<void> _fetch({bool showLoader = true, bool silent = false}) async {
    if (mounted) {
      setState(() {
        if (showLoader && !_profileLoaded) _loading = true;
        _error = null;
      });
    }

    try {
      final session = await AuthSessionService.readSession().timeout(
        const Duration(seconds: 8),
      );
      if (!mounted) return;

      if (session == null || session.accountType != 'rider') {
        await _leaveSession();
        return;
      }

      _token = session.token;

      final me = await AuthService.me(
        token: session.token,
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;

      if (!me.success) {
        if (me.statusCode == 401 || me.statusCode == 403) {
          await _leaveSession();
          return;
        }

        setState(() {
          _error = me.message;
        });
        return;
      }

      if (me.status == 'rider_application') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const RiderApplicationStatusScreen(),
          ),
          (_) => false,
        );
        return;
      }

      if (me.status != 'approved') {
        setState(() {
          _profileLoaded = false;
          _error = me.message;
        });
        return;
      }

      setState(() {
        _name = me.data['name']?.toString() ?? 'Rider';
        _logisticsCenter =
            me.data['logistics_company']?.toString() ??
            me.data['logistics_center']?.toString() ??
            'Logistics / Sorting Center';
        _sortingCenterName = me.data['sorting_center_name']?.toString();
        _sortingCenterCode = me.data['sorting_center_code']?.toString();
        _sortingCenterAddress = me.data['sorting_center_address']?.toString();
        _coverageArea = me.data['coverage_area']?.toString();
        _operationalAreaMode =
            me.data['operational_area_mode']?.toString() ?? 'legacy';
        final areas = me.data['operational_service_areas'];
        if (areas is List && areas.isNotEmpty) {
          final labels = areas
              .whereType<Map>()
              .map((item) => item['label']?.toString() ?? '')
              .where((value) => value.trim().isNotEmpty)
              .toList();
          _operationalAreaSummary = labels.take(4).join(' · ');
          if (labels.length > 4) {
            _operationalAreaSummary += ' · +${labels.length - 4} more';
          }
        } else {
          _operationalAreaSummary = '';
        }
        _profileLoaded = true;
      });

      final results = await Future.wait<AuthApiResult>([
        RiderDeliveryService.assignments(token: session.token),
        RiderReturnService.tasks(session.token),
        RiderDeliveryService.codCollections(token: session.token),
        RiderTransitService.earnings(session.token),
        RiderBatchService.batches(session.token, pages: _batchPages),
      ]).timeout(const Duration(seconds: 30));
      if (!mounted) return;

      final assignmentResult = results[0];
      final returnResult = results[1];
      final codResult = results[2];
      final earningsResult = results[3];
      final batchResult = results[4];

      final rawAssignments = assignmentResult.data['assignments'];
      final assignments = rawAssignments is List
          ? rawAssignments
                .whereType<Map>()
                .map(
                  (value) => RiderAssignment.fromJson(
                    Map<String, dynamic>.from(value),
                  ),
                )
                .where((assignment) => assignment.id > 0)
                .toList()
          : <RiderAssignment>[];

      final syncErrors = <String>[];
      if (!assignmentResult.success) syncErrors.add(assignmentResult.message);
      if (!returnResult.success) syncErrors.add(returnResult.message);
      if (!codResult.success) syncErrors.add(codResult.message);
      if (!earningsResult.success) syncErrors.add(earningsResult.message);

      if (!batchResult.success && batchResult.statusCode != 404) {
        syncErrors.add(batchResult.message);
      }
      setState(() {
        if (batchResult.success) {
          _batchesEnabled = batchResult.data['enabled'] == true;
          _batches
            ..clear()
            ..addAll(_rows(batchResult.data['batches']));
          _batchMore = batchResult.data['next_page'] != null;
        }
        if (assignmentResult.success) {
          _batchedDeliveryIds
            ..clear()
            ..addAll(
              _rows(rawAssignments)
                  .where((row) => row['rider_batch_id'] != null)
                  .map((row) => _id(row['id']))
                  .whereType<int>(),
            );
          _failedBatchPickupIds
            ..clear()
            ..addAll(
              _rows(rawAssignments)
                  .where((row) => row['rider_batch_pickup_failed'] == true)
                  .map((row) => _id(row['id']))
                  .whereType<int>(),
            );
          _assignments
            ..clear()
            ..addAll(assignments);
        }
        if (returnResult.success) {
          _returns
            ..clear()
            ..addAll(_rows(returnResult.data['returns']));
        }
        if (codResult.success) {
          _codOverview = RiderCodOverview.fromJson(codResult.data);
          _codCollections
            ..clear()
            ..addAll(_rows(codResult.data['collections']));
        }
        if (earningsResult.success) {
          final overview = RiderEarningsOverview.fromJson(earningsResult.data);
          _earnings
            ..clear()
            ..addAll(overview.entries);
          _pendingEarnings = overview.pending;
          _availableEarnings = overview.available;
          _paidEarnings = overview.paid;
        }
        _error = syncErrors.isEmpty
            ? null
            : 'Some Rider data could not refresh. ${syncErrors.first}';
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error =
            'ShopHop took too long to respond. Check your connection and make sure the Laravel API is running.';
      });
    } catch (error) {
      if (!mounted) return;
      final text = error.toString();
      setState(() {
        _error = text.contains('OperationError')
            ? 'The saved Rider session could not be read. Sign in again, then use a full restart if the browser input error returns.'
            : 'Unable to refresh Rider operations. ${text.isEmpty ? 'Please try again.' : text}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _leaveSession() async {
    await AuthSessionService.clearSession();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    final token = _token;
    if (token != null) await AuthService.logout(token: token);
    await _leaveSession();
  }

  Future<void> _runDeliveryAction(
    RiderAssignment assignment,
    Future<AuthApiResult> Function(String token) action,
  ) async {
    final token = _token;
    if (token == null || _busyDeliveryId != null) return;

    setState(() => _busyDeliveryId = assignment.id);
    final result = await action(token);
    if (!mounted) return;

    setState(() => _busyDeliveryId = null);
    _message(result.message, isError: !result.success);

    if (result.success) await _load(showLoader: false);
  }

  Future<void> _collectReturn(Map<String, dynamic> item) async {
    final token = _token;
    final id = _id(item['id']);
    if (token == null || id == null || _busyReturnId != null) return;

    final confirmed = await _confirmAction(
      title: 'Collect return parcel?',
      message:
          'Confirm only after physically collecting the return parcel from your assigned branch.',
      confirmLabel: 'Confirm pickup',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyReturnId = id);
    final result = await RiderReturnService.collect(token, id);
    if (!mounted) return;

    setState(() => _busyReturnId = null);
    _message(result.message, isError: !result.success);
    if (result.success) await _load(showLoader: false);
  }

  Future<void> _handoverReturn(Map<String, dynamic> item) async {
    final token = _token;
    final id = _id(item['id']);
    if (token == null || id == null || _busyReturnId != null) return;

    final selected = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || selected == null || selected.files.isEmpty) return;

    final confirmed = await _confirmAction(
      title: 'Submit Seller handover proof?',
      message:
          'Submit only after handing the parcel back to the Seller. The Seller will confirm receipt separately.',
      confirmLabel: 'Submit proof',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyReturnId = id);
    final result = await RiderReturnService.handover(
      token,
      id,
      selected.files.first,
    );
    if (!mounted) return;

    setState(() => _busyReturnId = null);
    _message(result.message, isError: !result.success);
    if (result.success) await _load(showLoader: false);
  }

  Future<void> _remitCod(Map<String, dynamic> cash) async {
    final id = _id(cash['delivery_id']);
    if (_token == null || id == null || _busyCodDeliveryId != null) return;
    setState(() => _busyCodDeliveryId = id);
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RiderCodRemittanceScreen(
          initialCollectionId: _id(cash['collection_id']),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busyCodDeliveryId = null);
    await _load(showLoader: false);
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    String confirmLabel = 'Continue',
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.tealDark),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _complete(RiderAssignment assignment) async {
    if (_deliveryFormOpen || _busyDeliveryId != null) return;
    _deliveryFormOpen = true;
    RiderDeliveryConfirmation? confirmation;
    try {
      confirmation = await showModalBottomSheet<RiderDeliveryConfirmation>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => RiderDeliveryCompletion(assignment: assignment),
      );
    } finally {
      _deliveryFormOpen = false;
    }
    if (!mounted || confirmation == null) return;
    final accepted = confirmation;
    await _runDeliveryAction(
      assignment,
      (token) => RiderDeliveryService.completeDelivery(
        token: token,
        deliveryId: assignment.id,
        proof: accepted.proof,
        cashCollected: accepted.cashCollected,
      ),
    );
  }

  Future<void> _fail(RiderAssignment assignment) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report failed delivery'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'e.g. Customer unavailable',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.tealDark),
            child: const Text('Record failure'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || reason == null || reason.isEmpty) return;
    await _runDeliveryAction(
      assignment,
      (token) => RiderDeliveryService.failDelivery(
        token: token,
        deliveryId: assignment.id,
        reason: reason,
      ),
    );
  }

  void _message(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? const Color(0xFFB54747) : AppColors.navy,
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  List<RiderAssignment> get _deliveryTasks =>
      _assignments.where((assignment) => assignment.isTask).toList();

  List<RiderAssignment> get _deliveryHistory =>
      _assignments.where((assignment) => !assignment.isTask).toList();

  List<Map<String, dynamic>> get _completedTransfers =>
      _transfers.where((item) {
        final received = item['received_at'];
        return received != null && received.toString().trim().isNotEmpty;
      }).toList();

  List<Map<String, dynamic>> get _activeReturns => _returns.where((item) {
    final status = item['status']?.toString().toLowerCase() ?? '';
    return status != 'seller_received' && status != 'cancelled';
  }).toList();

  List<Map<String, dynamic>> get _completedReturns => _returns.where((item) {
    final status = item['status']?.toString().toLowerCase() ?? '';
    return status == 'seller_received';
  }).toList();

  List<Map<String, dynamic>> get _codToRemit =>
      _codCollections.where((cash) => cash['can_remit'] == true).toList();

  double get _codOutstanding => _number(_codOverview.outstanding);

  List<_RiderTask> get _todayTasks {
    final tasks = <_RiderTask>[];

    for (final assignment in _deliveryTasks) {
      if (_failedBatchPickupIds.contains(assignment.id)) continue;
      final pickup = assignment.assignmentType == 'pickup';
      final seller = assignment.sellerBusinessName.trim().isNotEmpty
          ? assignment.sellerBusinessName.trim()
          : assignment.sellerName.trim();
      final pickupCenter =
          assignment.pickupDropoffCenter ??
          assignment.originSortingCenter ??
          assignment.currentSortingCenter;
      final deliveryCenter =
          assignment.deliveryPickupCenter ??
          assignment.destinationSortingCenter ??
          assignment.currentSortingCenter;

      tasks.add(
        _RiderTask(
          key: 'delivery-${assignment.id}',
          kind: pickup ? _RiderTaskKind.pickup : _RiderTaskKind.delivery,
          title: pickup ? 'Seller Pickup' : 'Buyer Delivery',
          trackingCode: assignment.trackingCode.isEmpty
              ? 'Order #${assignment.orderId}'
              : assignment.trackingCode,
          status: assignment.statusLabel,
          from: pickup
              ? (seller.isEmpty ? 'Seller' : seller)
              : (deliveryCenter?.name ?? 'Assigned branch'),
          to: pickup
              ? (pickupCenter?.name ?? 'Assigned branch')
              : (assignment.deliveryName.trim().isEmpty
                    ? 'Buyer'
                    : assignment.deliveryName.trim()),
          nextStep: _nextStep(assignment),
          priority: _assignmentPriority(assignment),
          assignment: assignment,
        ),
      );
    }

    for (final item in _activeReturns) {
      final id = _id(item['id']) ?? 0;
      final status = item['status']?.toString().toLowerCase() ?? '';
      final seller = item['seller']?.toString().trim();
      final branch = item['branch']?.toString().trim();
      tasks.add(
        _RiderTask(
          key: 'return-$id',
          kind: _RiderTaskKind.returnTask,
          title: 'Return to Seller',
          trackingCode:
              item['tracking_code']?.toString().trim().isNotEmpty == true
              ? item['tracking_code'].toString()
              : 'Order #${item['order_id'] ?? ''}',
          status: _humanize(status),
          from: branch == null || branch.isEmpty ? 'Assigned branch' : branch,
          to: seller == null || seller.isEmpty ? 'Seller' : seller,
          nextStep: status == 'assigned'
              ? 'Collect the return parcel from your assigned branch.'
              : status == 'in_transit'
              ? 'Hand the parcel to the Seller and upload proof.'
              : status == 'awaiting_seller'
              ? 'Waiting for the Seller to confirm receipt.'
              : 'Check the return status with your branch.',
          priority: status == 'in_transit'
              ? 5
              : status == 'assigned'
              ? 6
              : 10,
          raw: item,
        ),
      );
    }

    tasks.sort((a, b) => a.priority.compareTo(b.priority));
    return tasks;
  }

  int _assignmentPriority(RiderAssignment assignment) {
    if (assignment.canCompleteDelivery) return 0;
    if (assignment.canStartDelivery) return 1;
    if (assignment.canConfirmPickup || assignment.canAcceptPickup) return 2;
    if (assignment.status == 'picked_up') return 3;
    return 8;
  }

  String _nextStep(RiderAssignment assignment) {
    if (assignment.canAcceptPickup || assignment.canConfirmPickup) {
      return 'At the Seller, scan the parcel waybill QR. Confirming the scan accepts the assignment and records pickup in one step.';
    }
    if (assignment.status == 'picked_up') {
      final center =
          assignment.pickupDropoffCenter ??
          assignment.originSortingCenter ??
          assignment.currentSortingCenter;
      return center == null
          ? 'Bring the parcel to your assigned branch for receiving scan.'
          : 'Bring the parcel to ${center.name} for receiving scan.';
    }
    if (assignment.canStartDelivery) {
      return 'Collect the parcel from the branch, then start delivery.';
    }
    if (assignment.canCompleteDelivery) {
      return 'Deliver to the Buyer, collect COD if required, and upload proof.';
    }
    if (assignment.canFailDelivery) {
      return 'Complete the delivery or report a valid failed attempt.';
    }
    return 'Review the parcel status and branch instructions.';
  }

  String _humanize(String value) {
    final normalized = value.trim().replaceAll('_', ' ');
    if (normalized.isEmpty) return 'Pending';
    return normalized
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grayBg,
      appBar: ShopHopRoleAppBar(
        role: ShopHopRole.rider,
        index: _tab,
        refreshing: _requestFuture != null,
        onRefresh:
            _tab == 2 ||
                _busyDeliveryId != null ||
                _busyReturnId != null ||
                _busyCodDeliveryId != null
            ? null
            : () => _load(showLoader: false),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (!_profileLoaded && _error != null)
          ? _loadErrorPage()
          : Column(
              children: [
                if (_error != null && _tab != 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _notice(_error!, Icons.sync_problem_rounded),
                  ),
                Expanded(
                  child: _tab == 2
                      ? _pageForTab()
                      : RefreshIndicator(
                          onRefresh: () => _load(showLoader: false),
                          child: _pageForTab(),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: ShopHopNavigation(
        raisedIndex: 2,
        index: _tab,
        onChanged: (value) {
          setState(() => _tab = value);
          if (value == 3 && !_loading) _load(showLoader: false);
        },
        items: ShopHopRole.rider.destinations,
        badges: {1: _todayTasks.length, 3: _codToRemit.length},
      ),
    );
  }

  Widget _pageForTab() {
    switch (_tab) {
      case 1:
        return _tasksPage();
      case 2:
        final token = _token;
        if (token == null) {
          return _todayPage();
        }
        return RiderCustodyScanner(
          token: token,
          onConfirmed: () => _load(showLoader: false),
        );
      case 3:
        return _walletPage();
      case 4:
        return _accountPage();
      default:
        return _todayPage();
    }
  }

  Widget _todayPage() {
    final allTasks = _todayTasks;
    final legacyTasks = allTasks.where((t) => !_isBatchTask(t)).toList();
    final nextTask = legacyTasks.isEmpty ? null : legacyTasks.first;
    final pickup = allTasks
        .where((t) => t.kind == _RiderTaskKind.pickup)
        .length;
    final delivery = allTasks
        .where((t) => t.kind == _RiderTaskKind.delivery)
        .length;
    final returns = allTasks
        .where((t) => t.kind == _RiderTaskKind.returnTask)
        .length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      key: PageStorageKey('rider-$_tab-$_tasksCompleted'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        _todayHeader(allTasks.length),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _notice(_error!, Icons.sync_problem_rounded),
        ],
        if (_codToRemit.isNotEmpty) ...[
          const SizedBox(height: 12),
          _codAlert(),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _taskSummary(
                'Pickups',
                pickup,
                Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _taskSummary(
                'Deliveries',
                delivery,
                Icons.local_shipping_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _taskSummary(
                'Returns',
                returns,
                Icons.keyboard_return_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (_batches.isNotEmpty) ..._batchCards(),
        if (_batches.isEmpty || legacyTasks.isNotEmpty)
          _sectionHeader(
            title: 'Next action',
            subtitle: 'Only the highest priority assigned task is shown here.',
          ),
        const SizedBox(height: 9),
        if (nextTask == null && _batches.isEmpty)
          _empty(
            icon: Icons.check_circle_outline_rounded,
            title: 'No active assignments',
            text: 'Pull down to refresh when new work is assigned.',
          )
        else if (nextTask != null)
          _taskCard(nextTask, emphasized: true),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() {
              _tasksCompleted = false;
              _tab = 1;
            }),
            icon: const Icon(Icons.assignment_outlined),
            label: Text('See all ${allTasks.length} active tasks'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => setState(() => _tab = 2),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Open QR scanner'),
          ),
        ),
      ],
    );
  }

  Widget _taskSummary(String label, int value, IconData icon) =>
      ShopHopRoleMetric(
        label: label,
        value: '$value',
        icon: icon,
        onTap: () => setState(() {
          _tab = 1;
          _tasksCompleted = false;
          _taskSearch = '';
          _taskFilter = switch (label) {
            'Pickups' => 'pickup',
            'Deliveries' => 'delivery',
            _ => 'return',
          };
        }),
      );

  Widget _tasksPage() {
    if (_tasksCompleted) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        key: PageStorageKey('rider-$_tab-$_tasksCompleted'),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          _taskModeSwitch(),
          const SizedBox(height: 12),
          if (_batchesEnabled && _token != null)
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RiderBatchHistoryScreen(token: _token!),
                ),
              ),
              icon: const Icon(Icons.route_outlined),
              label: const Text('View route history'),
            ),
          // Reuse the existing history renderer without duplicating its records.
          _historyInline(),
        ],
      );
    }
    final tasks = _todayTasks;
    final filtered = tasks.where((task) {
      if (_isBatchTask(task)) return false;
      final query = _taskSearch.trim().toLowerCase();
      final assignment = task.assignment;
      final searchable =
          '${task.trackingCode} ${task.from} ${task.to} '
          '${assignment?.deliveryAddress ?? ''} ${assignment?.sellerAddress ?? ''}';
      if (!searchable.toLowerCase().contains(query)) return false;
      if (_taskFilter == 'pickup') return task.kind == _RiderTaskKind.pickup;
      if (_taskFilter == 'delivery') {
        return task.kind == _RiderTaskKind.delivery;
      }
      if (_taskFilter == 'return') {
        return task.kind == _RiderTaskKind.returnTask;
      }
      return true;
    }).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      key: PageStorageKey('rider-$_tab-$_tasksCompleted'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        _taskModeSwitch(),
        if (_batchesEnabled) ..._batchCards(),
        const SizedBox(height: 10),
        TextFormField(
          key: const ValueKey('rider-task-search'),
          initialValue: _taskSearch,
          decoration: const InputDecoration(
            hintText: 'Search tracking, name or address',
            prefixIcon: Icon(Icons.search, size: 20),
          ),
          onChanged: (value) => setState(() => _taskSearch = value),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _taskFilterChip('All', 'all', tasks.length),
              const SizedBox(width: 6),
              _taskFilterChip(
                'Pickup',
                'pickup',
                tasks.where((t) => t.kind == _RiderTaskKind.pickup).length,
              ),
              const SizedBox(width: 6),
              _taskFilterChip(
                'Delivery',
                'delivery',
                tasks.where((t) => t.kind == _RiderTaskKind.delivery).length,
              ),
              const SizedBox(width: 6),
              _taskFilterChip(
                'Returns',
                'return',
                tasks.where((t) => t.kind == _RiderTaskKind.returnTask).length,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty && _batches.isEmpty)
          _empty(
            icon: Icons.assignment_turned_in_outlined,
            title: 'No matching tasks',
            text: 'Choose another filter, or pull down to refresh.',
          ),
        for (final task in filtered) _taskCard(task),
      ],
    );
  }

  bool _isBatchTask(_RiderTask task) =>
      task.assignment != null &&
      (_batchedDeliveryIds.contains(task.assignment!.id) ||
          _batches.any(
            (batch) => _rows(
              batch['items'],
            ).any((item) => _id(item['delivery_id']) == task.assignment!.id),
          ));

  List<Widget> _batchCards() {
    final query = _taskSearch.trim().toLowerCase();
    final shown = _batches.where((batch) {
      if (_tab == 1 && _taskFilter != 'all' && _taskFilter != batch['type']) {
        return false;
      }
      return query.isEmpty ||
          '${batch['code']} ${batch['type']} ${batch['items']}'
              .toLowerCase()
              .contains(query);
    }).toList();
    return [
      const SizedBox(height: 12),
      if (shown.isNotEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Assigned routes',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      for (final batch in shown)
        RiderBatchCard(batch: batch, onTap: () => _openBatch(batch)),
      if (_batches.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No assigned routes. New branch assignments appear here.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      if (_batchMore)
        TextButton(
          onPressed: _requestFuture != null
              ? null
              : () {
                  _batchPages++;
                  _load(showLoader: false);
                },
          child: const Text('Load more routes'),
        ),
    ];
  }

  Future<void> _routeDeliveryAction(int id, String action) async {
    await _load(showLoader: false);
    if (!mounted || action == 'refresh') return;
    final assignment = _assignments.where((a) => a.id == id).firstOrNull;
    if (assignment == null) {
      _message(
        'This delivery is no longer assigned to you. Refresh the route.',
        isError: true,
      );
      return;
    }
    if (action == 'complete' && assignment.canCompleteDelivery) {
      await _complete(assignment);
    } else if (action == 'problem' && assignment.canFailDelivery) {
      await _fail(assignment);
    } else {
      _message(
        'The parcel status changed. Review the updated delivery step.',
        isError: true,
      );
    }
  }

  Future<void> _openBatch(Map<String, dynamic> batch) async {
    if (_token == null) return;
    final action = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RiderBatchDetailScreen(
          token: _token!,
          initial: batch,
          onDeliveryAction: _routeDeliveryAction,
        ),
      ),
    );
    if (!mounted) return;
    await _load(showLoader: false);
    if (!mounted) return;
    if (action == 'scan') {
      setState(() => _tab = 2);
      return;
    }
    if (action?.startsWith('parcel:') == true) {
      final id = int.tryParse(action!.substring(7));
      final task = _todayTasks.where((t) => t.assignment?.id == id).firstOrNull;
      if (task != null) {
        await _showTaskDetails(task);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parcel status changed. Refresh this route.'),
          ),
        );
      }
    }
  }

  Widget _taskModeSwitch() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _tasksCompleted ? 'Completed / history' : 'Active tasks',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
      ),
      const SizedBox(height: 10),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Active')),
          ButtonSegment(value: true, label: Text('History')),
        ],
        selected: {_tasksCompleted},
        onSelectionChanged: (values) =>
            setState(() => _tasksCompleted = values.first),
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11)),
        ),
      ),
    ],
  );

  Widget _historyInline() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_deliveryHistory.isEmpty &&
          _completedReturns.isEmpty &&
          _completedTransfers.isEmpty)
        _empty(
          icon: Icons.history_toggle_off_rounded,
          title: 'No completed records',
          text:
              'Your completed pickup, delivery and return records appear here.',
        ),
      if (_deliveryHistory.isNotEmpty) ...[
        _sectionHeader(title: 'Pickup & delivery'),
        const SizedBox(height: 8),
        ..._deliveryHistory.map(_assignmentHistoryRow),
        const SizedBox(height: 14),
      ],
      if (_completedTransfers.isNotEmpty) ...[
        _sectionHeader(title: 'Transfers'),
        const SizedBox(height: 8),
        ..._completedTransfers.map(
          (row) => _historyRow(
            icon: Icons.transfer_within_a_station_outlined,
            title: row['tracking_code']?.toString() ?? 'Transfer',
            subtitle:
                '${row['from'] ?? 'Origin'} → ${row['to'] ?? 'Destination'}',
            status: 'Received',
          ),
        ),
        const SizedBox(height: 14),
      ],
      if (_completedReturns.isNotEmpty) ...[
        _sectionHeader(title: 'Returns'),
        const SizedBox(height: 8),
        ..._completedReturns.map(
          (row) => _historyRow(
            icon: Icons.assignment_return_outlined,
            title:
                row['tracking_code']?.toString() ??
                'Order #${row['order_id'] ?? '-'}',
            subtitle:
                '${row['branch'] ?? 'Branch'} → ${row['seller'] ?? 'Seller'}',
            status: 'Seller received',
          ),
        ),
      ],
    ],
  );

  Widget _todayHeader(int taskCount) {
    final branch = _sortingCenterName?.trim().isNotEmpty == true
        ? _sortingCenterName!.trim()
        : _logisticsCenter;

    return ShopHopRoleIntro(
      title: '$_greeting, $_name',
      subtitle: [
        branch,
        if (_operationalAreaSummary.isNotEmpty)
          _operationalAreaSummary
        else if (_coverageArea?.trim().isNotEmpty == true)
          _coverageArea!.trim(),
      ].join(' / '),
      icon: Icons.two_wheeler_outlined,
      badge: '$taskCount assigned task${taskCount == 1 ? '' : 's'} remaining',
    );
  }

  Widget _codAlert() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _tab = 3),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF3D8A5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.payments_outlined, color: Color(0xFF8A5B12)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₱${_codOutstanding.toStringAsFixed(2)} COD awaiting verified receipt',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_codToRemit.length} collection${_codToRemit.length == 1 ? '' : 's'} awaiting Logistics handover.',
                    style: TextStyle(
                      color: AppColors.navy.withValues(alpha: 0.58),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A5B12)),
          ],
        ),
      ),
    );
  }

  Widget _taskFilterChip(String label, String value, int count) {
    final selected = _taskFilter == value;
    return ChoiceChip(
      label: Text('$label $count'),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.navy,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppColors.navy : AppColors.grayBorder),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.navy,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) => setState(() => _taskFilter = value),
    );
  }

  Widget _taskCard(_RiderTask task, {bool emphasized = false}) {
    final busy = _isTaskBusy(task);
    final color = _taskColor(task.kind);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: emphasized ? AppColors.tealDark : AppColors.grayBorder,
          width: emphasized ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_taskIcon(task.kind), size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                _statusPill(task.status),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              task.trackingCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  Icons.route_outlined,
                  size: 15,
                  color: Color(0xFF6B6B7B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${task.from} → ${task.to}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B6B7B),
                    ),
                  ),
                ),
              ],
            ),
            if (emphasized) ...[
              const SizedBox(height: 10),
              Text(
                task.nextStep,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              if (busy)
                const LinearProgressIndicator(minHeight: 3)
              else
                _taskActions(task),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: busy ? null : () => _showTaskDetails(task),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Details & actions'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isTaskBusy(_RiderTask task) {
    if (task.assignment != null) {
      return _busyDeliveryId == task.assignment!.id;
    }
    final id = _id(task.raw?['id']);
    if (task.kind == _RiderTaskKind.transfer) return false;
    if (task.kind == _RiderTaskKind.returnTask) return _busyReturnId == id;
    return false;
  }

  Widget _taskActions(_RiderTask task) {
    final assignment = task.assignment;
    if (assignment != null) {
      if (assignment.canAcceptPickup || assignment.canConfirmPickup) {
        return _primaryAction(
          label: 'Scan waybill at Seller',
          icon: Icons.qr_code_scanner_rounded,
          onPressed: () => setState(() => _tab = 2),
        );
      }
      if (assignment.canStartDelivery) {
        return _primaryAction(
          label: 'Scan parcel at branch',
          icon: Icons.qr_code_scanner_rounded,
          dark: true,
          onPressed: () => setState(() => _tab = 2),
        );
      }
      if (assignment.canCompleteDelivery || assignment.canFailDelivery) {
        return Row(
          children: [
            if (assignment.canCompleteDelivery)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _complete(assignment),
                  icon: const Icon(Icons.task_alt_rounded, size: 18),
                  label: const Text('Delivered'),
                ),
              ),
            if (assignment.canCompleteDelivery && assignment.canFailDelivery)
              const SizedBox(width: 8),
            if (assignment.canFailDelivery)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _fail(assignment),
                  icon: const Icon(Icons.report_outlined, size: 18),
                  label: const Text('Failed'),
                ),
              ),
          ],
        );
      }
      if (assignment.status == 'picked_up') {
        return _passiveAction(
          Icons.warehouse_outlined,
          'No app action yet — the branch receives and scans the parcel next.',
        );
      }
      return _passiveAction(
        Icons.info_outline_rounded,
        'No Rider action is available for this parcel right now.',
      );
    }

    final raw = task.raw ?? const <String, dynamic>{};
    if (task.kind == _RiderTaskKind.returnTask) {
      final status = raw['status']?.toString().toLowerCase() ?? '';
      if (status == 'assigned') {
        return _primaryAction(
          label: 'Confirm branch pickup',
          icon: Icons.inventory_2_outlined,
          onPressed: () => _collectReturn(raw),
        );
      }
      if (status == 'in_transit') {
        return _primaryAction(
          label: 'Submit Seller handover proof',
          icon: Icons.add_a_photo_outlined,
          onPressed: () => _handoverReturn(raw),
        );
      }
      if (status == 'awaiting_seller') {
        return _passiveAction(
          Icons.hourglass_top_rounded,
          'Waiting for Seller receipt confirmation.',
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _primaryAction({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool dark = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: dark ? AppColors.navy : AppColors.tealDark,
        ),
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }

  Widget _passiveAction(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.navy.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.navy.withValues(alpha: 0.58),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _routeLine(String from, String to, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.radio_button_checked, size: 16, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                from,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 7),
          child: Row(
            children: [
              Container(width: 1.5, height: 17, color: AppColors.grayBorder),
            ],
          ),
        ),
        Row(
          children: [
            Icon(Icons.location_on_rounded, size: 16, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                to,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _walletPage() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
      children: [
        const Text(
          'Wallet',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'COD company cash and your Rider payout ledger are kept separate.',
          style: TextStyle(
            color: AppColors.navy.withValues(alpha: 0.55),
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: true,
              label: Text('COD cash'),
              icon: Icon(Icons.payments_outlined),
            ),
            ButtonSegment(
              value: false,
              label: Text('My earnings'),
              icon: Icon(Icons.account_balance_wallet_outlined),
            ),
          ],
          selected: {_walletCod},
          onSelectionChanged: (values) =>
              setState(() => _walletCod = values.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 16),
        if (_walletCod) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Text(
                        'COD awaiting verified receipt',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '₱${_codOutstanding.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cash handover remains outstanding until the branch verifies receipt.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Buyer → Rider → Branch → Logistics → ShopHop',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _sectionHeader(
            title: 'COD collections',
            subtitle:
                'Choose the receiving branch when handing over cash. Receipt remains pending until verified.',
          ),
          const SizedBox(height: 10),
          if (_codCollections.isEmpty)
            _empty(
              icon: Icons.payments_outlined,
              title: 'No COD collections yet',
              text: 'COD records appear here after successful cash deliveries.',
            )
          else
            ..._codCollections.map(_codCollectionCard),
        ] else ...[
          _sectionHeader(
            title: 'My earnings',
            subtitle:
                'Compensation recorded and paid by your Logistics Partner.',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _moneySummary(
                  'Pending',
                  _pendingEarnings,
                  Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _moneySummary(
                  'Available',
                  _availableEarnings,
                  Icons.account_balance_wallet_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _moneySummary(
                  'Paid',
                  _paidEarnings,
                  Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 12),
          _notice(
            'Your Logistics Partner pays these earnings separately. Earnings never reduce collected COD or depend on Seller settlement.',
            Icons.info_outline_rounded,
          ),
          const SizedBox(height: 12),
          if (_earnings.isEmpty)
            _empty(
              icon: Icons.receipt_long_outlined,
              title: 'No Rider fee records yet',
              text: 'Eligible fees appear after the required logistics events.',
            )
          else
            ..._earnings.map(_earningRow),
        ],
      ],
    );
  }

  Widget _codCollectionCard(Map<String, dynamic> cash) {
    final id = _id(cash['delivery_id']);
    final canRemit = cash['can_remit'] == true;
    final busy = id != null && _busyCodDeliveryId == id;
    final status = RiderCodOverview.receiptStatus(cash);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order #${cash['order_id'] ?? '-'}',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _statusPill(status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₱${_number(cash['amount']).toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (RiderCodOverview.caseDescription(cash) != null) ...[
            const SizedBox(height: 8),
            Text(
              RiderCodOverview.caseDescription(cash)!,
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (cash['platform_receipt_status'] != null) ...[
            const SizedBox(height: 8),
            Text(
              RiderCodOverview.platformReceiptDescription(cash),
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (canRemit) ...[
            const SizedBox(height: 12),
            if (busy)
              const LinearProgressIndicator(minHeight: 3)
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _remitCod(cash),
                  icon: const Icon(Icons.account_balance_outlined, size: 18),
                  label: const Text('Hand over COD to branch'),
                ),
              ),
          ],
          if (cash['remitted_at'] != null ||
              cash['status'] == 'remitted' ||
              cash['status'] == 'reconciled') ...[
            const SizedBox(height: 8),
            Text(
              RiderCodOverview.receiverDescription(cash),
              style: const TextStyle(fontSize: 12),
            ),
            if (status == 'Awaiting verification')
              const Text(
                'Handover recorded. The receiving staff must still count and confirm the cash.',
                style: TextStyle(fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }

  Widget _moneySummary(String label, double amount, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.tealDark, size: 21),
          const SizedBox(height: 10),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppColors.navy.withValues(alpha: 0.56),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _earningRow(Map<String, dynamic> row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.tealDark,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${row['order_id'] ?? '-'} · ${_humanize(row['kind']?.toString() ?? 'Rider fee')}',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _humanize(row['status']?.toString() ?? 'Pending'),
                  style: TextStyle(
                    color: AppColors.navy.withValues(alpha: 0.5),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₱${_number(row['amount']).toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _assignmentHistoryRow(RiderAssignment assignment) {
    final pickup = assignment.assignmentType == 'pickup';
    final seller = assignment.sellerBusinessName.trim().isNotEmpty
        ? assignment.sellerBusinessName.trim()
        : assignment.sellerName.trim();
    final route = pickup
        ? '${seller.isEmpty ? 'Seller' : seller} → ${assignment.pickupDropoffCenter?.name ?? assignment.originSortingCenter?.name ?? 'Branch'}'
        : '${assignment.deliveryPickupCenter?.name ?? assignment.destinationSortingCenter?.name ?? 'Branch'} → ${assignment.deliveryName.trim().isEmpty ? 'Buyer' : assignment.deliveryName.trim()}';

    return _historyRow(
      icon: pickup ? Icons.storefront_outlined : Icons.home_outlined,
      title: assignment.trackingCode.isEmpty
          ? 'Order #${assignment.orderId}'
          : assignment.trackingCode,
      subtitle: route,
      status: assignment.statusLabel,
    );
  }

  Widget _historyRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.tealDark, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.navy.withValues(alpha: 0.52),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              status,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.tealDark,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountPage() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
      children: [
        const Text(
          'Account',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.grayBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.two_wheeler_rounded,
                  size: 29,
                  color: AppColors.tealDark,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _logisticsCenter,
                      style: TextStyle(
                        color: AppColors.navy.withValues(alpha: 0.52),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '● Active Rider',
                      style: TextStyle(
                        color: AppColors.tealDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _branchSummary(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RiderApplicationStatusScreen(),
              ),
            );
            if (mounted) await _load(showLoader: false);
          },
          icon: const Icon(Icons.assignment_ind_outlined),
          label: const Text('Availability, schedules & rider status'),
        ),
        if (_operationalAreaSummary.isNotEmpty) ...[
          const SizedBox(height: 12),
          _accountInfoCard(
            Icons.delivery_dining_outlined,
            'Assigned pickup / delivery service areas',
            _operationalAreaSummary,
          ),
        ] else if (_operationalAreaMode == 'configured') ...[
          const SizedBox(height: 12),
          _accountInfoCard(
            Icons.warning_amber_rounded,
            'Rider barangay assignment required',
            'No operational barangays assigned. Contact your branch manager.',
          ),
        ] else if (_coverageArea?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          _accountInfoCard(
            Icons.map_outlined,
            'Coverage area',
            _coverageArea!.trim(),
          ),
        ],
        const SizedBox(height: 18),
        _notice(
          'Assignments and operational permissions are controlled by your Logistics branch in the web system.',
          Icons.admin_panel_settings_outlined,
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showShopHopConfirmation(
                context,
                title: 'Sign out of Rider portal?',
                message: 'You can sign in again to view assigned tasks.',
                confirmLabel: 'Sign out',
              );
              if (confirmed) await _logout();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ),
      ],
    );
  }

  Widget _accountInfoCard(IconData icon, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.tealDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.navy.withValues(alpha: 0.48),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskSheetAction(
    String label,
    IconData icon,
    VoidCallback action,
    BuildContext sheetContext,
  ) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: () {
        Navigator.pop(sheetContext);
        action();
      },
      icon: Icon(icon, size: 18),
      label: Text(label),
    ),
  );

  Future<void> _showTaskDetails(_RiderTask task) async {
    final assignment = task.assignment;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                task.trackingCode,
                style: TextStyle(
                  color: AppColors.navy.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              _routeLine(task.from, task.to, _taskColor(task.kind)),
              const SizedBox(height: 14),
              _notice(task.nextStep, Icons.arrow_forward_rounded),
              if (assignment != null) ...[
                const SizedBox(height: 16),
                if (task.kind == _RiderTaskKind.pickup) ...[
                  _detailLine(
                    'Seller',
                    assignment.sellerBusinessName.isNotEmpty
                        ? assignment.sellerBusinessName
                        : assignment.sellerName,
                  ),
                  _detailLine('Contact', assignment.sellerContact),
                  _detailLine('Address', assignment.sellerAddress),
                ] else ...[
                  _detailLine('Buyer', assignment.deliveryName),
                  _detailLine('Contact', assignment.deliveryPhone),
                  _detailLine('Address', assignment.deliveryAddress),
                ],
                _detailLine(
                  'Items',
                  assignment.items.isEmpty
                      ? 'No item details available'
                      : assignment.items
                            .map((item) => '${item.quantity}× ${item.name}')
                            .join(' · '),
                ),
                if (assignment.isCod)
                  _detailLine('COD amount', '₱${assignment.totalAmount}'),
                if (assignment.failureReason?.trim().isNotEmpty == true)
                  _detailLine('Failure reason', assignment.failureReason!),
              ],
              if (task.raw?['reason']?.toString().trim().isNotEmpty ==
                  true) ...[
                const SizedBox(height: 12),
                _detailLine('Return reason', task.raw!['reason'].toString()),
              ],
              const SizedBox(height: 12),
              if (assignment != null &&
                  (assignment.canAcceptPickup ||
                      assignment.canConfirmPickup ||
                      assignment.canStartDelivery))
                _taskSheetAction(
                  'Open QR scanner',
                  Icons.qr_code_scanner_rounded,
                  () => setState(() => _tab = 2),
                  sheetContext,
                ),
              if (assignment != null && assignment.canCompleteDelivery)
                _taskSheetAction(
                  'Complete delivery',
                  Icons.task_alt_rounded,
                  () => _complete(assignment),
                  sheetContext,
                ),
              if (assignment != null && assignment.canFailDelivery)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _fail(assignment);
                    },
                    icon: const Icon(Icons.report_outlined),
                    label: const Text('Report delivery problem'),
                  ),
                ),
              if (task.kind == _RiderTaskKind.returnTask &&
                  task.raw?['status'] == 'assigned')
                _taskSheetAction(
                  'Confirm branch pickup',
                  Icons.inventory_2_outlined,
                  () => _collectReturn(task.raw!),
                  sheetContext,
                ),
              if (task.kind == _RiderTaskKind.returnTask &&
                  task.raw?['status'] == 'in_transit')
                _taskSheetAction(
                  'Submit Seller handover proof',
                  Icons.add_a_photo_outlined,
                  () => _handoverReturn(task.raw!),
                  sheetContext,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.navy.withValues(alpha: 0.48),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({required String title, String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.navy.withValues(alpha: 0.5),
              fontSize: 10.5,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  IconData _taskIcon(_RiderTaskKind kind) {
    switch (kind) {
      case _RiderTaskKind.pickup:
        return Icons.storefront_outlined;
      case _RiderTaskKind.transfer:
        return Icons.swap_horiz_rounded;
      case _RiderTaskKind.delivery:
        return Icons.local_shipping_outlined;
      case _RiderTaskKind.returnTask:
        return Icons.assignment_return_outlined;
    }
  }

  Color _taskColor(_RiderTaskKind kind) {
    switch (kind) {
      case _RiderTaskKind.pickup:
        return const Color(0xFF166534);
      case _RiderTaskKind.transfer:
        return const Color(0xFF2F6FA7);
      case _RiderTaskKind.delivery:
        return const Color(0xFF7657A8);
      case _RiderTaskKind.returnTask:
        return const Color(0xFF9A5C18);
    }
  }

  Widget _statusPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 105),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _loadErrorPage() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 64, 20, 100),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.grayBorder),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.sync_problem_rounded,
                    size: 44,
                    color: AppColors.tealDark,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Rider account could not load',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error ?? 'Please try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.navy.withValues(alpha: 0.56),
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => _load(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _notice(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.tealDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.tealDark, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy.withValues(alpha: 0.53),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchSummary() {
    final name = _sortingCenterName?.trim();
    final code = _sortingCenterCode?.trim();
    final address = _sortingCenterAddress?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_outlined, color: AppColors.tealDark, size: 20),
              SizedBox(width: 8),
              Text(
                'Assigned branch / hub',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (name == null || name.isEmpty)
            Text(
              'Center information will appear after Logistics assignment.',
              style: TextStyle(
                color: AppColors.navy.withValues(alpha: 0.55),
                fontSize: 11,
              ),
            )
          else ...[
            Text(
              name,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (code != null && code.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                code,
                style: const TextStyle(
                  color: AppColors.tealDark,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (address != null && address.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                address,
                style: TextStyle(
                  color: AppColors.navy.withValues(alpha: 0.55),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
