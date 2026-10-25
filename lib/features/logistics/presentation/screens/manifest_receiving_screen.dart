import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shophop/features/logistics/data/logistics_scan_service.dart';

class ManifestReceivingScreen extends StatefulWidget {
  const ManifestReceivingScreen({
    super.key,
    required this.token,
    required this.branchId,
    required this.branchName,
  });

  final String token;
  final int branchId;
  final String branchName;

  @override
  State<ManifestReceivingScreen> createState() => _ManifestReceivingScreenState();
}

class _ManifestReceivingScreenState extends State<ManifestReceivingScreen> {
  static const _navy = Color(0xFF172B4D);
  static const _teal = Color(0xFF159E8B);

  final _camera = MobileScannerController(autoStart: false);
  final _manifestCode = TextEditingController();
  final _count = TextEditingController();

  Map<String, dynamic>? _manifest;
  String? _message;
  bool _success = false;
  bool _busy = false;
  bool _scanning = false;

  @override
  void dispose() {
    _camera.dispose();
    _manifestCode.dispose();
    _count.dispose();
    super.dispose();
  }

  int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  Future<void> _setCamera(bool active) async {
    if (_busy) return;
    if (!active) {
      try { await _camera.stop(); } catch (_) {}
      if (mounted) setState(() => _scanning = false);
      return;
    }
    setState(() {
      _scanning = true;
      _message = null;
      _manifest = null;
    });
    try {
      await _camera.start();
    } catch (_) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _message = 'Camera unavailable. Grant permission or type the Manifest code.';
          _success = false;
        });
      }
    }
  }

  Future<void> _scan(String raw) async {
    final code = raw.trim().toUpperCase();
    if (_busy || code.isEmpty || !code.startsWith('MF-')) {
      if (mounted) setState(() {
        _message = 'Scan a valid ShopHop Manifest QR (MF-...).';
        _success = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _scanning = false;
      _manifest = null;
      _message = null;
      _manifestCode.text = code;
    });
    try { await _camera.stop(); } catch (_) {}

    final result = await LogisticsScanService.inboundManifestPreview(
      token: widget.token,
      branchId: widget.branchId,
      manifestCode: code,
    );
    if (!mounted) return;
    final manifest = result.success && result.data['manifest'] is Map
        ? Map<String, dynamic>.from(result.data['manifest'] as Map)
        : null;
    setState(() {
      _busy = false;
      _manifest = manifest;
      _message = result.success ? null : result.message;
      _success = false;
      if (manifest != null) _count.text = _int(manifest['expected']).toString();
    });
  }

  Future<void> _acknowledgeArrival() async {
    final manifest = _manifest;
    if (_busy || manifest == null) return;
    final code = manifest['manifest_code']?.toString() ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acknowledge Linehaul arrival?'),
        content: Text('Confirm only if vehicle ${manifest['vehicle_code'] ?? ''} (${manifest['plate_number'] ?? ''}) and manifest $code are physically at ${widget.branchName} now.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm arrival')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final result = await LogisticsScanService.acknowledgeManifestArrival(
      token: widget.token,
      branchId: widget.branchId,
      manifestCode: code,
    );
    if (!mounted) return;
    final updated = result.success && result.data['manifest'] is Map
        ? Map<String, dynamic>.from(result.data['manifest'] as Map)
        : manifest;
    setState(() {
      _busy = false;
      _manifest = updated;
      _message = result.message;
      _success = result.success;
    });
  }

  Future<void> _receiveAll() async {
    final manifest = _manifest;
    final count = int.tryParse(_count.text.trim());
    if (_busy || manifest == null || count == null || count < 1) return;
    final expected = _int(manifest['expected']);
    if (count != expected) {
      setState(() {
        _message = 'Physical count is $count but expected is $expected. Do NOT Receive All. Return to the normal Parcel Receiving scanner and scan individual parcel QRs for exception reconciliation.';
        _success = false;
      });
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receive entire manifest intact?'),
        content: Text('You are confirming that all $expected parcels are physically present and intact at ${widget.branchName}. This updates all parcel custody records at once.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Review')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Receive all intact')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final result = await LogisticsScanService.receiveManifestAll(
      token: widget.token,
      branchId: widget.branchId,
      manifestCode: manifest['manifest_code']?.toString() ?? '',
      physicalCount: count,
    );
    if (!mounted) return;
    final updated = result.success && result.data['manifest'] is Map
        ? Map<String, dynamic>.from(result.data['manifest'] as Map)
        : manifest;
    setState(() {
      _busy = false;
      _manifest = updated;
      _message = result.message;
      _success = result.success;
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = _manifest;
    final arrived = m?['arrival_acknowledged'] == true;
    final completed = m?['completed'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Receive Linehaul Manifest')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.branchName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _navy)),
          const SizedBox(height: 4),
          const Text('Destination Branch/Hub owns the arrival scan. Driver cannot mark arrival. For a normal intact batch, scan one Manifest QR and verify the physical count.', style: TextStyle(color: Color(0xFF65748A))),
          const SizedBox(height: 16),
          if (_message != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _success ? const Color(0xFFE8F7F1) : const Color(0xFFFFF3E8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(_message!),
            ),
            const SizedBox(height: 12),
          ],
          if (_scanning)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 300,
                child: MobileScanner(
                  controller: _camera,
                  onDetect: (capture) {
                    if (_busy || !_scanning) return;
                    for (final barcode in capture.barcodes) {
                      final value = barcode.rawValue;
                      if (value != null && value.trim().isNotEmpty) {
                        _scan(value);
                        break;
                      }
                    }
                  },
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _setCamera(!_scanning),
              icon: Icon(_scanning ? Icons.stop_circle_outlined : Icons.qr_code_scanner),
              label: Text(_scanning ? 'Stop camera' : 'Scan inbound Manifest QR'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _manifestCode,
            textCapitalization: TextCapitalization.characters,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Or type Manifest code',
              hintText: 'MF-20261025-001-001',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _teal),
            onPressed: _busy ? null : () => _scan(_manifestCode.text),
            child: const Text('Verify manifest'),
          ),
          if (m != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m['manifest_code']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _navy)),
                    Text('${m['from']} → ${m['to']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Trip: ${m['trip_code']} · ${m['trip_status']}'),
                    Text('Vehicle: ${m['vehicle_code']} · ${m['plate_number']}'),
                    Text('Driver: ${m['driver']}'),
                    Text('Expected: ${m['expected']} · Received: ${m['received']}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!arrived && !completed)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _teal),
                  onPressed: _busy ? null : _acknowledgeArrival,
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Confirm destination arrival'),
                ),
              ),
            if (arrived && !completed) ...[
              TextField(
                controller: _count,
                keyboardType: TextInputType.number,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Physical parcel count received',
                  helperText: 'Must match Expected for fast intact-batch receipt.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _teal),
                  onPressed: _busy ? null : _receiveAll,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Receive all intact'),
                ),
              ),
              const SizedBox(height: 8),
              const Text('If the physical count differs or a parcel is damaged/wrong, do not use Receive All. Use the normal Parcel Receiving scanner for individual exception reconciliation.', style: TextStyle(fontSize: 12, color: Color(0xFF65748A))),
            ],
            if (completed)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Row(children: [Icon(Icons.check_circle, color: _teal), SizedBox(width: 8), Expanded(child: Text('Manifest completed. The vehicle is released and the Driver trip moves to History.'))]))),
          ],
        ],
      ),
    );
  }
}
