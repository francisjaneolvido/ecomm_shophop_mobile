import 'package:flutter/material.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/rider/data/services/rider_transit_service.dart';

/// Legacy filename retained for compatibility. Center-to-center transport is no
/// longer a Rider task; this screen now shows first/last-mile Rider earnings only.
class RiderTransitEarningsScreen extends StatefulWidget {
  const RiderTransitEarningsScreen({super.key});

  @override
  State<RiderTransitEarningsScreen> createState() => _RiderTransitEarningsScreenState();
}

class _RiderTransitEarningsScreenState extends State<RiderTransitEarningsScreen> {
  static const _navy = Color(0xFF0E1B4D);
  static const _teal = Color(0xFF18AA94);
  bool _busy = true;
  String? _message;
  double _pending = 0;
  double _paid = 0;
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  double _amount(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

  Future<void> _load() async {
    final session = await AuthSessionService.readSession();
    if (!mounted) return;
    if (session == null || session.accountType != 'rider') {
      setState(() {
        _busy = false;
        _message = 'Rider login required.';
      });
      return;
    }

    setState(() => _busy = true);
    final response = await RiderTransitService.earnings(session.token);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = response.success ? null : response.message;
      if (response.success) {
        _pending = _amount(response.data['pending']);
        _paid = _amount(response.data['paid']);
        _entries = _rows(response.data['entries']);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Rider Earnings'),
          actions: [IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh))],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Pickup & Delivery Earnings',
                style: TextStyle(color: _navy, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Branch/Hub transport is now handled by Linehaul Drivers and fleet vehicles, not Rider accounts.',
                style: TextStyle(color: Color(0xFF65748A)),
              ),
              const SizedBox(height: 16),
              if (_busy) const LinearProgressIndicator(color: _teal),
              if (_message != null) ...[
                const SizedBox(height: 10),
                Text(_message!),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _moneyCard('Pending', _pending)),
                  const SizedBox(width: 10),
                  Expanded(child: _moneyCard('Paid', _paid)),
                ],
              ),
              const SizedBox(height: 18),
              if (_entries.isEmpty && !_busy)
                const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No Rider earnings recorded yet.'))),
              ..._entries.map((entry) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
                      title: Text('Order #${entry['order_id'] ?? '—'}'),
                      subtitle: Text((entry['kind'] ?? '').toString().replaceAll('_', ' ')),
                      trailing: Text(
                        '₱${_amount(entry['amount']).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: _navy),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      );

  Widget _moneyCard(String label, double amount) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Color(0xFF65748A), fontSize: 12)),
            const SizedBox(height: 5),
            Text('₱${amount.toStringAsFixed(2)}', style: const TextStyle(color: _navy, fontSize: 20, fontWeight: FontWeight.w900)),
          ]),
        ),
      );
}
