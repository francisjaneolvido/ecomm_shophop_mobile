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
import 'package:shophop/features/logistics/data/logistics_scan_service.dart';
import 'package:shophop/features/logistics/presentation/screens/manifest_loading_screen.dart';
import 'package:shophop/features/logistics/presentation/screens/manifest_receiving_screen.dart';

/// Logistics company and company-provisioned staff share one scanner backend.
/// Staff can only scan at their assigned branch; no public Logistics registration.
class LogisticsScannerScreen extends StatefulWidget {
  const LogisticsScannerScreen({super.key});

  @override
  State<LogisticsScannerScreen> createState() => _LogisticsScannerScreenState();
}

class _LogisticsScannerScreenState extends State<LogisticsScannerScreen> {
  static const Color _navy = AppColors.navy;
  static const Color _teal = AppColors.tealDark;
  static const Color _background = AppColors.grayBg;

  final MobileScannerController _camera = MobileScannerController(
    autoStart: false,
  );
  final TextEditingController _tracking = TextEditingController();
  final TextEditingController _branchSearch = TextEditingController();

  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _preview;
  String? _token;
  int? _branchId;
  String _company = 'ShopHop Logistics';
  String _search = '';
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
  bool _moreBranches = false;
  String _operator = '';
  String? _message;
  bool _messageSuccess = false;
  bool _branchLocked = false;
  bool _busy = false;
  bool _scanning = false;
  late final ForegroundRefresh _liveRefresh;
  int _tab = 0; // Home, Manifests, Scan, Activity, Account
  bool get _showHistory => _tab == 3;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _liveRefresh = ForegroundRefresh(
      refresh: () => _load(silent: true),
      canRefresh: () =>
          mounted &&
          _requestFuture == null &&
          !_busy &&
          !_scanning &&
          _preview == null &&
          (_tab == 0 || _tab == 3) &&
          (ModalRoute.of(context)?.isCurrent ?? true),
    );
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : <Map<String, dynamic>>[];

  int? _id(dynamic value) => int.tryParse(value?.toString() ?? '');

  String _eventLabel(dynamic value) {
    switch (value?.toString()) {
      case 'seller_handoff':
        return 'Seller → Pickup Rider';
      case 'pickup_received':
        return 'Pickup Rider → Branch received';
      case 'manifest_loaded':
        return 'Included in confirmed Linehaul load';
      case 'linehaul_departed':
        return 'Linehaul departed';
      case 'manifest_arrived':
        return 'Destination acknowledged Manifest arrival';
      case 'transit_rider_handoff':
        return 'Legacy Center → Transit Rider';
      case 'transfer_received':
        return 'Linehaul → Center received';
      case 'delivery_rider_handoff':
        return 'Branch → Delivery Rider';
      case 'hub_sorted':
        return 'Sorted at Province Hub';
      default:
        final raw = value?.toString().replaceAll('_', ' ').trim() ?? '';
        if (raw.isEmpty) return 'Parcel event';
        return raw[0].toUpperCase() + raw.substring(1);
    }
  }

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
    final generation = ++_requestGeneration;
    final session = await AuthSessionService.readSession();
    if (!mounted || generation != _requestGeneration) return;
    if (session == null ||
        (session.accountType != 'logistics' &&
            session.accountType != 'logistics_staff' &&
            session.accountType != 'branch')) {
      await _signOut();
      return;
    }

