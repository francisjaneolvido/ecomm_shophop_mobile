import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_messages_page.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_product_card.dart';

class BuyerShopPage extends StatefulWidget {
  const BuyerShopPage({
    super.key,
    required this.token,
    required this.sellerId,
    required this.onOpenProduct,
    required this.onSessionExpired,
  });

  final String token;
  final int sellerId;
  final ValueChanged<BuyerProductData> onOpenProduct;
  final Future<void> Function() onSessionExpired;

  @override
  State<BuyerShopPage> createState() => _BuyerShopPageState();
}

class _BuyerShopPageState extends State<BuyerShopPage> {
  BuyerShopData? _shop;
  final List<BuyerProductData> _products = [];
  String? _category;
  String? _error;
  int _page = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await BuyerCatalogService.getShop(
        token: widget.token,
        sellerId: widget.sellerId,
        category: _category,
        page: more ? _page + 1 : 1,
      );
      if (!mounted) return;
      setState(() {
        _shop = result;
        _page = more ? _page + 1 : 1;
        if (!more) _products.clear();
        _products.addAll(result.products);
      });
    } on BuyerCatalogException catch (error) {
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return;
      }
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectCategory(String? category) {
    if (_category == category) return;
    setState(() => _category = category);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final shop = _shop;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(shop?.businessName ?? 'Shop')),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (shop == null && _busy)
              const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (shop == null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(_error ?? 'Shop is unavailable.'),
                    TextButton(
                      onPressed: () => _load(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else ...[
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
                child: SizedBox(
                  height: 185,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: colors.primaryContainer),
                      if (shop.coverUrl.isNotEmpty)
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                          child: Image.network(
                            shop.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      const ColoredBox(color: Color(0x880D1735)),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 33,
                                  backgroundColor: colors.surface,
                                  foregroundImage: shop.logoUrl.isEmpty
                                      ? null
                                      : NetworkImage(shop.logoUrl),
                                  child: shop.logoUrl.isEmpty
                                      ? Text(
                                          shop.businessName.isEmpty
                                              ? 'S'
                                              : shop.businessName[0]
                                                    .toUpperCase(),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        shop.businessName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        [
                                              shop.businessCategory,
                                              shop.municipality,
                                              shop.province,
                                            ]
                                            .where((part) => part.isNotEmpty)
                                            .join(' · '),
                                        maxLines: 2,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _stat(context, '${shop.productsCount}', 'Products'),
                    _stat(
                      context,
                      shop.reviewsCount == 0
                          ? 'New shop'
                          : '${shop.rating.toStringAsFixed(1)} / 5',
                      'Rating',
                    ),
                    _stat(context, '${shop.reviewsCount}', 'Reviews'),
                    if (shop.joined.isNotEmpty)
                      _stat(context, shop.joined, 'Joined'),
                  ],
                ),
              ),
              if (shop.userId > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BuyerChatPage(
                          token: widget.token,
                          sellerUserId: shop.userId,
                          name: shop.businessName,
                          onSessionExpired: widget.onSessionExpired,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 17),
                    label: const Text('Chat with shop'),
                  ),
                ),
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('All products'),
                        selected: _category == null,
                        onSelected: (_) => _selectCategory(null),
                      ),
                    ),
                    for (final category in shop.categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _category == category,
                          onSelected: (_) => _selectCategory(category),
                        ),
                      ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(_error!, style: TextStyle(color: colors.error)),
                ),
              if (_products.isEmpty && !_busy)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No available products here yet.')),
                ),
              if (_products.isNotEmpty)
                LayoutBuilder(
                  builder: (context, constraints) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: BuyerProductCard.gridDelegate(
                        context,
                        constraints.maxWidth - 32,
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, index) => BuyerProductCard(
                        product: _products[index],
                        onTap: () => widget.onOpenProduct(_products[index]),
                      ),
                    ),
                  ),
                ),
              if (shop.hasMore)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _load(more: true),
                    child: Text(_busy ? 'Loading…' : 'Load more products'),
                  ),
                ),
              if (_busy && _products.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    ),
  );
}
