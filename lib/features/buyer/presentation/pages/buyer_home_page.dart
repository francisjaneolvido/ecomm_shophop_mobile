import 'dart:async';

import 'package:flutter/material.dart';

import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_product_card.dart';

class BuyerHomePage extends StatefulWidget {
  const BuyerHomePage({
    super.key,
    required this.token,
    required this.onSessionExpired,
    required this.onOpenSearch,
    required this.onOpenCategory,
    required this.onOpenProduct,
    required this.onOpenCart,
    required this.onOpenOrders,
    required this.onOpenMessages,
  });

  final String token;
  final Future<void> Function() onSessionExpired;
  final VoidCallback onOpenSearch;
  final ValueChanged<BuyerCategoryData> onOpenCategory;
  final ValueChanged<BuyerProductData> onOpenProduct;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenMessages;

  @override
  State<BuyerHomePage> createState() => _BuyerHomePageState();
}

class _BuyerHomePageState extends State<BuyerHomePage>
    with AutomaticKeepAliveClientMixin {
  final PageController _bannerController = PageController(viewportFraction: 0.94);
  final ScrollController _scrollController = ScrollController();

  BuyerHomeData? _home;
  BuyerCatalogException? _error;
  Timer? _bannerTimer;
  int _bannerIndex = 0;
  bool _loading = true;
  bool _refreshing = false;
  bool _showBackToTop = false;
  final Set<int> _likedProductIds = <int>{};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadHome();
  }

  @override
  void didUpdateWidget(covariant BuyerHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _loadHome();
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _bannerController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final shouldShow = _scrollController.hasClients && _scrollController.offset > 500;
    if (shouldShow != _showBackToTop && mounted) {
      setState(() => _showBackToTop = shouldShow);
    }
  }

  Future<void> _loadHome({bool refresh = false}) async {
    if (refresh) {
      if (_refreshing) return;
      setState(() => _refreshing = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final home = await BuyerCatalogService.getHome(token: widget.token);
      if (!mounted) return;

      final allProducts = <BuyerProductData>[
        ...home.dealProducts,
        ...home.trendingProducts,
        ...home.newArrivals,
        ...home.recommendedProducts,
      ];

      setState(() {
        _home = home;
        _error = null;
        _loading = false;
        _refreshing = false;
        _bannerIndex = 0;
        _likedProductIds
          ..clear()
          ..addAll(allProducts.where((p) => p.isLiked).map((p) => p.id));
      });

      _startBannerRotation();
    } on BuyerCatalogException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
        await widget.onSessionExpired();
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
        _refreshing = false;
      });
    }
  }

  void _startBannerRotation() {
    _bannerTimer?.cancel();
    if (_heroItems.length <= 1) return;

    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_bannerController.hasClients) return;
      final next = (_bannerIndex + 1) % _heroItems.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<_HeroItem> get _heroItems {
    final home = _home;
    if (home == null) return const [];

    final List<_HeroItem> items = [];

    if (home.dealProducts.isNotEmpty) {
      final product = home.dealProducts.first;
      items.add(
        _HeroItem(
          title: 'Deal picks',
          subtitle: product.discountPercent > 0
              ? 'Up to ${product.discountPercent}% off'
              : 'Great savings from sellers',
          imageUrl: product.image,
          tag: 'DEALS',
          product: product,
        ),
      );
    }

    if (home.newArrivals.isNotEmpty) {
      final product = home.newArrivals.first;
      items.add(
        _HeroItem(
          title: 'Fresh arrivals',
          subtitle: 'New finds from ${product.seller.businessName}',
          imageUrl: product.image,
          tag: 'NEW',
          product: product,
        ),
      );
    }

    if (home.categories.isNotEmpty) {
      final category = home.categories.firstWhere(
        (item) => item.coverImage.isNotEmpty,
        orElse: () => home.categories.first,
      );
      items.add(
        _HeroItem(
          title: category.name,
          subtitle: category.subcategories.isNotEmpty
              ? category.subcategories.take(2).join(' · ')
              : 'Explore seller products in this category',
          imageUrl: category.coverImage.isNotEmpty
              ? category.coverImage
              : (category.images.isNotEmpty ? category.images.first : ''),
          tag: 'CATEGORY',
          category: category,
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        const _HeroItem(
          title: 'ShopHop Marketplace',
          subtitle: 'Approved seller products will appear here automatically.',
          imageUrl: '',
          tag: 'SHOPHOP',
        ),
      );
    }

    return items;
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
    super.build(context);

    if (_loading && _home == null) {
      return const _HomeLoadingView();
    }

    if (_error != null && _home == null) {
      return _HomeErrorView(
        message: _error!.message,
        onRetry: () => _loadHome(),
      );
    }

    final home = _home!;
    final recommended = [
      ...home.recommendedProducts,
      ...home.trendingProducts,
      ...home.newArrivals,
    ].fold<List<BuyerProductData>>(<BuyerProductData>[], (list, product) {
      if (list.every((item) => item.id != product.id)) {
        list.add(product);
      }
      return list;
    });

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.teal,
            onRefresh: () => _loadHome(refresh: true),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: AppColors.tealDark,
                  surfaceTintColor: AppColors.tealDark,
                  scrolledUnderElevation: 0,
                  elevation: 0,
                  toolbarHeight: 68,
                  titleSpacing: 0,
                  title: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    child: Row(
                      children: [
                        Semantics(
                          label: 'ShopHop logo',
                          image: true,
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SearchField(
                            hint: _buildSearchHint(home),
                            onTap: widget.onOpenSearch,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _HeaderActionButton(
                          type: _HardcodedActionType.message,
                          tooltip: 'Messages',
                          onTap: widget.onOpenMessages,
                        ),
                        _HeaderActionButton(
                          type: _HardcodedActionType.cart,
                          tooltip: 'Cart',
                          count: home.cartCount,
                          onTap: widget.onOpenCart,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                    child: _HeroCarousel(
                      controller: _bannerController,
                      items: _heroItems,
                      currentIndex: _bannerIndex,
                      onChanged: (index) => setState(() => _bannerIndex = index),
                      onTap: (item) {
                        if (item.product != null) {
                          widget.onOpenProduct(item.product!);
                        } else if (item.category != null) {
                          widget.onOpenCategory(item.category!);
                        }
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
                    child: _PromoShortcutRow(
                      onOrders: widget.onOpenOrders,
                      onMessages: widget.onOpenMessages,
                      onSearch: widget.onOpenSearch,
                      onCart: widget.onOpenCart,
                    ),
                  ),
                ),
                if (home.dealProducts.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
                      child: _SectionHeader(
                        title: 'Deals for you',
                        subtitle: 'Shop offers from our sellers',
                      ),
                    ),
                  ),
                  _productGridSliver(home.dealProducts.take(4).toList()),
                ],
                if (home.newArrivals.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
                      child: _SectionHeader(
                        title: 'Just arrived',
                        subtitle: 'Fresh from ShopHop stores',
                      ),
                    ),
                  ),
                  _productGridSliver(home.newArrivals.take(4).toList()),
                ],
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
                    child: _SectionHeader(
                      title: 'Find your next favorite',
                      subtitle: 'Discover more from local sellers',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 92),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: MediaQuery.sizeOf(context).width < 350
                          ? 0.50
                          : MediaQuery.sizeOf(context).width < 400 ? 0.57 : 0.63,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (recommended.isEmpty) {
                          return const _EmptyCatalogCard();
                        }
                        final product = recommended[index];
                        return BuyerProductCard(
                          product: product.copyWith(
                            isLiked: _likedProductIds.contains(product.id),
                          ),
                          onTap: () => widget.onOpenProduct(product),
                          onLike: () => _toggleLike(product),
                        );
                      },
                      childCount: recommended.isEmpty ? 1 : recommended.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 18,
            child: IgnorePointer(
              ignoring: !_showBackToTop,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showBackToTop ? 1 : 0,
                child: FloatingActionButton.small(
                  heroTag: 'buyer_home_back_to_top_v35',
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  onPressed: _showBackToTop
                      ? () => _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOutCubic,
                          )
                      : null,
                  child: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productGridSliver(List<BuyerProductData> products) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: MediaQuery.sizeOf(context).width < 350
              ? 0.50
              : MediaQuery.sizeOf(context).width < 400 ? 0.57 : 0.63,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = products[index];
            return BuyerProductCard(
              product: product.copyWith(
                isLiked: _likedProductIds.contains(product.id),
              ),
              onTap: () => widget.onOpenProduct(product),
              onLike: () => _toggleLike(product),
            );
          },
          childCount: products.length,
        ),
      ),
    );
  }

  String _buildSearchHint(BuyerHomeData home) {
    if (home.categories.isNotEmpty) {
      return 'Try "${home.categories.first.name}"';
    }
    if (home.trendingProducts.isNotEmpty) {
      return 'Try "${home.trendingProducts.first.name}"';
    }
    return 'Search products';
  }
}

