import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/rider/data/services/rider_return_service.dart';

class RiderReturnsScreen extends StatefulWidget {
  const RiderReturnsScreen({super.key});
  @override
  State<RiderReturnsScreen> createState() => _RiderReturnsScreenState();
}

class _RiderReturnsScreenState extends State<RiderReturnsScreen> {
  List<Map<String, dynamic>> _returns = [];
  bool _loading = false;
  int? _working;
  String? _error;
  String? _token;

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    final session = await AuthSessionService.readSession();
    if (!mounted) return;
    if (session == null || session.accountType != 'rider') {
      setState(() { _loading = false; _error = 'Sign in as an approved Rider.'; });
      return;
    }
    _token = session.token;
    final result = await RiderReturnService.tasks(session.token);
    if (!mounted) return;
    final raw = result.data['returns'];
    setState(() {
      _loading = false;
      if (result.success) {
        _returns = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
      } else { _error = result.message; }
    });
  }

  Future<void> _collect(int id) async {
    final token = _token; if (token == null || _working != null) return;
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Collect return parcel?'),
      content: const Text('Only confirm after physically collecting the parcel from your assigned branch.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm pickup'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _working = id);
    final result = await RiderReturnService.collect(token, id);
    if (!mounted) return;
    setState(() => _working = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) await _refresh();
  }

  Future<void> _handover(int id) async {
    final token = _token; if (token == null || _working != null) return;
    final selected = await FilePicker.pickFiles(type: FileType.image,
      allowMultiple: false, withData: true);
    if (!mounted || selected == null || selected.files.isEmpty) return;
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Submit Seller handover proof?'),
      content: const Text('Only submit a real handover photo after giving this parcel back to the Seller. Seller will confirm receipt separately.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit proof'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _working = id);
    final result = await RiderReturnService.handover(token, id, selected.files.first);
    if (!mounted) return;
    setState(() => _working = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Return-to-Seller Tasks')),
    body: RefreshIndicator(onRefresh: _refresh, child: ListView(
      padding: const EdgeInsets.all(16), children: [
        const Text('Return parcels', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Assigned return parcels only. Confirm actual branch pickup, then upload Seller handover proof.'),
        const SizedBox(height: 14),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(14),
          child: Text(_error!, style: const TextStyle(color: Colors.red)))),
        if (!_loading && _returns.isEmpty) const Padding(padding: EdgeInsets.all(24),
          child: Center(child: Text('No assigned return parcels.'))),
        for (final item in _returns) Card(
          child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Order #${item['order_id'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 6),
              Text('Tracking: ${item['tracking_code'] ?? '-'}'),
              Text('Seller: ${item['seller'] ?? '-'}'),
              Text('Pickup branch: ${item['branch'] ?? '-'}'),
              Text('Status: ${item['status'] ?? '-'}'),
              const SizedBox(height: 10),
              if (item['status'] == 'assigned') FilledButton.icon(
                onPressed: _working != null ? null : () => _collect(item['id'] as int),
                icon: const Icon(Icons.inventory_2_outlined), label: const Text('Confirm branch pickup')),
              if (item['status'] == 'in_transit') FilledButton.icon(
                onPressed: _working != null ? null : () => _handover(item['id'] as int),
                icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Submit Seller handover photo')),
              if (item['status'] == 'awaiting_seller') const Text('Waiting for Seller receipt confirmation.'),
              if (item['status'] == 'seller_received') const Text('Seller confirmed parcel received.'),
              if (_working == item['id']) const LinearProgressIndicator(),
            ],
          )),
        ),
      ],
    )),
  );
}
