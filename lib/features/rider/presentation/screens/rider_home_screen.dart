import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:shophop/features/rider/data/models/rider_assignment.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/rider/data/services/rider_delivery_service.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  final List<RiderAssignment> _assignments = [];

  bool _loading = true;
  bool _profileLoaded = false;
  int? _busyDeliveryId;
  int _tab = 0;
  String? _error;
  String? _token;
  String _name = 'Rider';
  String _logisticsCenter = 'Logistics / Sorting Center';
  String? _sortingCenterName;
  String? _sortingCenterCode;
  String? _sortingCenterAddress;
  String? _coverageArea;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final session = await AuthSessionService.readSession()
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;

      if (session == null || session.accountType != 'rider') {
        await _leaveSession();
        return;
      }

      _token = session.token;

      final me = await AuthService.me(token: session.token)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;

      if (!me.success) {
        if (me.statusCode == 401) {
          await _leaveSession();
          return;
        }

        setState(() {
          _profileLoaded = false;
          _error = me.message;
        });
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
        _logisticsCenter = me.data['logistics_company']?.toString() ??
            me.data['logistics_center']?.toString() ??
            'Logistics / Sorting Center';
        _sortingCenterName = me.data['sorting_center_name']?.toString();
        _sortingCenterCode = me.data['sorting_center_code']?.toString();
        _sortingCenterAddress = me.data['sorting_center_address']?.toString();
        _coverageArea = me.data['coverage_area']?.toString();
        _profileLoaded = true;
      });

      final result = await RiderDeliveryService.assignments(token: session.token)
          .timeout(const Duration(seconds: 25));
      if (!mounted) return;

      final rawAssignments = result.data['assignments'];
      final assignments = rawAssignments is List
          ? rawAssignments
              .whereType<Map>()
              .map((value) =>
                  RiderAssignment.fromJson(Map<String, dynamic>.from(value)))
              .where((assignment) => assignment.id > 0)
              .toList()
          : <RiderAssignment>[];

      setState(() {
        _assignments
          ..clear()
          ..addAll(assignments);
        _error = result.success ? null : result.message;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error =
            'ShopHop took too long to respond. Make sure Laravel is running, then retry.';
      });
    } catch (error) {
      if (!mounted) return;
      final text = error.toString();
      setState(() {
        _error = text.contains('OperationError')
            ? 'The browser could not read the saved Rider session. Sign in again, then use a full restart instead of hot reload if the browser text-input error returns.'
            : 'Unable to load the Rider account. ${text.isEmpty ? 'Please try again.' : text}';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
    if (token != null) {
      await AuthService.logout(token: token);
    }
    await _leaveSession();
  }

  Future<void> _runAction(
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

    if (result.success) {
      await _load();
    }
  }

  Future<void> _complete(RiderAssignment assignment) async {
    final picked = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
    );
    if (!mounted || picked == null || picked.files.isEmpty) return;

    if (assignment.isCod) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm COD collection'),
          content: Text(
            'Confirm that you collected ₱${assignment.totalAmount} from the customer before marking this parcel delivered.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cash collected'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await _runAction(
      assignment,
      (token) => RiderDeliveryService.completeDelivery(
        token: token,
        deliveryId: assignment.id,
        proof: picked.files.single,
        cashCollected: assignment.isCod,
      ),
    );
  }

  Future<void> _fail(RiderAssignment assignment) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delivery failed'),
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
            child: const Text('Record failure'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || reason == null || reason.isEmpty) return;
    await _runAction(
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

  List<RiderAssignment> get _tasks =>
      _assignments.where((assignment) => assignment.isTask).toList();

  List<RiderAssignment> get _history =>
      _assignments.where((assignment) => !assignment.isTask).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grayBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 30, height: 30),
            const SizedBox(width: 8),
            const Text(
              'ShopHop Rider',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (!_profileLoaded && _error != null)
              ? _loadErrorPage()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      _taskPage(),
                      _historyPage(),
                      _accountPage(),
                    ],
                  ),
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.delivery_dining_outlined),
            selectedIcon: Icon(Icons.delivery_dining_rounded),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }

  Widget _taskPage() {
    final tasks = _tasks;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
      children: [
        _welcome(),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _notice(_error!, Icons.wifi_off_rounded),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Current assignments',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${tasks.length}',
              style: const TextStyle(
                color: AppColors.tealDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          _empty(
            icon: Icons.task_alt_rounded,
            title: 'No active Rider tasks',
            text:
                'Pickup and final-delivery assignments from your Logistics / Sorting Center will appear here.',
          )
        else
          ...tasks.map(_assignmentCard),
      ],
    );
  }

  Widget _historyPage() {
    final history = _history;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
      children: [
        const Text(
          'Assignment history',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Completed pickup handoffs, delivered parcels, failed attempts, and returned parcels.',
          style: TextStyle(
            color: AppColors.navy.withValues(alpha: 0.52),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        if (history.isEmpty)
          _empty(
            icon: Icons.history_toggle_off_rounded,
            title: 'No history yet',
            text: 'Your finished Rider activities will appear here.',
          )
        else
          ...history.map(_assignmentCard),
      ],
    );
  }

  Widget _accountPage() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.grayBorder),
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.tealLight,
                child: Icon(
                  Icons.delivery_dining_rounded,
                  size: 34,
                  color: AppColors.tealDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _name,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _logisticsCenter,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navy.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              _branchSummary(),
              if (_coverageArea != null && _coverageArea!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Chip(
                  avatar: const Icon(Icons.location_on_outlined, size: 16),
                  label: Text('Delivery area: $_coverageArea'),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _welcome() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $_name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _sortingCenterName?.trim().isNotEmpty == true
                      ? '$_logisticsCenter · $_sortingCenterName'
                      : _logisticsCenter,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.two_wheeler_rounded,
              color: AppColors.teal,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _assignmentCard(RiderAssignment assignment) {
    final busy = _busyDeliveryId == assignment.id;
    final pickup = assignment.assignmentType == 'pickup';
    final destination = pickup ? assignment.sellerAddress : assignment.deliveryAddress;
    final contact = pickup ? assignment.sellerContact : assignment.deliveryPhone;
    final person = pickup
        ? (assignment.sellerBusinessName.isNotEmpty
            ? assignment.sellerBusinessName
            : assignment.sellerName)
        : assignment.deliveryName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  pickup ? Icons.storefront_outlined : Icons.home_outlined,
                  color: AppColors.tealDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.trackingCode.isEmpty
                          ? 'Order #${assignment.orderId}'
                          : assignment.trackingCode,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      assignment.statusLabel,
                      style: const TextStyle(
                        color: AppColors.tealDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (assignment.isCod)
                const Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('COD', style: TextStyle(fontSize: 10)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _detail(Icons.person_outline_rounded, person),
          if (destination.isNotEmpty)
            _detail(Icons.location_on_outlined, destination),
          if (contact.isNotEmpty) _detail(Icons.phone_outlined, contact),
          const SizedBox(height: 4),
          _assignmentRoute(assignment),
          if (assignment.destinationArea != null &&
              assignment.destinationArea!.isNotEmpty)
            _detail(
              Icons.map_outlined,
              'Delivery area: ${assignment.destinationArea}',
            ),
          if (assignment.items.isNotEmpty) ...[
            const Divider(height: 22),
            Text(
              assignment.items
                  .map((item) => '${item.quantity}× ${item.name}')
                  .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.navy.withValues(alpha: 0.62),
                fontSize: 11,
              ),
            ),
          ],
          if (assignment.status == 'picked_up') ...[
            const SizedBox(height: 12),
            _notice(
              _pickupHandoffMessage(assignment),
              Icons.warehouse_outlined,
            ),
          ],
          if (assignment.failureReason != null &&
              assignment.failureReason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _notice(
              'Failure reason: ${assignment.failureReason}',
              Icons.error_outline_rounded,
            ),
          ],
          if (assignment.canAcceptPickup ||
              assignment.canConfirmPickup ||
              assignment.canStartDelivery ||
              assignment.canCompleteDelivery) ...[
            const SizedBox(height: 14),
            if (busy)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (assignment.canAcceptPickup)
                    FilledButton.icon(
                      onPressed: () => _runAction(
                        assignment,
                        (token) => RiderDeliveryService.acceptPickup(
                          token: token,
                          deliveryId: assignment.id,
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text('Accept pickup'),
                    ),
                  if (assignment.canConfirmPickup)
                    FilledButton.icon(
                      onPressed: () => _runAction(
                        assignment,
                        (token) => RiderDeliveryService.confirmPickup(
                          token: token,
                          deliveryId: assignment.id,
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 17),
                      label: const Text('Confirm pickup'),
                    ),
                  if (assignment.canStartDelivery)
                    FilledButton.icon(
                      onPressed: () => _runAction(
                        assignment,
                        (token) => RiderDeliveryService.outForDelivery(
                          token: token,
                          deliveryId: assignment.id,
                        ),
                      ),
                      icon: const Icon(Icons.route_rounded, size: 17),
                      label: const Text('Out for delivery'),
                    ),
                  if (assignment.canCompleteDelivery)
                    FilledButton.icon(
                      onPressed: () => _complete(assignment),
                      icon: const Icon(Icons.task_alt_rounded, size: 17),
                      label: const Text('Delivered'),
                    ),
                  if (assignment.canFailDelivery)
                    OutlinedButton.icon(
                      onPressed: () => _fail(assignment),
                      icon: const Icon(Icons.report_gmailerrorred_rounded,
                          size: 17),
                      label: const Text('Failed'),
                    ),
                ],
              ),
          ],
        ],
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
                borderRadius: BorderRadius.circular(22),
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
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error ?? 'Please try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.navy.withValues(alpha: 0.58),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _leaveSession,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign in again'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _branchSummary() {
    final center = _sortingCenterName?.trim();
    if (center == null || center.isEmpty) {
      return _notice(
        'No Sorting Center branch is assigned yet. Ask Logistics to assign your branch before accepting branch-based delivery work.',
        Icons.warehouse_outlined,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.tealLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warehouse_outlined,
                  size: 18, color: AppColors.tealDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  center,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_sortingCenterCode?.trim().isNotEmpty == true)
                Text(
                  _sortingCenterCode!,
                  style: const TextStyle(
                    color: AppColors.tealDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (_sortingCenterAddress?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              _sortingCenterAddress!,
              style: TextStyle(
                color: AppColors.navy.withValues(alpha: 0.58),
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _assignmentRoute(RiderAssignment assignment) {
    final pickup = assignment.assignmentType == 'pickup';
    final center = pickup
        ? assignment.pickupDropoffCenter
        : assignment.deliveryPickupCenter;

    if (center == null) {
      return const SizedBox.shrink();
    }

    final start = pickup
        ? (assignment.sellerBusinessName.isNotEmpty
            ? assignment.sellerBusinessName
            : 'Seller')
        : center.name;
    final end = pickup ? center.name : assignment.deliveryName;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.grayBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pickup ? 'Pickup route' : 'Final delivery route',
            style: const TextStyle(
              color: AppColors.tealDark,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$start  →  $end',
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (center.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              pickup
                  ? 'Drop off at: ${center.address}'
                  : 'Pick up parcel at: ${center.address}',
              style: TextStyle(
                color: AppColors.navy.withValues(alpha: 0.55),
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _pickupHandoffMessage(RiderAssignment assignment) {
    final center = assignment.pickupDropoffCenter;
    if (center == null) {
      return 'Parcel collected. Bring it to your assigned Sorting Center and wait for Logistics to scan the tracking code.';
    }

    final address = center.address.trim();
    return address.isEmpty
        ? 'Parcel collected. Bring it to ${center.name} and wait for Logistics to scan the tracking code.'
        : 'Parcel collected. Bring it to ${center.name}: $address. Logistics will scan the tracking code on arrival.';
  }

  Widget _detail(IconData icon, String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.navy.withValues(alpha: 0.4)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.navy.withValues(alpha: 0.68),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice(String text, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tealLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.tealDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 10.5,
                height: 1.45,
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppColors.tealDark),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy.withValues(alpha: 0.48),
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
