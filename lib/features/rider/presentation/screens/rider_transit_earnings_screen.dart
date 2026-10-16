import 'package:flutter/material.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/rider/data/services/rider_transit_service.dart';

/// Transit Rider actions and the payout ledger share the Logistics backend.
/// Balances are recorded fees, not automatic real-money transfers.
class RiderTransitEarningsScreen extends StatefulWidget {
  const RiderTransitEarningsScreen({super.key});

  @override
  State<RiderTransitEarningsScreen> createState() => _RiderTransitEarningsScreenState();
}

class _RiderTransitEarningsScreenState extends State<RiderTransitEarningsScreen> {
  static const Color _navy = Color(0xFF172B4D);
  static const Color _teal = Color(0xFF159E8B);
  List<Map<String, dynamic>> _transfers = [];
  List<Map<String, dynamic>> _earnings = [];
  String? _token;
  String? _transferError;
  String? _earningsError;
  bool _busy = true;
  double _pending = 0;
  double _paid = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  List<Map<String, dynamic>> _rows(dynamic source) => source is List
      ? source.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
      : <Map<String, dynamic>>[];

  double _number(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;
  int? _id(dynamic value) => int.tryParse(value?.toString() ?? '');

  Future<void> _refresh() async {
    final session = await AuthSessionService.readSession();
    if (!mounted) return;
    if (session == null || session.accountType != 'rider') {
      setState(() {
        _busy = false;
        _transferError = 'Sign in with an approved Rider account.';
        _earningsError = _transferError;
      });
      return;
    }
    setState(() { _busy = true; _token = session.token; });
    final results = await Future.wait([
      RiderTransitService.tasks(session.token),
      RiderTransitService.earnings(session.token),
    ]);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (results[0].success) _transfers = _rows(results[0].data['transfers']);
      if (results[1].success) {
        _earnings = _rows(results[1].data['entries']);
        _pending = _number(results[1].data['pending']);
        _paid = _number(results[1].data['paid']);
      }
      _transferError = results[0].success ? null : results[0].message;
      _earningsError = results[1].success ? null : results[1].message;
    });
  }

  Future<void> _depart(int id) async {
    if (_busy || _token == null) return;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Confirm departure?'),
      content: const Text('Confirm only after physically receiving the parcel from the origin branch. The destination branch must scan it upon arrival.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm departure')),
      ],
    ));
    if (confirmed != true || !mounted || _busy || _token == null) return;
    setState(() => _busy = true);
    final result = await RiderTransitService.depart(_token!, id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(result.message)));
    await _refresh();
  }

  Widget _banner(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFFFF4E8), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [const Icon(Icons.info_outline, color: Color(0xFF995D20)),
      const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(fontSize: 12)))]),
  );

  Widget _transferCard(Map<String, dynamic> job) {
    final canDepart = job['can_depart'] == true;
    final departed = job['departed_at'] != null;
    final from = job['from']?.toString() ?? 'Origin branch';
    final to = job['to']?.toString() ?? 'Destination branch';
    final id = _id(job['id']);
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8EE))),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.local_shipping_outlined, color: _teal),
            const SizedBox(width: 8),
            Expanded(child: Text(job['tracking_code']?.toString() ?? 'Parcel',
              style: const TextStyle(color: _navy, fontWeight: FontWeight.w800))),
            Chip(label: Text(departed ? 'In transit' : job['status']?.toString() ?? 'Assigned'),
              visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 10),
          Text('FROM  $from', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text('TO        $to', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          if (canDepart && id != null)
            SizedBox(width: double.infinity, child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _teal),
              onPressed: _busy ? null : () => _depart(id),
              icon: const Icon(Icons.output_outlined),
              label: const Text('Confirm parcel handoff & depart'),
            ))
          else
            Text(departed
                ? 'Waiting for the destination branch to scan the parcel.'
                : 'No departure action available. Check with your Logistics branch.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF617389))),
        ],
      )),
    );
  }

  Widget _transitPage() => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 28), children: [
      const Text('My branch transfers', style: TextStyle(color: _navy, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Origin branch → Transit Rider → Destination branch QR receipt',
        style: TextStyle(fontSize: 12, color: Color(0xFF617389))),
      const SizedBox(height: 12),
      if (_transferError != null) ...[_banner(_transferError!), const SizedBox(height: 12)],
      if (_transfers.isEmpty) Card(
        elevation: 0,
        child: Padding(padding: const EdgeInsets.all(20),
          child: Text(_transferError == null
              ? 'No branch transfers assigned yet. Pull down to refresh.'
              : 'Last loaded transfers are unavailable. Try refreshing.')),
      ),
      ..._transfers.map(_transferCard),
    ]),
  );

  Widget _moneyCard(String label, double amount, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE2E8EE)),
        borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: _teal), const SizedBox(height: 10),
        Text('₱${amount.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 19, color: _navy, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 12)),
      ]),
    ),
  );

  Widget _earningsPage() => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 28), children: [
      const Text('My earnings', style: TextStyle(color: _navy, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Pickup, delivery and transit fees recorded by Logistics.',
        style: TextStyle(fontSize: 12, color: Color(0xFF617389))),
      const SizedBox(height: 14),
      Row(children: [_moneyCard('Pending record', _pending, Icons.schedule_outlined),
        const SizedBox(width: 10), _moneyCard('Marked as paid', _paid, Icons.check_circle_outline)]),
      const SizedBox(height: 12),
      const Text('Amounts are ledger records; your Logistics company handles actual manual payouts.',
        style: TextStyle(fontSize: 12, color: Color(0xFF617389))),
      const SizedBox(height: 14),
      if (_earningsError != null) ...[_banner(_earningsError!), const SizedBox(height: 12)],
      if (_earnings.isEmpty)
        const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(20),
          child: Text('No Rider fee records yet. Eligible fees appear after the required delivery events.'))),
      ..._earnings.map((row) => Card(elevation: 0, margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const Icon(Icons.receipt_long_outlined, color: _teal),
          title: Text('Order #${row['order_id']} · ${row['kind']}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          subtitle: Text('Status: ${row['status']}', style: const TextStyle(fontSize: 12)),
          trailing: Text('₱${_number(row['amount']).toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
        ),
      )),
    ]),
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(length: 2, child: Scaffold(
    backgroundColor: const Color(0xFFF5F7FA),
    appBar: AppBar(
      title: const Text('Transit & Earnings', style: TextStyle(color: _navy, fontWeight: FontWeight.w800)),
      backgroundColor: Colors.white,
      bottom: const TabBar(tabs: [Tab(text: 'Branch Transfers'), Tab(text: 'My Earnings')]),
      actions: [IconButton(tooltip: 'Refresh', onPressed: _busy ? null : _refresh,
        icon: const Icon(Icons.refresh))],
    ),
    body: Column(children: [
      if (_busy) const LinearProgressIndicator(minHeight: 3, color: _teal),
      Expanded(child: TabBarView(children: [_transitPage(), _earningsPage()])),
    ]),
  ));
}
