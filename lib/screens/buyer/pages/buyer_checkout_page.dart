import 'package:flutter/material.dart';

import '../../../services/buyer_checkout_service.dart';
import '../../../theme/app_colors.dart';
import 'buyer_payment_proof_page.dart';

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
  final Map<int, String> _shippingMethods = <int, String>{};
  final Map<int, String> _notes = <int, String>{};
  String _paymentMethod = 'cod';
  String _voucherCode = '';
  bool _loading = true;
  bool _recalculating = false;
  bool _placingOrder = false;

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
        _shippingMethods
          ..clear()
          ..addEntries(
            preview.groups.map(
              (group) => MapEntry(
                group.sellerId,
                group.selectedShippingMethod,
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
    Map<int, String>? shippingMethods,
    String? paymentMethod,
    String? voucherCode,
    bool showBusy = true,
  }) async {
    if (showBusy && mounted) setState(() => _recalculating = true);
    try {
      final preview = await BuyerCheckoutService.preview(
        token: widget.token,
        items: widget.items,
        shippingMethods: shippingMethods ?? _shippingMethods,
        paymentMethod: paymentMethod ?? _paymentMethod,
        voucherCode: voucherCode ?? _voucherCode,
      );
      if (!mounted) return null;
      setState(() {
        _preview = preview;
        _error = null;
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

  Future<void> _changeShipping(int sellerId, String method) async {
    final previous = _shippingMethods[sellerId] ?? 'standard';
    if (previous == method || _recalculating) return;

    final next = Map<int, String>.from(_shippingMethods)..[sellerId] = method;
    setState(() => _shippingMethods[sellerId] = method);
    final preview = await _fetchPreview(shippingMethods: next);
    if (!mounted) return;
    if (preview == null) {
      setState(() => _shippingMethods[sellerId] = previous);
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

  Future<void> _chooseVoucher() async {
    final preview = _preview;
    if (preview == null || _recalculating) return;

    final selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VoucherSheet(
        vouchers: preview.vouchers,
        selectedCode: _voucherCode,
      ),
    );

    if (!mounted || selected == null) return;
    final candidate = selected == '__NONE__' ? '' : selected;
    if (candidate == _voucherCode) return;

    final updated = await _fetchPreview(voucherCode: candidate);
    if (!mounted || updated == null) return;
    setState(() => _voucherCode = candidate);
  }

  Future<void> _placeOrder() async {
    final preview = _preview;
    if (preview == null || _placingOrder || _recalculating) return;
    if (!preview.address.complete) {
      _showMessage('Complete your delivery address in your ShopHop profile first.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Place order?'),
        content: Text(
          '${preview.quantityCount} item${preview.quantityCount == 1 ? '' : 's'} · ${_price(preview.summary.grandTotal)} total\n\nShopHop will recheck stock, prices, voucher eligibility, and fees on the server before creating the order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Review'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.tealDark),
            child: const Text('Place Order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _placingOrder = true);
    try {
      final result = await BuyerCheckoutService.placeOrder(
        token: widget.token,
        items: widget.items,
        shippingMethods: _shippingMethods,
        paymentMethod: _paymentMethod,
        voucherCode: _voucherCode,
        notes: _notes,
      );
      if (!mounted) return;

      widget.onCartCountChanged?.call(result.cartCount);

      if (result.paymentMethod == 'online' && result.paymentId != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BuyerPaymentProofPage(
              token: widget.token,
              paymentId: result.paymentId!,
              onSessionExpired: widget.onSessionExpired,
              onGoToOrders: widget.onOrderPlaced,
            ),
          ),
        );
        return;
      }

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
              style: FilledButton.styleFrom(backgroundColor: AppColors.tealDark),
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
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
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
            fontSize: 18,
            fontWeight: FontWeight.w900,
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
              ? _CheckoutErrorState(
                  message: _error!.message,
                  onRetry: _loadInitial,
                )
              : _buildBody(),
      bottomNavigationBar: _preview == null
          ? null
          : _CheckoutBottomBar(
              total: _preview!.summary.grandTotal,
              busy: _placingOrder || _recalculating,
              enabled: _preview!.address.complete,
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
        children: [
          _SecureCheckoutHeader(
            itemCount: preview.quantityCount,
            shopCount: preview.shopCount,
          ),
          const SizedBox(height: 10),
          _AddressCard(address: preview.address),
          const SizedBox(height: 10),
          for (final group in preview.groups) ...[
            _CheckoutShopCard(
              group: group,
              selectedShipping:
                  _shippingMethods[group.sellerId] ?? group.selectedShippingMethod,
              note: _notes[group.sellerId] ?? '',
              disabled: _recalculating || _placingOrder,
              onShippingChanged: (method) =>
                  _changeShipping(group.sellerId, method),
              onNoteChanged: (value) => _notes[group.sellerId] = value,
            ),
            const SizedBox(height: 10),
          ],
          _VoucherCard(
            selectedCode: _voucherCode,
            selectedDiscount: preview.summary.voucherDiscount,
            voucherCount: preview.vouchers.length,
            enabled: !_recalculating && !_placingOrder,
            onTap: _chooseVoucher,
          ),
          const SizedBox(height: 10),
          _PaymentCard(
            selected: _paymentMethod,
            disabled: _recalculating || _placingOrder,
            onChanged: _changePayment,
          ),
          const SizedBox(height: 10),
          _SummaryCard(summary: preview.summary),
        ],
      ),
    );
  }
}

class _SecureCheckoutHeader extends StatelessWidget {
  const _SecureCheckoutHeader({required this.itemCount, required this.shopCount});

  final int itemCount;
  final int shopCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10264D), Color(0xFF16445A)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: Colors.white.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Secure Checkout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$itemCount item${itemCount == 1 ? '' : 's'} from $shopCount shop${shopCount == 1 ? '' : 's'} · totals are verified by Laravel before order creation.',
                  style: TextStyle(
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(.72),
                    fontSize: 9.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});

  final BuyerCheckoutAddressData address;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.location_on_outlined,
            title: 'Delivery Address',
          ),
          const SizedBox(height: 11),
          if (!address.complete)
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFD65362),
                    size: 19,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your ShopHop Buyer profile does not have a complete delivery address yet. Update the same profile used by the web app before placing an order.',
                      style: TextStyle(
                        color: Color(0xFFD65362),
                        fontSize: 10,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    address.name,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  address.phone,
                  style: const TextStyle(
                    color: Color(0xFF7D8791),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${address.line}, ${address.city}',
              style: const TextStyle(
                color: Color(0xFF66717B),
                fontSize: 10.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'DEFAULT PROFILE ADDRESS',
                style: TextStyle(
                  color: AppColors.tealDark,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckoutShopCard extends StatelessWidget {
  const _CheckoutShopCard({
    required this.group,
    required this.selectedShipping,
    required this.note,
    required this.disabled,
    required this.onShippingChanged,
    required this.onNoteChanged,
  });

  final BuyerCheckoutGroupData group;
  final String selectedShipping;
  final String note;
  final bool disabled;
  final ValueChanged<String> onShippingChanged;
  final ValueChanged<String> onNoteChanged;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppColors.tealDark,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (group.municipality.isNotEmpty)
                        Text(
                          group.municipality,
                          style: const TextStyle(
                            color: Color(0xFF8B949D),
                            fontSize: 9.5,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  _price(group.groupTotal),
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEDF0F2)),
          for (var i = 0; i < group.items.length; i++) ...[
            _CheckoutItemTile(item: group.items[i]),
            if (i != group.items.length - 1)
              const Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: Color(0xFFF0F2F3),
              ),
          ],
          const Divider(height: 1, color: Color(0xFFEDF0F2)),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shipping Option',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                _ShippingOption(
                  title: 'Standard Delivery',
                  subtitle: 'Published ShopHop standard shipping fee',
                  price: group.shippingFeeStandard,
                  selected: selectedShipping == 'standard',
                  enabled: !disabled,
                  onTap: () => onShippingChanged('standard'),
                ),
                const SizedBox(height: 7),
                _ShippingOption(
                  title: 'Express Delivery',
                  subtitle: 'Standard fee + express surcharge',
                  price: group.shippingFeeExpress,
                  selected: selectedShipping == 'express',
                  enabled: !disabled,
                  onTap: () => onShippingChanged('express'),
                ),
                const SizedBox(height: 11),
                TextFormField(
                  initialValue: note,
                  maxLength: 500,
                  enabled: !disabled,
                  onChanged: onNoteChanged,
                  decoration: _fieldDecoration(
                    'Message to seller (optional)',
                    'Add packing or order notes',
                  ).copyWith(counterText: ''),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutItemTile extends StatelessWidget {
  const _CheckoutItemTile({required this.item});

  final BuyerCheckoutItemData item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: 66,
              height: 66,
              color: const Color(0xFFF1F4F5),
              child: item.image.isEmpty
                  ? const Icon(Icons.image_outlined, color: Color(0xFFB4BFC4))
                  : Image.network(
                      item.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_not_supported_outlined,
                        color: Color(0xFFB4BFC4),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (item.variant.isNotEmpty && item.variant != 'Standard') ...[
                  const SizedBox(height: 4),
                  Text(
                    item.variant,
                    style: const TextStyle(
                      color: Color(0xFF7D8791),
                      fontSize: 9.5,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      _price(item.price),
                      style: const TextStyle(
                        color: Color(0xFFEA5369),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'x${item.quantity}',
                      style: const TextStyle(
                        color: Color(0xFF6F7A84),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShippingOption extends StatelessWidget {
  const _ShippingOption({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final double price;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0FBF8) : const Color(0xFFF8FAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.tealDark : AppColors.grayBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.tealDark : const Color(0xFFADB5BB),
              size: 19,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF89939B),
                      fontSize: 8.8,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _price(price),
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({
    required this.selectedCode,
    required this.selectedDiscount,
    required this.voucherCount,
    required this.enabled,
    required this.onTap,
  });

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
                  color: const Color(0xFFFFF2E4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  color: Color(0xFFE58A2B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shop Voucher',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
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
                        color: Color(0xFF7E8992),
                        fontSize: 9.5,
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
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.payments_outlined,
            title: 'Payment Method',
          ),
          const SizedBox(height: 10),
          _PaymentOption(
            icon: Icons.local_shipping_outlined,
            title: 'Cash on Delivery',
            subtitle: 'COD handling fee is applied per seller order.',
            selected: selected == 'cod',
            enabled: !disabled,
            onTap: () => onChanged('cod'),
          ),
          const SizedBox(height: 8),
          _PaymentOption(
            icon: Icons.receipt_long_outlined,
            title: 'Online Payment',
            subtitle:
                'Submit a payment reference and receipt for ShopHop Admin review after placing the order.',
            selected: selected == 'online',
            enabled: !disabled,
            onTap: () => onChanged('online'),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0FBF8) : const Color(0xFFF8FAFA),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? AppColors.tealDark : AppColors.grayBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? AppColors.tealDark : AppColors.navy),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7E8992),
                      fontSize: 9.2,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.tealDark : const Color(0xFFABB3B9),
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
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
            title: 'Payment Details',
          ),
          const SizedBox(height: 12),
          _SummaryRow('Merchandise Subtotal', summary.merchandiseSubtotal),
          _SummaryRow('Shipping Fee', summary.shippingFee),
          if (summary.codFee > 0) _SummaryRow('COD Fee', summary.codFee),
          if (summary.voucherDiscount > 0)
            _SummaryRow(
              'Voucher Discount',
              -summary.voucherDiscount,
              discount: true,
            ),
          const Divider(height: 20, color: Color(0xffecef1f1)),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Order Total',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _price(summary.grandTotal),
                style: const TextStyle(
                  color: Color(0xFFEA5369),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
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
              style: const TextStyle(
                color: Color(0xFF6F7A83),
                fontSize: 10,
              ),
            ),
          ),
          Text(
            display,
            style: TextStyle(
              color: discount ? AppColors.tealDark : AppColors.navy,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      fontWeight: FontWeight.w900,
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
                          fontSize: 10.5,
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0FBF8) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
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
                color: selected ? AppColors.tealLight : const Color(0xFFFFF2E4),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.confirmation_number_outlined,
                color: selected ? AppColors.tealDark : const Color(0xFFE58A2B),
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
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF7E8992),
                      fontSize: 9.2,
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
  final bool busy;
  final bool enabled;
  final VoidCallback onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.grayBorder)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(color: Color(0xFF7D8791), fontSize: 9.5),
                  ),
                  Text(
                    _price(total),
                    style: const TextStyle(
                      color: Color(0xFFEA5369),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 156,
              height: 46,
              child: FilledButton(
                onPressed: enabled && !busy ? onPlaceOrder : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.tealDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Place Order',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.tealDark, size: 17),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
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
            const Icon(Icons.shopping_bag_outlined,
                size: 46, color: AppColors.navy),
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

InputDecoration _fieldDecoration(String label, String hint) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF8FAFA),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.grayBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.grayBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.tealDark, width: 1.2),
    ),
  );
}

String _price(double value) => '₱${value.toStringAsFixed(2)}';
