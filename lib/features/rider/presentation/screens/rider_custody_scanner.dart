import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/rider/data/services/rider_custody_scan_service.dart';

class RiderCustodyScanner extends StatefulWidget {
  const RiderCustodyScanner({
    super.key,
    required this.token,
    required this.onConfirmed,
  });

  final String token;
  final Future<void> Function() onConfirmed;

  @override
  State<RiderCustodyScanner> createState() => _RiderCustodyScannerState();
}

class _RiderCustodyScannerState extends State<RiderCustodyScanner> {
  final MobileScannerController _camera = MobileScannerController(
    autoStart: false,
  );

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
      if (mounted) {
        setState(() {
          _success = false;
          _message = 'That is not a ShopHop parcel QR. Scan the shipping label.';
        });
      }
      return;
    }

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
    setState(() {
      _busy = false;
      _handoff = response.success && rawHandoff is Map
          ? Map<String, dynamic>.from(rawHandoff)
          : null;
      _success = false;
      _message = response.success ? null : response.message;
    });
  }

  Future<void> _confirm() async {
    final handoff = _handoff;
    if (_busy || handoff == null) return;

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
            child: Text(handoff['confirm_label']?.toString() ?? 'Confirm custody'),
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
      _handoff = null;
      _success = response.success;
      _message = response.message;
    });

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

  Widget _notice(String text, {required bool success}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: success ? const Color(0xFFE8F7F1) : const Color(0xFFFFF3E8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.info_outline_rounded,
            color: success ? AppColors.tealDark : const Color(0xFF9B5718),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.camera_alt_rounded, color: AppColors.tealDark),
              SizedBox(width: 8),
              Text(
                'Custody camera',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Scan the permanent QR on the ShopHop waybill. The server verifies the assignment and shows the parcel waybill before any custody status changes.',
            style: TextStyle(
              color: Color(0xFF65748A),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (_scanning)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 300,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _camera,
                      onDetect: (capture) {
                        if (_busy || !_scanning) return;
                        for (final barcode in capture.barcodes) {
                          final raw = barcode.rawValue;
                          if (raw != null && raw.trim().isNotEmpty) {
                            _preview(raw);
                            break;
                          }
                        }
                      },
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 215,
                          height: 215,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 34),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 54,
                    color: AppColors.tealDark,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Camera is paused',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _scanning ? _stopCamera() : _startCamera(),
              icon: Icon(
                _scanning ? Icons.stop_circle_outlined : Icons.camera_alt_rounded,
              ),
              label: Text(_scanning ? 'Pause camera' : 'Open camera'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _handoffCard(Map<String, dynamic> handoff) {
    final action = handoff['action']?.toString() ?? '';
    final color = _actionColor(action);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      handoff['tracking_code']?.toString() ?? '',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
            _waybillCard(Map<String, dynamic>.from(handoff['waybill'] as Map), color),
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
              onPressed: _busy ? null : _confirm,
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
        ? rawItems.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
    final cod = waybill['cod_amount']?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(14),
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
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                waybill['order_number']?.toString() ?? '',
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
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
          _waybillLine('Payment', cod != null && cod.isNotEmpty
              ? '${waybill['payment_method'] ?? 'COD'} · ₱$cod'
              : waybill['payment_method']),
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
                  style: const TextStyle(color: Color(0xFF526174), fontSize: 11.2, height: 1.3),
                ),
              );
            }),
            if (items.length > 4)
              Text(
                '+ ${items.length - 4} more item line(s)',
                style: const TextStyle(color: Color(0xFF7A8799), fontSize: 10.5),
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
              style: const TextStyle(color: Color(0xFF7A8799), fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.navy, fontSize: 10.8, fontWeight: FontWeight.w600, height: 1.3),
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
        borderRadius: BorderRadius.circular(13),
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
                  fontWeight: FontWeight.w800,
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
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 38),
      children: [
        const Text(
          'Scan waybill & custody',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 24,
            fontWeight: FontWeight.w900,
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
        else
          _cameraCard(),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.grayBorder),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where this scanner is required',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
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
