import 'package:shophop/shared/widgets/shop_hop_scanner.dart';
import 'package:shophop/shared/widgets/shop_hop_scan_feedback.dart';
import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';
import 'package:shophop/shared/widgets/shop_hop_workflow.dart';
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
  static const _navy = AppColors.navy;
  static const _teal = AppColors.tealDark;

  List<Map<String, dynamic>> _manifests = [];
  int? _manifestId;
  final _count = TextEditingController();
  final _camera = MobileScannerController(autoStart: false);
  final _tracking = TextEditingController();
  Map<String, dynamic>? _preview;
  String? _message;
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
    _scanScroll.dispose();
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

  Future<void> _loadManifests({bool keepResult = false}) async {
    setState(() => _busy = true);
    final result = await LogisticsScanService.manifests(
      token: widget.token,
      branchId: widget.branchId,
    );
    if (!mounted) return;
    final rows = result.success
        ? _rows(result.data['manifests'])
        : <Map<String, dynamic>>[];
    var selected = _manifestId;
    if (!rows.any((m) => _id(m['id']) == selected)) {
      selected = rows.isEmpty ? null : _id(rows.first['id']);
    }
    final selectedRow = rows.where((m) => _id(m['id']) == selected).toList();
    setState(() {
      _busy = false;
      _needsRecheck = false;
      _manifests = rows;
      _manifestId = selected;
      _count.text = selectedRow.isEmpty
          ? ''
          : _int(selectedRow.first['expected']).toString();
      if (!keepResult || !result.success) {
        _message = result.success ? null : result.message;
        _success = false;
      }
    });
  }

  Future<void> _setCamera(bool active) async {
    if (_busy || _manifestId == null || !_exceptionMode) return;
    if (!active) {
      try {
        await _camera.stop();
      } catch (_) {}
      if (mounted) setState(() => _scanning = false);
      return;
    }
    setState(() {
      _scanning = true;
      _success = false;
      _preview = null;
      _message = null;
    });
    try {
      await _camera.start();
    } catch (_) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _message =
              'Camera unavailable. Grant camera permission or type the parcel tracking code.';
          _success = false;
        });
      }
    }
  }

  Future<void> _previewExceptionParcel(String raw) async {
    final code = raw.trim().toUpperCase();
    if (_busy) return;
    if (_manifestId == null ||
        !RegExp(r'^SHP-[0-9]{8}-[0-9]{6,}$').hasMatch(code)) {
      if (mounted) {
        setState(() {
          _message = 'Scan a valid ShopHop Parcel QR.';
          ShopHopScanFeedback.instance.notify(
            ScanFeedbackEvent.error,
            reference: code,
          );
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
    try {
      await _camera.stop();
    } catch (_) {}
    final result = await LogisticsScanService.loadPreview(
      token: widget.token,
      branchId: widget.branchId,
      manifestId: _manifestId!,
      trackingCode: code,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _needsRecheck = false;
      _preview = result.success && result.data['parcel'] is Map
          ? Map<String, dynamic>.from(result.data['parcel'] as Map)
          : null;
      _message = result.success ? null : result.message;
      _success = false;
    });
    if (_preview != null) _revealReview();
    ShopHopScanFeedback.instance.notify(
      _preview != null ? ScanFeedbackEvent.verified : ScanFeedbackEvent.error,
      reference: code,
    );
  }

  Future<void> _confirmExceptionParcel() async {
    final parcel = _preview;
    if (_busy || _needsRecheck || parcel == null || _manifestId == null) return;
    final code = parcel['tracking_code']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm exception parcel loaded?'),
        content: Text(
          'Confirm only after $code is physically inside the load for manifest ${parcel['manifest_code']}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark loaded'),
          ),
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
      _preview = result.success ? null : parcel;
      _needsRecheck = !result.success;
      _message = result.message;
      _needsRecheck = !result.success;
      _success = result.success;
      if (result.success) _tracking.clear();
    });
    ShopHopScanFeedback.instance.notify(
      result.success ? ScanFeedbackEvent.complete : ScanFeedbackEvent.error,
      reference: code,
    );
    _showResult();
    if (result.success) await _loadManifests(keepResult: true);
  }

  Future<void> _confirmBatch() async {
    final manifest = _selected;
    final count = int.tryParse(_count.text.trim());
    if (_busy || _needsRecheck) return;
    if (manifest == null || count == null || count < 1) {
      setState(() {
        _message = 'Enter the physical parcel count loaded into this manifest.';
        _success = false;
      });
      return;
    }

    final expected = _int(manifest['expected']);
    if (count != expected) {
      _showResult();
      ShopHopScanFeedback.instance.notify(
        ScanFeedbackEvent.error,
        reference: manifest['code']?.toString(),
      );
      setState(() {
        _message =
            'Physical count is $count but this manifest expects $expected. Do not confirm the batch. Use individual Parcel QR scanning for exception reconciliation.';
        _success = false;
      });
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm complete batch loaded?'),
        content: Text(
          'You are confirming that all $expected parcels for ${manifest['code']} are physically present in the load staging area / assigned vehicle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm batch'),
          ),
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
      _needsRecheck = !result.success;
      _success = result.success;
    });
    ShopHopScanFeedback.instance.notify(
      result.success ? ScanFeedbackEvent.complete : ScanFeedbackEvent.error,
      reference: manifest['code']?.toString(),
    );
    _showResult();
    if (result.success) await _loadManifests(keepResult: true);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final expected = selected == null ? 0 : _int(selected['expected']);
    final loaded = selected == null ? 0 : _int(selected['loaded']);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.tealDark,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        title: const Text('Outbound Manifest Loading'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _loadManifests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        controller: _scanScroll,
        padding: const EdgeInsets.all(12),
        children: [
          ShopHopWorkflowHeader(
            title: 'Outbound manifest loading',
            subtitle: widget.branchName,
            icon: Icons.outbox_outlined,
            badge: 'Verify → count → confirm',
          ),
          const SizedBox(height: 10),
          const ShopHopSurface(
            padding: EdgeInsets.all(12),
            child: Text(
              'Normal flow: select a manifest, verify the physical count and confirm. '
              'Use individual Parcel QR reconciliation only for mismatches or exceptions.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B6B7B)),
            ),
          ),
          const SizedBox(height: 14),
          if (!_exceptionMode) const ShopHopScanPreferences(),
          if (_message != null) ...[
            ShopHopScanNotice(
              message: _message!,
              success: _success,
              onNext: _busy
                  ? null
                  : _success
                  ? () {
                      _loadManifests();
                    }
                  : _needsRecheck
                  ? () {
                      _exceptionMode && _preview != null
                          ? _previewExceptionParcel(_tracking.text)
                          : _loadManifests();
                    }
                  : null,
              nextLabel: _success ? 'Continue loading' : 'Recheck manifest',
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'STEP 1  Select outbound manifest',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _navy,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: ValueKey(_manifestId),
            initialValue: _manifestId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Outbound manifest',
              border: OutlineInputBorder(),
            ),
            items: _manifests
                .map(
                  (m) => DropdownMenuItem<int>(
                    value: _id(m['id']),
                    child: Text(
                      '${m['code']} → ${m['to']} (${m['loaded']}/${m['expected']})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) async {
                    setState(() {
                      _manifestId = value;
                      final row = _selected;
                      _count.text = row == null
                          ? ''
                          : _int(row['expected']).toString();
                      _preview = null;
                      _message = null;
                      _success = false;
                    });
                    await _loadManifests();
                  },
          ),
          const SizedBox(height: 16),
          if (selected != null) ...[
            ShopHopSurface(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selected['code']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  Text(
                    '${widget.branchName} → ${selected['to'] ?? 'Destination'}',
                  ),
                  const SizedBox(height: 10),
                  Text('Expected: $expected parcels'),
                  Text('Already marked loaded: $loaded'),
                  Text('Status: ${selected['status']}'),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: expected <= 0
                        ? 0
                        : (loaded / expected).clamp(0.0, 1.0),
                    backgroundColor: AppColors.grayBg,
                    color: _teal,
                    minHeight: 5,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'STEP 2  Match physical parcel count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _navy,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _count,
              keyboardType: TextInputType.number,
              enabled: !_busy && selected['status'] != 'ready',
              decoration: const InputDecoration(
                labelText: 'Physical parcel count loaded',
                helperText:
                    'This must match the manifest expected count for normal batch confirmation.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _teal),
                onPressed:
                    _busy || _needsRecheck || selected['status'] == 'ready'
                    ? null
                    : _confirmBatch,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(
                  selected['status'] == 'ready'
                      ? 'Manifest already ready'
                      : 'STEP 3  Confirm complete load',
                ),
              ),
            ),
            if (selected['status'] != 'ready') ...[
              const SizedBox(height: 14),
              const Divider(),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _exceptionMode,
                onChanged: _busy
                    ? null
                    : (value) async {
                        if (!value) {
                          try {
                            await _camera.stop();
                          } catch (_) {}
                        }
                        if (!mounted) return;
                        setState(() {
                          _exceptionMode = value;
                          _scanning = false;
                          _preview = null;
                          if (!_needsRecheck) _message = null;
                        });
                      },
                title: const Text(
                  'Exception / reconciliation mode',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Use individual Parcel QR only when the physical count does not match or a specific parcel needs verification.',
                ),
              ),
              if (_exceptionMode) ...[
                if (_preview == null) ...[
                  ShopHopCameraPanel(
                    controller: _camera,
                    scanning: _scanning,
                    busy: _busy,
                    instruction:
                        'Scan an exception parcel QR for this manifest',
                    onToggle: () => _setCamera(!_scanning),
                    onDetect: (capture) {
                      if (_busy || !_scanning) return;
                      for (final barcode in capture.barcodes) {
                        final code = barcode.rawValue;
                        if (code != null && code.trim().isNotEmpty) {
                          _previewExceptionParcel(code);
                          break;
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _tracking,
                    onChanged: (_) => setState(() {
                      _preview = null;
                      _message = null;
                      _success = false;
                    }),
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Or type parcel tracking code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _previewExceptionParcel(_tracking.text),
                    child: const Text('Verify exception parcel'),
                  ),
                ],
                if (_preview != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    key: _reviewKey,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _busy ? null : () => _setCamera(true),
                              icon: const Icon(Icons.qr_code_scanner, size: 18),
                              label: const Text('Scan another parcel'),
                            ),
                          ),
                          Text(
                            '${_preview!['tracking_code']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          Text('${_preview!['from']} → ${_preview!['to']}'),
                          Text(
                            'Final destination: ${_preview!['final_destination'] ?? '—'}',
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _busy || _needsRecheck
                                  ? null
                                  : _confirmExceptionParcel,
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
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No open outbound manifests.'),
              ),
            ),
        ],
      ),
    );
  }
}
