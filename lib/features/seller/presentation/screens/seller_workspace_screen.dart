import 'package:shophop/shared/widgets/shop_hop_role_layout.dart';
import 'package:flutter/material.dart';
import 'package:shophop/shared/realtime/foreground_refresh.dart';
import 'package:shophop/features/seller/presentation/screens/seller_account_screen.dart';
import 'package:shophop/features/seller/presentation/screens/seller_feedback_screen.dart';

import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/shared/widgets/shop_hop_product_media.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';
import 'package:shophop/features/seller/data/services/seller_earnings_service.dart';
import 'package:shophop/features/seller/data/services/seller_workspace_service.dart';
import 'package:shophop/features/seller/presentation/screens/seller_product_editor_screen.dart';
import 'package:shophop/shared/widgets/shop_hop_navigation.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';

/// Seller's five-tab workspace. Reads the same Seller products and orders as Web;
/// actions remain intentionally scoped to API-supported operations.
class SellerWorkspaceScreen extends StatefulWidget {
  const SellerWorkspaceScreen({super.key});

  @override
  State<SellerWorkspaceScreen> createState() => _SellerWorkspaceScreenState();
}

class _SellerWorkspaceScreenState extends State<SellerWorkspaceScreen> {
  late final ForegroundRefresh _liveRefresh;
  int _tab = 0;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _token;
  String _orderSearch = '';
  String _productSearch = '';
  String _orderFilter = 'All';
  String _inventoryFilter = 'All';
  Map<String, dynamic> _dashboard = {};
  Map<String, dynamic> _earnings = {};
  Map<String, dynamic> _reports = {};
  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
    _liveRefresh = ForegroundRefresh(
      refresh: () => _load(silent: true),
      canRefresh: () =>
          mounted &&
          _requestFuture == null &&
          !_loading &&
          !_saving &&
          (ModalRoute.of(context)?.isCurrent ?? true),
    );
  }

  @override
  void dispose() {
    _liveRefresh.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
  double _num(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;
  String _money(dynamic value) => '₱${_num(value).toStringAsFixed(2)}';
  String _str(dynamic value, [String fallback = '—']) =>
      value == null || value.toString().trim().isEmpty
      ? fallback
      : value.toString();

  Future<void>? _requestFuture;

  Future<void> _load({bool silent = false}) {
    final pending = _requestFuture;
    if (pending != null) {
      if (silent) return pending;
      return pending.then(
        (_) => mounted ? _load(silent: silent) : Future<void>.value(),
      );
    }
    final request = _fetch(silent: silent).whenComplete(() {
      if (mounted) setState(() => _requestFuture = null);
    });
    _requestFuture = request;
    return request;
  }

  Future<void> _fetch({bool silent = false}) async {
    final session = await AuthSessionService.readSession();
    if (!mounted) return;
    if (session == null || session.accountType != 'seller') {
      await _signOut(localOnly: true);
      return;
    }
    setState(() {
      _loading = !silent && _dashboard.isEmpty;
      _error = null;
      _token = session.token;
    });

    final results = await Future.wait([
      SellerWorkspaceService.get(session.token, 'dashboard'),
      SellerWorkspaceService.get(session.token, 'orders'),
      SellerWorkspaceService.get(session.token, 'inventory'),
      SellerEarningsService.load(session.token),
      SellerWorkspaceService.get(session.token, 'reports'),
      SellerWorkspaceService.get(session.token, 'profile'),
    ]);
    if (!mounted) return;
    if (results.any((r) => r.statusCode == 401 || r.statusCode == 403)) {
      await _signOut(localOnly: true);
      return;
    }
    final errors = results
        .where((r) => !r.success)
        .map((r) => r.message)
        .toSet();
    setState(() {
      _loading = false;
      _error = errors.isEmpty ? null : errors.join('  •  ');
      if (results[0].success) _dashboard = results[0].data;
      if (results[1].success) _orders = _rows(results[1].data['orders']);
      if (results[2].success) _products = _rows(results[2].data['products']);
      if (results[3].success) _earnings = results[3].data;
      if (results[4].success) _reports = results[4].data;
      if (results[5].success) _profile = results[5].data;
    });
  }

  Future<void> _signOut({bool localOnly = false}) async {
    final token = _token;
    if (!localOnly && token != null) await AuthService.logout(token: token);
    await AuthSessionService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _orderAction(Map<String, dynamic> order, String action) async {
    final id = _int(order['id']);
    final verb = action == 'accept' ? 'Accept' : 'Start preparing';
    final confirmed = await shopHopConfirm(
      context,
      title: '$verb order?',
      message:
          'Order ${_str(order['display_id'])} · ${_str(order['buyer'])}. '
          '${action == 'accept' ? 'This confirms you will fulfill this COD order.' : 'Only proceed when you are ready to pack this parcel.'}',
      confirmLabel: verb,
    );
    if (!confirmed || !mounted || _token == null || _saving) return;
    setState(() => _saving = true);
    final response = await SellerWorkspaceService.post(
      _token!,
      'orders/$id/$action',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _notice(response.message);
    if (response.success) await _load();
  }

  Future<void> _bookPickup(Map<String, dynamic> order) async {
    if (_token == null || _saving) return;
    final id = _int(order['id']);
    setState(() => _saving = true);
    final couriers = await SellerWorkspaceService.get(
      _token!,
      'orders/$id/couriers',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!couriers.success) {
      _notice(couriers.message);
      return;
    }
    final options = _rows(couriers.data['partners']);
    if (options.isEmpty) {
      _notice(
        'No approved courier covers both your pickup and buyer destination yet.',
      );
      return;
    }
    final lockedId = _int(couriers.data['selected_id']);
    int? selected = options.any((p) => _int(p['id']) == lockedId)
        ? lockedId
        : (options.length == 1 ? _int(options.first['id']) : null);
    final chosen = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request courier pickup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order ${_str(order['display_id'])}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text(
                'Choose a Logistics partner that serves the origin and destination.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Logistics partner *',
                ),
                items: options
                    .map(
                      (p) => DropdownMenuItem<int>(
                        value: _int(p['id']),
                        child: Text(
                          _str(p['name']),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: lockedId > 0
                    ? null
                    : (value) => setDialogState(() => selected = value),
              ),
              if (lockedId > 0)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Courier was selected by the buyer.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              child: const Text('Review pickup'),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    final partner = options.firstWhere((p) => _int(p['id']) == chosen);
    final ok = await shopHopConfirm(
      context,
      title: 'Ready for pickup?',
      message:
          '${_str(order['display_id'])} will be assigned to ${_str(partner['name'])}. '
          'Confirm only when the order is packed. Attach the shipping label from Seller Web before handoff.',
      confirmLabel: 'Request pickup',
    );
    if (!ok || !mounted || _token == null) return;
    setState(() => _saving = true);
    final response = await SellerWorkspaceService.postWithBody(
      _token!,
      'orders/$id/ready',
      {'logistics_partner_id': chosen},
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _notice(response.message);
    if (response.success) await _load();
  }

  Future<void> _editStock(Map<String, dynamic> product) async {
    if (product['has_variants'] == true) {
      _notice('Variant stock is managed on Seller Web.');
      return;
    }
    final controller = TextEditingController(text: _str(product['stock'], '0'));
    final formKey = GlobalKey<FormState>();
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update stock'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _str(product['name']),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Available units *',
                  helperText: 'Whole number, 0 or more',
                ),
                validator: (v) =>
                    int.tryParse((v ?? '').trim()) == null ||
                        int.parse(v!.trim()) < 0
                    ? 'Enter a valid non-negative quantity.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, int.parse(controller.text.trim()));
              }
            },
            child: const Text('Review update'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    final ok = await shopHopConfirm(
      context,
      title: 'Save new stock?',
      message:
          '${_str(product['name'])}: ${_int(product['stock'])} → $value units. This change affects available inventory on both Web and Mobile.',
      confirmLabel: 'Update stock',
    );
    if (!ok || !mounted || _token == null || _saving) return;
    setState(() => _saving = true);
    final response = await SellerWorkspaceService.patch(
      _token!,
      'inventory/${_int(product['id'])}/stock',
      {'stock': value},
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _notice(response.message);
    if (response.success) await _load();
  }

  Widget _metric(
    String name,
    String value,
    IconData icon, {
    bool accent = false,
    String? hint,
  }) => ShopHopRoleMetric(
    label: name,
    value: value,
    icon: icon,
    accent: accent,
    hint: hint,
    onTap:
        _tab == 0 &&
            [
              'New orders',
              'Preparing',
              'Ready for pickup',
              'Low stock',
            ].contains(name)
        ? () => _openMetric(name)
        : null,
  );

  void _openMetric(String label) => setState(() {
    if (label == 'Low stock') {
      _tab = 2;
      _inventoryFilter = 'Low stock';
      _productSearch = '';
    } else {
      _tab = 1;
      _orderSearch = '';
      _orderFilter = label == 'Ready for pickup' ? 'In delivery' : 'To do';
    }
  });

  Widget _sectionTitle(String title, {String? subtitle}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ShopHopSectionHeading(title: title, subtitle: subtitle),
  );

  Widget _empty(String title, String subtitle, IconData icon) =>
      ShopHopEmptyState(icon: icon, title: title, description: subtitle);

  Widget _orderTile(Map<String, dynamic> order, {bool actions = true}) {
    final status = _str(order['status_label']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ShopHopSurface(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _str(order['display_id']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                ShopHopStatusPill(label: status),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              _str(order['buyer']),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              '${_int(order['items_count'])} items · COD',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B7B)),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _money(order['total_amount']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showOrderDetails(order),
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('Details'),
                ),
              ],
            ),
            if (actions &&
                (order['can_accept'] == true ||
                    order['can_prepare'] == true)) ...[
              const Divider(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : () => _orderAction(
                          order,
                          order['can_accept'] == true ? 'accept' : 'prepare',
                        ),
                  child: Text(
                    order['can_accept'] == true
                        ? 'Accept order'
                        : 'Start preparing',
                  ),
                ),
              ),
            ],
            if (actions && order['needs_pickup_booking'] == true) ...[
              const Divider(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _bookPickup(order),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Request pickup'),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'After requesting pickup, print the shipping label on Seller Web.',
                style: TextStyle(fontSize: 11, color: Color(0xFF996900)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .75,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
            children: [
              Text(
                _str(order['display_id']),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              ShopHopStatusPill(label: _str(order['status_label'])),
              const SizedBox(height: 14),
              Text('Buyer: ${_str(order['buyer'])}'),
              Text('Delivery: ${_str(order['delivery_address'])}'),
              Text('Tracking: ${_str(order['tracking_code'])}'),
              const Divider(height: 26),
              const Text(
                'Order items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 9),
              for (final item in _rows(order['items']))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_str(item['name'])),
                  subtitle: Text('Qty ${_int(item['quantity'])}'),
                  trailing: Text(_money(item['price'])),
                ),
              const Divider(height: 26),
              Text(
                'Order total: ${_money(order['total_amount'])}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (order['needs_pickup_booking'] == true) ...[
                const SizedBox(height: 18),
                const ShopHopSurface(
                  child: Text(
                    'You can request pickup from Orders once packing is complete. Print the ShopHop waybill on Seller Web before handoff.',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _home() => ListView(
    key: PageStorageKey('seller-$_tab'),
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
    children: [
      ShopHopRoleIntro(
        title: _str(_dashboard['business_name'], 'Your store'),
        subtitle: 'Review orders, prepare pickups and keep stock up to date.',
        icon: Icons.storefront_outlined,
        badge: '${_int(_dashboard['new_orders'])} new orders',
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _metric(
              'New orders',
              '${_int(_dashboard['new_orders'])}',
              Icons.notification_important_outlined,
              accent: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metric(
              'Preparing',
              '${_int(_dashboard['preparing'])}',
              Icons.inventory_2_outlined,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _metric(
              'Ready for pickup',
              '${_int(_dashboard['ready'])}',
              Icons.local_shipping_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metric(
              'Low stock',
              '${_int(_dashboard['low_stock'])}',
              Icons.warning_amber_rounded,
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      _sectionTitle(
        'Recent orders',
        subtitle: 'Review the orders that need your attention.',
      ),
      if (_rows(_dashboard['recent_orders']).isEmpty)
        _empty(
          'No orders yet',
          'New orders will appear here.',
          Icons.receipt_long_outlined,
        ),
      for (final order in _rows(_dashboard['recent_orders']).take(5))
        _orderTile(order, actions: false),
      OutlinedButton.icon(
        onPressed: () => setState(() => _tab = 1),
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('View all orders'),
      ),
    ],
  );

  Widget _ordersPage() {
    final rows = _orders.where((order) {
      final matchesSearch =
          ('${order['display_id']} ${order['buyer']} ${order['tracking_code']}')
              .toLowerCase()
              .contains(_orderSearch.toLowerCase());
      final status = _str(order['status'], '').toLowerCase();
      return matchesSearch &&
          (_orderFilter == 'All' ||
              (_orderFilter == 'To do' &&
                  ['to-ship', 'confirmed', 'preparing'].contains(status)) ||
              (_orderFilter == 'In delivery' &&
                  ['ready_for_pickup', 'to-receive'].contains(status)) ||
              (_orderFilter == 'Completed' &&
                  ['completed', 'cancelled', 'returned'].contains(status)));
    }).toList();
    return ListView(
      key: PageStorageKey('seller-$_tab'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        _sectionTitle(
          'Orders',
          subtitle: 'Accept, prepare and track your COD orders.',
        ),
        TextFormField(
          key: const ValueKey('seller-order-search'),
          initialValue: _orderSearch,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search order, buyer or tracking',
          ),
          onChanged: (v) => setState(() => _orderSearch = v),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in [
                'All',
                'To do',
                'In delivery',
                'Completed',
              ]) ...[
                ChoiceChip(
                  label: Text(filter),
                  selected: _orderFilter == filter,
                  onSelected: (_) => setState(() => _orderFilter = filter),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          _empty(
            'No matching orders',
            'Try another filter or refresh.',
            Icons.receipt_long_outlined,
          ),
        for (final order in rows) _orderTile(order),
        const Text(
          'Shipping labels remain available on Seller Web. Pickup booking is available here after packing.',
          style: TextStyle(fontSize: 11, color: Color(0xFF6B6B7B)),
        ),
      ],
    );
  }

  Future<void> _openProductEditor([Map<String, dynamic>? product]) async {
    final token = _token;
    if (token == null || _saving) return;
    final raw = _profile['allowed_subcategories'];
    final allowed = raw is List
        ? raw.map((item) => item.toString()).toList()
        : <String>[];
    if (allowed.isEmpty) {
      _notice(
        'Your registered shop category needs an approved subcategory list. Contact Admin.',
      );
      return;
    }
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SellerProductEditorScreen(
          token: token,
          product: product,
          businessCategory: _str(_profile['business_category']),
          subcategories: allowed,
        ),
      ),
    );
    if (updated == true && mounted) await _load();
  }

  Future<void> _toggleProduct(Map<String, dynamic> product) async {
    if (_token == null || _saving) return;
    final archived = product['status'] == 'archived';
    final ok = await shopHopConfirm(
      context,
      title: archived ? 'Restore product?' : 'Archive product?',
      message:
          '${_str(product['name'])} will be ${archived ? 'available for review/stock visibility again' : 'hidden from buyers'}.',
      confirmLabel: archived ? 'Restore' : 'Archive',
      destructive: !archived,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    final result = await SellerWorkspaceService.post(
      _token!,
      'inventory/products/${_int(product['id'])}/toggle',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _notice(result.message);
    if (result.success) await _load();
  }

  String _productImageUrl(Map<String, dynamic> product) {
    final primary = product['image_url']?.toString() ?? '';
    if (primary.trim().isNotEmpty) return ApiConfig.resolveMediaUrl(primary);
    final media = product['media'];
    if (media is List) {
      for (final row in media) {
        if (row is Map &&
            row['type']?.toString() == 'image' &&
            (row['url']?.toString() ?? '').trim().isNotEmpty) {
          return ApiConfig.resolveMediaUrl(row['url']?.toString());
        }
      }
    }
    return '';
  }

  Widget _productsPage() {
    final rows = _products.where((p) {
      final matches =
          '${p['name']} ${p['sku']} ${p['category']} ${p['subcategory']}'
              .toLowerCase()
              .contains(_productSearch.toLowerCase());
      final stock = _int(p['stock']);
      final active = p['status'] != 'archived';
      return matches &&
          switch (_inventoryFilter) {
            'Pending review' =>
              active && p['compliance_status'] == 'pending_review',
            'Low stock' =>
              active && stock <= _int(p['low_stock_threshold'] ?? 10),
            'Archived' => !active,
            _ => true,
          };
    }).toList();
    return ListView(
      key: PageStorageKey('seller-$_tab'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        _sectionTitle(
          'Products & inventory',
          subtitle: 'Manage your store catalog and stock.',
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : () => _openProductEditor(),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Add product'),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('seller-product-search'),
          initialValue: _productSearch,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search product, SKU or category',
          ),
          onChanged: (v) => setState(() => _productSearch = v),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in [
                'All',
                'Pending review',
                'Low stock',
                'Archived',
              ]) ...[
                ChoiceChip(
                  label: Text(filter),
                  selected: _inventoryFilter == filter,
                  onSelected: (_) => setState(() => _inventoryFilter = filter),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          _empty(
            'No matching products',
            'Add your first product above or try another keyword.',
            Icons.inventory_2_outlined,
          ),
        for (final p in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ShopHopSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShopHopProductThumbnail(
                        imageUrl: _productImageUrl(p),
                        videoUrl: p['video_url']?.toString(),
                        videoFirst: p['media_first'] == 'video',
                        width: 72,
                        height: 72,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _str(p['name']),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_str(p['sku'])} · ${_str(p['subcategory'], _str(p['category']))}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B6B7B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ShopHopStatusPill(
                              label: p['status'] == 'archived'
                                  ? 'Archived'
                                  : _str(
                                      p['compliance_status'],
                                    ).replaceAll('_', ' '),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (p['compliance_status'] == 'pending_review' &&
                      p['status'] != 'archived')
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Awaiting Admin approval before buyers can see this product.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B6B7B),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _money(p['price']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        '${_int(p['stock'])} units',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (p['has_variants'] != true) ...[
                        OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _openProductEditor(p),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                        ),
                        OutlinedButton(
                          onPressed: _saving ? null : () => _editStock(p),
                          child: const Text('Stock'),
                        ),
                      ] else
                        const Chip(label: Text('Variants: edit on Web')),
                      TextButton.icon(
                        onPressed: _saving ? null : () => _toggleProduct(p),
                        icon: Icon(
                          p['status'] == 'archived'
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          size: 16,
                        ),
                        label: Text(
                          p['status'] == 'archived' ? 'Restore' : 'Archive',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const Text(
          'Product variants, vouchers and existing photo removal remain on Seller Web.',
          style: TextStyle(fontSize: 11, color: Color(0xFF6B6B7B)),
        ),
      ],
    );
  }

  Widget _earningsPage() {
    final entries = _rows(_earnings['entries']);
    return ListView(
      key: PageStorageKey('seller-$_tab'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        _sectionTitle(
          'Earnings',
          subtitle: 'Settlement amounts from ShopHop Finance.',
        ),
        Row(
          children: [
            Expanded(
              child: _metric(
                'Pending',
                _money(_earnings['pending']),
                Icons.schedule_outlined,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _metric(
                'Available',
                _money(_earnings['available']),
                Icons.account_balance_wallet_outlined,
                accent: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _metric(
          'Paid',
          _money(_earnings['paid']),
          Icons.check_circle_outline_rounded,
        ),
        const SizedBox(height: 22),
        _sectionTitle('Recent settlements'),
        if (entries.isEmpty)
          _empty(
            'No settlements yet',
            'Entries will appear after ShopHop Finance creates them.',
            Icons.payments_outlined,
          ),
        for (final e in entries.take(50))
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: ShopHopSurface(
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.tealDark,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${_str(e['order_id'])}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          _str(e['status']).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF6B6B7B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _money(e['amount']),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _morePage() => ListView(
    key: PageStorageKey('seller-$_tab'),
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
    children: [
      _sectionTitle(
        'Account & store',
        subtitle: 'Profile, customer feedback and store reports.',
      ),
      ShopHopSurface(
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insert_chart_outlined),
              title: const Text('Reports'),
              subtitle: const Text('Order and sales summary'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openReports,
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Store & account'),
              subtitle: Text(_str(_profile['business_name'])),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openAccount,
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.rate_review_outlined),
              title: const Text('Customer Feedback'),
              subtitle: const Text('Read product reviews and reply'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (_token == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellerFeedbackScreen(
                      token: _token!,
                      onSessionExpired: () => _signOut(localOnly: true),
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline),
              title: Text('Advanced seller tools'),
              subtitle: Text(
                'Variants, vouchers, shipping labels and detailed report exports remain on Seller Web.',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () async {
          if (await shopHopConfirm(
                context,
                title: 'Sign out?',
                message: 'End this Seller Mobile session?',
                confirmLabel: 'Sign out',
              ) &&
              mounted) {
            await _signOut();
          }
        },
        icon: const Icon(Icons.logout),
        label: const Text('Sign out'),
      ),
    ],
  );

  void _openReports() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Seller reports')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _metric(
              'Completed sales (gross)',
              _money(_reports['completed_sales']),
              Icons.trending_up_rounded,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _metric(
                    'All orders',
                    '${_int(_reports['total_orders'])}',
                    Icons.receipt_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metric(
                    'Completed',
                    '${_int(_reports['completed_orders'])}',
                    Icons.check_circle_outline_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _metric(
              'This month · gross',
              _money(_reports['this_month_sales']),
              Icons.calendar_month_outlined,
            ),
            const SizedBox(height: 14),
            const ShopHopSurface(
              child: Text(
                'These are gross order totals, not net payout. The detailed commissions, daily analytics and CSV export remain available on Seller Web.',
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _openAccount() async {
    if (_token == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerAccountScreen(
          token: _token!,
          onSessionExpired: () => _signOut(localOnly: true),
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _home(),
      _ordersPage(),
      _productsPage(),
      _earningsPage(),
      _morePage(),
    ];
    return Scaffold(
      backgroundColor: AppColors.grayBg,
      appBar: ShopHopRoleAppBar(
        role: ShopHopRole.seller,
        index: _tab,
        refreshing: _requestFuture != null,
        onRefresh: _saving ? null : _load,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _loading && _dashboard.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    if (_saving) const LinearProgressIndicator(minHeight: 3),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: MaterialBanner(
                          content: Text(_error!),
                          actions: [
                            TextButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: pages[_tab],
                      ),
                    ),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: ShopHopNavigation(
        items: ShopHopRole.seller.destinations,
        index: _tab,
        onChanged: (value) => setState(() => _tab = value),
        badges: {1: _int(_dashboard['new_orders'])},
      ),
    );
  }
}
