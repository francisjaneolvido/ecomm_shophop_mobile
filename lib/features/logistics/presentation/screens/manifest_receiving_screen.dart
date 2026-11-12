import 'package:shophop/shared/widgets/shop_hop_scanner.dart';
import 'package:shophop/shared/widgets/shop_hop_scan_feedback.dart';
import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';
import 'package:shophop/shared/widgets/shop_hop_workflow.dart';
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
  State<ManifestReceivingScreen> createState() =>
      _ManifestReceivingScreenState();
}

class _ManifestReceivingScreenState extends State<ManifestReceivingScreen> {
  static const _navy = AppColors.navy;
  static const _teal = AppColors.tealDark;

  final _camera = MobileScannerController(autoStart: false);
  final _manifestCode = TextEditingController();
  final _count = TextEditingController();

  Map<String, dynamic>? _manifest;
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
  bool _scanning = false;

  @override
  void dispose() {
    _scanScroll.dispose();
    _camera.dispose();
    _manifestCode.dispose();
    _count.dispose();
    super.dispose();
  }

  int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  Future<void> _setCamera(bool active) async {
    if (_busy) return;
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
      _needsRecheck = false;
      _message = null;
      _manifest = null;
    });
    try {
      await _camera.start();
    } catch (_) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _message =
              'Camera unavailable. Grant permission or type the Manifest code.';
          _success = false;
        });
      }
    }
  }

  Future<void> _scan(String raw) async {
    final code = raw.trim().toUpperCase();
    if (_busy) return;
    if (code.isEmpty || !code.startsWith('MF-')) {
      if (mounted) {
        setState(() {
          _message = 'Scan a valid ShopHop Manifest QR (MF-...).';
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
      _manifest = null;
      _message = null;
      _manifestCode.text = code;
    });
    try {
      await _camera.stop();
    } catch (_) {}

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
      _needsRecheck = false;
      _manifest = manifest;
      _message = result.success ? null : result.message;
      _success = false;
      if (manifest != null) _count.text = _int(manifest['expected']).toString();
    });
    if (_manifest != null) _revealReview();
    ShopHopScanFeedback.instance.notify(
      _manifest != null ? ScanFeedbackEvent.verified : ScanFeedbackEvent.error,
      reference: code,
    );
  }

  Future<void> _acknowledgeArrival() async {
    final manifest = _manifest;
    if (_busy || _needsRecheck || manifest == null) return;
    final code = manifest['manifest_code']?.toString() ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          manifest['transport_mode'] == 'road'
              ? 'Acknowledge road arrival?'
              : 'Confirm carrier cargo arrival?',
        ),
        content: Text(
          manifest['transport_mode'] == 'road'
              ? 'Confirm only after vehicle ${manifest['vehicle_code'] ?? ''} (${manifest['plate_number'] ?? ''}) and manifest $code physically arrive at ${widget.branchName}.'
              : 'Confirm only after actual ${manifest['transport_mode']?.toString().toUpperCase()} carrier ${manifest['carrier_name'] ?? ''} has delivered booking ${manifest['booking_reference'] ?? ''} and manifest $code to ${widget.branchName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm arrival'),
          ),
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
      _needsRecheck = !result.success;
      _success = result.success;
    });
    ShopHopScanFeedback.instance.notify(
      result.success ? ScanFeedbackEvent.complete : ScanFeedbackEvent.error,
      reference: '$code:arrival',
    );
    _showResult();
  }

  Future<void> _receiveAll() async {
    final manifest = _manifest;
    final count = int.tryParse(_count.text.trim());
    if (_busy || _needsRecheck || manifest == null) return;
    if (count == null || count < 1) {
      setState(() {
        _message = 'Enter the actual parcel count received.';
        _success = false;
      });
      ShopHopScanFeedback.instance.notify(
        ScanFeedbackEvent.error,
        reference: manifest['manifest_code']?.toString(),
      );
      _showResult();
      return;
    }
    final expected = _int(manifest['expected']);
    if (count != expected) {
      _showResult();
      ShopHopScanFeedback.instance.notify(
        ScanFeedbackEvent.error,
        reference: '${manifest['manifest_code']}:receipt',
      );
      setState(() {
        _message =
            'Physical count is $count but expected is $expected. Do NOT Receive All. Return to the normal Parcel Receiving scanner and scan individual parcel QRs for exception reconciliation.';
        _success = false;
      });
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receive entire manifest intact?'),
        content: Text(
          'You are confirming that all $expected parcels are physically present and intact at ${widget.branchName}. This updates all parcel custody records at once.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Review'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Receive all intact'),
          ),
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
      _needsRecheck = !result.success;
      _success = result.success;
    });
    ShopHopScanFeedback.instance.notify(
      result.success ? ScanFeedbackEvent.complete : ScanFeedbackEvent.error,
      reference: '${manifest['manifest_code']}:receipt',
    );
    _showResult();
  }

  @override
  Widget build(BuildContext context) {
    final m = _manifest;
    final arrived = m?['arrival_acknowledged'] == true;
    final completed = m?['completed'] == true;

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
        title: const Text('Inbound Manifest'),
      ),
      body: ListView(
        controller: _scanScroll,
        padding: const EdgeInsets.all(12),
        children: [
          ShopHopWorkflowHeader(
            title: 'Inbound manifest receiving',
            subtitle: widget.branchName,
            icon: Icons.move_to_inbox_outlined,
            badge: 'Scan → arrival → count',
          ),
          const SizedBox(height: 10),
          const ShopHopSurface(
            padding: EdgeInsets.all(12),
            child: Text(
              'Only the destination facility confirms physical arrival. '
              'Scan the Manifest QR, verify the shipment, then receive the actual parcel count.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B6B7B)),
            ),
          ),
          const SizedBox(height: 14),
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
                      _count.clear();
                      _setCamera(true);
                    }
                  : _needsRecheck
                  ? () => _scan(_manifestCode.text)
                  : null,
              nextLabel: _success ? 'Scan next manifest' : 'Recheck manifest',
            ),
            const SizedBox(height: 12),
          ],
          if (m == null) ...[
            const Text(
              'STEP 1  Scan or enter Manifest QR',
              style: TextStyle(
                color: _navy,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 9),
            ShopHopCameraPanel(
              controller: _camera,
              scanning: _scanning,
              busy: _busy,
              instruction: 'Scan the inbound Manifest QR at the destination',
              onToggle: () => _setCamera(!_scanning),
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
            const SizedBox(height: 12),
            TextField(
              controller: _manifestCode,
              onChanged: (_) => setState(() {
                _manifest = null;
                _message = null;
                _success = false;
              }),
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
          ],
          if (m != null) ...[
            const SizedBox(height: 16),
            ShopHopSurface(
              padding: const EdgeInsets.all(14),
              child: Column(
                key: _reviewKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _busy ? null : () => _setCamera(true),
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Scan another manifest'),
                    ),
                  ),
                  Text(
                    '${m['manifest_code']}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  Text(
                    '${m['from']} → ${m['to']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF7EE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(m['transport_mode'] ?? 'road').toString().toUpperCase()} · ${(m['trip_status'] ?? '').toString().replaceAll('_', ' ')}',
                      style: const TextStyle(
                        color: _teal,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (m['transport_mode'] != 'road') ...[
                    Text('Carrier: ${m['carrier_name'] ?? '—'}'),
                    Text('Booking: ${m['booking_reference'] ?? '—'}'),
                  ] else ...[
                    Text('Trip: ${m['trip_code']}'),
                    Text(
                      'Vehicle: ${m['vehicle_code']} · ${m['plate_number']}',
                    ),
                    Text('Driver: ${m['driver']}'),
                  ],
                  Text(
                    'Expected: ${m['expected']} · Received: ${m['received']}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!arrived && !completed) ...[
              const Text(
                'STEP 2  Confirm actual arrival',
                style: TextStyle(
                  color: _navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _teal),
                  onPressed: _busy || _needsRecheck
                      ? null
                      : _acknowledgeArrival,
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Confirm destination arrival'),
                ),
              ),
            ],
            if (arrived && !completed) ...[
              const Text(
                'STEP 3  Confirm received parcel count',
                style: TextStyle(
                  color: _navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _count,
                keyboardType: TextInputType.number,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Physical parcel count received',
                  helperText:
                      'Must match Expected for fast intact-batch receipt.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _teal),
                  onPressed: _busy || _needsRecheck ? null : _receiveAll,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Receive all intact'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'If the physical count differs or a parcel is damaged/wrong, do not use Receive All. Use the normal Parcel Receiving scanner for individual exception reconciliation.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B6B7B)),
              ),
            ],
            if (completed)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: _teal),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Transport manifest received and completed. Vehicle release applies only to road trips.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
