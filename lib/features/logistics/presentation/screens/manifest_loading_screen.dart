import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shophop/features/logistics/data/logistics_scan_service.dart';

class ManifestLoadingScreen extends StatefulWidget {
  const ManifestLoadingScreen({
    super.key,
    required this.token,
    required this.branchId,
    required this.branchName,
  });

  final String token;
  final int branchId;
  final String branchName;

  @override
  State<ManifestLoadingScreen> createState() => _ManifestLoadingScreenState();
}

class _ManifestLoadingScreenState extends State<ManifestLoadingScreen> {
  static const _navy = Color(0xFF172B4D);
  static const _teal = Color(0xFF159E8B);
  final _camera = MobileScannerController(autoStart: false);
  final _tracking = TextEditingController();

  List<Map<String, dynamic>> _manifests = [];
  int? _manifestId;
  Map<String, dynamic>? _preview;
  String? _message;
  bool _success = false;
  bool _busy = false;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _loadManifests();
  }

  @override
  void dispose() {
    _camera.dispose();
    _tracking.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  int? _id(dynamic value) => int.tryParse(value?.toString() ?? '');

  Future<void> _loadManifests() async {
    setState(() => _busy = true);
    final result = await LogisticsScanService.manifests(token: widget.token, branchId: widget.branchId);
    if (!mounted) return;
    final rows = result.success ? _rows(result.data['manifests']) : <Map<String, dynamic>>[];
    var selected = _manifestId;
    if (!rows.any((m) => _id(m['id']) == selected)) {
      selected = rows.isEmpty ? null : _id(rows.first['id']);
    }
    setState(() {
      _busy = false;
      _manifests = rows;
      _manifestId = selected;
      _message = result.success ? null : result.message;
      _success = false;
      _preview = null;
    });
  }

  Future<void> _setCamera(bool active) async {
    if (_busy || _manifestId == null) return;
    if (!active) {
      try { await _camera.stop(); } catch (_) {}
      if (mounted) setState(() => _scanning = false);
      return;
    }
    setState(() { _scanning = true; _message = null; _preview = null; });
    try { await _camera.start(); } catch (_) {
      if (mounted) setState(() { _scanning = false; _message = 'Camera unavailable. Grant camera permission or type the tracking code.'; });
    }
  }

  Future<void> _previewCode(String raw) async {
    final code = raw.trim().toUpperCase();
    if (_busy || _manifestId == null || !RegExp(r'^SHP-[0-9]{8}-[0-9]{6,}$').hasMatch(code)) {
      if (mounted) setState(() { _message = 'Scan a valid ShopHop parcel QR.'; _success = false; });
      return;
    }
    setState(() { _busy = true; _scanning = false; _preview = null; _tracking.text = code; _message = null; });
    try { await _camera.stop(); } catch (_) {}
    final result = await LogisticsScanService.loadPreview(
      token: widget.token, branchId: widget.branchId, manifestId: _manifestId!, trackingCode: code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _preview = result.success && result.data['parcel'] is Map
          ? Map<String, dynamic>.from(result.data['parcel'] as Map) : null;
      _message = result.success ? null : result.message;
      _success = false;
    });
  }

  Future<void> _confirmLoad() async {
    final parcel = _preview;
    if (_busy || parcel == null || _manifestId == null) return;
    final code = parcel['tracking_code']?.toString() ?? '';
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Confirm parcel loaded?'),
      content: Text('Confirm only after $code is physically inside the assigned vehicle/load staging area for manifest ${parcel['manifest_code']}.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mark loaded')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final result = await LogisticsScanService.loadParcel(
      token: widget.token, branchId: widget.branchId, manifestId: _manifestId!, trackingCode: code);
    if (!mounted) return;
    setState(() { _busy = false; _preview = null; _message = result.message; _success = result.success; _tracking.clear(); });
    if (result.success) await _loadManifests();
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? selected;
    for (final manifest in _manifests) {
      if (_id(manifest['id']) == _manifestId) {
        selected = manifest;
        break;
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Load Linehaul Manifest'), actions: [IconButton(onPressed: _busy ? null : _loadManifests, icon: const Icon(Icons.refresh))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(widget.branchName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 4),
        const Text('Scan every parcel while physically loading it. The manifest becomes READY only when Expected = Loaded.', style: TextStyle(color: Color(0xFF65748A))),
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(color: _teal),
        if (_message != null) ...[
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _success ? const Color(0xFFE7F9F1) : const Color(0xFFFFF3E8), borderRadius: BorderRadius.circular(12)), child: Text(_message!)),
        ],
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          value: _manifestId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Outbound manifest', border: OutlineInputBorder()),
          items: _manifests.map((m) => DropdownMenuItem<int>(value: _id(m['id']), child: Text('${m['code']} → ${m['to']} (${m['loaded']}/${m['expected']})', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: _busy ? null : (v) => setState(() { _manifestId = v; _preview = null; _message = null; }),
        ),
        if (selected != null) ...[
          const SizedBox(height: 10),
          Text('Expected ${selected['expected']} · Loaded ${selected['loaded']} · Status ${selected['status']}', style: const TextStyle(fontWeight: FontWeight.w700, color: _navy)),
        ],
        const SizedBox(height: 16),
        if (_scanning) ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(height: 260, child: MobileScanner(
          controller: _camera,
          onDetect: (capture) {
            if (_busy || !_scanning) return;
            for (final barcode in capture.barcodes) {
              final value = barcode.rawValue;
              if (value != null && value.trim().isNotEmpty) { _previewCode(value); break; }
            }
          },
        ))),
        if (_scanning) const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _busy || _manifestId == null ? null : () => _setCamera(!_scanning), icon: Icon(_scanning ? Icons.stop_circle_outlined : Icons.camera_alt_outlined), label: Text(_scanning ? 'Stop camera' : 'Open loading camera')),
        const SizedBox(height: 12),
        TextField(controller: _tracking, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Or type parcel tracking code', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: _teal), onPressed: _busy || _manifestId == null ? null : () => _previewCode(_tracking.text), child: const Text('Verify parcel')),
        if (_preview != null) ...[
          const SizedBox(height: 18),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ready to load', style: TextStyle(fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(height: 8),
            Text('${_preview!['tracking_code']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('${_preview!['from']} → ${_preview!['to']}'),
            Text('Final destination: ${_preview!['final_destination'] ?? '—'}'),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: _teal), onPressed: _busy ? null : _confirmLoad, icon: const Icon(Icons.local_shipping_outlined), label: const Text('Confirm physically loaded'))),
          ]))),
        ],
      ]),
    );
  }
}
