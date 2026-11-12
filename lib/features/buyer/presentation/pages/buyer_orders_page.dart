import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/buyer/data/services/buyer_order_service.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_item_rating_sheet.dart';

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
  String? _statusGroup;
  Map<String, int> _counts = const {};
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BuyerOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _orders = const [];
      _counts = const {};
      _load();
    }
  }

  Future<void> _load({bool more = false}) async {
    if (more && (!_hasMore || _loadingMore)) return;
    if (!mounted) return;
    final version = ++_requestVersion;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _loadingMore = false;
        _error = null;
      }
    });

    try {
      final requestedPage = more ? _page + 1 : 1;
      final result = await BuyerOrderService.list(
        token: widget.token,
        page: requestedPage,
        statusGroup: _statusGroup,
      );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _counts = result.statusCounts;
        _orders = more ? [..._orders, ...result.orders] : result.orders;
        _page = requestedPage;
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } on BuyerOrderException catch (error) {
      if (!mounted || version != _requestVersion) return;
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
        content: Text(
          'Confirm only if you have received all items in ${order.displayId}. This completes the order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyOrderId = order.id);
    try {
      await BuyerOrderService.confirmReceipt(
        token: widget.token,
        orderId: order.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt confirmed. Order completed.')),
      );
      await _load();
    } on BuyerOrderException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busyOrderId = null);
    }
  }

  static const _groups = [
    (id: 'to-ship', label: 'To Ship', icon: Icons.inventory_2_outlined),
    (
      id: 'to-receive',
      label: 'To Receive',
      icon: Icons.local_shipping_outlined,
    ),
    (id: 'to-rate', label: 'To Rate', icon: Icons.star_outline_rounded),
    (id: 'completed', label: 'Completed', icon: Icons.task_alt_rounded),
  ];

  String get _selectedLabel => _statusGroup == null
      ? 'All orders'
      : _statusGroup == 'cancelled'
      ? 'Cancelled'
      : _groups.firstWhere((group) => group.id == _statusGroup).label;

  Future<void> _rateItem(BuyerOrderData order, BuyerOrderItemData item) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => BuyerItemRatingSheet(
        item: item,
        onSessionExpired: widget.onSessionExpired,
        onSubmit: (rating, comment) => BuyerOrderService.rateItem(
          token: widget.token,
          orderId: order.id,
          itemId: item.id,
          rating: rating,
          comment: comment,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks! Your product rating is saved.')),
    );
    await _load();
  }

  void _selectGroup(String? group) {
    if (group == _statusGroup) return;
    setState(() {
      _statusGroup = group;
      _orders = const [];
      _hasMore = false;
    });
    _load();
  }

  String _peso(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '₱$whole.${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = _counts[_statusGroup ?? 'all'];
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh orders',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            _purchaseShortcuts(),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedLabel,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (visibleCount != null)
                  Text(
                    '$visibleCount ${visibleCount == 1 ? 'order' : 'orders'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MaterialBanner(
                  content: Text(_error!),
                  actions: [
                    TextButton(
                      onPressed: () => _load(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_orders.isEmpty && _error == null)
              _emptyState()
            else
              ..._orders.map(_orderCard),
            if (_hasMore && !_loading)
              Center(
                child: OutlinedButton(
                  onPressed: _loadingMore ? null : () => _load(more: true),
                  child: Text(_loadingMore ? 'Loading…' : 'Load more orders'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _purchaseShortcuts() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'My purchases',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            TextButton(
              onPressed: () => _selectGroup(null),
              child: const Text('View all'),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                MediaQuery.textScalerOf(context).scale(12) > 17 ||
                    constraints.maxWidth < 290
                ? 2
                : 4;
            final width = (constraints.maxWidth - (columns - 1) * 4) / columns;
            return Wrap(
              spacing: 4,
              runSpacing: 8,
              children: _groups.map((group) {
                final selected = _statusGroup == group.id;
                final count = _counts[group.id];
                return SizedBox(
                  width: width,
                  child: Semantics(
                    selected: selected,
                    button: true,
                    label:
                        '${group.label}${count == null ? '' : ', $count orders'}',
                    excludeSemantics: true,
                    child: Material(
                      color: selected ? AppColors.pinkSoft : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        key: ValueKey('order-filter-${group.id}'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _selectGroup(group.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 2,
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 37,
                                width: 48,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      group.icon,
                                      size: 28,
                                      color: AppColors.navy,
                                    ),
                                    if (count != null && count > 0)
                                      Positioned(
                                        right: -5,
                                        top: -5,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 20,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.navy,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: Text(
                                            count > 99 ? '99+' : '$count',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                group.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 18,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.navy
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('order-filter-cancelled'),
            onPressed: () => _selectGroup('cancelled'),
            child: Text(
              'Cancelled${_counts['cancelled'] == null ? '' : ' (${_counts['cancelled']})'}',
            ),
          ),
        ),
        if (_statusGroup == null)
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 6),
            child: Text(
              'All purchases, from checkout to delivery.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
      ],
    ),
  );

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
    child: Column(
      children: [
        const Icon(
          Icons.receipt_long_outlined,
          size: 48,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: 16),
        Text(
          _statusGroup == null
              ? 'No orders yet'
              : 'No ${_selectedLabel.toLowerCase()} orders',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          _statusGroup == null
              ? 'Your ShopHop purchases will appear here.'
              : 'Orders will appear here when they reach this stage.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (_statusGroup == null)
          FilledButton(
            onPressed: widget.onBrowseProducts,
            child: const Text('Browse products'),
          )
        else
          OutlinedButton(
            onPressed: () => _selectGroup(null),
            child: const Text('View all orders'),
          ),
      ],
    ),
  );

  Widget _orderCard(BuyerOrderData order) {
    final closed = order.status == 'cancelled' || order.status == 'returned';
    final complete = order.status == 'completed';
    final tone = closed
        ? AppColors.errorStrong
        : complete
        ? AppColors.successStrong
        : AppColors.navy;
    final background = closed
        ? AppColors.errorSoft
        : complete
        ? AppColors.successSoft
        : AppColors.pinkSoft;
    return Card(
      key: ValueKey('buyer-order-${order.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.storefront_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.sellerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        order.displayId,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    closed
                        ? Icons.cancel_outlined
                        : complete
                        ? Icons.check_circle_outline
                        : Icons.local_shipping_outlined,
                    color: tone,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.statusLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: tone,
                            fontSize: 13,
                          ),
                        ),
                        if (order.statusNote.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            order.statusNote,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...order.items.map((item) => _itemRow(order, item)),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order.items.fold<int>(0, (sum, item) => sum + item.quantity)} items · Order total',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _peso(order.totalAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            if (order.failureReason?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Delivery issue: ${order.failureReason}',
                  style: const TextStyle(
                    color: AppColors.errorStrong,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey('order-details-${order.id}'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 6),
                title: const Text(
                  'Delivery & tracking',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                children: [
                  if (order.trackingCode?.isNotEmpty == true)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tracking number',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              SelectableText(
                                order.trackingCode!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy tracking number',
                          icon: const Icon(Icons.copy_outlined, size: 18),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: order.trackingCode!),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tracking number copied.'),
                              ),
                            );
                          },
                        ),
                      ],
                    )
                  else
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tracking number not assigned yet.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  if (order.deliveryAddress.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.deliveryAddress,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ...order.timeline.map(
                    (event) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: AppColors.navy,
                      ),
                      title: Text(
                        event.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _eventTime(event.at),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (order.canConfirmReceipt)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busyOrderId == null
                      ? () => _confirmReceipt(order)
                      : null,
                  child: Text(
                    _busyOrderId == order.id
                        ? 'Confirming…'
                        : 'Confirm order received',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(BuyerOrderData order, BuyerOrderItemData item) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 58,
            height: 58,
            child: item.image?.isNotEmpty == true
                ? Image.network(
                    ApiConfig.resolveMediaUrl(item.image),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.variant} · Qty ${item.quantity}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _peso(item.price * item.quantity),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (item.canRate)
                OutlinedButton.icon(
                  key: ValueKey('rate-item-${item.id}'),
                  onPressed: () => _rateItem(order, item),
                  icon: const Icon(Icons.star_outline_rounded, size: 18),
                  label: const Text('Rate item'),
                )
              else if (item.rating != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '★ Your rating: ${item.rating}/5',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.successStrong,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _imagePlaceholder() => const ColoredBox(
    color: AppColors.surfaceSoft,
    child: Icon(
      Icons.inventory_2_outlined,
      color: AppColors.textMuted,
      size: 25,
    ),
  );

  String _eventTime(String value) {
    // API emits ISO timestamps. Convert the instant once to Philippine time.
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
      return 'Time not recorded';
    }
    final at = parsed.toUtc().add(const Duration(hours: 8));
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[at.month - 1]} ${at.day}, ${at.year} · ${at.hour % 12 == 0 ? 12 : at.hour % 12}:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'AM' : 'PM'} PHT';
  }
}
