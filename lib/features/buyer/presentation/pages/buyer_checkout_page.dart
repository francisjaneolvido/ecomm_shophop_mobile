import 'package:flutter/material.dart';

import 'package:shophop/features/buyer/data/services/buyer_checkout_service.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_address_editor_page.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_purchase_widgets.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_icon_tile.dart';

class BuyerCheckoutPage extends StatefulWidget {
  const BuyerCheckoutPage({
    super.key,
    required this.token,
    required this.items,
    required this.onSessionExpired,
    required this.onOrderPlaced,
    this.onCartCountChanged,
  });

  final String token;
  final Map<String, int> items;
  final Future<void> Function() onSessionExpired;
  final VoidCallback onOrderPlaced;
  final ValueChanged<int>? onCartCountChanged;

  @override
  State<BuyerCheckoutPage> createState() => _BuyerCheckoutPageState();
}

class _BuyerCheckoutPageState extends State<BuyerCheckoutPage> {
  BuyerCheckoutPreviewData? _preview;
  BuyerCheckoutException? _error;
  final Map<int, int> _logisticsPartners = <int, int>{};
  final Map<int, String> _notes = <int, String>{};
  String _paymentMethod = 'cod';
  final String _voucherCode =
      ''; // Legacy field: new checkouts use _sellerVouchers instead.
  final Map<int, String> _sellerVouchers = <int, String>{};
  String _merchandiseVoucherCode = '';
  String _shippingVoucherCode = '';
  bool _loading = true;
  bool _recalculating = false;
  bool _placingOrder = false;
  bool _confirmingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final preview = await BuyerCheckoutService.preview(
        token: widget.token,
        items: widget.items,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _error = null;
        _loading = false;
        _paymentMethod = preview.paymentMethod;
        _logisticsPartners
          ..clear()
          ..addEntries(
            preview.groups
                .where((group) => group.selectedLogisticsPartnerId != null)
                .map(
                  (group) => MapEntry(
                    group.sellerId,
                    group.selectedLogisticsPartnerId!,
                  ),
                ),
          );
      });
    } on BuyerCheckoutException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        setState(() => _loading = false);
        await widget.onSessionExpired();
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<BuyerCheckoutPreviewData?> _fetchPreview({
    Map<int, int>? logisticsPartners,
    String? paymentMethod,
    String? voucherCode,
    Map<int, String>? sellerVouchers,
    String? merchandiseVoucherCode,
    String? shippingVoucherCode,
    bool showBusy = true,
  }) async {
    if (showBusy && mounted) setState(() => _recalculating = true);
    try {
      final preview = await BuyerCheckoutService.preview(
        token: widget.token,
        items: widget.items,
        shippingMethods: {
          for (final group in (_preview?.groups ?? <BuyerCheckoutGroupData>[]))
            group.sellerId: 'standard',
        },
        logisticsPartners: logisticsPartners ?? _logisticsPartners,
        paymentMethod: paymentMethod ?? _paymentMethod,
        voucherCode: voucherCode ?? _voucherCode,
        sellerVouchers: sellerVouchers ?? _sellerVouchers,
        merchandiseVoucherCode:
            merchandiseVoucherCode ?? _merchandiseVoucherCode,
        shippingVoucherCode: shippingVoucherCode ?? _shippingVoucherCode,
      );
      if (!mounted) return null;
      setState(() {
        _preview = preview;
        _error = null;
        // The backend may replace an invalid courier after an address change.
        // Use only its newly eligible selected partners, never stale local IDs.
        _logisticsPartners
          ..clear()
          ..addEntries(
            preview.groups
                .where((group) => group.selectedLogisticsPartnerId != null)
                .map(
                  (group) => MapEntry(
                    group.sellerId,
                    group.selectedLogisticsPartnerId!,
                  ),
                ),
          );
      });
      return preview;
    } on BuyerCheckoutException catch (error) {
      if (!mounted) return null;
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return null;
      }
      _showMessage(error.message);
      return null;
    } finally {
      if (showBusy && mounted) setState(() => _recalculating = false);
    }
  }

  Future<void> _editDeliveryAddress() async {
    if (_placingOrder || _recalculating) return;
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => BuyerAddressEditorPage(token: widget.token),
      ),
    );
    if (!mounted) return;
    _logisticsPartners.clear();
    await _fetchPreview(logisticsPartners: const <int, int>{}, showBusy: true);
  }

  Future<void> _changeCourier(int sellerId, int partnerId) async {
    final previous = _logisticsPartners[sellerId];
    if (previous == partnerId || _recalculating) return;

    final next = Map<int, int>.from(_logisticsPartners)..[sellerId] = partnerId;
    setState(() => _logisticsPartners[sellerId] = partnerId);
    final preview = await _fetchPreview(logisticsPartners: next);
    if (!mounted) return;
    if (preview == null) {
      setState(() {
        if (previous == null) {
          _logisticsPartners.remove(sellerId);
        } else {
          _logisticsPartners[sellerId] = previous;
        }
      });
    }
  }

  Future<void> _changePayment(String method) async {
    if (_paymentMethod == method || _recalculating) return;
    final previous = _paymentMethod;
    setState(() => _paymentMethod = method);
    final preview = await _fetchPreview(paymentMethod: method);
    if (!mounted) return;
    if (preview == null) setState(() => _paymentMethod = previous);
  }

  Future<void> _chooseVoucher(int sellerId) async {
    final preview = _preview;
    if (preview == null || _recalculating || _placingOrder) return;
    final shopVouchers = preview.vouchers
        .where((voucher) => voucher.sellerId == sellerId)
        .toList();
    final selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VoucherSheet(
        vouchers: shopVouchers,
        selectedCode: _sellerVouchers[sellerId] ?? '',
      ),
    );
    if (!mounted || selected == null) return;
    final candidate = selected == '__NONE__' ? '' : selected;
    if (candidate == (_sellerVouchers[sellerId] ?? '')) return;
    final next = Map<int, String>.from(_sellerVouchers);
    if (candidate.isEmpty) {
      next.remove(sellerId);
    } else {
      next[sellerId] = candidate;
    }
    final updated = await _fetchPreview(sellerVouchers: next);
    if (!mounted || updated == null) return;
    setState(() {
      _sellerVouchers
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _choosePlatformVouchers() async {
    if (_recalculating || _placingOrder) return;
    final merchandise = TextEditingController(text: _merchandiseVoucherCode);
    final shipping = TextEditingController(text: _shippingVoucherCode);
    final values = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ShopHop vouchers'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Apply a ShopHop voucher or free shipping code.'),
              const SizedBox(height: 10),
              TextField(
                controller: merchandise,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'ShopHop voucher code',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: shipping,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Free shipping code',
                ),
              ),
              const SizedBox(height: 8),
              const Text('Available vouchers', style: TextStyle(fontSize: 11)),
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final voucher
                      in (_preview?.availablePlatformVouchers ??
                          <BuyerCheckoutPlatformVoucherData>[]))
                    ActionChip(
                      label: Text(
                        '${voucher.code} · ${voucher.type == 'percent' ? '${voucher.value.toStringAsFixed(0)}%' : '₱${voucher.value.toStringAsFixed(0)}'} ${voucher.kind}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      onPressed: () {
                        if (voucher.kind == 'shipping') {
                          shipping.text = voucher.code;
                        } else {
                          merchandise.text = voucher.code;
                        }
                      },
                    ),
                ],
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
            onPressed: () => Navigator.pop(dialogContext, [
              merchandise.text.trim().toUpperCase(),
              shipping.text.trim().toUpperCase(),
            ]),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    // Controllers are no longer used after the dialog returns.
    merchandise.dispose();
    shipping.dispose();
    if (!mounted || values == null) return;
    final result = await _fetchPreview(
      merchandiseVoucherCode: values[0],
      shippingVoucherCode: values[1],
    );
    if (!mounted || result == null) return;
    setState(() {
      _merchandiseVoucherCode = values[0];
      _shippingVoucherCode = values[1];
    });
  }

  Future<void> _placeOrder() async {
    final preview = _preview;
    if (preview == null ||
        _placingOrder ||
        _confirmingOrder ||
        _recalculating) {
      return;
    }
    if (!preview.address.complete) {
      _showMessage(
        'Add your complete delivery address before placing an order.',
      );
      return;
    }

    final missingCourier = preview.groups.any(
      (group) =>
          group.logisticsOptions.isEmpty ||
          _logisticsPartners[group.sellerId] == null,
    );
    if (missingCourier) {
      _showMessage(
        'Delivery is unavailable for one or more shops. Check your delivery address or try again later.',
      );
      return;
    }

    setState(() => _confirmingOrder = true);
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Place order?'),
          content: Text(
            '${preview.quantityCount} item${preview.quantityCount == 1 ? '' : 's'} · ${_price(preview.summary.grandTotal)} total\n\nPlease confirm your items, delivery address, and total before placing your order.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Review'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.tealDark,
              ),
              child: const Text('Place Order'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _confirmingOrder = false);
    }
    if (confirmed != true || !mounted) return;

    setState(() => _placingOrder = true);
    try {
      final result = await BuyerCheckoutService.placeOrder(
        token: widget.token,
        items: widget.items,
        shippingMethods: {
          for (final group in preview.groups) group.sellerId: 'standard',
        },
        logisticsPartners: _logisticsPartners,
        paymentMethod: _paymentMethod,
        voucherCode: _voucherCode,
        sellerVouchers: _sellerVouchers,
        merchandiseVoucherCode: _merchandiseVoucherCode,
        shippingVoucherCode: _shippingVoucherCode,
        notes: _notes,
      );
      if (!mounted) return;

      widget.onCartCountChanged?.call(result.cartCount);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.tealDark,
            size: 46,
          ),
          title: const Text('Order placed!'),
          content: Text(
            '${result.orderIds.length} seller order${result.orderIds.length == 1 ? '' : 's'} created successfully. You can track progress in My Orders.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.tealDark,
              ),
              child: const Text('View My Orders'),
            ),
          ],
        ),
      );
      if (mounted) widget.onOrderPlaced();
    } on BuyerCheckoutException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return;
      }
      _showMessage(error.message);
      await _fetchPreview(showBusy: false);
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grayBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 21,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_recalculating)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.tealDark,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            )
          : _error != null && _preview == null
          ? _CheckoutErrorState(message: _error!.message, onRetry: _loadInitial)
          : _buildBody(),
      bottomNavigationBar: _preview == null
          ? null
          : _CheckoutBottomBar(
              total: _preview!.summary.grandTotal,
              busy: _placingOrder || _recalculating,
              enabled:
                  !_confirmingOrder &&
                  _preview!.address.complete &&
                  _preview!.groups.every(
                    (group) =>
                        group.logisticsOptions.isNotEmpty &&
                        _logisticsPartners[group.sellerId] != null,
                  ),
              onPlaceOrder: _placeOrder,
            ),
    );
  }

  Widget _buildBody() {
    final preview = _preview!;

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: () async {
        await _fetchPreview(showBusy: false);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _AddressCard(
            address: preview.address,
            onEdit: _editDeliveryAddress,
            disabled: _recalculating || _placingOrder || _confirmingOrder,
          ),
          const SizedBox(height: 10),
          for (final group in preview.groups) ...[
            _CheckoutShopCard(
              group: group,
              selectedLogisticsPartnerId:
                  _logisticsPartners[group.sellerId] ??
                  group.selectedLogisticsPartnerId,
              note: _notes[group.sellerId] ?? '',
              disabled: _recalculating || _placingOrder || _confirmingOrder,
              onLogisticsChanged: (partnerId) =>
                  _changeCourier(group.sellerId, partnerId),
              onEditAddress: _editDeliveryAddress,
              onNoteChanged: (value) => _notes[group.sellerId] = value,
            ),
            _VoucherCard(
              selectedCode: _sellerVouchers[group.sellerId] ?? '',
              selectedDiscount:
                  group.voucherDiscount + group.sellerShippingDiscount,
              voucherCount: preview.vouchers
                  .where((v) => v.sellerId == group.sellerId)
                  .length,
              enabled: !_recalculating && !_placingOrder,
              onTap: () => _chooseVoucher(group.sellerId),
              shopName: group.shopName,
            ),
            const SizedBox(height: 10),
          ],
          _SurfaceCard(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              leading: const Icon(
                Icons.discount_outlined,
                color: AppColors.tealDark,
              ),
              title: const Text('ShopHop vouchers'),
              subtitle: Text(
                _merchandiseVoucherCode.isEmpty && _shippingVoucherCode.isEmpty
                    ? 'Add a voucher or free shipping code'
                    : 'Platform: ${_merchandiseVoucherCode.isEmpty ? 'None' : _merchandiseVoucherCode} · Shipping: ${_shippingVoucherCode.isEmpty ? 'None' : _shippingVoucherCode}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _recalculating || _placingOrder
                  ? null
                  : _choosePlatformVouchers,
            ),
          ),
          const SizedBox(height: 10),
          _PaymentCard(
            selected: _paymentMethod,
            disabled: _recalculating || _placingOrder || _confirmingOrder,
            onChanged: _changePayment,
          ),
          const SizedBox(height: 10),
          _SummaryCard(summary: preview.summary),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.disabled,
  });
  final BuyerCheckoutAddressData address;
  final VoidCallback onEdit;
  final bool disabled;
  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: _CardTitle(
                icon: Icons.location_on_outlined,
                title: 'Delivery Address',
              ),
            ),
            TextButton(
              onPressed: disabled ? null : onEdit,
              child: Text(address.complete ? 'Change' : 'Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!address.complete)
          Text(
            'Add your complete address to see delivery options.',
            style: PurchaseText.detail.copyWith(color: AppColors.errorStrong),
          )
        else ...[
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(address.name, style: PurchaseText.product),
              Text(address.phone, style: PurchaseText.detail),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              address.line,
              address.city,
            ].where((value) => value.trim().isNotEmpty).join(', '),
            style: PurchaseText.detail,
          ),
          if (address.isDefault) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.pinkSoft,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'Default address',
                style: PurchaseText.detail.copyWith(
                  color: AppColors.navy,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ],
    ),
  );
}

