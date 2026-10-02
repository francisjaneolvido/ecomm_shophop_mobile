import 'package:flutter/material.dart';

import '../../../services/buyer_cart_service.dart';
import '../../../theme/app_colors.dart';

class BuyerCartPage extends StatefulWidget {
  const BuyerCartPage({
    super.key,
    required this.token,
    required this.onSessionExpired,
    required this.onOpenProductId,
    required this.onContinueShopping,
    required this.onCheckout,
    this.buyNowLineKey,
    this.onCartCountChanged,
  });

  final String token;
  final Future<void> Function() onSessionExpired;
  final ValueChanged<int> onOpenProductId;
  final VoidCallback onContinueShopping;
  final void Function(Map<String, int> items) onCheckout;
  final String? buyNowLineKey;
  final ValueChanged<int>? onCartCountChanged;

  @override
  State<BuyerCartPage> createState() => _BuyerCartPageState();
}

class _BuyerCartPageState extends State<BuyerCartPage> {
  BuyerCartData? _cart;
  BuyerCartException? _error;
  final Set<String> _selected = <String>{};
  final Set<String> _busyLines = <String>{};
  bool _loading = true;
  bool _deletingSelected = false;

  @override
  void initState() {
    super.initState();
    _loadCart(initial: true);
  }

  Future<void> _loadCart({bool initial = false}) async {
    if (mounted) {
      setState(() {
        _loading = _cart == null;
        _error = null;
      });
    }

    try {
      final cart = await BuyerCartService.getCart(token: widget.token);
      if (!mounted) return;

      final availableKeys = cart.items
          .where((item) => item.isAvailable)
          .map((item) => item.lineKey)
          .toSet();

      setState(() {
        _cart = cart;
        _loading = false;
        _error = null;

        if (initial) {
          final buyNow = widget.buyNowLineKey;
          _selected
            ..clear()
            ..addAll(
              buyNow != null && availableKeys.contains(buyNow)
                  ? <String>{buyNow}
                  : availableKeys,
            );
        } else {
          _selected.removeWhere((key) => !availableKeys.contains(key));
        }
      });

      widget.onCartCountChanged?.call(cart.cartCount);
    } on BuyerCartException catch (error) {
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

  List<BuyerCartItemData> get _items => _cart?.items ?? const [];

  List<BuyerCartItemData> get _availableItems =>
      _items.where((item) => item.isAvailable).toList(growable: false);

  List<BuyerCartItemData> get _selectedItems => _availableItems
      .where((item) => _selected.contains(item.lineKey))
      .toList(growable: false);

  double get _selectedSubtotal => _selectedItems.fold<double>(
        0,
        (sum, item) => sum + item.lineTotal,
      );

  bool get _allAvailableSelected =>
      _availableItems.isNotEmpty && _selected.length == _availableItems.length;

  void _toggleAll(bool selected) {
    setState(() {
      _selected.clear();
      if (selected) {
        _selected.addAll(_availableItems.map((item) => item.lineKey));
      }
    });
  }

  void _toggleGroup(BuyerCartGroupData group, bool selected) {
    final keys = group.items
        .where((item) => item.isAvailable)
        .map((item) => item.lineKey)
        .toList(growable: false);
    setState(() {
      if (selected) {
        _selected.addAll(keys);
      } else {
        _selected.removeAll(keys);
      }
    });
  }

  void _toggleItem(BuyerCartItemData item, bool selected) {
    if (!item.isAvailable) return;
    setState(() {
      if (selected) {
        _selected.add(item.lineKey);
      } else {
        _selected.remove(item.lineKey);
      }
    });
  }

  Future<void> _changeQuantity(BuyerCartItemData item, int nextQty) async {
    if (_busyLines.contains(item.lineKey) || !item.isAvailable) return;
    if (nextQty < 1 || nextQty > item.stock || nextQty == item.quantity) return;

    setState(() => _busyLines.add(item.lineKey));

    try {
      await BuyerCartService.updateQuantity(
        token: widget.token,
        lineKey: item.lineKey,
        quantity: nextQty,
      );
      if (!mounted) return;
      await _loadCart();
    } on BuyerCartException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return;
      }
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _busyLines.remove(item.lineKey));
      }
    }
  }

  Future<void> _removeItem(BuyerCartItemData item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('Remove “${item.name}” from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE25566),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busyLines.add(item.lineKey));
    try {
      final result = await BuyerCartService.remove(
        token: widget.token,
        lineKey: item.lineKey,
      );
      if (!mounted) return;
      _selected.remove(item.lineKey);
      widget.onCartCountChanged?.call(result.cartCount);
      await _loadCart();
    } on BuyerCartException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return;
      }
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _busyLines.remove(item.lineKey));
      }
    }
  }

  Future<void> _removeSelected() async {
    if (_selected.isEmpty || _deletingSelected) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove selected items?'),
        content: Text(
          'Remove ${_selected.length} selected item${_selected.length == 1 ? '' : 's'} from your cart?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE25566),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingSelected = true);
    try {
      final result = await BuyerCartService.removeMany(
        token: widget.token,
        lineKeys: _selected.toList(growable: false),
      );
      if (!mounted) return;
      _selected.clear();
      widget.onCartCountChanged?.call(result.cartCount);
      await _loadCart();
    } on BuyerCartException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return;
      }
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _deletingSelected = false);
      }
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
          'My Cart',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          if (_selected.isNotEmpty)
            TextButton.icon(
              onPressed: _deletingSelected ? null : _removeSelected,
              icon: _deletingSelected
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD94E60),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _cart != null && _cart!.items.isNotEmpty
          ? _CartSummaryBar(
              allSelected: _allAvailableSelected,
              selectedCount: _selectedItems.length,
              subtotal: _selectedSubtotal,
              onSelectAll: _toggleAll,
              onCheckout: _selectedItems.isEmpty
                  ? null
                  : () => widget.onCheckout(<String, int>{
                        for (final item in _selectedItems)
                          item.lineKey: item.quantity,
                      }),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading && _cart == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal),
      );
    }

    if (_error != null && _cart == null) {
      return _CartErrorState(
        message: _error!.message,
        onRetry: () => _loadCart(initial: true),
      );
    }

    final cart = _cart;
    if (cart == null || cart.items.isEmpty) {
      return _EmptyCart(onContinueShopping: widget.onContinueShopping);
    }

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: () => _loadCart(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
        children: [
          _CartInfoCard(
            cartCount: cart.cartCount,
            quantityCount: cart.quantityCount,
            unavailableCount: cart.unavailableCount,
          ),
          const SizedBox(height: 10),
          for (final group in cart.groups) ...[
            _ShopCartCard(
              group: group,
              selected: _selected,
              busyLines: _busyLines,
              onToggleGroup: (value) => _toggleGroup(group, value),
              onToggleItem: _toggleItem,
              onOpenProduct: widget.onOpenProductId,
              onDecrease: (item) => _changeQuantity(item, item.quantity - 1),
              onIncrease: (item) => _changeQuantity(item, item.quantity + 1),
              onRemove: _removeItem,
            ),
            const SizedBox(height: 10),
          ],
          if (cart.vouchers.isNotEmpty) ...[
            _VoucherPreview(vouchers: cart.vouchers),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CartInfoCard extends StatelessWidget {
  const _CartInfoCard({
    required this.cartCount,
    required this.quantityCount,
    required this.unavailableCount,
  });

  final int cartCount;
  final int quantityCount;
  final int unavailableCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7ECEE)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE9F8F5),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$cartCount product line${cartCount == 1 ? '' : 's'} · $quantityCount item${quantityCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  unavailableCount > 0
                      ? '$unavailableCount item${unavailableCount == 1 ? ' is' : 's are'} currently unavailable.'
                      : 'Your cart is synchronized with ShopHop web.',
                  style: TextStyle(
                    color: unavailableCount > 0
                        ? const Color(0xFFD55262)
                        : const Color(0xFF7D8791),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
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

class _ShopCartCard extends StatelessWidget {
  const _ShopCartCard({
    required this.group,
    required this.selected,
    required this.busyLines,
    required this.onToggleGroup,
    required this.onToggleItem,
    required this.onOpenProduct,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final BuyerCartGroupData group;
  final Set<String> selected;
  final Set<String> busyLines;
  final ValueChanged<bool> onToggleGroup;
  final void Function(BuyerCartItemData item, bool selected) onToggleItem;
  final ValueChanged<int> onOpenProduct;
  final ValueChanged<BuyerCartItemData> onDecrease;
  final ValueChanged<BuyerCartItemData> onIncrease;
  final ValueChanged<BuyerCartItemData> onRemove;

  @override
  Widget build(BuildContext context) {
    final selectableKeys = group.items
        .where((item) => item.isAvailable)
        .map((item) => item.lineKey)
        .toList(growable: false);
    final allSelected = selectableKeys.isNotEmpty &&
        selectableKeys.every(selected.contains);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE5EAED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              children: [
                Checkbox.adaptive(
                  value: allSelected,
                  onChanged: selectableKeys.isEmpty
                      ? null
                      : (value) => onToggleGroup(value == true),
                  activeColor: AppColors.tealDark,
                  visualDensity: VisualDensity.compact,
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFDCF7F1), Color(0xFFF3FCFA)],
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppColors.tealDark,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.shop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (group.shop.municipality.isNotEmpty)
                        Text(
                          group.shop.municipality,
                          style: const TextStyle(
                            color: Color(0xFF8B949D),
                            fontSize: 9.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEAEDEF)),
          for (var i = 0; i < group.items.length; i++) ...[
            _CartItemTile(
              item: group.items[i],
              selected: selected.contains(group.items[i].lineKey),
              busy: busyLines.contains(group.items[i].lineKey),
              onSelected: (value) => onToggleItem(group.items[i], value),
              onOpenProduct: () => onOpenProduct(group.items[i].productId),
              onDecrease: () => onDecrease(group.items[i]),
              onIncrease: () => onIncrease(group.items[i]),
              onRemove: () => onRemove(group.items[i]),
            ),
            if (i != group.items.length - 1)
              const Divider(
                height: 1,
                indent: 12,
                endIndent: 12,
                color: Color(0xFFEEF1F2),
              ),
          ],
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.selected,
    required this.busy,
    required this.onSelected,
    required this.onOpenProduct,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final BuyerCartItemData item;
  final bool selected;
  final bool busy;
  final ValueChanged<bool> onSelected;
  final VoidCallback onOpenProduct;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Checkbox.adaptive(
              value: item.isAvailable ? selected : false,
              onChanged: item.isAvailable && !busy
                  ? (value) => onSelected(value == true)
                  : null,
              activeColor: AppColors.tealDark,
              visualDensity: VisualDensity.compact,
            ),
          ),
          InkWell(
            onTap: onOpenProduct,
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 82,
                height: 82,
                color: const Color(0xFFF0F4F4),
                child: item.image.isEmpty
                    ? const Icon(
                        Icons.image_outlined,
                        color: Color(0xFFB6C1C6),
                      )
                    : Image.network(
                        item.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFFB6C1C6),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onOpenProduct,
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (item.variant.isNotEmpty && item.variant != 'Standard') ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F5F6),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      item.variant,
                      style: const TextStyle(
                        color: Color(0xFF74808A),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      _price(item.price),
                      style: const TextStyle(
                        color: Color(0xFFEC526A),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (item.originalPrice != null &&
                        item.originalPrice! > item.price) ...[
                      const SizedBox(width: 6),
                      Text(
                        _price(item.originalPrice!),
                        style: const TextStyle(
                          color: Color(0xFFA2AAB2),
                          fontSize: 9.5,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (!item.isAvailable)
                  const Text(
                    'Unavailable · remove or wait for seller update',
                    style: TextStyle(
                      color: Color(0xFFD34E60),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Row(
                    children: [
                      _QtyButton(
                        icon: Icons.remove_rounded,
                        enabled: item.quantity > 1 && !busy,
                        onTap: onDecrease,
                      ),
                      Container(
                        width: 38,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(color: Color(0xFFDCE2E5)),
                          ),
                        ),
                        child: busy
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.tealDark,
                                ),
                              )
                            : Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                      _QtyButton(
                        icon: Icons.add_rounded,
                        enabled: item.quantity < item.stock && !busy,
                        onTap: onIncrease,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item.stock} available',
                          style: const TextStyle(
                            color: Color(0xFF929AA2),
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: busy ? null : onRemove,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFF9AA3AB),
              size: 19,
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF5F6F7),
          border: Border.all(color: const Color(0xFFDCE2E5)),
        ),
        child: Icon(
          icon,
          size: 15,
          color: enabled ? AppColors.navy : const Color(0xFFBCC3C8),
        ),
      ),
    );
  }
}

class _VoucherPreview extends StatelessWidget {
  const _VoucherPreview({required this.vouchers});

  final List<BuyerCartVoucherData> vouchers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE5EAED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.local_activity_outlined,
                color: AppColors.tealDark,
                size: 19,
              ),
              SizedBox(width: 7),
              Text(
                'Available Shop Vouchers',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...vouchers.take(3).map(
                (voucher) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F2),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFFFDDC7)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.confirmation_number_outlined,
                          color: Color(0xFFEB7A57),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                voucher.title,
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${voucher.code} · ${voucher.description}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF858E97),
                                  fontSize: 9,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const Text(
            'Choose and validate vouchers on the checkout page. ShopHop Laravel remains the authority for final totals.',
            style: TextStyle(
              color: Color(0xFF8A939C),
              fontSize: 9.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartSummaryBar extends StatelessWidget {
  const _CartSummaryBar({
    required this.allSelected,
    required this.selectedCount,
    required this.subtotal,
    required this.onSelectAll,
    required this.onCheckout,
  });

  final bool allSelected;
  final int selectedCount;
  final double subtotal;
  final ValueChanged<bool> onSelectAll;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 9, 10, 9),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () => onSelectAll(!allSelected),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox.adaptive(
                    value: allSelected,
                    onChanged: (value) => onSelectAll(value == true),
                    activeColor: AppColors.tealDark,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text(
                    'All',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Subtotal',
                    style: TextStyle(
                      color: Color(0xFF838C95),
                      fontSize: 9,
                    ),
                  ),
                  Text(
                    _price(subtotal),
                    style: const TextStyle(
                      color: Color(0xFFEC526A),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: onCheckout,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEC526A),
                disabledBackgroundColor: const Color(0xFFD6DADD),
                minimumSize: const Size(118, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                selectedCount > 0 ? 'Checkout ($selectedCount)' : 'Checkout',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onContinueShopping});

  final VoidCallback onContinueShopping;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: const BoxDecoration(
                color: Color(0xFFE9F8F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: AppColors.tealDark,
                size: 39,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Products added from the ShopHop web or mobile app will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7C8791),
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onContinueShopping,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.tealDark,
              ),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Continue Shopping'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartErrorState extends StatelessWidget {
  const _CartErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              color: AppColors.tealDark,
              size: 56,
            ),
            const SizedBox(height: 14),
            const Text(
              'Could not load cart',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF737D89),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.tealDark),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

String _price(double value) {
  final whole = value == value.roundToDouble();
  return '₱${value.toStringAsFixed(whole ? 0 : 2)}';
}
