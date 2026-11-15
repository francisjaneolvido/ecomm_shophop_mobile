import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/after_sales/data/after_sales_service.dart';

class RiderBuyerReturnsScreen extends StatefulWidget {
  const RiderBuyerReturnsScreen({super.key});
  @override
  State<RiderBuyerReturnsScreen> createState() =>
      _RiderBuyerReturnsScreenState();
}

class _RiderBuyerReturnsScreenState extends State<RiderBuyerReturnsScreen> {
  String? _token;
  String? _error;
  List<Map<String, dynamic>> _cases = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = (await AuthSessionService.readSession())?.token;
    if (token == null) {
      if (mounted) setState(() => _error = 'Sign in as a Rider.');
      return;
    }
    final result = await AfterSalesService.list(token, 'rider');
    if (!mounted) return;
    final rows = result.data['cases'];
    setState(() {
      _token = token;
      _cases = rows is List
          ? rows
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList()
          : [];
      _error = result.success ? null : result.message;
    });
  }

  Future<void> _pickup(int id) async {
    final token = _token;
    if (token == null || _busy) return;
    final selected = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (selected == null || selected.files.isEmpty || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm buyer pickup?'),
        content: const Text(
          'Confirm only after the parcel is in your possession. The selected photo will be saved as pickup proof.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm pickup'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final result = await AfterSalesService.riderPickup(
      token,
      id,
      selected.files.first,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.success ? null : result.message;
    });
    if (result.success) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Buyer Return Pickups')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_cases.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No assigned buyer pickups.'),
            ),
          for (final row in _cases)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Return #${row['id']} · ${row['item_name']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Pickup: ${row['buyer_address'] ?? 'Address unavailable'}',
                    ),
                    Text('Branch: ${row['pickup_branch'] ?? 'Unassigned'}'),
                    Text('Status: ${row['status']}'.replaceAll('_', ' ')),
                    if (row['status'] == 'rider_assigned')
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pickup(row['id'] as int),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Confirm pickup with photo'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
