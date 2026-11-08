import 'package:shophop/shared/widgets/shop_hop_scanner.dart';
import 'package:shophop/shared/widgets/shop_hop_scan_feedback.dart';
import 'package:shophop/shared/widgets/shop_hop_role_layout.dart';
import 'package:shophop/shared/realtime/foreground_refresh.dart';
import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/shared/widgets/shop_hop_navigation.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';
import 'package:shophop/shared/widgets/shop_hop_workflow.dart';
import 'package:shophop/shared/widgets/shop_hop_ops.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';
import 'package:shophop/features/linehaul/data/linehaul_service.dart';

class LinehaulDriverHomeScreen extends StatefulWidget {
  const LinehaulDriverHomeScreen({super.key});
  @override
  State<LinehaulDriverHomeScreen> createState() =>
      _LinehaulDriverHomeScreenState();
}

class _LinehaulDriverHomeScreenState extends State<LinehaulDriverHomeScreen> {
  static const _navy = AppColors.navy;
  static const _teal = AppColors.tealDark;
  final _camera = MobileScannerController(autoStart: false);
  final _manifestCode = TextEditingController();
  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _earnings = [];
  double _pendingEarnings = 0, _availableEarnings = 0, _paidEarnings = 0;
  Map<String, dynamic>? _manifest;
  String? _token, _email, _message;
  final _reviewKey = GlobalKey();
  void _revealReview() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _reviewKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  final _scanScroll = ScrollController();
  void _showResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scanScroll.hasClients) return;
      _scanScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  bool _needsRecheck = false;
  bool _success = false, _busy = true, _scanning = false;
  int _tab = 0;
  late final ForegroundRefresh _liveRefresh;
  bool _initialLoading = true;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _load();
    _liveRefresh = ForegroundRefresh(
      refresh: () => _load(silent: true),
      interval: const Duration(seconds: 10),
      canRefresh: () =>
          mounted &&
          _requestFuture == null &&
          !_busy &&
          !_scanning &&
          _tab != 2 &&
          _manifest == null &&
          (ModalRoute.of(context)?.isCurrent ?? true),
    );
  }

  @override
  void dispose() {
    _scanScroll.dispose();
    _liveRefresh.dispose();
    _manifestCode.dispose();
    _camera.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : [];

  Future<void>? _requestFuture;

  Future<void> _load({bool silent = false}) {
    final pending = _requestFuture;
    if (pending != null) {
      if (silent) return pending;
      return pending.then(
        (_) => mounted ? _load(silent: silent) : Future<void>.value(),
      );
    }
    final request = _fetch(silent: silent).whenComplete(() {
      if (mounted) setState(() => _requestFuture = null);
    });
    _requestFuture = request;
    return request;
  }

  Future<void> _fetch({bool silent = false}) async {
    final session = await AuthSessionService.readSession();
    if (!mounted) return;
    if (session == null || session.accountType != 'linehaul_driver') {
      await _logout(localOnly: true);
      return;
    }
    setState(() {
      _token = session.token;
      _email = session.email;
      if (!silent) _busy = true;
    });
    final results = await Future.wait([
      LinehaulService.trips(session.token),
      LinehaulService.earnings(session.token),
    ]);
    if (!mounted) return;
    final r = results[0], e = results[1];
    if (r.statusCode == 401 ||
        r.statusCode == 403 ||
        e.statusCode == 401 ||
        e.statusCode == 403) {
      await _logout(localOnly: true);
      return;
    }
    setState(() {
      _busy = false;
      _initialLoading = false;
      if (r.success) _trips = _rows(r.data['trips']);
      if (e.success) {
        _earnings = _rows(e.data['entries']);
        _pendingEarnings = (e.data['pending'] as num?)?.toDouble() ?? 0;
        _availableEarnings = (e.data['available'] as num?)?.toDouble() ?? 0;
        _paidEarnings = (e.data['paid'] as num?)?.toDouble() ?? 0;
      }
      _syncError = r.success ? (e.success ? null : e.message) : r.message;
    });
  }

  Future<void> _logout({bool localOnly = false}) async {
    try {
      await _camera.stop();
    } catch (_) {}
    if (!localOnly && _token != null) await AuthService.logout(token: _token!);
    await AuthSessionService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _startScan() async {
    if (_busy) return;
    setState(() {
      _scanning = true;
      _success = false;
      _needsRecheck = false;
      _manifest = null;
      _message = null;
    });
    try {
      await _camera.start();
    } catch (_) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _message =
              'Camera unavailable. Grant camera permission and try again.';
        });
      }
    }
  }

  Future<void> _scan(String code) async {
    if (_busy || _token == null || code.trim().isEmpty) return;
    _manifestCode.text = code.trim().toUpperCase();
    setState(() {
      _busy = true;
      _scanning = false;
      _manifest = null;
      _message = null;
    });
    try {
      await _camera.stop();
    } catch (_) {}
    final r = await LinehaulService.preview(
      token: _token!,
      manifestCode: _manifestCode.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _needsRecheck = false;
      _manifest = r.success && r.data['manifest'] is Map
          ? Map<String, dynamic>.from(r.data['manifest'] as Map)
          : null;
      _message = r.success ? null : r.message;
      _success = false;
    });
    if (_manifest != null) _revealReview();
    ShopHopScanFeedback.instance.notify(
      _manifest != null ? ScanFeedbackEvent.verified : ScanFeedbackEvent.error,
      reference: _manifestCode.text,
    );
  }

  Future<void> _confirm() async {
    final m = _manifest;
    if (m == null || _token == null || _busy || _needsRecheck) return;
    final action = m['action']?.toString() ?? 'none';
    if (action != 'depart') return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Accept load & depart?'),
        content: Text(
          'Confirm only after manifest ${m['manifest_code']} is physically loaded in ${m['vehicle_code']} (${m['plate_number']}). The destination Branch/Hub will confirm arrival by scanning this Manifest QR.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Accept & depart'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await LinehaulService.confirm(
      token: _token!,
      manifestCode: m['manifest_code'].toString(),
      action: 'depart',
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _manifest = r.success ? null : m;
      _needsRecheck = !r.success;
      _message = r.message;
      _success = r.success;
    });
    ShopHopScanFeedback.instance.notify(
      r.success ? ScanFeedbackEvent.complete : ScanFeedbackEvent.error,
      reference: m['manifest_code']?.toString(),
    );
    _showResult();
    await _load();
  }

  Widget _tripCard(Map<String, dynamic> trip, {bool featured = false}) {
    final status = (trip['status'] ?? 'assigned').toString();
    final flagged = trip['requires_review'] == true;
    final active = !['completed', 'cancelled'].contains(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: ShopHopSurface(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  color: _teal,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '${trip['code'] ?? 'Linehaul trip'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _navy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ShopHopStatusPill(label: status.replaceAll('_', ' ')),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              '${trip['from'] ?? 'Origin'} → ${trip['to'] ?? 'Destination'}',
              style: const TextStyle(
                color: _navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Manifest ${trip['manifest_code'] ?? '—'} · '
              '${trip['parcel_count'] ?? 0} parcels',
              style: const TextStyle(fontSize: 11, color: Color(0xFF607084)),
            ),
            if (featured) ...[
              const SizedBox(height: 4),
              Text(
                'Vehicle ${trip['vehicle_code'] ?? '—'} · '
                '${trip['plate_number'] ?? '—'}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF607084)),
              ),
            ],
            if (flagged) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${trip['route_warning'] ?? 'Route needs Logistics review.'}',
                  style: const TextStyle(
                    color: Color(0xFF8C5100),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
            if (active && !flagged) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _tab = 2;
                          _manifest = null;
                          _message = null;
                          _success = false;
                          _needsRecheck = false;
                          _manifestCode.text = (trip['manifest_code'] ?? '')
                              .toString();
                        }),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Review / scan manifest'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tripsPage({bool history = false}) {
    final rows = _trips
        .where(
          (trip) => history
              ? ['completed', 'cancelled'].contains(trip['status'])
              : !['completed', 'cancelled'].contains(trip['status']),
        )
        .toList();
    if (!history) {
      rows.sort((a, b) {
        final rankA = a['status'] == 'in_transit' ? 0 : 1;
        final rankB = b['status'] == 'in_transit' ? 0 : 1;
        final rank = rankA.compareTo(rankB);
        return rank != 0
            ? rank
            : ((a['id'] as num?) ?? 0).compareTo((b['id'] as num?) ?? 0);
      });
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: PageStorageKey('linehaul-$_tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          ShopHopWorkflowHeader(
            title: history ? 'Trip history' : 'My assigned trips',
            subtitle: history
                ? 'Completed and cancelled manifests.'
                : 'Check the vehicle and route, then scan before departure.',
            icon: Icons.route_rounded,
            badge: '${rows.length} ${history ? 'past' : 'active'} trips',
          ),
          const SizedBox(height: 12),
          if (!history && rows.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: ShopHopOpsCount(
                    label: 'Assigned trips',
                    value: '${rows.length}',
                    icon: Icons.route_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShopHopOpsCount(
                    label: 'Awaiting review',
                    value:
                        '${rows.where((t) => t['requires_review'] == true).length}',
                    icon: Icons.rule_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ShopHopOpsHeading(
              title: rows.first['status'] == 'in_transit'
                  ? 'Current trip'
                  : 'Next trip',
              subtitle:
                  'Manifest acceptance requires physical load verification.',
            ),
            const SizedBox(height: 8),
            _tripCard(rows.first, featured: true),
            if (rows.length > 1) ...[
              const SizedBox(height: 10),
              const ShopHopOpsHeading(title: 'Other assigned trips'),
              const SizedBox(height: 8),
            ],
            for (final trip in rows.skip(1)) _tripCard(trip),
          ] else if (rows.isNotEmpty)
            for (final trip in rows) _tripCard(trip)
          else
            const ShopHopEmptyState(
              icon: Icons.route_outlined,
              title: 'No trips to show',
              description:
                  'Dispatch assignments appear here after Logistics creates a trip.',
            ),
        ],
      ),
    );
  }

  Widget _scanPage() => ListView(
    controller: _scanScroll,
    key: PageStorageKey('linehaul-$_tab'),
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
    children: [
      const ShopHopWorkflowHeader(
        title: 'Scan manifest',
        subtitle:
            '1. Scan or enter Manifest QR → 2. Review the load → 3. Confirm physical custody.',
        icon: Icons.qr_code_scanner_rounded,
      ),
      const SizedBox(height: 12),
      ShopHopScanSteps(
        step: _success
            ? 2
            : _manifest != null
            ? 1
            : 0,
      ),
      if (_message != null) ...[
        ShopHopScanNotice(
          message: _message!,
          success: _success,
          onNext: _busy
              ? null
              : _success
              ? () {
                  _manifestCode.clear();
                  _startScan();
                }
              : _needsRecheck
              ? () => _scan(_manifestCode.text)
              : null,
          nextLabel: _success ? 'Scan next' : 'Recheck manifest',
        ),
        const SizedBox(height: 10),
      ],
      if (_manifest == null)
        ShopHopSurface(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1  Scan manifest QR',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Driver scans the Manifest QR, not individual parcel labels.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              ShopHopCameraPanel(
                controller: _camera,
                scanning: _scanning,
                busy: _busy,
                instruction: 'Scan the Manifest QR for your assigned vehicle',
                onToggle: () async {
                  if (_scanning) {
                    await _camera.stop();
                    if (mounted) setState(() => _scanning = false);
                  } else {
                    await _startScan();
                  }
                },
                onDetect: (capture) {
                  if (_busy || !_scanning) return;
                  for (final barcode in capture.barcodes) {
                    final code = barcode.rawValue;
                    if (code != null && code.trim().isNotEmpty) {
                      _scan(code);
                      break;
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _manifestCode,
                enabled: !_busy,
                onChanged: (_) => setState(() {
                  _manifest = null;
                  _message = null;
                  _success = false;
                }),
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Or enter Manifest code',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy || _manifestCode.text.trim().isEmpty
                      ? null
                      : () => _scan(_manifestCode.text),
                  child: const Text('Review manifest details'),
                ),
              ),
            ],
          ),
        ),
      if (_manifest != null) ...[
        const SizedBox(height: 12),
        ShopHopSurface(
          padding: const EdgeInsets.all(14),
          child: Column(
            key: _reviewKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _busy ? null : _startScan,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Scan another manifest'),
                ),
              ),
              const Text(
                '2  Review load & custody',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${_manifest!['manifest_code']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              Text(
                '${_manifest!['from']} → ${_manifest!['to']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              if (_manifest!['requires_review'] == true)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _manifest!['route_warning']?.toString() ??
                        'Road trip requires Logistics review.',
                    style: const TextStyle(
                      color: Color(0xFF8C5100),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              Text(
                'ROAD trip ${_manifest!['trip_code']} · ${_manifest!['trip_status']}',
              ),
              Text(
                'Vehicle ${_manifest!['vehicle_code']} · ${_manifest!['plate_number']}',
              ),
              Text(
                'Loaded ${_manifest!['loaded']} / ${_manifest!['expected']} · Received ${_manifest!['received']}',
              ),
              const Divider(height: 20),
              const Text(
                '3  Confirm only after physical load verification.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _busy ||
                          _needsRecheck ||
                          _manifest!['requires_review'] == true ||
                          _manifest!['action'] != 'depart'
                      ? null
                      : _confirm,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    _manifest!['confirm_label']?.toString() ??
                        'Confirm custody',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _vehiclePage() {
    final active = _trips
        .where((t) => !['completed', 'cancelled'].contains(t['status']))
        .toList();
    final t = active.isEmpty ? null : active.first;
    return ListView(
      key: const PageStorageKey('linehaul-account'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        const ShopHopWorkflowHeader(
          title: 'Assigned vehicle',
          subtitle: 'Registered transport linked to your active manifest.',
          icon: Icons.local_shipping_outlined,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: t == null
                ? const Text('No active vehicle assignment.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t['vehicle_code'] ?? 'Vehicle'}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${t['vehicle_type'] ?? ''} · ${t['plate_number'] ?? '—'}',
                      ),
                      const SizedBox(height: 8),
                      Text('Active trip: ${t['code']}'),
                      Text('${t['from']} → ${t['to']}'),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  String _money(double value) => '₱${value.toStringAsFixed(2)}';

  Widget _accountPage() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      key: const PageStorageKey('linehaul-account'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        const ShopHopWorkflowHeader(
          title: 'Account & earnings',
          subtitle: 'Your linehaul work and completed-trip earnings.',
          icon: Icons.wallet_outlined,
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
            title: const Text('Linehaul Driver'),
            subtitle: Text(_email ?? ''),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pending',
                        style: TextStyle(color: Color(0xFF65748A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _money(_pendingEarnings),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available',
                        style: TextStyle(color: Color(0xFF65748A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _money(_availableEarnings),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Paid',
                        style: TextStyle(color: Color(0xFF65748A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _money(_paidEarnings),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Trip Earnings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
        const SizedBox(height: 8),
        if (_earnings.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No completed-trip earnings yet.'),
            ),
          ),
        ..._earnings
            .take(20)
            .map(
              (e) => Card(
                child: ListTile(
                  leading: Icon(
                    e['status'] == 'paid'
                        ? Icons.check_circle_outline
                        : e['status'] == 'available'
                        ? Icons.account_balance_wallet_outlined
                        : Icons.schedule,
                    color: _teal,
                  ),
                  title: Text(
                    '${e['trip_code'] ?? 'Trip'} · ${_money((e['amount'] as num?)?.toDouble() ?? 0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${e['from'] ?? 'Origin'} → ${e['to'] ?? 'Destination'}\n${(e['status'] ?? 'pending').toString().toUpperCase()}${e['payment_reference'] != null ? ' · Ref ${e['payment_reference']}' : ''}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pages = [
      _tripsPage(),
      _vehiclePage(),
      _scanPage(),
      _tripsPage(history: true),
      _accountPage(),
    ];
    return Scaffold(
      appBar: ShopHopRoleAppBar(
        role: ShopHopRole.linehaul,
        index: _tab,
        refreshing: _requestFuture != null,
        onRefresh: _busy || _scanning || _tab == 2 ? null : _load,
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_syncError != null)
                  MaterialBanner(
                    content: Text(
                      _syncError!,
                      style: const TextStyle(fontSize: 12),
                    ),
                    actions: [
                      TextButton(
                        onPressed: _requestFuture != null ? null : _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                Expanded(child: pages[_tab]),
              ],
            ),
      bottomNavigationBar: ShopHopNavigation(
        raisedIndex: 2,
        index: _tab,
        onChanged: (i) {
          if (_scanning && i != 2) {
            _camera.stop();
            _scanning = false;
          }
          setState(() => _tab = i);
        },
        items: ShopHopRole.linehaul.destinations,
        badges: {
          0: _trips
              .where(
                (trip) => !['completed', 'cancelled'].contains(trip['status']),
              )
              .length,
        },
      ),
    );
  }
}