class _HeroItem {
  const _HeroItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.tag,
    this.product,
    this.category,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final String tag;
  final BuyerProductData? product;
  final BuyerCategoryData? category;
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.hint,
    required this.onTap,
    this.compact = false,
  });

  final String hint;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(compact ? 18 : 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 18 : 16),
        child: Container(
          height: compact ? 38 : 46,
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: Color(0xFF7A8994), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF7A8994),
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// This is deliberately hardcoded in Dart rather than loaded from PNG/SVG assets.
// It reproduces the message/cart shapes supplied for ShopHop and cannot break
// because an image file was not bundled or a later patch changed an icon name.
enum _HardcodedActionType { message, cart }

class _HardcodedActionIcon extends StatelessWidget {
  const _HardcodedActionIcon({
    required this.type,
    required this.color,
    this.size = 23,
  });

  final _HardcodedActionType type;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _HardcodedActionPainter(type: type, color: color),
        ),
      );
}

class _HardcodedActionPainter extends CustomPainter {
  const _HardcodedActionPainter({required this.type, required this.color});

  final _HardcodedActionType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final outline = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    if (type == _HardcodedActionType.cart) {
      final basket = Path()
        ..moveTo(6.3, 5)
        ..lineTo(21, 5)
        ..lineTo(19, 12)
        ..lineTo(7.38, 12)
        ..moveTo(20, 16)
        ..lineTo(8, 16)
        ..lineTo(6, 3)
        ..lineTo(3, 3);
      canvas.drawPath(basket, outline);
      canvas.drawCircle(const Offset(8, 20), 1, outline);
      canvas.drawCircle(const Offset(19, 20), 1, outline);
    } else {
      final bubble = Path()
        ..moveTo(5.2, 15.4)
        ..cubicTo(4.4, 14.35, 3.94, 13.2, 3.94, 12)
        ..cubicTo(3.94, 7.54, 7.74, 4.3, 12.47, 4.3)
        ..cubicTo(17.2, 4.3, 21, 7.54, 21, 12)
        ..cubicTo(21, 16.46, 17.2, 19.7, 12.47, 19.7)
        ..cubicTo(11.17, 19.7, 9.98, 19.45, 8.86, 18.88)
        ..lineTo(3.4, 20)
        ..lineTo(5.2, 15.4)
        ..close();
      canvas.drawPath(bubble, outline);
      final dots = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      for (final x in <double>[9, 12.5, 16]) {
        canvas.drawCircle(Offset(x, 12), 1, dots);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HardcodedActionPainter oldDelegate) =>
      type != oldDelegate.type || color != oldDelegate.color;
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.type,
    required this.tooltip,
    required this.onTap,
    this.count = 0,
  });

  final _HardcodedActionType type;
  final String tooltip;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          tooltip: tooltip,
          iconSize: 23,
          splashRadius: 22,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 42, height: 42),
          icon: _HardcodedActionIcon(
            type: type,
            color: Colors.white,
          ),
        ),
        if (count > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFE84F5B),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.tealDark, width: 1.2),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({
    required this.controller,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    required this.onTap,
  });

  final PageController controller;
  final List<_HeroItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final ValueChanged<_HeroItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 124,
          child: PageView.builder(
            controller: controller,
            itemCount: items.length,
            onPageChanged: onChanged,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onTap(item),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (item.imageUrl.isNotEmpty)
                          Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const _MissingBannerImage(),
                          )
                        else
                          const _MissingBannerImage(),
                        Container(color: AppColors.navy.withValues(alpha: 0.43)),
                        Positioned(
                          left: 14,
                          right: 12,
                          bottom: 12,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        item.tag,
                                        style: const TextStyle(
                                          color: AppColors.navy,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        height: 1.16,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.92),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppColors.tealDark,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (index) {
            final selected = index == currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected ? 18 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: selected ? AppColors.tealDark : const Color(0xFFCFD6DD),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PromoShortcutRow extends StatelessWidget {
  const _PromoShortcutRow({
    required this.onOrders,
    required this.onMessages,
    required this.onSearch,
    required this.onCart,
  });

  final VoidCallback onOrders;
  final VoidCallback onMessages;
  final VoidCallback onSearch;
  final VoidCallback onCart;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ShortcutTile(
            icon: Icons.local_offer_outlined,
            label: 'Browse',
            onTap: onSearch,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ShortcutTile(
            icon: Icons.receipt_long_outlined,
            label: 'Orders',
            onTap: onOrders,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ShortcutTile(
            icon: Icons.chat_bubble_outline_rounded,
            actionType: _HardcodedActionType.message,
            label: 'Messages',
            onTap: onMessages,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ShortcutTile(
            icon: Icons.shopping_cart_checkout_rounded,
            actionType: _HardcodedActionType.cart,
            label: 'Cart',
            onTap: onCart,
          ),
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    this.actionType,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final _HardcodedActionType? actionType;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8ECF1)),
          ),
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: actionType == null
                      ? Icon(icon, size: 17, color: AppColors.tealDark)
                      : _HardcodedActionIcon(
                          type: actionType!,
                          color: AppColors.tealDark,
                          size: 19,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.navy.withValues(alpha: 0.56),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.teal),
    );
  }
}

class _HomeErrorView extends StatelessWidget {
  const _HomeErrorView({required this.message, required this.onRetry});

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
            const Icon(Icons.inventory_2_outlined, size: 42, color: AppColors.tealDark),
            const SizedBox(height: 12),
            const Text(
              'Unable to load ShopHop',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.navy.withValues(alpha: 0.56),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.tealDark),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCatalogCard extends StatelessWidget {
  const _EmptyCatalogCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.storefront_outlined, color: AppColors.tealDark),
          ),
          const SizedBox(height: 12),
          const Text(
            'Products will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Once sellers publish their products, your buyer feed will fill with marketplace listings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy.withValues(alpha: 0.56),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}


/// Honest media fallback when a seller image URL is missing or unavailable.
/// Keep live image URLs from the Laravel API; no fake product photography.
class _MissingBannerImage extends StatelessWidget {
  const _MissingBannerImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A766F),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 76,
        color: Colors.white.withValues(alpha: .22),
      ),
    );
  }
}
