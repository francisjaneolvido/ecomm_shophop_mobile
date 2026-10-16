import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/buyer/data/services/buyer_order_service.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_payment_proof_page.dart';

class BuyerOrdersPage extends StatefulWidget {
  const BuyerOrdersPage({
    super.key,
    required this.token,
    required this.onSessionExpired,
    required this.onBrowseProducts,
  });
  final String token;
  final Future<void> Function() onSessionExpired;
  final VoidCallback onBrowseProducts;

  @override
  State<BuyerOrdersPage> createState() => _BuyerOrdersPageState();
}

class _BuyerOrdersPageState extends State<BuyerOrdersPage> {
  List<BuyerOrderData> _orders = const [];
  bool _loading = true;
  bool _hasMore = false;
  bool _loadingMore = false;
  int _page = 1;
  int? _busyOrderId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BuyerOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (!_hasMore || _loadingMore)) return;
    if (!mounted) return;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });

    try {
      final requestedPage = more ? _page + 1 : 1;
      final result = await BuyerOrderService.list(token: widget.token, page: requestedPage);
      if (!mounted) return;
      setState(() {
        _orders = more ? [..._orders, ...result.orders] : result.orders;
        _page = requestedPage;
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } on BuyerOrderException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return;
      }
      setState(() {
        _error = error.message;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _confirmReceipt(BuyerOrderData order) async {
    if (_busyOrderId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm received?'),
        content: Text('Confirm only if you have received all items in ${order.displayId}. This completes the order.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyOrderId = order.id);
    try {
      await BuyerOrderService.confirmReceipt(token: widget.token, orderId: order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt confirmed. Order completed.')));
      await _load();
    } on BuyerOrderException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busyOrderId = null);
    }
  }

  void _openPayment(int paymentId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BuyerPaymentProofPage(
        token: widget.token,
        paymentId: paymentId,
        onSessionExpired: widget.onSessionExpired,
        onGoToOrders: () {
          Navigator.of(context).pop();
          _load();
        },
      ),
    ));
  }

  String _peso(double value) => '₱${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grayBg,
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [IconButton(tooltip: 'Refresh orders', onPressed: () => _load(), icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading && _orders.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.teal,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                children: [
                  if (_error != null) Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MaterialBanner(
                      content: Text(_error!),
                      actions: [TextButton(onPressed: () => _load(), child: const Text('Retry'))],
                    ),
                  ),
                  if (_orders.isEmpty) Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 65, horizontal: 20),
                      child: Column(children: [
                        const Icon(Icons.receipt_long_outlined, size: 54, color: AppColors.tealDark),
                        const SizedBox(height: 16),
                        const Text('No orders yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Orders from both ShopHop web and mobile will appear here.', textAlign: TextAlign.center),
                        const SizedBox(height: 18),
                        FilledButton(onPressed: widget.onBrowseProducts, child: const Text('Browse products')),
                      ]),
                    ),
                  ),
                  ..._orders.map(_orderCard),
                  if (_hasMore) Center(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: OutlinedButton(
                      onPressed: _loadingMore ? null : () => _load(more: true),
                      child: Text(_loadingMore ? 'Loading...' : 'Load more orders'),
                    ),
                  )),
                ],
              ),
            ),
    );
  }

  Widget _orderCard(BuyerOrderData order) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(order.sellerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          const SizedBox(width: 6),
          Text(order.displayId, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        Text(order.statusLabel, style: const TextStyle(color: AppColors.tealDark, fontWeight: FontWeight.w700)),
        if (order.statusNote.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(order.statusNote, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ),
        if (order.failureReason != null && order.failureReason!.isNotEmpty)
          Text('Delivery issue: ${order.failureReason}', style: const TextStyle(color: Colors.red)),
        const Divider(height: 22),
        ...order.items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(child: Text('${item.name} · ${item.variant}\nQty ${item.quantity}', style: const TextStyle(fontSize: 13))),
            Text(_peso(item.price * item.quantity), style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        )),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Order total', style: TextStyle(fontWeight: FontWeight.w600)),
          Text(_peso(order.totalAmount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        if (order.trackingCode != null) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SelectableText('Tracking: ${order.trackingCode}'),
        ),
        if (order.deliveryAddress.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Deliver to: ${order.deliveryAddress}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ),
        if (order.timeline.isNotEmpty) ExpansionTile(
          title: const Text('Tracking history', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          tilePadding: EdgeInsets.zero,
          children: order.timeline.map((event) => ListTile(
            dense: true,
            leading: const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.tealDark),
            title: Text(event.label),
            subtitle: Text(event.at.replaceFirst('T', ' ').split('.').first),
          )).toList(),
        ),
        if (order.paymentMethod == 'online' && order.paymentId != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => _openPayment(order.paymentId!),
              icon: const Icon(Icons.payment_rounded),
              label: const Text('View payment status / proof'),
            ),
          ),
        if (order.canConfirmReceipt)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busyOrderId == null ? () => _confirmReceipt(order) : null,
                child: Text(_busyOrderId == order.id ? 'Confirming...' : 'Confirm order received'),
              ),
            ),
          ),
      ]),
    ),
  );
}
