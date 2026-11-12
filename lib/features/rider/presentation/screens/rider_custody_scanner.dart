import 'package:shophop/shared/widgets/shop_hop_scanner.dart';
import 'package:shophop/shared/widgets/shop_hop_scan_feedback.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/rider/data/services/rider_custody_scan_service.dart';

class RiderCustodyScanner extends StatefulWidget {
  const RiderCustodyScanner({
    super.key,
    required this.token,
    required this.onConfirmed,
    this.expectedTrackingCode,
    this.expectedAction,
  });

  final String token;
  final Future<void> Function() onConfirmed;
  final String? expectedTrackingCode;
  final String? expectedAction;

  @override
  State<RiderCustodyScanner> createState() => _RiderCustodyScannerState();
}

class _RiderCustodyScannerState extends State<RiderCustodyScanner> {
  final MobileScannerController _camera = MobileScannerController(
    autoStart: false,
  );

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
  bool _scanning = false;
  bool _busy = false;
  bool _success = false;
  String? _message;
  Map<String, dynamic>? _handoff;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
  }

  bool _validTrackingCode(String value) =>
      RegExp(r'^SHP-[0-9]{8}-[0-9]{6,}$').hasMatch(value.trim().toUpperCase());

  Future<void> _startCamera() async {
    if (!mounted || _busy || _scanning) return;
    setState(() {
      _handoff = null;
      _message = null;
      _success = false;
      _scanning = true;
    });
    try {
      await _camera.start();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _success = false;
        _message =
            'Camera unavailable. Allow camera permission, then open the scanner again.';
      });
    }
  }

  Future<void> _stopCamera() async {
    if (mounted && _scanning) setState(() => _scanning = false);
    try {
      await _camera.stop();
    } catch (_) {
      // Camera can already be stopped after route/tab changes.
    }
  }

  Future<void> _preview(String rawCode) async {
    if (_busy) return;
    final code = rawCode.trim().toUpperCase();
    if (!_validTrackingCode(code)) {
      ShopHopScanFeedback.instance.notify(
        ScanFeedbackEvent.error,
        reference: code,
      );
      await _stopCamera();
      if (mounted) {
        setState(() {
          _success = false;
          _message =
              'That is not a ShopHop parcel QR. Scan the shipping label.';
        });
      }
      return;
    }

    if (widget.expectedTrackingCode != null &&
        code != widget.expectedTrackingCode!.trim().toUpperCase()) {
      await _stopCamera();
      if (mounted) {
        setState(() {
          _handoff = null;
          _success = false;
          _message =
              'This is a different parcel. Scan ${widget.expectedTrackingCode} for this delivery.';
        });
      }
      return;
    }

    setState(() => _busy = true);
    await _stopCamera();
    if (!mounted) return;
    setState(() {
      _busy = true;
      _handoff = null;
      _message = null;
    });

    final response = await RiderCustodyScanService.preview(
      token: widget.token,
      trackingCode: code,
    );
    if (!mounted) return;

    final rawHandoff = response.data['handoff'];
    final matchesAction =
        widget.expectedAction == null ||
        (rawHandoff is Map && rawHandoff['action'] == widget.expectedAction);
    setState(() {
      _busy = false;
      _needsRecheck = false;
      _handoff = response.success && rawHandoff is Map && matchesAction
          ? Map<String, dynamic>.from(rawHandoff)
          : null;
      _success = false;
      _message = response.success
          ? (matchesAction
                ? null
                : 'This parcel is not awaiting collection from the branch. Refresh the delivery.')
          : response.message;
    });
    if (_handoff != null) _revealReview();
    ShopHopScanFeedback.instance.notify(
      _handoff != null ? ScanFeedbackEvent.verified : ScanFeedbackEvent.error,
      reference: code,
    );
  }

  Future<void> _confirm() async {
    final handoff = _handoff;
    if (_busy || _needsRecheck || handoff == null) return;

    final tracking = handoff['tracking_code']?.toString() ?? '';
    final action = handoff['action']?.toString() ?? '';
    if (!_validTrackingCode(tracking) || action.isEmpty) return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm waybill & physical custody?'),
        content: Text(
          '${handoff['title'] ?? 'Parcel handoff'}\n\n'
          '${handoff['from'] ?? 'Origin'} → ${handoff['to'] ?? 'Destination'}\n\n'
          'Verify the waybill details on screen and on the parcel. Confirm only if $tracking is physically in your possession now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              handoff['confirm_label']?.toString() ?? 'Confirm custody',
            ),
          ),
        ],
      ),
    );

    if (!mounted || accepted != true) return;
    setState(() {
      _busy = true;
      _message = null;
    });

    final response = await RiderCustodyScanService.confirm(
      token: widget.token,
      trackingCode: tracking,
      expectedAction: action,
    );
    if (!mounted) return;

    setState(() {
      _busy = false;
      _handoff = response.success ? null : handoff;
      _needsRecheck = !response.success;
      _success = response.success;
      _message = response.success && action == 'seller_pickup'
          ? 'Pickup recorded. Bring this parcel to ${handoff['center'] ?? 'your assigned branch'}. Branch staff must scan it to confirm receipt.'
          : response.message;
    });

    ShopHopScanFeedback.instance.notify(
      response.success ? ScanFeedbackEvent.complete : ScanFeedbackEvent.error,
      reference: tracking,
    );
    _showResult();
    if (response.success) {
      await widget.onConfirmed();
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'seller_pickup':
        return const Color(0xFF0B7C70);
      case 'delivery_handoff':
        return const Color(0xFF76522E);
      default:
        return AppColors.tealDark;
    }
  }

  Widget _notice(String text, {required bool success}) => ShopHopScanNotice(
    message: text,
    success: success,
    onNext: _busy
        ? null
        : success
        ? _startCamera
        : _needsRecheck && _handoff != null
        ? () => _preview(_handoff!['tracking_code'].toString())
        : null,
    nextLabel: success ? 'Scan next' : 'Recheck parcel',
  );

  Widget _cameraCard() => Column(
    children: [
      ShopHopCameraPanel(
        controller: _camera,
        scanning: _scanning,
        busy: _busy,
        instruction: 'Scan the QR printed on the parcel waybill',
        onToggle: () => _scanning ? _stopCamera() : _startCamera(),
        onDetect: (capture) {
          if (_busy || !_scanning) return;
          for (final barcode in capture.barcodes) {
            final code = barcode.rawValue;
            if (code != null && code.trim().isNotEmpty) {
              _preview(code);
              break;
            }
          }
        },
      ),
    ],
  );

  Widget _handoffCard(Map<String, dynamic> handoff) {
    final action = handoff['action']?.toString() ?? '';
    final color = _actionColor(action);
    return Container(
      key: _reviewKey,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
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
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inventory_2_outlined, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      handoff['title']?.toString() ?? 'Parcel custody handoff',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      handoff['tracking_code']?.toString() ?? '',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _routeBox(
                  'FROM',
                  handoff['from']?.toString() ?? 'Origin',
                  Icons.store_mall_directory_outlined,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded, color: color),
              ),
              Expanded(
                child: _routeBox(
                  'TO',
                  handoff['to']?.toString() ?? 'Destination',
                  Icons.flag_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          if (handoff['waybill'] is Map) ...[
            _waybillCard(
              Map<String, dynamic>.from(handoff['waybill'] as Map),
              color,
            ),
            const SizedBox(height: 13),
          ],
          Text(
            handoff['instruction']?.toString() ??
                'Verify the physical parcel before confirming custody.',
            style: const TextStyle(
              color: Color(0xFF65748A),
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: _busy || _needsRecheck ? null : _confirm,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(
                handoff['confirm_label']?.toString() ?? 'Confirm custody',
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _handoff = null);
                      await _startCamera();
                    },
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Wrong parcel — scan again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waybillCard(Map<String, dynamic> waybill, Color color) {
    final rawItems = waybill['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final cod = waybill['cod_amount']?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, size: 18, color: color),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'WAYBILL VERIFICATION',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                waybill['order_number']?.toString() ?? '',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _waybillLine('Seller', waybill['seller_name']),
          if ((waybill['seller_address']?.toString() ?? '').isNotEmpty)
            _waybillLine('Seller address', waybill['seller_address']),
          _waybillLine('Recipient', waybill['buyer_name']),
          if ((waybill['buyer_address']?.toString() ?? '').isNotEmpty)
            _waybillLine('Ship to', waybill['buyer_address']),
          if ((waybill['buyer_phone']?.toString() ?? '').isNotEmpty)
            _waybillLine('Contact', waybill['buyer_phone']),
          _waybillLine(
            'Payment',
            cod != null && cod.isNotEmpty
                ? '${waybill['payment_method'] ?? 'COD'} · ₱$cod'
                : waybill['payment_method'],
          ),
          _waybillLine('Items', '${waybill['item_count'] ?? 0} pc(s)'),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 7),
            ...items.take(4).map((item) {
              final qty = item['quantity']?.toString() ?? '0';
              final name = item['name']?.toString() ?? 'Product';
              final variant = item['variant']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '• $qty× $name${variant.isNotEmpty && variant != 'Standard' ? ' · $variant' : ''}',
                  style: const TextStyle(
                    color: Color(0xFF526174),
                    fontSize: 11.2,
                    height: 1.3,
                  ),
                ),
              );
            }),
            if (items.length > 4)
              Text(
                '+ ${items.length - 4} more item line(s)',
                style: const TextStyle(
                  color: Color(0xFF7A8799),
                  fontSize: 10.5,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _waybillLine(String label, dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7A8799),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 10.8,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.tealDark),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF7A8799),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scanScroll.dispose();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scanScroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        const Text(
          'Scan waybill & custody',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Scan the ShopHop waybill QR to verify the parcel and record every physical handoff to a Rider.',
          style: TextStyle(
            color: Color(0xFF65748A),
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        ShopHopScanSteps(
          step: _success
              ? 2
              : _handoff != null
              ? 1
              : 0,
        ),
        if (_busy) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 12),
        ],
        if (_message != null) ...[
          _notice(_message!, success: _success),
          const SizedBox(height: 12),
        ],
        if (_handoff != null)
          _handoffCard(_handoff!)
        else if (!_success)
          _cameraCard(),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.grayBorder),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where this scanner is required',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text('• Seller → Pickup Rider'),
              Text('• Destination Branch → Delivery Rider'),
              SizedBox(height: 8),
              Text(
                'Branch/Hub staff use the Logistics scanner for parcel receiving and manifest loading. Linehaul Drivers scan the Manifest QR instead of parcel QRs.',
                style: TextStyle(
                  color: Color(0xFF65748A),
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
