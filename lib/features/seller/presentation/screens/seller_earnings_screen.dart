import 'package:flutter/material.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';
import 'package:shophop/features/seller/data/services/seller_earnings_service.dart';

class SellerEarningsScreen extends StatefulWidget {
  const SellerEarningsScreen({super.key});

  @override
  State<SellerEarningsScreen> createState() => _SellerEarningsScreenState();
}

class _SellerEarningsScreenState extends State<SellerEarningsScreen> {
  static const _navy = Color(0xFF0E1B4D);
  static const _teal = Color(0xFF18AA94);
  bool _busy = true;
  String? _message;
  String _sellerName = 'Seller';
  String? _email;
  double _pending = 0, _available = 0, _paid = 0;
  List<Map<String, dynamic>> _entries = [];

  double _num(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;
  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await AuthSessionService.readSession();
    if (!mounted) return;
    if (session == null || session.accountType != 'seller') {
      await _logout(localOnly: true);
      return;
    }
    setState(() { _busy = true; _email = session.email; });
    final result = await SellerEarningsService.load(session.token);
    if (!mounted) return;
    if (result.statusCode == 401 || result.statusCode == 403) {
      await _logout(localOnly: true);
      return;
    }
    setState(() {
      _busy = false;
      _message = result.success ? null : result.message;
      if (result.success) {
        _sellerName = result.data['seller_name']?.toString() ?? 'Seller';
        _pending = _num(result.data['pending']);
        _available = _num(result.data['available']);
        _paid = _num(result.data['paid']);
        _entries = _rows(result.data['entries']);
      }
    });
  }

  Future<void> _logout({bool localOnly = false}) async {
    final session = await AuthSessionService.readSession();
    if (!localOnly && session != null) await AuthService.logout(token: session.token);
    await AuthSessionService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  String _money(double v) => '₱${v.toStringAsFixed(2)}';

  Widget _moneyCard(String label, double amount, {bool highlight = false}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF65748A))),
        const SizedBox(height: 5),
        Text(_money(amount), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: highlight ? _teal : _navy)),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('ShopHop Seller', style: TextStyle(fontWeight: FontWeight.w800)),
      actions: [IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh))],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
        children: [
          Text(_sellerName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _navy)),
          Text(_email ?? '', style: const TextStyle(color: Color(0xFF65748A))),
          const SizedBox(height: 6),
          const Text('Earnings only on mobile for now. Seller operations remain on ShopHop Web.', style: TextStyle(color: Color(0xFF65748A))),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(color: _teal),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_message!)),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: _moneyCard('Pending', _pending)), const SizedBox(width: 8), Expanded(child: _moneyCard('Available', _available, highlight: true))]),
          Row(children: [Expanded(child: _moneyCard('Paid', _paid)), const Expanded(child: SizedBox())]),
          const SizedBox(height: 14),
          const Text('Settlement history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 8),
          if (_entries.isEmpty && !_busy) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No Seller earnings prepared yet.'))),
          ..._entries.map((e) {
            final status = (e['status'] ?? 'pending').toString();
            return Card(child: ListTile(
              leading: Icon(status == 'paid' ? Icons.check_circle_outline : status == 'available' ? Icons.account_balance_wallet_outlined : Icons.schedule, color: status == 'available' ? _teal : _navy),
              title: Text('Order #${e['order_id'] ?? '—'} · ${_money(_num(e['amount']))}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${status.toUpperCase()}${e['payment_reference'] != null ? ' · Ref ${e['payment_reference']}' : e['distribution_reference'] != null ? ' · ${e['distribution_reference']}' : ''}'),
            ));
          }),
          const SizedBox(height: 18),
          OutlinedButton.icon(onPressed: _busy ? null : () => _logout(), icon: const Icon(Icons.logout), label: const Text('Sign out')),
        ],
      ),
    ),
  );
}
