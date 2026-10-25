import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';
import 'package:shophop/features/logistics/data/logistics_scan_service.dart';
import 'package:shophop/features/logistics/presentation/screens/manifest_loading_screen.dart';

/// Logistics company and company-provisioned staff share one scanner backend.
/// Staff can only scan at their assigned branch; no public Logistics registration.
class LogisticsScannerScreen extends StatefulWidget {
  const LogisticsScannerScreen({super.key});

  @override
  State<LogisticsScannerScreen> createState() => _LogisticsScannerScreenState();
}

class _LogisticsScannerScreenState extends State<LogisticsScannerScreen> {
  static const Color _navy = Color(0xFF172B4D);
  static const Color _teal = Color(0xFF159E8B);
  static const Color _background = Color(0xFFF5F7FA);

  final MobileScannerController _camera = MobileScannerController(autoStart: false);
  final TextEditingController _tracking = TextEditingController();

  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _preview;
  String? _token;
  int? _branchId;
  String _company = 'ShopHop Logistics';
  String _operator = '';
  String? _message;
  bool _messageSuccess = false;
  bool _branchLocked = false;
  bool _busy = false;
  bool _scanning = false;
  bool _showHistory = false;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
      : <Map<String, dynamic>>[];

  int? _id(dynamic value) => int.tryParse(value?.toString() ?? '');

  String _eventLabel(dynamic value) {
    switch (value?.toString()) {
      case 'seller_handoff':
        return 'Seller → Pickup Rider';
      case 'pickup_received':
        return 'Pickup Rider → Branch received';
      case 'manifest_loaded':
        return 'Parcel loaded to Linehaul manifest';
      case 'linehaul_departed':
        return 'Linehaul departed';
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

  Future<void> _load() async {
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
      _busy = true;
      _token = session.token;
      _preview = null;
      _message = null;
    });
    final response = await LogisticsScanService.branches(session.token);
    if (!mounted || generation != _requestGeneration) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      await _signOut();
      return;
    }