    setState(() {
      _busy = !silent;
      _token = session.token;
      if (!silent) {
        _preview = null;
        _message = null;
      }
    });
    final response = await LogisticsScanService.branches(
      session.token,
      search: _search,
    );
    if (!mounted || generation != _requestGeneration) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      await _signOut();
      return;
    }

    final branches = _rows(response.data['branches']);
    final locked =
        response.data['branch_locked'] == true ||
        session.accountType == 'logistics_staff' ||
        session.accountType == 'branch';
    int? next = _branchId;
    if (!branches.any((branch) => _id(branch['id']) == next)) {
      next = branches.isEmpty ? null : _id(branches.first['id']);
    }
    setState(() {
      _busy = false;
      _branches = branches;
      _moreBranches = response.data['more_branches'] == true;
      _branchLocked = locked;
      _branchId = next;
      _company = response.data['company']?.toString() ?? _company;
      _operator = response.data['operator']?.toString() ?? session.email;
      _message = response.success ? null : response.message;
      _messageSuccess = false;
      if (!response.success) _history = [];
    });
    if (response.success && next != null) await _loadHistory(next, generation);
  }

  Future<void> _loadHistory(int branchId, int generation) async {
    final token = _token;
    if (token == null) return;
    final response = await LogisticsScanService.history(
      token: token,
      branchId: branchId,
    );
    if (!mounted || generation != _requestGeneration || branchId != _branchId) {
      return;
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      setState(() {
        _message = response.message;
        _messageSuccess = false;
      });
      return;
    }
    setState(() {
      if (response.success) {
        _history = _rows(response.data['events']);
      } else if (_showHistory) {
        _message = response.message;
        _messageSuccess = false;
      }
    });
  }

  void _selectBranch(int? branchId) {
    if (_branchLocked || _busy || branchId == null || branchId == _branchId) {
      return;
    }
    final generation = ++_requestGeneration;
    setState(() {
      _branchId = branchId;
      _preview = null;
      _message = null;
      _history = [];
      _tracking.clear();
    });
    _loadHistory(branchId, generation);
  }

  Future<void> _signOut() async {
    ++_requestGeneration;
    await _stopScanner();
    final token = _token;
    if (token != null) await AuthService.logout(token: token);
    await AuthSessionService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  bool _validCode(String value) =>
      RegExp(r'^SHP-[0-9]{8}-[0-9]{6,}$').hasMatch(value);

  Future<void> _previewParcel(String code) async {
    final tracking = code.trim().toUpperCase();
    if (_busy || _branchId == null || _token == null) return;
    if (!_validCode(tracking)) {
      ShopHopScanFeedback.instance.notify(
        ScanFeedbackEvent.error,
        reference: tracking,
      );
      await _stopScanner();
      if (!mounted) return;
      setState(() {
        _preview = null;
        _message =
            'Invalid ShopHop QR or tracking code. Use the code printed on the parcel label.';
        _messageSuccess = false;
      });
      return;
    }

    // Lock further camera detections before making any network request.
    final generation = ++_requestGeneration;
    setState(() {
      _busy = true;
      _scanning = false;
      _preview = null;
      _tracking.text = tracking;
      _message = null;
    });
    await _camera.stop();
    final selectedBranch = _branchId!;
    final response = await LogisticsScanService.preview(
      token: _token!,
      branchId: selectedBranch,
      trackingCode: tracking,
    );
    if (!mounted ||
        generation != _requestGeneration ||
        selectedBranch != _branchId) {
      return;
    }
    setState(() {
      _busy = false;
      _needsRecheck = false;
      _preview = response.success && response.data['parcel'] is Map
          ? Map<String, dynamic>.from(response.data['parcel'] as Map)
          : null;
      _message = response.success ? null : response.message;
      _messageSuccess = false;
    });
    if (_preview != null) _revealReview();
    ShopHopScanFeedback.instance.notify(
      _preview != null ? ScanFeedbackEvent.verified : ScanFeedbackEvent.error,
      reference: tracking,
    );
  }

  Future<void> _confirmReceipt() async {
    final parcel = _preview;
    final token = _token;
    final branchId = _branchId;
    if (_busy ||
        _needsRecheck ||
        parcel == null ||
        token == null ||
        branchId == null) {
      return;
    }
    final tracking = parcel['tracking_code']?.toString() ?? '';
    if (!_validCode(tracking)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm physical handoff?'),
        content: Text(
          'Only confirm after checking the parcel label and physically receiving $tracking at ${parcel['branch']}. This action updates tracking for all roles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm received'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _busy || _preview == null) return;
    final generation = ++_requestGeneration;
    setState(() {
      _busy = true;
      _message = null;
    });
    final response = await LogisticsScanService.receive(
      token: token,
      branchId: branchId,
      trackingCode: tracking,
    );
    if (!mounted || generation != _requestGeneration) return;
    setState(() {
      _busy = false;
      _preview = response.success ? null : parcel;
      _needsRecheck = !response.success;
      _message = response.message;
      _messageSuccess = response.success;
    });
    ShopHopScanFeedback.instance.notify(
      response.success ? ScanFeedbackEvent.complete : ScanFeedbackEvent.error,
      reference: tracking,
    );
    _showResult();
    if (response.success) await _loadHistory(branchId, generation);
  }

  Future<void> _stopScanner() async {
    if (_scanning && mounted) setState(() => _scanning = false);
    try {
      await _camera.stop();
    } catch (_) {
      /* Already stopped. */
    }
  }

  Future<void> _setScanner(bool active) async {
    if (_busy || _branchId == null) return;
    if (!active) {
      await _stopScanner();
      return;
    }
    setState(() {
      _preview = null;
      _message = null;
      _scanning = true;
      _messageSuccess = false;
      _needsRecheck = false;
      _tab = 2;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scanning) return;
      try {
        await _camera.start();
      } catch (_) {
        if (mounted) {
          setState(() {
            _scanning = false;
            _message =
                'Camera unavailable. Grant camera permission or enter a tracking code below.';
            _messageSuccess = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scanScroll.dispose();
    _liveRefresh.dispose();
    ++_requestGeneration;
    _tracking.dispose();
    _branchSearch.dispose();
    _camera.dispose();
    super.dispose();
  }

  Widget _surface(Widget child) => SizedBox(
    width: double.infinity,
    child: ShopHopSurface(padding: const EdgeInsets.all(12), child: child),
  );

  Widget _notice(String text, {required bool success}) => ShopHopScanNotice(
    message: text,
    success: success,
    onNext: _busy
        ? null
        : success && _tab == 2
        ? () {
            _tracking.clear();
            _setScanner(true);
          }
        : _needsRecheck && _preview != null
        ? () => _previewParcel(_tracking.text)
        : null,
    nextLabel: success ? 'Scan next' : 'Recheck parcel',
  );

  // Keep physical location selection out of the camera workflow.
  Widget _branchPicker() => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current receiving facility',
          style: TextStyle(fontWeight: FontWeight.w600, color: _navy),
        ),
        const SizedBox(height: 6),
        Text(
          _branchLocked
              ? 'This branch is assigned to your staff account. Ask the company owner to change your assignment.'
              : 'Select the branch where the parcel is physically being handed over.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF65748A)),
        ),
        if (!_branchLocked) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _branchSearch,
            enabled: !_busy && !_scanning,
            textInputAction: TextInputAction.search,
            onSubmitted: (term) {
              final next = term.trim();
              if (next == _search) return;
              _search = next;
              _load();
            },
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Search city / branch',
              hintText: 'e.g. Calamba or Pila',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: IconButton(
                tooltip: 'Clear branch search',
                onPressed: () {
                  _branchSearch.clear();
                  _search = '';
                  _load();
                },
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          if (_moreBranches)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Showing first 80 branches. Search to select another location.',
                style: TextStyle(fontSize: 11, color: Color(0xFF65748A)),
              ),
            ),
        ],
        const SizedBox(height: 12),
        if (_branches.isEmpty)
          const Text(
            'No active branches assigned. Ask your Logistics administrator to activate and assign a branch.',
          )
        else
          DropdownButtonFormField<int>(
            key: ValueKey('$_branchId-$_branchLocked'),
            initialValue: _branchId,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Branch / Province Hub',
            ),
            items: _branches
                .map(
                  (branch) => DropdownMenuItem<int>(
                    value: _id(branch['id']),
                    child: Text(
                      '${branch['name']} · ${branch['code']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy || _scanning || _branchLocked
                ? null
                : _selectBranch,
          ),
        if (_branchLocked)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 15, color: _teal),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Branch-locked staff access',
                    style: TextStyle(color: _teal, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _receiveContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ShopHopScanSteps(
        step: _messageSuccess
            ? 2
            : _preview != null
            ? 1
            : 0,
      ),
      if (_preview == null)
        _surface(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1  Scan parcel · verify',
                style: TextStyle(fontWeight: FontWeight.w600, color: _navy),
              ),
              const SizedBox(height: 6),
              const Text(
                'The QR is checked first. Scanning alone will NOT mark the parcel as received.',
                style: TextStyle(fontSize: 12, color: Color(0xFF65748A)),
              ),
              const SizedBox(height: 14),
              ShopHopCameraPanel(
                controller: _camera,
                scanning: _scanning,
                busy: _busy,
                instruction: 'Scan the parcel QR at your receiving facility',
                onToggle: () => _setScanner(!_scanning),
                onDetect: (capture) {
                  if (_busy || !_scanning) return;
                  for (final barcode in capture.barcodes) {
                    final code = barcode.rawValue;
                    if (code != null && code.trim().isNotEmpty) {
                      _previewParcel(code);
                      break;
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Manual tracking entry',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tracking,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) {
                  if (_preview != null) setState(() => _preview = null);
                },
                decoration: const InputDecoration(
                  hintText: 'SHP-20261015-000001',
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _teal),
                  onPressed: _busy || _branchId == null
                      ? null
                      : () => _previewParcel(_tracking.text),
                  child: const Text('Check parcel details'),
                ),
              ),
            ],
          ),
        ),
      if (_preview != null) ...[
        const SizedBox(height: 12),
        _surface(
          Column(
            key: _reviewKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          _tracking.clear();
                          _setScanner(true);
                        },
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Scan another parcel'),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.fact_check_outlined, color: _teal),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '2  Review & confirm receipt',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _navy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${_preview!['tracking_code']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_preview!['next_action']}',
                style: const TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text('Receiving at: ${_preview!['branch']}'),
              Text('Current status: ${_preview!['delivery_status']}'),
              if (_preview!['route'] is Map) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF8F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFB7E5DB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PARCEL ROUTE · PREVIEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF087D6A),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Type: ${(_preview!['route'] as Map)['route_type'] ?? 'Unknown'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      if (((_preview!['route'] as Map)['next_hop'] ?? '')
                          .toString()
                          .isNotEmpty)
                        Text(
                          'Next: ${(_preview!['route'] as Map)['next_hop']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (((_preview!['route'] as Map)['next_leg'] ?? '')
                          .toString()
                          .isNotEmpty)
                        Text(
                          'Transfer: ${((_preview!['route'] as Map)['next_leg'] == 'verified_direct_station_road') ? 'Verified direct branch ROAD' : ((_preview!['route'] as Map)['next_leg'] == 'station_to_origin_hub' ? 'Origin Province Hub' : 'Manifest-controlled transfer')}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _navy,
                          ),
                        ),
                      if ((_preview!['route'] as Map)['network_path']
                          is Map) ...[
                        const SizedBox(height: 7),
                        Text(
                          'VERIFIED NETWORK · ${(((_preview!['route'] as Map)['network_path'] as Map)['status'] ?? 'unavailable').toString().toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF087D6A),
                          ),
                        ),
                        Text(
                          '${(((_preview!['route'] as Map)['network_path'] as Map)['note'] ?? '')}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF46625D),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${(_preview!['route'] as Map)['note'] ?? 'Follow the verified manifest workflow.'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF46625D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _teal),
                  onPressed: _busy || _needsRecheck ? null : _confirmReceipt,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Confirm parcel received'),
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _historyContent() => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent custody events for this branch',
                style: TextStyle(fontWeight: FontWeight.w600, color: _navy),
              ),
            ),
            IconButton(
              tooltip: 'Refresh scan history',
              onPressed: _branchId == null || _busy
                  ? null
                  : () => _loadHistory(_branchId!, _requestGeneration),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No confirmed scans at this branch yet. Scans appear here after the server records them.',
            ),
          ),
        ..._history.map(
          (event) => Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE5F6F2),
                  child: Icon(Icons.qr_code, color: _teal),
                ),
                title: Text(event['tracking_code']?.toString() ?? 'Parcel'),
                subtitle: Text(
                  '${_eventLabel(event['event'])}\n${event['scanned_at'] ?? ''}',
                ),
                isThreeLine: true,
              ),
              const Divider(height: 1),
            ],
          ),
        ),
      ],
    ),
  );

  String get _selectedBranchName {
    for (final branch in _branches) {
      if (_id(branch['id']) == _branchId) {
        return branch['name']?.toString() ?? 'Selected branch';
      }
    }
    return _branchId == null ? 'No branch assigned' : 'Selected branch';
  }

  Future<void> _openManifestReceiving() async {
    if (_token == null || _branchId == null) return;
    await _stopScanner();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManifestReceivingScreen(
          token: _token!,
          branchId: _branchId!,
          branchName: _selectedBranchName,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openManifestLoading() async {
    if (_token == null || _branchId == null) return;
    await _stopScanner();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManifestLoadingScreen(
          token: _token!,
          branchId: _branchId!,
          branchName: _selectedBranchName,
        ),
      ),
    );
    if (mounted) _load();
  }

  Widget _homeContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ShopHopWorkflowHeader(
        title: 'Operations workspace',
        subtitle: _operator.isEmpty ? _company : '$_company · $_operator',
        icon: Icons.warehouse_outlined,
        badge: _branchLocked
            ? 'Assigned facility'
            : 'Authorized logistics operator',
      ),
      const SizedBox(height: 12),
      _surface(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current facility',
              style: TextStyle(fontSize: 11, color: Color(0xFF607084)),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedBranchName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _branchLocked
                  ? 'Assigned to this facility'
                  : 'Change facility in Account',
              style: const TextStyle(fontSize: 11, color: Color(0xFF607084)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const ShopHopOpsHeading(
        title: 'Quick actions',
        subtitle: 'Choose the physical operation you need to complete.',
      ),
      const SizedBox(height: 10),
      ShopHopOpsAction(
        icon: Icons.move_to_inbox_outlined,
        title: 'Receive inbound manifest',
        subtitle: 'Scan manifest, verify arrival and physical parcel count',
        enabled: !_busy && _branchId != null,
        onTap: _openManifestReceiving,
      ),
      const SizedBox(height: 8),
      ShopHopOpsAction(
        icon: Icons.inventory_2_outlined,
        title: 'Load outbound manifest',
        subtitle: 'Verify the batch before linehaul custody',
        enabled: !_busy && _branchId != null,
        onTap: _openManifestLoading,
      ),
      const SizedBox(height: 8),
      ShopHopOpsAction(
        icon: Icons.qr_code_scanner_rounded,
        title: 'Scan individual parcel',
        subtitle: 'Review an exception and confirm a physical handoff',
        enabled: !_busy && _branchId != null,
        onTap: () => setState(() => _tab = 2),
      ),
      const SizedBox(height: 18),
      ShopHopOpsHeading(
        title: 'Recent scans',
        subtitle:
            'Showing ${_history.length} events returned for this facility, not an all-time total.',
        trailing: TextButton(
          onPressed: _branchId == null
              ? null
              : () {
                  setState(() => _tab = 3);
                  _loadHistory(_branchId!, _requestGeneration);
                },
          child: const Text('View all'),
        ),
      ),
      const SizedBox(height: 8),
      if (_history.isEmpty)
        _surface(
          const Text(
            'No recent scan events. Use a QR action above to get started.',
            style: TextStyle(fontSize: 12, color: Color(0xFF607084)),
          ),
        )
      else
        _surface(
          Column(
            children: _history
                .take(3)
                .map(
                  (event) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.qr_code, color: _teal),
                    title: Text(
                      event['tracking_code']?.toString() ?? 'Parcel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _eventLabel(event['event']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
    ],
  );

  Widget _accountContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const ShopHopWorkflowHeader(
        title: 'Facility & account',
        subtitle: 'Review your assigned location and manage access.',
        icon: Icons.manage_accounts_outlined,
      ),
      const SizedBox(height: 12),
      _branchPicker(),
      const SizedBox(height: 12),
      _surface(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Signed in as',
              style: TextStyle(color: Color(0xFF607084), fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              _operator.isNotEmpty ? _operator : _company,
              style: const TextStyle(fontWeight: FontWeight.w600, color: _navy),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _manifestsContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ShopHopWorkflowHeader(
        title: 'Manifest operations',
        subtitle: _selectedBranchName,
        icon: Icons.inventory_2_outlined,
        badge: 'Receive inbound / prepare outbound',
      ),
      const SizedBox(height: 14),
      ShopHopOpsAction(
        icon: Icons.move_to_inbox_outlined,
        title: 'Receive inbound manifest',
        subtitle: 'Verify arrival and receive the physical parcel count',
        enabled: !_busy && _branchId != null,
        onTap: _openManifestReceiving,
      ),
      const SizedBox(height: 10),
      ShopHopOpsAction(
        icon: Icons.local_shipping_outlined,
        title: 'Load outbound manifest',
        subtitle: 'Review the load before handing custody to Linehaul',
        enabled: !_busy && _branchId != null,
        onTap: _openManifestLoading,
      ),
      const SizedBox(height: 14),
      const Text(
        'For missing parcels or count mismatches, use individual Parcel Scan for exception reconciliation.',
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
      ),
    ],
  );

  Widget _page() {
    switch (_tab) {
      case 1:
        return _manifestsContent();
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShopHopWorkflowHeader(
              title: 'Parcel QR scanner',
              subtitle: 'Scan → review → confirm the physical parcel receipt.',
              icon: Icons.qr_code_scanner_rounded,
            ),
            const SizedBox(height: 12),
            _receiveContent(),
          ],
        );
      case 3:
        return Column(
          children: [
            const ShopHopWorkflowHeader(
              title: 'Custody history',
              subtitle: 'Confirmed events from the active facility.',
              icon: Icons.history_rounded,
            ),
            const SizedBox(height: 12),
            _historyContent(),
          ],
        );
      case 4:
        return _accountContent();
      default:
        return _homeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      controller: _scanScroll,
      key: PageStorageKey('logistics-$_tab'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        if (_busy) const LinearProgressIndicator(minHeight: 3),
        if (_message != null) ...[
          _notice(_message!, success: _messageSuccess),
          const SizedBox(height: 10),
        ],
        _page(),
      ],
    );
    return Scaffold(
      backgroundColor: _background,
      appBar: ShopHopRoleAppBar(
        role: ShopHopRole.logistics,
        index: _tab,
        refreshing: _requestFuture != null,
        onRefresh: _busy || _scanning || _preview != null || _tab == 2
            ? null
            : _load,
      ),
      body: SafeArea(
        child: _busy && _branches.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _tab == 2
            ? content
            : RefreshIndicator(onRefresh: _load, child: content),
      ),
      bottomNavigationBar: ShopHopNavigation(
        raisedIndex: 2,
        index: _tab,
        onChanged: (value) {
          if (value == _tab) return;
          _stopScanner();
          setState(() => _tab = value);
          if (value == 3 && _branchId != null) {
            _loadHistory(_branchId!, _requestGeneration);
          }
        },
        items: ShopHopRole.logistics.destinations,
      ),
    );
  }
}
