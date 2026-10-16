import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';
import 'package:shophop/features/rider/data/models/rider_assignment.dart';
import 'package:shophop/features/rider/data/services/rider_delivery_service.dart';
import 'package:shophop/features/rider/presentation/screens/rider_transit_earnings_screen.dart';
import 'package:shophop/features/rider/presentation/screens/rider_cod_remittance_screen.dart';
import 'package:shophop/features/rider/presentation/screens/rider_returns_screen.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';

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
  String _taskFilter = 'all';
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
      final session = await AuthSessionService.readSession().timeout(const Duration(seconds: 8));
      if (!mounted) return;

      if (session == null || session.accountType != 'rider') {
        await _leaveSession();
        return;
      }

      _token = session.token;

      final me = await AuthService.me(token: session.token).timeout(const Duration(seconds: 15));
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
              .map((value) => RiderAssignment.fromJson(Map<String, dynamic>.from(value)))
              .where((assignment) => assignment.id > 0)
              .toList()
          : <RiderAssignment>[];

      setState(() {
        if (result.success) {
          _assignments
            ..clear()
            ..addAll(assignments);
        }
        _error = result.success ? null : result.message;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = 'ShopHop took too long to respond. Make sure Laravel is running, then retry.';
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
    final picked = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
    );
    if (!mounted || picked == null || picked.files.isEmpty) return;

    if (assignment.isCod) {
      final confirmed = await _confirmAction(
        title: 'Confirm COD collection',
        message:
            'Confirm that you collected ₱${assignment.totalAmount} from the customer before marking this parcel delivered.',
        confirmLabel: 'Cash collected',
      );
      if (!confirmed) return;
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.tealDark),
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

  List<RiderAssignment> get _tasks => _assignments.where((assignment) => assignment.isTask).toList();

  List<RiderAssignment> get _history =>
      _assignments.where((assignment) => !assignment.isTask).toList();

  int get _pickupCount => _tasks.where((item) => item.assignmentType == 'pickup').length;
  int get _deliveryCount => _tasks.where((item) => item.assignmentType != 'pickup').length;
  int get _codCount => _tasks.where((item) => item.isCod).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grayBg,
      appBar: AppBar(
        backgroundColor: AppColors.tealDark,
        surfaceTintColor: AppColors.tealDark,
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 28, height: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'ShopHop Rider',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'COD Cash Handover',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const RiderCodRemittanceScreen(),
            )),
            icon: const Icon(Icons.payments_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Transit & Rider Earnings',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const RiderTransitEarningsScreen(),
            )),
            icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
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
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 72,
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: Colors.transparent,
          iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
            return IconThemeData(
              size: 23,
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFF087968)
                  : const Color(0xFF526177),
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? const Color(0xFF087968)
                  : const Color(0xFF526177),
            );
          }),
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.delivery_dining_outlined),
              selectedIcon: Icon(
                Icons.delivery_dining_rounded,
                color: Color(0xFF087968),
              ),
              label: 'Tasks',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              selectedIcon: Icon(
                Icons.history_rounded,
                color: Color(0xFF087968),
              ),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(
                Icons.person_rounded,
                color: Color(0xFF087968),
              ),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskPage() {
    final tasks = _tasks.where((assignment) {
      if (_taskFilter == 'pickup') return assignment.assignmentType == 'pickup';
      if (_taskFilter == 'delivery') return assignment.assignmentType != 'pickup';
      return true;
    }).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _welcomeCard(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _notice(_error!, Icons.wifi_off_rounded),
        ],
        const SizedBox(height: 14),
        _summaryCards(),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.assignment_return_outlined, color: AppColors.tealDark),
            title: const Text('Return-to-Seller Tasks', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Branch pickup → Seller handover proof'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const RiderReturnsScreen(),
            )),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Current assignments',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${tasks.length} active',
              style: const TextStyle(
                color: AppColors.tealDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Accept, confirm, and complete operational tasks with cleaner action flows.',
          style: TextStyle(
            color: AppColors.navy.withValues(alpha: 0.55),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _taskFilterChip('All tasks', 'all', _tasks.length),
            const SizedBox(width: 8),
            _taskFilterChip('Seller pickups', 'pickup', _pickupCount),
            const SizedBox(width: 8),
            _taskFilterChip('Buyer deliveries', 'delivery', _deliveryCount),
          ]),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: const Color(0xFFE8F7F3),
          child: ListTile(
            leading: const Icon(Icons.swap_horiz_rounded, color: AppColors.tealDark),
            title: const Text('Branch transfers & Rider earnings',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            subtitle: const Text('Transit assignments and manual payout records',
              style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const RiderTransitEarningsScreen(),
            )),
          ),
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          _empty(
            icon: Icons.task_alt_rounded,
            title: 'No active Rider tasks',
            text:
                _tasks.isEmpty
                    ? 'Pickup and delivery assignments from your Logistics branch will appear here.'
                    : 'No ${_taskFilter == 'pickup' ? 'pickup' : 'delivery'} tasks right now. Try All tasks.',
          )
        else
          ...tasks.map(_assignmentCard),
      ],
    );
  }

  Widget _taskFilterChip(String label, String value, int count) => FilterChip(
    label: Text('$label ($count)', style: const TextStyle(fontSize: 12)),
    selected: _taskFilter == value,
    selectedColor: const Color(0xFFDCF5EE),
    checkmarkColor: AppColors.tealDark,
    onSelected: (_) => setState(() => _taskFilter = value),
  );

  String _nextStep(RiderAssignment assignment) {
    if (assignment.canAcceptPickup) return 'Next: Accept the Seller pickup';
    if (assignment.canConfirmPickup) return 'Next: Collect the parcel, then confirm pickup';
    if (assignment.status == 'picked_up') return 'Next: Deliver the parcel to the assigned origin branch';
    if (assignment.canStartDelivery) return 'Next: Collect from the branch, then start delivery';
    if (assignment.canCompleteDelivery) return 'Next: Deliver to Buyer and upload proof';
    if (assignment.canFailDelivery) return 'Attempt delivery or record a valid failure reason';
    return 'Check status and delivery instructions';
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
          'Completed pickups, delivered parcels, failed attempts, and returned orders.',
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
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
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.two_wheeler_rounded,
                  size: 34,
                  color: AppColors.tealDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _name,
                textAlign: TextAlign.center,
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
              const SizedBox(height: 16),
              _branchSummary(),
              if (_coverageArea != null && _coverageArea!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Delivery area: $_coverageArea',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
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

  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    const SizedBox(height: 4),
                    Text(
                      _sortingCenterName?.trim().isNotEmpty == true
                          ? '$_logisticsCenter · $_sortingCenterName'
                          : _logisticsCenter,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
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
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.route_rounded, color: AppColors.teal, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _headerInfoChip(Icons.pin_drop_outlined, _sortingCenterCode ?? 'No center code'),
              _headerInfoChip(Icons.map_outlined, _coverageArea ?? 'Coverage pending'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCards() {
    return Row(
      children: [
        Expanded(child: _statCard('Pickups', _pickupCount.toString(), Icons.inventory_2_outlined)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Deliveries', _deliveryCount.toString(), Icons.local_shipping_outlined)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('COD', _codCount.toString(), Icons.payments_outlined)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppColors.tealDark),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppColors.navy.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  pickup ? Icons.storefront_outlined : Icons.home_outlined,
                  color: AppColors.tealDark,
                  size: 22,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _statusChip(assignment.statusLabel),
                        if (assignment.isCod) _statusChip('COD'),
                        _statusChip(pickup ? 'Pickup' : 'Delivery'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _detailRow(Icons.person_outline_rounded, person),
          if (destination.isNotEmpty) _detailRow(Icons.location_on_outlined, destination),
          if (contact.isNotEmpty) _detailRow(Icons.phone_outlined, contact),
          _detailRow(
            Icons.shopping_bag_outlined,
            assignment.items.isEmpty
                ? 'No item details available yet'
                : assignment.items.map((item) => '${item.quantity}× ${item.name}').join(' · '),
          ),
          if (assignment.destinationArea != null && assignment.destinationArea!.isNotEmpty)
            _detailRow(Icons.map_outlined, 'Delivery area: ${assignment.destinationArea}'),
          if (assignment.isTask) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.arrow_forward_rounded, color: AppColors.tealDark, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_nextStep(assignment),
                  style: const TextStyle(color: AppColors.navy, fontSize: 12, fontWeight: FontWeight.w700))),
              ]),
            ),
          ],
          if (assignment.status == 'picked_up') ...[
            const SizedBox(height: 10),
            _notice(_pickupHandoffMessage(assignment), Icons.warehouse_outlined),
          ],
          if (assignment.failureReason != null && assignment.failureReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _notice('Failure reason: ${assignment.failureReason}', Icons.error_outline_rounded),
          ],
          if (assignment.deliveryAttempts > 0) ...[
            const SizedBox(height: 10),
            _notice(
              'Delivery attempts: ${assignment.deliveryAttempts}',
              Icons.info_outline_rounded,
            ),
          ],
          if (assignment.canAcceptPickup ||
              assignment.canConfirmPickup ||
              assignment.canStartDelivery ||
              assignment.canCompleteDelivery ||
              assignment.canFailDelivery) ...[
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
                      onPressed: () async {
                        final confirmed = await _confirmAction(
                          title: 'Accept pickup?',
                          message: 'You are about to accept this pickup assignment.',
                          confirmLabel: 'Accept',
                        );
                        if (!confirmed) return;
                        await _runAction(
                          assignment,
                          (token) => RiderDeliveryService.acceptPickup(
                            token: token,
                            deliveryId: assignment.id,
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(backgroundColor: AppColors.tealDark),
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text('Accept pickup'),
                    ),
                  if (assignment.canConfirmPickup)
                    FilledButton.icon(
                      onPressed: () async {
                        final confirmed = await _confirmAction(
                          title: 'Confirm pickup?',
                          message: 'Confirm that the parcel has been collected from the seller.',
                          confirmLabel: 'Confirm',
                        );
                        if (!confirmed) return;
                        await _runAction(
                          assignment,
                          (token) => RiderDeliveryService.confirmPickup(
                            token: token,
                            deliveryId: assignment.id,
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(backgroundColor: AppColors.tealDark),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 17),
                      label: const Text('Confirm pickup'),
                    ),
                  if (assignment.canStartDelivery)
                    FilledButton.icon(
                      onPressed: () async {
                        final confirmed = await _confirmAction(
                          title: 'Mark out for delivery?',
                          message: 'This parcel will be moved to the final delivery stage.',
                          confirmLabel: 'Proceed',
                        );
                        if (!confirmed) return;
                        await _runAction(
                          assignment,
                          (token) => RiderDeliveryService.outForDelivery(
                            token: token,
                            deliveryId: assignment.id,
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
                      icon: const Icon(Icons.route_rounded, size: 17),
                      label: const Text('Out for delivery'),
                    ),
                  if (assignment.canCompleteDelivery)
                    FilledButton.icon(
                      onPressed: () => _complete(assignment),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.tealDark),
                      icon: const Icon(Icons.task_alt_rounded, size: 17),
                      label: const Text('Delivered'),
                    ),
                  if (assignment.canFailDelivery)
                    OutlinedButton.icon(
                      onPressed: () => _fail(assignment),
                      icon: const Icon(Icons.report_gmailerrorred_rounded, size: 17),
                      label: const Text('Failed'),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.tealDark,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 17, color: AppColors.navy.withValues(alpha: 0.55)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
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
                      color: AppColors.navy.withValues(alpha: 0.56),
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _load,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.tealDark),
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
        borderRadius: BorderRadius.circular(14),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.tealDark, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy.withValues(alpha: 0.55),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchSummary() {
    final rows = <String>[];
    if (_sortingCenterName != null && _sortingCenterName!.trim().isNotEmpty) {
      rows.add(_sortingCenterName!.trim());
    }
    if (_sortingCenterCode != null && _sortingCenterCode!.trim().isNotEmpty) {
      rows.add(_sortingCenterCode!.trim());
    }
    if (_sortingCenterAddress != null && _sortingCenterAddress!.trim().isNotEmpty) {
      rows.add(_sortingCenterAddress!.trim());
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assigned hub',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(
              'Center information will appear after admin assignment.',
              style: TextStyle(
                color: AppColors.navy.withValues(alpha: 0.55),
                fontSize: 11,
              ),
            )
          else
            ...rows.map(
              (value) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _pickupHandoffMessage(RiderAssignment assignment) {
    final center = assignment.pickupDropoffCenter ?? assignment.currentSortingCenter;
    if (center == null) {
      return 'Bring this parcel to your assigned sorting center for receiving and sorting.';
    }

    final code = center.code.trim().isEmpty ? '' : ' (${center.code.trim()})';
    return 'Bring this parcel to ${center.name}$code at ${center.address} for receiving and sorting.';
  }
}
