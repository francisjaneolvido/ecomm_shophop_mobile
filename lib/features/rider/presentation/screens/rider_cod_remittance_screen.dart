import 'package:flutter/material.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/rider/data/services/rider_delivery_service.dart';

class RiderCodRemittanceScreen extends StatefulWidget {
  const RiderCodRemittanceScreen({super.key});

  @override
  State<RiderCodRemittanceScreen> createState() => _RiderCodRemittanceScreenState();
}

class _RiderCodRemittanceScreenState extends State<RiderCodRemittanceScreen> {
  bool _busy = true;
  int? _remitting;
  String? _error;
  String? _token;
  List<Map<String, dynamic>> _collections = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final session = await AuthSessionService.readSession();
    if (!mounted) return;
    if (session == null || session.accountType != 'rider') {
      setState(() { _busy = false; _error = 'Rider login required.'; });
      return;
    }
    setState(() { _busy = true; _error = null; _token = session.token; });
    final result = await RiderDeliveryService.codCollections(token: session.token);
    if (!mounted) return;
    final raw = result.data['collections'];
    setState(() {
      _busy = false;
      if (!result.success) {
        _error = result.message;
      } else {
        _collections = raw is List
            ? raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
            : [];
      }
    });
  }

  Future<void> _remit(Map<String, dynamic> cash) async {
    if (_remitting != null || _token == null) return;
    final amount = cash['amount']?.toString() ?? '0.00';
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Confirm physical COD handover?'),
      content: Text('Only continue if you have physically handed ₱$amount to your Logistics company. Logistics must separately acknowledge receipt.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record handover')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    final id = int.tryParse(cash['delivery_id'].toString());
    if (id == null) return;
    setState(() => _remitting = id);
    final result = await RiderDeliveryService.remitCod(token: _token!, deliveryId: id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    setState(() => _remitting = null);
    if (result.success) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('COD Cash Handover'),
      actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh',
        onPressed: _busy ? null : _refresh)],
    ),
    body: _busy
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _refresh, child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text(
                'Money path: Buyer → Rider → Logistics → ShopHop Admin. '
                'This page records physical handover; it does not transfer money automatically.'))),
              if (_error != null) Padding(padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.red))),
              if (_collections.isEmpty) const Padding(padding: EdgeInsets.all(20),
                child: Text('No COD collections recorded for this Rider.')),
              ..._collections.map((cash) => Card(child: Padding(
                padding: const EdgeInsets.all(14), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #${cash['order_id']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Collected: ₱${cash['amount']}'),
                    Text('Status: ${cash['status']}'),
                    if (cash['can_remit'] == true) Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: FilledButton.icon(
                        onPressed: _remitting != null ? null : () => _remit(cash),
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: const Text('Record handover to Logistics'),
                      ),
                    ),
                  ],
                ),
              ))),
            ],
          )),
  );
}
