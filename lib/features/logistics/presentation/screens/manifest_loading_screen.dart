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

  List<Map<String, dynamic>> _manifests = [];
  int? _manifestId;
  final _count = TextEditingController();
  final _camera = MobileScannerController(autoStart: false);
  final _tracking = TextEditingController();
  Map<String, dynamic>? _preview;
  String? _message;
  bool _success = false;
  bool _busy = false;
  bool _exceptionMode = false;
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
    _count.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  int? _id(dynamic value) => int.tryParse(value?.toString() ?? '');
  int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  Map<String, dynamic>? get _selected {
    for (final manifest in _manifests) {
      if (_id(manifest['id']) == _manifestId) return manifest;
    }
    return null;
  }

  Future<void> _loadManifests() async {
    setState(() => _busy = true);
    final result = await LogisticsScanService.manifests(
      token: widget.token,
      branchId: widget.branchId,
    );
    if (!mounted) return;
    final rows = result.success ? _rows(result.data['manifests']) : <Map<String, dynamic>>[];
    var selected = _manifestId;
    if (!rows.any((m) => _id(m['id']) == selected)) {
      selected = rows.isEmpty ? null : _id(rows.first['id']);
    }
    final selectedRow = rows.where((m) => _id(m['id']) == selected).toList();
    setState(() {
      _busy = false;
      _manifests = rows;
      _manifestId = selected;
      _count.text = selectedRow.isEmpty ? '' : _int(selectedRow.first['expected']).toString();
      _message = result.success ? null : result.message;
      _success = false;
    });
  }

  Future<void> _setCamera(bool active) async {
    if (_busy || _manifestId == null || !_exceptionMode) return;
    if (!active) {
      try { await _camera.stop(); } catch (_) {}
      if (mounted) setState(() => _scanning = false);
      return;
    }
    setState(() {
      _scanning = true;
      _preview = null;
      _message = null;
    });
    try {
      await _camera.start();
    } catch (_) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _message = 'Camera unavailable. Grant camera permission or type the parcel tracking code.';
          _success = false;
        });
      }
    }
  }

  Future<void> _previewExceptionParcel(String raw) async {
    final code = raw.trim().toUpperCase();
    if (_busy || _manifestId == null || !RegExp(r'^SHP-[0-9]{8}-[0-9]{6,}$').hasMatch(code)) {
      if (mounted) {
        setState(() {
          _message = 'Scan a valid ShopHop Parcel QR.';
          _success = false;
        });
      }
      return;
    }
    setState(() {
      _busy = true;
      _scanning = false;
      _preview = null;
      _tracking.text = code;
      _message = null;
    });
    try { await _camera.stop(); } catch (_) {}
    final result = await LogisticsScanService.loadPreview(
      token: widget.token,
      branchId: widget.branchId,
      manifestId: _manifestId!,
      trackingCode: code,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _preview = result.success && result.data['parcel'] is Map
          ? Map<String, dynamic>.from(result.data['parcel'] as Map)
          : null;
      _message = result.success ? null : result.message;
      _success = false;
    });
  }

  Future<void> _confirmExceptionParcel() async {
    final parcel = _preview;
    if (_busy || parcel == null || _manifestId == null) return;
    final code = parcel['tracking_code']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm exception parcel loaded?'),
        content: Text('Confirm only after $code is physically inside the load for manifest ${parcel['manifest_code']}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mark loaded')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final result = await LogisticsScanService.loadParcel(
      token: widget.token,
      branchId: widget.branchId,
      manifestId: _manifestId!,
      trackingCode: code,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _preview = null;
      _message = result.message;
      _success = result.success;
      _tracking.clear();
    });
    if (result.success) await _loadManifests();
  }

  Future<void> _confirmBatch() async {
    final manifest = _selected;
    final count = int.tryParse(_count.text.trim());
    if (_busy || manifest == null || count == null || count < 1) {
      setState(() {
        _message = 'Enter the physical parcel count loaded into this manifest.';
        _success = false;
      });
      return;
    }

    final expected = _int(manifest['expected']);
    if (count != expected) {
      setState(() {
        _message = 'Physical count is $count but this manifest expects $expected. Do not confirm the batch. Use individual Parcel QR scanning for exception reconciliation.';
        _success = false;
      });
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm complete batch loaded?'),
        content: Text('You are confirming that all $expected parcels for ${manifest['code']} are physically present in the load staging area / assigned vehicle.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm batch')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final result = await LogisticsScanService.batchLoad(
      token: widget.token,
      branchId: widget.branchId,
      manifestId: _manifestId!,
      physicalCount: count,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.message;
      _success = result.success;
    });
    if (result.success) await _loadManifests();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final expected = selected == null ? 0 : _int(selected['expected']);
    final loaded = selected == null ? 0 : _int(selected['loaded']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Load Linehaul Manifest'),
        actions: [IconButton(onPressed: _busy ? null : _loadManifests, icon: const Icon(Icons.refresh))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.branchName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _navy)),
          const SizedBox(height: 4),
          const Text('Fast normal flow: verify the physical batch count once. Individual Parcel QR scans are reserved for count mismatches or exceptions.', style: TextStyle(color: Color(0xFF65748A))),
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
          DropdownButtonFormField<int>(
            value: _manifestId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Outbound manifest', border: OutlineInputBorder()),
            items: _manifests.map((m) => DropdownMenuItem<int>(
              value: _id(m['id']),
              child: Text('${m['code']} → ${m['to']} (${m['loaded']}/${m['expected']})', overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: _busy ? null : (value) {
              setState(() {
                _manifestId = value;
                final row = _selected;
                _count.text = row == null ? '' : _int(row['expected']).toString();
                _preview = null;
                _message = null;
                _success = false;
              });
            },
          ),
          const SizedBox(height: 16),
          if (selected != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${selected['code']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navy)),
                    Text('${widget.branchName} → ${selected['to'] ?? 'Destination'}'),
                    const SizedBox(height: 10),
                    Text('Expected: $expected parcels'),
                    Text('Already marked loaded: $loaded'),
                    Text('Status: ${selected['status']}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _count,
              keyboardType: TextInputType.number,
              enabled: !_busy && selected['status'] != 'ready',
              decoration: const InputDecoration(
                labelText: 'Physical parcel count loaded',
                helperText: 'This must match the manifest expected count for normal batch confirmation.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _teal),
                onPressed: _busy || selected['status'] == 'ready' ? null : _confirmBatch,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(selected['status'] == 'ready' ? 'Manifest already ready' : 'Confirm complete batch loaded'),
              ),
            ),
            if (selected['status'] != 'ready') ...[
              const SizedBox(height: 14),
              const Divider(),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _exceptionMode,
                onChanged: _busy ? null : (value) async {
                  if (!value) {
                    try { await _camera.stop(); } catch (_) {}
                  }
                  if (!mounted) return;
                  setState(() {
                    _exceptionMode = value;
                    _scanning = false;
                    _preview = null;
                    _message = null;
                  });
                },
                title: const Text('Exception / reconciliation mode', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Use individual Parcel QR only when the physical count does not match or a specific parcel needs verification.'),
              ),
              if (_exceptionMode) ...[
                if (_scanning) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 260,
                      child: MobileScanner(
                        controller: _camera,
                        onDetect: (capture) {
                          if (_busy || !_scanning) return;
                          for (final barcode in capture.barcodes) {
                            final value = barcode.rawValue;
                            if (value != null && value.trim().isNotEmpty) {
                              _previewExceptionParcel(value);
                              break;
                            }
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _setCamera(!_scanning),
                  icon: Icon(_scanning ? Icons.stop_circle_outlined : Icons.qr_code_scanner),
                  label: Text(_scanning ? 'Stop exception camera' : 'Scan exception Parcel QR'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _tracking,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Or type parcel tracking code',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy ? null : () => _previewExceptionParcel(_tracking.text),
                  child: const Text('Verify exception parcel'),
                ),
                if (_preview != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_preview!['tracking_code']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                          Text('${_preview!['from']} → ${_preview!['to']}'),
                          Text('Final destination: ${_preview!['final_destination'] ?? '—'}'),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _busy ? null : _confirmExceptionParcel,
                              child: const Text('Confirm this parcel loaded'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ] else
            const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No open outbound manifests.'))),
        ],
      ),
    );
  }
}