    final branches = _rows(response.data['branches']);
    final locked = response.data['branch_locked'] == true ||
        session.accountType == 'logistics_staff' ||
        session.accountType == 'branch';
    int? next = _branchId;
    if (!branches.any((branch) => _id(branch['id']) == next)) {
      next = branches.isEmpty ? null : _id(branches.first['id']);
    }
    setState(() {
      _busy = false;
      _branches = branches;
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
    final response = await LogisticsScanService.history(token: token, branchId: branchId);
    if (!mounted || generation != _requestGeneration || branchId != _branchId) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      setState(() { _message = response.message; _messageSuccess = false; });
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
    if (_branchLocked || _busy || branchId == null || branchId == _branchId) return;
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
      MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  bool _validCode(String value) => RegExp(r'^SHP-[0-9]{8}-[0-9]{6,}$').hasMatch(value);

  Future<void> _previewParcel(String code) async {
    final tracking = code.trim().toUpperCase();
    if (_busy || _branchId == null || _token == null) return;
    if (!_validCode(tracking)) {
      setState(() {
        _preview = null;
        _message = 'Invalid ShopHop QR or tracking code. Use the code printed on the parcel label.';
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
      token: _token!, branchId: selectedBranch, trackingCode: tracking);
    if (!mounted || generation != _requestGeneration || selectedBranch != _branchId) return;
    setState(() {
      _busy = false;
      _preview = response.success && response.data['parcel'] is Map
          ? Map<String, dynamic>.from(response.data['parcel'] as Map)
          : null;
      _message = response.success ? null : response.message;
      _messageSuccess = false;
    });
  }

  Future<void> _confirmReceipt() async {
    final parcel = _preview;
    final token = _token;
    final branchId = _branchId;
    if (_busy || parcel == null || token == null || branchId == null) return;
    final tracking = parcel['tracking_code']?.toString() ?? '';
    if (!_validCode(tracking)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm physical handoff?'),
        content: Text('Only confirm after checking the parcel label and physically receiving $tracking at ${parcel['branch']}. This action updates tracking for all roles.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm received')),
        ],
      ),
    );
    if (!mounted || confirmed != true || _busy || _preview == null) return;
    final generation = ++_requestGeneration;
    setState(() { _busy = true; _message = null; });
    final response = await LogisticsScanService.receive(
      token: token, branchId: branchId, trackingCode: tracking);
    if (!mounted || generation != _requestGeneration) return;
    setState(() {
      _busy = false;
      _preview = null; // Never allow resubmitting an old preview.
      _message = response.message;
      _messageSuccess = response.success;
    });
    if (response.success) await _loadHistory(branchId, generation);
  }

  Future<void> _stopScanner() async {
    if (_scanning && mounted) setState(() => _scanning = false);
    try { await _camera.stop(); } catch (_) { /* Already stopped. */ }
  }

  Future<void> _setScanner(bool active) async {
    if (_busy || _branchId == null) return;
    if (!active) { await _stopScanner(); return; }
    setState(() {
      _preview = null;
      _message = null;
      _scanning = true;
      _showHistory = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scanning) return;
      try {
        await _camera.start();
      } catch (_) {
        if (mounted) {
          setState(() {
            _scanning = false;
            _message = 'Camera unavailable. Grant camera permission or enter a tracking code below.';
            _messageSuccess = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    ++_requestGeneration;
    _tracking.dispose();
    _camera.dispose();
    super.dispose();
  }

  Widget _surface(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE1E8EC)),
    ),
    child: child,
  );

  Widget _notice(String text, {required bool success}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: success ? const Color(0xFFE7F9F1) : const Color(0xFFFFF3E8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(success ? Icons.check_circle_outline : Icons.info_outline,
          color: success ? const Color(0xFF087966) : const Color(0xFF9B5718)),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]),
  );

  Widget _receiveContent() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('1  Select receiving branch', style: TextStyle(fontWeight: FontWeight.w800, color: _navy)),
      const SizedBox(height: 6),
      Text(_branchLocked
          ? 'This branch is assigned to your staff account. Ask the company owner to change your assignment.'
          : 'Select the branch where the parcel is physically being handed over.',
        style: const TextStyle(fontSize: 12, color: Color(0xFF65748A))),
      const SizedBox(height: 12),
      if (_branches.isEmpty)
        const Text('No active branches assigned. Ask your Logistics administrator to activate and assign a branch.')
      else
        DropdownButtonFormField<int>(
          key: ValueKey('$_branchId-$_branchLocked'),
          initialValue: _branchId,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Receiving branch'),
          items: _branches.map((branch) => DropdownMenuItem<int>(
            value: _id(branch['id']),
            child: Text('${branch['name']} · ${branch['code']}', overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: _busy || _scanning || _branchLocked ? null : _selectBranch,
        ),
      if (_branchLocked) const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(children: [Icon(Icons.lock_outline, size: 15, color: _teal), SizedBox(width: 5),
          Text('Branch-locked staff access', style: TextStyle(color: _teal, fontSize: 12))]),
      ),
    ])),
    const SizedBox(height: 12),
    _surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('2  Scan and verify parcel', style: TextStyle(fontWeight: FontWeight.w800, color: _navy)),
      const SizedBox(height: 6),
      const Text('The QR is checked first. Scanning alone will NOT mark the parcel as received.',
          style: TextStyle(fontSize: 12, color: Color(0xFF65748A))),
      const SizedBox(height: 14),
      if (_scanning) ...[
        ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(
          height: 260,
          child: MobileScanner(
            controller: _camera,
            onDetect: (capture) {
              if (_busy || !_scanning) return;
              for (final barcode in capture.barcodes) {
                final value = barcode.rawValue;
                if (value != null && value.trim().isNotEmpty) {
                  _previewParcel(value);
                  break;
                }
              }
            },
          ),
        )),
        const SizedBox(height: 12),
      ],
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: _busy || _branchId == null ? null : () => _setScanner(!_scanning),
        icon: Icon(_scanning ? Icons.stop_circle_outlined : Icons.qr_code_scanner),
        label: Text(_scanning ? 'Stop camera' : 'Open QR scanner'),
      )),
      const SizedBox(height: 16),
      const Text('Or type tracking code', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 8),
      TextField(
        controller: _tracking,
        enabled: !_busy,
        textCapitalization: TextCapitalization.characters,
        onChanged: (_) { if (_preview != null) setState(() => _preview = null); },
        decoration: const InputDecoration(
          hintText: 'SHP-20261015-000001',
          prefixIcon: Icon(Icons.local_shipping_outlined),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: _teal),
        onPressed: _busy || _branchId == null ? null : () => _previewParcel(_tracking.text),
        child: const Text('Check parcel details'),
      )),
    ])),
    if (_preview != null) ...[
      const SizedBox(height: 12),
      _surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.fact_check_outlined, color: _teal), SizedBox(width: 8),
          Text('3  Confirm physical receipt', style: TextStyle(fontWeight: FontWeight.w800, color: _navy))]),
        const SizedBox(height: 12),
        Text('${_preview!['tracking_code']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 8),
        Text('${_preview!['next_action']}', style: const TextStyle(color: _teal, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Receiving at: ${_preview!['branch']}'),
        Text('Current status: ${_preview!['delivery_status']}'),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: _teal),
          onPressed: _busy ? null : _confirmReceipt,
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Confirm parcel received'),
        )),
      ])),
    ],
  ]);

  Widget _historyContent() => _surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Expanded(child: Text('Recent custody events for this branch', style: TextStyle(fontWeight: FontWeight.w800, color: _navy))),
      IconButton(tooltip: 'Refresh scan history', onPressed: _branchId == null || _busy
        ? null : () => _loadHistory(_branchId!, _requestGeneration), icon: const Icon(Icons.refresh)),
    ]),
    const SizedBox(height: 8),
    if (_history.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No confirmed scans at this branch yet. Scans appear here after the server records them.')),
    ..._history.map((event) => Column(children: [
      ListTile(contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(backgroundColor: Color(0xFFE5F6F2), child: Icon(Icons.qr_code, color: _teal)),
        title: Text(event['tracking_code']?.toString() ?? 'Parcel'),
        subtitle: Text('${_eventLabel(event['event'])}\n${event['scanned_at'] ?? ''}'),
        isThreeLine: true,
      ),
      const Divider(height: 1),
    ])),
  ]));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Parcel Receiving', style: TextStyle(fontWeight: FontWeight.w800, color: _navy)),
      actions: [
        IconButton(tooltip: 'Refresh branches and scans', onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh)),
        IconButton(tooltip: 'Sign out', onPressed: _busy ? null : _signOut, icon: const Icon(Icons.logout)),
      ],
    ),
    body: SafeArea(child: _busy && _branches.isEmpty
      ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 40), children: [
        Text(_company, style: const TextStyle(color: _navy, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(_operator.isEmpty ? 'Authorized logistics scanner' : 'Signed in as $_operator',
            style: const TextStyle(fontSize: 12, color: Color(0xFF65748A))),
        const SizedBox(height: 16),
        if (_branchId != null) ...[
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Load outbound manifest'),
            onPressed: _busy ? null : () async {
              await _stopScanner();
              final branch = _branches.where((b) => _id(b['id']) == _branchId).toList();
              if (!mounted || _token == null || _branchId == null) return;
              await Navigator.push(context, MaterialPageRoute(builder: (_) => ManifestLoadingScreen(
                token: _token!, branchId: _branchId!, branchName: branch.isEmpty ? 'Current center' : (branch.first['name']?.toString() ?? 'Current center'),
              )));
              if (mounted) _load();
            },
          )),
          const SizedBox(height: 12),
        ],
        Row(children: [
          Expanded(child: ChoiceChip(label: const Center(child: Text('Receive Parcel')),
            selected: !_showHistory, onSelected: (_) { _stopScanner(); setState(() => _showHistory = false); })),
          const SizedBox(width: 8),
          Expanded(child: ChoiceChip(label: const Center(child: Text('Scan History')),
            selected: _showHistory, onSelected: (_) {
              _stopScanner();
              setState(() => _showHistory = true);
              if (_branchId != null) _loadHistory(_branchId!, _requestGeneration);
            })),
        ]),
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(minHeight: 3, color: _teal),
        if (_message != null) ...[
          const SizedBox(height: 10),
          _notice(_message!, success: _messageSuccess),
          const SizedBox(height: 12),
        ],
        if (_showHistory) _historyContent() else _receiveContent(),
        const SizedBox(height: 18),
        const Text('Receiving scans update parcel tracking; Rider custody scans also appear in this history. Internet connection is required.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF65748A))),
      ])),
  );
}
