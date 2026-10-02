import 'package:flutter/material.dart';

import '../../../services/buyer_catalog_service.dart';
import '../../../services/buyer_cart_service.dart';
import '../../../theme/app_colors.dart';
import '../widgets/buyer_product_card.dart';

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
  State<BuyerProductDetailPage> createState() =>
      _BuyerProductDetailPageState();
}

class _BuyerProductDetailPageState extends State<BuyerProductDetailPage> {
  final PageController _galleryController = PageController();

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
    _galleryController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detail = await BuyerCatalogService.getProduct(
        token: widget.token,
        productId: widget.productId,
      );

      if (!mounted) return;

      final availableVariants = detail.variants.where((item) => item.inStock);
      setState(() {
        _detail = detail;
        _selectedVariant = availableVariants.isNotEmpty
            ? availableVariants.first
            : null;
        _quantity = 1;
        _galleryIndex = 0;
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

  int get _availableStock {
    final detail = _detail;
    if (detail == null) return 0;
    if (detail.product.hasVariants) {
      return _selectedVariant?.stock ?? 0;
    }
    return detail.product.stock;
  }

  double get _displayPrice {
    final detail = _detail;
    if (detail == null) return 0;
    return _selectedVariant?.price ?? detail.product.price;
  }

  void _changeQuantity(int delta) {
    final max = _availableStock;
    if (max <= 0) return;
    final next = (_quantity + delta).clamp(1, max).toInt();
    if (next == _quantity) return;
    setState(() => _quantity = next);
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
            content: Text(liked ? 'Added to My Likes' : 'Removed from My Likes'),
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
          'Product Details',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: widget.onOpenSearch,
            icon: const Icon(Icons.search_rounded, color: AppColors.navy),
          ),
          IconButton(
            tooltip: 'Cart',
            onPressed: () => widget.onOpenCart(),
            icon: const Icon(
              Icons.shopping_cart_outlined,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            )
          : _error != null
              ? _ProductErrorState(
                  message: _error!.message,
                  onRetry: _loadProduct,
                )
              : _buildProductBody(),
      bottomNavigationBar: !_loading && _error == null && _detail != null
          ? _ProductActionBar(
              stock: _availableStock,
              busy: _cartBusy,
              onChat: _showChatPending,
              onAddToCart: () => _addToCart(buyNow: false),
              onBuyNow: () => _addToCart(buyNow: true),
            )
          : null,
    );
  }

  Widget _buildProductBody() {
    final detail = _detail!;
    final product = detail.product;
    final gallery = detail.gallery.isEmpty
        ? <String>[product.image]
        : detail.gallery;

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: _loadProduct,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _GallerySection(
            images: gallery,
            controller: _galleryController,
            currentIndex: _galleryIndex,
            onPageChanged: (index) => setState(() => _galleryIndex = index),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 19,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => _toggleLike(product),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF2F5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _likedProductIds.contains(product.id)
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: const Color(0xFFED647C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 5,
                  children: [
                    Text(
                      buyerPrice(_displayPrice),
                      style: const TextStyle(
                        color: Color(0xFFEC526A),
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (_selectedVariant == null &&
                        product.originalPrice != null &&
                        product.originalPrice! > product.price)
                      Text(
                        buyerPrice(product.originalPrice!),
                        style: const TextStyle(
                          color: Color(0xFF9AA2AC),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    if (product.discountPercent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE9ED),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '-${product.discountPercent}%',
                          style: const TextStyle(
                            color: Color(0xFFDA455D),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _ProductStats(product: product),
                const SizedBox(height: 10),
                Text(
                  _availableStock > 0
                      ? '$_availableStock item${_availableStock == 1 ? '' : 's'} available'
                      : 'Currently out of stock',
                  style: TextStyle(
                    color: _availableStock > 0
                        ? const Color(0xFF5D6975)
                        : const Color(0xFFD54C5F),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (detail.vouchers.isNotEmpty)
            _WhiteSection(
              title: 'Shop Vouchers',
              child: SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: detail.vouchers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return _VoucherCard(voucher: detail.vouchers[index]);
                  },
                ),
              ),
            ),
          if (detail.vouchers.isNotEmpty) const SizedBox(height: 8),
          if (detail.product.hasVariants)
            _WhiteSection(
              title: 'Select Variation',
              child: _VariantSelector(
                variants: detail.variants,
                selected: _selectedVariant,
                onSelected: (variant) {
                  if (!variant.inStock) return;
                  setState(() {
                    _selectedVariant = variant;
                    _quantity = 1;
                  });
                },
              ),
            ),
          if (detail.product.hasVariants) const SizedBox(height: 8),
          _WhiteSection(
            title: 'Quantity',
            child: Row(
              children: [
                _QuantityButton(
                  icon: Icons.remove_rounded,
                  onTap: _quantity > 1 ? () => _changeQuantity(-1) : null,
                ),
                Container(
                  width: 52,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: Color(0xFFDDE3E6)),
                    ),
                  ),
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _QuantityButton(
                  icon: Icons.add_rounded,
                  onTap: _quantity < _availableStock
                      ? () => _changeQuantity(1)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _availableStock > 0
                        ? 'Maximum $_availableStock for this selection'
                        : 'Choose an available variation',
                    style: const TextStyle(
                      color: Color(0xFF7A8490),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _SellerSection(seller: detail.seller),
          const SizedBox(height: 8),
          _WhiteSection(
            title: 'Product Description',
            child: Text(
              detail.description.isEmpty
                  ? 'No additional product description was provided by the seller.'
                  : detail.description,
              style: const TextStyle(
                color: Color(0xFF59636F),
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ReviewSection(detail: detail),
          if (detail.relatedProducts.isNotEmpty) ...[
            const SizedBox(height: 8),
            _WhiteSection(
              title: 'You May Also Like',
              child: SizedBox(
                height: 278,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: detail.relatedProducts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final related = detail.relatedProducts[index];
                    final displayed = related.copyWith(
                      isLiked: _likedProductIds.contains(related.id),
                    );
                    return SizedBox(
                      width: 168,
                      child: BuyerProductCard(
                        product: displayed,
                        onTap: () => widget.onOpenProduct(displayed),
                        onLike: () => _toggleLike(displayed),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
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

  void _showChatPending() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Seller chat connection will follow the shared web messaging API.'),
        ),
      );
  }
}

class _GallerySection extends StatelessWidget {
  const _GallerySection({
    required this.images,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
  });

  final List<String> images;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.12,
            child: PageView.builder(
              controller: controller,
              itemCount: images.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                final url = images[index];
                if (url.isEmpty) return const _GalleryFallback();
                return Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const _GalleryFallback(showLoader: true);
                  },
                  errorBuilder: (_, __, ___) => const _GalleryFallback(),
                );
              },
            ),
          ),
          if (images.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (index) {
                  final active = index == currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: active ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.tealDark
                          : const Color(0xFFD2D8DE),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _GalleryFallback extends StatelessWidget {
  const _GalleryFallback({this.showLoader = false});

  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F5F5),
      alignment: Alignment.center,
      child: showLoader
          ? const CircularProgressIndicator(color: AppColors.teal)
          : const Icon(
              Icons.image_outlined,
              color: Color(0xFFB7C2C7),
              size: 64,
            ),
    );
  }
}

class _ProductStats extends StatelessWidget {
  const _ProductStats({required this.product});

  final BuyerProductData product;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (product.rating > 0)
          _StatItem(
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFFFB02E),
            text: '${product.rating.toStringAsFixed(1)} (${product.reviews})',
          ),
        if (product.sold > 0)
          _StatItem(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFEC526A),
            text: '${product.sold} sold',
          ),
        if (product.category.isNotEmpty)
          _StatItem(
            icon: Icons.category_outlined,
            iconColor: AppColors.tealDark,
            text: product.category,
          ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF707A85),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _WhiteSection extends StatelessWidget {
  const _WhiteSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.voucher});

  final BuyerVoucherData voucher;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 178,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD9C2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_activity_outlined,
            color: Color(0xFFEC7655),
            size: 25,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  voucher.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  voucher.code.isEmpty ? 'Shop voucher' : voucher.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8A6D60),
                    fontSize: 9.5,
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

class _VariantSelector extends StatelessWidget {
  const _VariantSelector({
    required this.variants,
    required this.selected,
    required this.onSelected,
  });

  final List<BuyerVariantData> variants;
  final BuyerVariantData? selected;
  final ValueChanged<BuyerVariantData> onSelected;

  @override
  Widget build(BuildContext context) {
    if (variants.isEmpty) {
      return const Text(
        'No variation data is available for this product.',
        style: TextStyle(color: Color(0xFF7A8490)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: variants.map((variant) {
        final isSelected = selected?.id == variant.id;
        return ChoiceChip(
          selected: isSelected,
          onSelected: variant.inStock ? (_) => onSelected(variant) : null,
          showCheckmark: false,
          label: Text(
            variant.label.isNotEmpty ? variant.label : variant.name,
          ),
          selectedColor: AppColors.tealLight,
          disabledColor: const Color(0xFFF0F1F2),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: isSelected ? AppColors.teal : const Color(0xFFDDE3E6),
          ),
          labelStyle: TextStyle(
            color: !variant.inStock
                ? const Color(0xFFADB4BB)
                : isSelected
                    ? AppColors.tealDark
                    : AppColors.navy,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFFF5F6F7) : Colors.white,
          border: Border.all(color: const Color(0xFFDDE3E6)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null
              ? const Color(0xFFB9C0C6)
              : AppColors.navy,
        ),
      ),
    );
  }
}

class _SellerSection extends StatelessWidget {
  const _SellerSection({required this.seller});

  final BuyerSellerDetailData seller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFDBF8F1), Color(0xFFAEEADB)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppColors.tealDark,
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seller.businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (seller.municipality.isNotEmpty) seller.municipality,
                    if (seller.productsCount > 0)
                      '${seller.productsCount} products',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7D8792),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.tealDark,
              side: const BorderSide(color: Color(0xFFD1EAE4)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Shop'),
          ),
        ],
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.detail});

  final BuyerProductDetailData detail;

  @override
  Widget build(BuildContext context) {
    final reviews = detail.reviews.take(3).toList(growable: false);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ratings & Reviews',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (detail.product.rating > 0)
                Text(
                  '${detail.product.rating.toStringAsFixed(1)} / 5',
                  style: const TextStyle(
                    color: Color(0xFFEC526A),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (detail.product.reviews <= 0 || reviews.isEmpty)
            const Text(
              'No buyer reviews yet.',
              style: TextStyle(color: Color(0xFF7A8490), fontSize: 12),
            )
          else ...[
            _RatingBreakdown(
              total: detail.product.reviews,
              values: detail.ratingBreakdown,
            ),
            const SizedBox(height: 12),
            ...reviews.map(
              (review) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _ReviewCard(review: review),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingBreakdown extends StatelessWidget {
  const _RatingBreakdown({required this.total, required this.values});

  final int total;
  final Map<int, int> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var stars = 5; stars >= 1; stars--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '$stars',
                    style: const TextStyle(
                      color: Color(0xFF68737E),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.star_rounded,
                  size: 13,
                  color: Color(0xFFFFB02E),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: total <= 0 ? 0 : (values[stars] ?? 0) / total,
                      backgroundColor: const Color(0xFFEEF1F3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFB02E),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${values[stars] ?? 0}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF8A939C),
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final BuyerReviewData review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE8ECEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.buyerName,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (review.date.isNotEmpty)
                Text(
                  review.date,
                  style: const TextStyle(
                    color: Color(0xFF9AA2AA),
                    fontSize: 9.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                Icons.star_rounded,
                size: 14,
                color: index < review.rating
                    ? const Color(0xFFFFB02E)
                    : const Color(0xFFD9DEE2),
              ),
            ),
          ),
          if (review.variant.isNotEmpty && review.variant != '—') ...[
            const SizedBox(height: 4),
            Text(
              'Variation: ${review.variant}',
              style: const TextStyle(
                color: Color(0xFF8B949D),
                fontSize: 9.5,
              ),
            ),
          ],
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              review.comment,
              style: const TextStyle(
                color: Color(0xFF58636E),
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
          if (review.image.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                review.image,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductActionBar extends StatelessWidget {
  const _ProductActionBar({
    required this.stock,
    required this.busy,
    required this.onChat,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  final int stock;
  final bool busy;
  final VoidCallback onChat;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;

  @override
  Widget build(BuildContext context) {
    final enabled = stock > 0 && !busy;
    return SafeArea(
      top: false,
      child: Container(
        height: 66,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 14,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              child: InkWell(
                onTap: onChat,
                borderRadius: BorderRadius.circular(12),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppColors.tealDark,
                      size: 21,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Chat',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: OutlinedButton(
                onPressed: enabled ? onAddToCart : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.tealDark,
                  side: const BorderSide(color: AppColors.teal),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.tealDark,
                        ),
                      )
                    : const Text(
                        'Add to Cart',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: enabled ? onBuyNow : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEC526A),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Buy Now',
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

class _ProductErrorState extends StatelessWidget {
  const _ProductErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.tealDark,
              size: 56,
            ),
            const SizedBox(height: 14),
            const Text(
              'Product unavailable',
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