class _CheckoutShopCard extends StatelessWidget {
  const _CheckoutShopCard({
    required this.group,
    required this.selectedLogisticsPartnerId,
    required this.note,
    required this.disabled,
    required this.onLogisticsChanged,
    required this.onEditAddress,
    required this.onNoteChanged,
  });
  final BuyerCheckoutGroupData group;
  final int? selectedLogisticsPartnerId;
  final String note;
  final bool disabled;
  final ValueChanged<int> onLogisticsChanged;
  final VoidCallback onEditAddress;
  final ValueChanged<String> onNoteChanged;
  @override
  Widget build(BuildContext context) => _SurfaceCard(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const BuyerIconTile(
                icon: Icons.storefront_outlined,
                dimension: 34,
                iconSize: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.shopName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PurchaseText.section,
                    ),
                    if (group.municipality.isNotEmpty)
                      Text(group.municipality, style: PurchaseText.detail),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        for (final item in group.items) _CheckoutItemTile(item: item),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Shipping', style: PurchaseText.section),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 21),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Standard Delivery',
                          style: PurchaseText.product,
                        ),
                        Text(
                          group.shippingRouteLabel,
                          style: PurchaseText.detail,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _price(group.shippingFee),
                      textAlign: TextAlign.end,
                      style: PurchaseText.product,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Logistics provider', style: PurchaseText.section),
              const SizedBox(height: 8),
              if (group.logisticsOptions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery is unavailable for this address. Try another address or check again later.',
                        style: PurchaseText.detail.copyWith(
                          color: AppColors.errorStrong,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: disabled ? null : onEditAddress,
                        icon: const Icon(
                          Icons.edit_location_alt_outlined,
                          size: 18,
                        ),
                        label: const Text('Change delivery address'),
                      ),
                    ],
                  ),
                )
              else
                for (final partner in group.logisticsOptions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      checked: selectedLogisticsPartnerId == partner.id,
                      enabled: !disabled,
                      child: InkWell(
                        onTap: disabled
                            ? null
                            : () => onLogisticsChanged(partner.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: selectedLogisticsPartnerId == partner.id
                                ? AppColors.pinkSoft
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedLogisticsPartnerId == partner.id
                                  ? AppColors.navy
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedLogisticsPartnerId == partner.id
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 20,
                                color: selectedLogisticsPartnerId == partner.id
                                    ? AppColors.navy
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  partner.name,
                                  style: PurchaseText.detail.copyWith(
                                    color: AppColors.navy,
                                    fontWeight:
                                        selectedLogisticsPartnerId == partner.id
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 8),
              TextFormField(
                key: ValueKey('seller-note-${group.sellerId}'),
                initialValue: note,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                enabled: !disabled,
                style: PurchaseText.detail.copyWith(color: AppColors.navy),
                onChanged: onNoteChanged,
                decoration: const InputDecoration(
                  labelText: 'Message to seller (optional)',
                  hintText: 'Add a note for this shop',
                  counterText: '',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _SummaryRow('Items subtotal', group.merchandiseSubtotal),
              _SummaryRow('Shop total', group.groupTotal),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CheckoutItemTile extends StatelessWidget {
  const _CheckoutItemTile({required this.item});
  final BuyerCheckoutItemData item;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PurchaseImage(url: item.image),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PurchaseText.product,
              ),
              if (item.variant.trim().isNotEmpty &&
                  item.variant.toLowerCase() != 'standard') ...[
                const SizedBox(height: 4),
                Text(
                  item.variant,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PurchaseText.detail,
                ),
              ],
              const SizedBox(height: 8),
              PurchasePrice(value: item.price, original: item.originalPrice),
              const SizedBox(height: 4),
              Text('Qty: ${item.quantity}', style: PurchaseText.detail),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({
    required this.selectedCode,
    required this.selectedDiscount,
    required this.voucherCount,
    required this.enabled,
    required this.onTap,
    required this.shopName,
  });

  final String shopName;
  final String selectedCode;
  final double selectedDiscount;
  final int voucherCount;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.pinkSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shop Voucher · $shopName',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedCode.isNotEmpty
                          ? '$selectedCode · -${_price(selectedDiscount)}'
                          : voucherCount > 0
                          ? '$voucherCount voucher${voucherCount == 1 ? '' : 's'} available'
                          : 'No voucher available for these items',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFA0A8AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.selected,
    required this.disabled,
    required this.onChanged,
  });
  final String selected;
  final bool disabled;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CardTitle(
          icon: Icons.payments_outlined,
          title: 'Payment Method',
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: disabled ? null : () => onChanged('cod'),
          child: Row(
            children: [
              const Icon(Icons.local_shipping_outlined, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cash on Delivery', style: PurchaseText.product),
                    Text(
                      'Pay when your order arrives.',
                      style: PurchaseText.detail,
                    ),
                  ],
                ),
              ),
              Icon(
                selected == 'cod' ? Icons.check_circle : Icons.radio_button_off,
                size: 21,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final BuyerCheckoutSummaryData summary;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.receipt_outlined,
            title: 'Order Summary',
          ),
          const SizedBox(height: 12),
          _SummaryRow('Merchandise Subtotal', summary.merchandiseSubtotal),
          _SummaryRow('Shipping Fee', summary.shippingFee),
          if (summary.codFee > 0) _SummaryRow('COD Fee', summary.codFee),
          if (summary.platformDiscount > 0)
            _SummaryRow(
              'ShopHop Discount',
              -summary.platformDiscount,
              discount: true,
            ),
          if (summary.shippingDiscount > 0)
            _SummaryRow(
              'Free Shipping Discount',
              -summary.shippingDiscount,
              discount: true,
            ),
          if (summary.voucherDiscount > 0)
            _SummaryRow(
              'Seller Merchandise Voucher',
              -summary.voucherDiscount,
              discount: true,
            ),
          if (summary.sellerShippingDiscount > 0)
            _SummaryRow(
              'Seller Shipping Voucher',
              -summary.sellerShippingDiscount,
              discount: true,
            ),
          const Divider(height: 20, color: Color(0xFFECEFF1)),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Order Total',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _price(summary.grandTotal),
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.discount = false});

  final String label;
  final double value;
  final bool discount;

  @override
  Widget build(BuildContext context) {
    final display = value < 0 ? '-${_price(value.abs())}' : _price(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          Text(
            display,
            style: TextStyle(
              color: discount ? AppColors.tealDark : AppColors.navy,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherSheet extends StatelessWidget {
  const _VoucherSheet({required this.vouchers, required this.selectedCode});

  final List<BuyerCheckoutVoucherData> vouchers;
  final String selectedCode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .72,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD6DBDE),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Text(
                    'Choose Shop Voucher',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                children: [
                  _VoucherTile(
                    title: 'No voucher',
                    description: 'Checkout without a voucher discount',
                    selected: selectedCode.isEmpty,
                    onTap: () => Navigator.of(context).pop('__NONE__'),
                  ),
                  const SizedBox(height: 8),
                  if (vouchers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No active voucher is available for the selected products.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF7D8791),
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    for (final voucher in vouchers) ...[
                      _VoucherTile(
                        title: '${voucher.code} · ${voucher.title}',
                        description: voucher.description,
                        selected: selectedCode == voucher.code,
                        onTap: () => Navigator.of(context).pop(voucher.code),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherTile extends StatelessWidget {
  const _VoucherTile({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.tealLight : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.tealDark : AppColors.grayBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? AppColors.tealLight : AppColors.pinkSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.confirmation_number_outlined,
                color: selected ? AppColors.tealDark : AppColors.navy,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? AppColors.tealDark : const Color(0xFFB4BBC0),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutBottomBar extends StatelessWidget {
  const _CheckoutBottomBar({
    required this.total,
    required this.busy,
    required this.enabled,
    required this.onPlaceOrder,
  });
  final double total;
  final bool busy, enabled;
  final VoidCallback onPlaceOrder;
  @override
  Widget build(BuildContext context) => PurchaseBottomBar(
    summary: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Total payment', style: PurchaseText.detail),
        Text(_price(total), style: PurchaseText.price),
      ],
    ),
    action: FilledButton(
      key: const ValueKey('place-order-button'),
      onPressed: enabled && !busy ? onPlaceOrder : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size(150, 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Place Order'),
    ),
  );
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      BuyerIconTile(icon: icon, dimension: 32, iconSize: 19),
      const SizedBox(width: 10),
      Expanded(child: Text(title, style: PurchaseText.section)),
    ],
  );
}

class _CheckoutErrorState extends StatelessWidget {
  const _CheckoutErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 46,
              color: AppColors.navy,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6C7780), fontSize: 11),
            ),
            const SizedBox(height: 13),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

String _price(double value) => '₱${value.toStringAsFixed(2)}';
