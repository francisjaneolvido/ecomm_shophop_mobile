import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shophop/shared/realtime/foreground_refresh.dart';
import 'package:flutter/services.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_product_gallery.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_variant_sheet.dart';

import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/data/services/buyer_cart_service.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_product_card.dart';

class BuyerProductDetailPage extends StatefulWidget {
  const BuyerProductDetailPage({
    super.key,
    required this.token,
    required this.productId,
    required this.onSessionExpired,
    required this.onOpenProduct,
    required this.onOpenSearch,
    required this.onOpenCart,
    this.onCartCountChanged,
  });

  final String token;
  final int productId;
  final Future<void> Function() onSessionExpired;
  final ValueChanged<BuyerProductData> onOpenProduct;
  final VoidCallback onOpenSearch;
  final void Function({String? buyNowLineKey}) onOpenCart;
  final ValueChanged<int>? onCartCountChanged;

  @override
  State<BuyerProductDetailPage> createState() => _BuyerProductDetailPageState();
}

class _BuyerProductDetailPageState extends State<BuyerProductDetailPage> {
  final PageController _galleryController = PageController();
  late final ForegroundRefresh _liveRefresh;
  bool _requestBusy = false;
  int _requestId = 0;

  BuyerProductDetailData? _detail;
  BuyerCatalogException? _error;
  BuyerVariantData? _selectedVariant;
  bool _loading = true;
  bool _cartBusy = false;
  final Set<int> _likedProductIds = <int>{};
  int _galleryIndex = 0;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _loadProduct();
    _liveRefresh = ForegroundRefresh(
      refresh: () => _loadProduct(silent: true),
      canRefresh: () =>
          mounted &&
          !_requestBusy &&
          !_cartBusy &&
          (ModalRoute.of(context)?.isCurrent ?? true),
    );
  }

  @override
  void didUpdateWidget(covariant BuyerProductDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId ||
        oldWidget.token != widget.token) {
      _galleryIndex = 0;
      _quantity = 1;
      _selectedVariant = null;
      _loadProduct();
    }
  }

  @override
  void dispose() {
    _liveRefresh.dispose();
    _galleryController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct({bool silent = false}) async {
    final requestId = ++_requestId;
    _requestBusy = true;
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });

    try {
      final detail = await BuyerCatalogService.getProduct(
        token: widget.token,
        productId: widget.productId,
      );

      if (!mounted || requestId != _requestId) return;

      final availableVariants = detail.variants.where((item) => item.inStock);
      setState(() {
        _detail = detail;
        final previousId = _selectedVariant?.id;
        final previous = availableVariants.where((v) => v.id == previousId);
        _selectedVariant = silent && previous.isNotEmpty
            ? previous.first
            : (availableVariants.isNotEmpty ? availableVariants.first : null);
        if (!silent) {
          _quantity = 1;
          _galleryIndex = 0;
        } else {
          final stock = buyerSelectionStock(detail, _selectedVariant);
          _quantity = _quantity.clamp(1, stock > 0 ? stock : 1);
          final mediaCount = buyerProductMedia(detail).length;
          if (_galleryIndex >= mediaCount) {
            _galleryIndex = 0;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _galleryController.hasClients) {
                _galleryController.jumpToPage(0);
              }
            });
          }
        }
        _error = null;
        _loading = false;
        _likedProductIds
          ..clear()
          ..addAll([
            if (detail.product.isLiked) detail.product.id,
            ...detail.relatedProducts
                .where((item) => item.isLiked)
                .map((item) => item.id),
          ]);
      });
    } on BuyerCatalogException catch (error) {
      if (!mounted || requestId != _requestId) return;
      if (error.isUnauthorized) {
        setState(() => _loading = false);
        await widget.onSessionExpired();
        return;
      }
      setState(() {
        if (!silent || error.statusCode == 404) _error = error;
        _loading = false;
      });
    } finally {
      if (requestId == _requestId) _requestBusy = false;
    }
  }

  int get _availableStock =>
      _detail == null ? 0 : buyerSelectionStock(_detail!, _selectedVariant);

  double get _displayPrice {
    final detail = _detail;
    if (detail == null) return 0;
    return _selectedVariant?.price ?? detail.product.price;
  }

  Future<void> _toggleLike(BuyerProductData product) async {
    final wasLiked = _likedProductIds.contains(product.id);
    final targetLiked = !wasLiked;

    setState(() {
      if (targetLiked) {
        _likedProductIds.add(product.id);
      } else {
        _likedProductIds.remove(product.id);
      }
    });

    try {
      final liked = await BuyerCatalogService.setFavorite(
        token: widget.token,
        productId: product.id,
        liked: targetLiked,
      );
      if (!mounted) return;

      setState(() {
        if (liked) {
          _likedProductIds.add(product.id);
        } else {
          _likedProductIds.remove(product.id);
        }
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              liked ? 'Added to My Likes' : 'Removed from My Likes',
            ),
          ),
        );
    } on BuyerCatalogException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return;
      }

      setState(() {
        if (wasLiked) {
          _likedProductIds.add(product.id);
        } else {
          _likedProductIds.remove(product.id);
        }
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(error.message),
          ),
        );
    }
  }

  Future<void> _openOptions() async {
    final detail = _detail;
    if (detail == null || _cartBusy) return;
    final selection = await showBuyerVariantSheet(
      context,
      detail: detail,
      selected: _selectedVariant,
      quantity: _quantity,
    );
    if (!mounted || selection == null) return;
    setState(() {
      _selectedVariant = selection.variant;
      _quantity = selection.quantity;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_loading || _error != null || _detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product Details')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.cube_box,
                        size: 40,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Product unavailable',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _error?.message ?? 'Please try again.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadProduct,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
      );
    }
    final detail = _detail!;
    final product = detail.product;
    final gallery = buyerProductMedia(detail);
    final size = MediaQuery.sizeOf(context);
    final photoHeight = (size.height * .42).clamp(
      220.0,
      size.width.clamp(220.0, 460.0),
    );
    final expandedHeight = photoHeight + (gallery.length > 1 ? 62 : 0);
    return Scaffold(
      backgroundColor: colors.surfaceContainer,
      body: RefreshIndicator(
        onRefresh: () => _loadProduct(silent: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final collapsed =
                    constraints.scrollOffset >= expandedHeight - 58;
                return SliverAppBar(
                  pinned: true,
                  toolbarHeight: 48,
                  expandedHeight: expandedHeight,
                  titleSpacing: 0,
                  backgroundColor: collapsed
                      ? colors.surface
                      : Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  leading: _GalleryAction(
                    label: 'Back',
                    icon: CupertinoIcons.arrow_left,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  title: collapsed
                      ? InkWell(
                          onTap: widget.onOpenSearch,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.search,
                                  size: 16,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Search ShopHop',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : null,
                  actions: [
                    if (!collapsed)
                      _GalleryAction(
                        label: 'Search',
                        icon: CupertinoIcons.search,
                        onTap: widget.onOpenSearch,
                      ),
                    _GalleryAction(
                      label: 'Cart',
                      icon: CupertinoIcons.cart,
                      onTap: () => widget.onOpenCart(),
                    ),
                    const SizedBox(width: 6),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: BuyerProductGallery(
                      media: gallery,
                      controller: _galleryController,
                      index: _galleryIndex,
                      active: !collapsed,
                      onChanged: (index) =>
                          setState(() => _galleryIndex = index),
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _DetailSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              buyerPrice(_displayPrice),
                              key: const ValueKey('product-price'),
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                                height: 1.25,
                              ),
                            ),
                            if (_selectedVariant == null &&
                                product.originalPrice != null &&
                                product.originalPrice! > product.price) ...[
                              Text(
                                buyerPrice(product.originalPrice!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              _DiscountLabel(percent: product.discountPercent),
                            ],
                          ],
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  product.name,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: _likedProductIds.contains(product.id)
                                  ? 'Remove from Likes'
                                  : 'Save to Likes',
                              onPressed: () => _toggleLike(product),
                              icon: Icon(
                                _likedProductIds.contains(product.id)
                                    ? CupertinoIcons.heart_fill
                                    : CupertinoIcons.heart,
                                size: 21,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (product.reviews > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFF4AA23),
                                    size: 15,
                                  ),
                                  Text(
                                    ' ${product.rating.toStringAsFixed(1)} (${product.reviews})',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            if (product.sold > 0)
                              Text(
                                '${product.sold} completed sales',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            Text(
                              _availableStock > 0
                                  ? '$_availableStock in stock'
                                  : 'Currently unavailable',
                              style: TextStyle(
                                fontSize: 11,
                                color: _availableStock > 0
                                    ? colors.onSurfaceVariant
                                    : colors.error,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _DetailSection(
                    child: InkWell(
                      onTap: _openOptions,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.hasVariants
                                        ? 'Variation & quantity'
                                        : 'Quantity',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    [
                                      if (_selectedVariant != null)
                                        (_selectedVariant!.label.isEmpty
                                            ? _selectedVariant!.name
                                            : _selectedVariant!.label),
                                      'Qty: $_quantity',
                                    ].join(' / '),
                                    key: const ValueKey('selected-options'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(CupertinoIcons.chevron_right, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (detail.vouchers.isNotEmpty)
                    _DetailSection(
                      title: 'Shop vouchers',
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final voucher in detail.vouchers)
                            ActionChip(
                              backgroundColor: colors.primaryContainer,
                              label: Text(
                                '${voucher.label}${voucher.code.isEmpty ? '' : ' / ${voucher.code}'}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              onPressed: voucher.code.isEmpty
                                  ? null
                                  : () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: voucher.code),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${voucher.code} copied',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                            ),
                        ],
                      ),
                    ),
                  _SellerSummary(seller: detail.seller),
                  _DescriptionSection(
                    text: detail.description,
                    category: product.category,
                  ),
                  _CompactReviews(detail: detail),
                  if (detail.relatedProducts.isNotEmpty)
                    _DetailSection(
                      title: 'You may also like',
                      child: SizedBox(
                        height: BuyerProductCard.extent(context, 136),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: detail.relatedProducts.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final related = detail.relatedProducts[index];
                            return SizedBox(
                              width: 136,
                              child: BuyerProductCard(
                                product: related.copyWith(
                                  isLiked: _likedProductIds.contains(
                                    related.id,
                                  ),
                                ),
                                onTap: () => widget.onOpenProduct(related),
                                onLike: () => _toggleLike(related),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _CompactPurchaseBar(
        stock: _availableStock,
        busy: _cartBusy,
        onAddToCart: () => _addToCart(buyNow: false),
        onBuyNow: () => _addToCart(buyNow: true),
      ),
    );
  }

  Future<void> _addToCart({required bool buyNow}) async {
    final detail = _detail;
    if (detail == null || _cartBusy || _availableStock <= 0) return;

    if (detail.product.hasVariants && _selectedVariant == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Please select an available variation first.'),
          ),
        );
      return;
    }

    setState(() => _cartBusy = true);

    try {
      final result = await BuyerCartService.addToCart(
        token: widget.token,
        productId: detail.product.id,
        variantId: detail.product.hasVariants ? _selectedVariant?.id : null,
        quantity: _quantity,
        buyNow: buyNow,
      );

      if (!mounted) return;
      widget.onCartCountChanged?.call(result.cartCount);

      if (buyNow) {
        widget.onOpenCart(buyNowLineKey: result.lineKey);
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: const Text('Added to your ShopHop cart.'),
            action: SnackBarAction(
              label: 'VIEW CART',
              onPressed: () => widget.onOpenCart(),
            ),
          ),
        );
    } on BuyerCartException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(error.message),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _cartBusy = false);
      }
    }
  }
}

class _GalleryAction extends StatelessWidget {
  const _GalleryAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    style: IconButton.styleFrom(
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: .92),
    ),
    icon: Icon(icon, size: 21),
  );
}

class _DiscountLabel extends StatelessWidget {
  const _DiscountLabel({required this.percent});
  final int percent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      '-$percent%',
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({this.title, required this.child, this.trailing});
  final String? title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 6),
    color: Theme.of(context).colorScheme.surface,
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
        ],
        child,
      ],
    ),
  );
}

class _SellerSummary extends StatelessWidget {
  const _SellerSummary({required this.seller});
  final BuyerSellerDetailData seller;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _DetailSection(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(CupertinoIcons.bag, color: colors.primary, size: 23),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seller.businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (seller.municipality.isNotEmpty) seller.municipality,
                    '${seller.productsCount} products',
                  ].join(' / '),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (seller.joined.isNotEmpty)
                  Text(
                    'Joined ${seller.joined}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
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

class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection({required this.text, required this.category});
  final String text;
  final String category;
  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = widget.text.isEmpty
        ? 'No additional description was provided by the seller.'
        : widget.text;
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(
      fontSize: 13,
      height: 1.5,
      color: colors.onSurfaceVariant,
    );
    return _DetailSection(
      title: 'Description',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            maxLines: 5,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth);
          final overflows = painter.didExceedMaxLines;
          painter.dispose();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.category.isNotEmpty) ...[
                Text(
                  widget.category,
                  style: TextStyle(fontSize: 11, color: colors.primary),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                text,
                style: style,
                maxLines: _expanded ? null : 5,
                overflow: _expanded ? null : TextOverflow.ellipsis,
              ),
              if (overflows)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? 'Show less' : 'Read more'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CompactReviews extends StatelessWidget {
  const _CompactReviews({required this.detail});
  final BuyerProductDetailData detail;
  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        minChildSize: .5,
        maxChildSize: .95,
        builder: (context, scroll) => CustomScrollView(
          controller: scroll,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Product reviews',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close reviews',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(CupertinoIcons.xmark, size: 18),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.product.reviews > detail.reviews.length
                          ? 'Latest ${detail.reviews.length} of ${detail.product.reviews} reviews'
                          : '${detail.product.reviews} reviews',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        for (var stars = 5; stars >= 1; stars--)
                          Text(
                            '$stars stars: ${detail.ratingBreakdown[stars] ?? 0}',
                            style: const TextStyle(fontSize: 11),
                          ),
                      ],
                    ),
                    const Divider(height: 20),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              sliver: SliverList.separated(
                itemCount: detail.reviews.length,
                separatorBuilder: (_, _) => const Divider(height: 20),
                itemBuilder: (context, index) =>
                    _ReviewPreview(review: detail.reviews[index], full: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _DetailSection(
    title: 'Product ratings',
    trailing: detail.reviews.length > 2
        ? TextButton(
            onPressed: () => _open(context),
            child: const Text('View reviews'),
          )
        : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.product.reviews > 0) ...[
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFF4AA23),
                size: 17,
              ),
              const SizedBox(width: 4),
              Text(
                '${detail.product.rating.toStringAsFixed(1)} / 5',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${detail.product.reviews} ratings',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
        ],
        if (detail.reviews.isEmpty)
          const Text('No buyer reviews yet.', style: TextStyle(fontSize: 12))
        else
          for (var i = 0; i < detail.reviews.take(2).length; i++) ...[
            if (i > 0) const Divider(height: 20),
            _ReviewPreview(
              review: detail.reviews[i],
              onExpand: () => _open(context),
            ),
          ],
      ],
    ),
  );
}

class _ReviewPreview extends StatelessWidget {
  const _ReviewPreview({
    required this.review,
    this.full = false,
    this.onExpand,
  });
  final BuyerReviewData review;
  final bool full;
  final VoidCallback? onExpand;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                review.buyerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (review.date.isNotEmpty)
              Text(
                review.date,
                style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            for (var i = 0; i < 5; i++)
              Icon(
                Icons.star_rounded,
                size: 13,
                color: i < review.rating
                    ? const Color(0xFFF4AA23)
                    : colors.outline,
              ),
          ],
        ),
        if (review.variant.isNotEmpty && review.variant != '\u2014')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Variation: ${review.variant}',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ),
        if (review.comment.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: GestureDetector(
              onTap: onExpand,
              child: Text(
                review.comment,
                maxLines: full ? null : 3,
                overflow: full ? null : TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          ),
        if (review.image.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => showBuyerMediaViewer(
                context,
                media: [BuyerMediaItem(type: 'image', url: review.image)],
                title: 'Review photo',
              ),
              child: SizedBox.square(
                dimension: 64,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: BuyerMediaImage(url: review.image, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        if (review.sellerReply.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Seller reply: ${review.sellerReply}',
              style: const TextStyle(fontSize: 11, height: 1.45),
            ),
          ),
        if (review.helpful > 0)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              '${review.helpful} found this helpful',
              style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _CompactPurchaseBar extends StatelessWidget {
  const _CompactPurchaseBar({
    required this.stock,
    required this.busy,
    required this.onAddToCart,
    required this.onBuyNow,
  });
  final int stock;
  final bool busy;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = stock > 0 && !busy;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: enabled ? onAddToCart : null,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    side: BorderSide(color: colors.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  child: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add to Cart', textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: enabled ? onBuyNow : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('Buy Now', textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
