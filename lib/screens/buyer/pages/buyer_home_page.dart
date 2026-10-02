import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/buyer_catalog_service.dart';
import '../../../theme/app_colors.dart';

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
  final PageController _bannerController = PageController(viewportFraction: 0.93);

  BuyerHomeData? _home;
  BuyerCatalogException? _error;
  Timer? _bannerTimer;
  bool _loading = true;
  bool _refreshing = false;
  int _bannerIndex = 0;
  final Set<int> _likedProductIds = <int>{};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
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
    _bannerController.dispose();
    super.dispose();
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
          ..addAll(
            allProducts
                .where((product) => product.isLiked)
                .map((product) => product.id),
          );
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

    final bannerCount = _heroItems.length;
    if (bannerCount <= 1) return;

    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_bannerController.hasClients) return;

      final next = (_bannerIndex + 1) % bannerCount;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 430),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<_HeroItem> get _heroItems {
    final home = _home;
    if (home == null) return const [];

    final items = <_HeroItem>[];

    if (home.dealProducts.isNotEmpty) {
      items.add(
        _HeroItem(
          eyebrow: 'LIVE DEALS',
          title: '${home.dealProducts.length} discounted picks',
          subtitle: 'Real offers from ShopHop sellers',
          icon: Icons.local_offer_rounded,
          imageUrl: home.dealProducts.first.image,
          startColor: const Color(0xFF0F6D63),
          endColor: AppColors.teal,
        ),
      );
    }

    if (home.newArrivals.isNotEmpty) {
      items.add(
        _HeroItem(
          eyebrow: 'JUST IN',
          title: '${home.newArrivals.length} new arrivals',
          subtitle: 'Recently added products from approved sellers',
          icon: Icons.auto_awesome_rounded,
          imageUrl: home.newArrivals.first.image,
          startColor: const Color(0xFF3D4FA3),
          endColor: const Color(0xFF6F7FE6),
        ),
      );
    }

    if (home.trendingProducts.isNotEmpty) {
      items.add(
        _HeroItem(
          eyebrow: 'TRENDING NOW',
          title: '${home.trendingProducts.length} popular finds',
          subtitle: 'Discover what is getting attention on ShopHop',
          icon: Icons.trending_up_rounded,
          imageUrl: home.trendingProducts.first.image,
          startColor: AppColors.navy,
          endColor: const Color(0xFF294D79),
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        _HeroItem(
          eyebrow: 'SHOPHOP MARKETPLACE',
          title: 'Discover your next find',
          subtitle: 'Products from approved ShopHop sellers will appear here',
          icon: Icons.storefront_rounded,
          startColor: AppColors.navy,
          endColor: AppColors.tealDark,
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

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: () => _loadHome(refresh: true),
        child: CustomScrollView(
          key: const PageStorageKey<String>('buyer-home-scroll'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              toolbarHeight: 72,
              elevation: 0,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              titleSpacing: 14,
              title: _SearchHeader(
                cartCount: home.cartCount,
                onSearch: widget.onOpenSearch,
                onCart: widget.onOpenCart,
                onMessages: widget.onOpenMessages,
              ),
            ),
            // Marketplace hierarchy: Search -> Banner -> Purchases -> Categories.
            // This keeps the most visual/promotional content at the top,
            // followed by the buyer's order shortcuts and then discovery.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _HeroCarousel(
                  controller: _bannerController,
                  items: _heroItems,
                  currentIndex: _bannerIndex,
                  onPageChanged: (index) {
                    setState(() => _bannerIndex = index);
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _MaxWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _SectionTitle(
                      title: 'My Purchases',
                      subtitle: 'Track the orders that need your attention',
                      icon: Icons.inventory_2_outlined,
                    ),
                    const SizedBox(height: 10),
                    _QuickActions(onOrders: widget.onOpenOrders),
                    const SizedBox(height: 22),
                    _SectionTitle(
                      title: 'Categories',
                      subtitle: 'Browse ${home.categories.length} ShopHop categories',
                      icon: Icons.grid_view_rounded,
                    ),
                    const SizedBox(height: 12),
                    _CategoryStrip(
                      categories: home.categories,
                      onTap: widget.onOpenCategory,
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _MaxWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    if (home.dealProducts.isNotEmpty) ...[
                      const _SectionTitle(
                        title: 'Deals for You',
                        subtitle: 'Discounted products currently available',
                        icon: Icons.bolt_rounded,
                      ),
                      const SizedBox(height: 12),
                      _HorizontalProducts(
                        products: home.dealProducts,
                        likedProductIds: _likedProductIds,
                        onTap: widget.onOpenProduct,
                        onLike: _toggleLike,
                      ),
                      const SizedBox(height: 26),
                    ],
                    if (home.trendingProducts.isNotEmpty) ...[
                      const _SectionTitle(
                        title: 'Trending Now',
                        subtitle: 'Popular products across ShopHop',
                        icon: Icons.trending_up_rounded,
                      ),
                      const SizedBox(height: 12),
                      _HorizontalProducts(
                        products: home.trendingProducts,
                        likedProductIds: _likedProductIds,
                        onTap: widget.onOpenProduct,
                        onLike: _toggleLike,
                      ),
                      const SizedBox(height: 26),
                    ],
                    if (home.newArrivals.isNotEmpty) ...[
                      const _SectionTitle(
                        title: 'New Arrivals',
                        subtitle: 'Freshly listed by ShopHop sellers',
                        icon: Icons.auto_awesome_rounded,
                      ),
                      const SizedBox(height: 12),
                      _HorizontalProducts(
                        products: home.newArrivals,
                        likedProductIds: _likedProductIds,
                        onTap: widget.onOpenProduct,
                        onLike: _toggleLike,
                      ),
                      const SizedBox(height: 26),
                    ],
                    if (home.recommendedProducts.isNotEmpty) ...[
                      const _SectionTitle(
                        title: 'Recommended for You',
                        subtitle: 'More products to explore',
                      ),
                      const SizedBox(height: 12),
                      _ResponsiveProductGrid(
                        products: home.recommendedProducts,
                        likedProductIds: _likedProductIds,
                        onTap: widget.onOpenProduct,
                        onLike: _toggleLike,
                      ),
                    ],
                    if (_allProductSectionsEmpty(home))
                      const _EmptyCatalogCard(),
                    if (_refreshing)
                      const Padding(
                        padding: EdgeInsets.only(top: 18),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.teal,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _allProductSectionsEmpty(BuyerHomeData home) {
    return home.dealProducts.isEmpty &&
        home.trendingProducts.isEmpty &&
        home.newArrivals.isEmpty &&
        home.recommendedProducts.isEmpty;
  }
}

class _MaxWidth extends StatelessWidget {
  const _MaxWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: child,
        ),
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.cartCount,
    required this.onSearch,
    required this.onCart,
    required this.onMessages,
  });

  final int cartCount;
  final VoidCallback onSearch;
  final VoidCallback onCart;
  final VoidCallback onMessages;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: const Color(0xFFF4F7F8),
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(15),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 21, color: Color(0xFF6B7787)),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Search products, shops, and categories',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF7B8492),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        _HeaderIconButton(
          tooltip: 'Cart',
          icon: Icons.shopping_cart_outlined,
          count: cartCount,
          onPressed: onCart,
        ),
        _HeaderIconButton(
          tooltip: 'Messages',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: onMessages,
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.count = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: AppColors.navy, size: 24),
        ),
        if (count > 0)
          Positioned(
            right: 3,
            top: 2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5C5C),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onOrders});

  final VoidCallback onOrders;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickActionData>[
      const _QuickActionData(Icons.inventory_2_outlined, 'To Ship'),
      const _QuickActionData(Icons.local_shipping_outlined, 'In Transit'),
      const _QuickActionData(Icons.markunread_mailbox_outlined, 'To Receive'),
      const _QuickActionData(Icons.star_outline_rounded, 'To Rate'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.grayBorder.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F1B3D),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: actions.map((action) {
          return Expanded(
            child: InkWell(
              onTap: onOrders,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF1FFFB), Color(0xFFD8F6EF)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFCFEDE6)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0D0F1B3D),
                            blurRadius: 9,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(action.icon, color: AppColors.tealDark, size: 22),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: AppColors.tealDark),
          ),
          const SizedBox(width: 9),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: Color(0xFF7E8793),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.onTap,
  });

  final List<BuyerCategoryData> categories;
  final ValueChanged<BuyerCategoryData> onTap;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const _InlineEmptyState(
        icon: Icons.category_outlined,
        text: 'No categories are available yet.',
      );
    }

    // Give each of the two category rows a little more vertical room.
    // On real Android devices, font metrics/text scaling can be slightly
    // taller than on Chrome, which previously caused a 1 px RenderFlex
    // overflow in _CategoryTile.
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final rowHeight = textScale > 1.10 ? 104.0 : 98.0;

    return SizedBox(
      height: (rowHeight * 2) + 8,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 92,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _CategoryTile(
            category: category,
            onTap: () => onTap(category),
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final BuyerCategoryData category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = _categoryIcon(category.icon);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFDDF8F1)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD8EFE9)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F1B3D),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: category.coverImage.isNotEmpty
                    ? Image.network(
                        category.coverImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _CategoryIconFallback(icon: icon),
                      )
                    : _CategoryIconFallback(icon: icon),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 86,
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 10.2,
                  height: 1.06,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIconFallback extends StatelessWidget {
  const _CategoryIconFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8FBF6), Color(0xFFC9F0E7)],
        ),
      ),
      child: Center(
        child: Icon(icon, color: AppColors.tealDark, size: 28),
      ),
    );
  }
}

class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({
    required this.controller,
    required this.items,
    required this.currentIndex,
    required this.onPageChanged,
  });

  final PageController controller;
  final List<_HeroItem> items;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 172,
          child: PageView.builder(
            controller: controller,
            itemCount: items.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [item.startColor, item.endColor],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A0F1B3D),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.eyebrow,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.84),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 86,
                        height: 86,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: item.imageUrl.isNotEmpty
                              ? Image.network(
                                  item.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    item.icon,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                )
                              : Icon(item.icon, color: Colors.white, size: 38),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (index) {
            final active = index == currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: active ? 22 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active ? AppColors.tealDark : const Color(0xFFD2D8DE),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _HorizontalProducts extends StatelessWidget {
  const _HorizontalProducts({
    required this.products,
    required this.likedProductIds,
    required this.onTap,
    required this.onLike,
  });

  final List<BuyerProductData> products;
  final Set<int> likedProductIds;
  final ValueChanged<BuyerProductData> onTap;
  final ValueChanged<BuyerProductData> onLike;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 268,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final product = products[index];
          return SizedBox(
            width: 168,
            child: _ProductCard(
              product: product,
              liked: likedProductIds.contains(product.id),
              onTap: () => onTap(product),
              onLike: () => onLike(product),
            ),
          );
        },
      ),
    );
  }
}

class _ResponsiveProductGrid extends StatelessWidget {
  const _ResponsiveProductGrid({
    required this.products,
    required this.likedProductIds,
    required this.onTap,
    required this.onLike,
  });

  final List<BuyerProductData> products;
  final Set<int> likedProductIds;
  final ValueChanged<BuyerProductData> onTap;
  final ValueChanged<BuyerProductData> onLike;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1050
            ? 5
            : width >= 780
                ? 4
                : width >= 560
                    ? 3
                    : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: width < 430 ? 0.62 : 0.67,
          ),
          itemBuilder: (context, index) {
            final product = products[index];
            return _ProductCard(
              product: product,
              liked: likedProductIds.contains(product.id),
              onTap: () => onTap(product),
              onLike: () => onLike(product),
            );
          },
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.liked,
    required this.onTap,
    required this.onLike,
  });

  final BuyerProductData product;
  final bool liked;
  final VoidCallback onTap;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE9EDF0)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ProductImage(url: product.image),
                    if (product.discountPercent > 0)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5C5C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '-${product.discountPercent}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 7,
                      top: 7,
                      child: InkWell(
                        onTap: onLike,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x19000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 17,
                            color: const Color(0xFFED647C),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 12.2,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              _price(product.price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFEC526A),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (product.sold > 0)
                            Text(
                              '${_compactCount(product.sold)} sold',
                              style: const TextStyle(
                                color: Color(0xFF8A929E),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (product.rating > 0) ...[
                            const Icon(Icons.star_rounded, color: Color(0xFFFFB02E), size: 13),
                            const SizedBox(width: 2),
                            Text(
                              product.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Color(0xFF6F7782),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              product.seller.municipality.isNotEmpty
                                  ? product.seller.municipality
                                  : product.seller.businessName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF9299A3),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const _ProductImageFallback();
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _ProductImageFallback(showLoader: true);
      },
      errorBuilder: (_, __, ___) => const _ProductImageFallback(),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback({this.showLoader = false});

  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F5F5),
      alignment: Alignment.center,
      child: showLoader
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.teal,
              ),
            )
          : const Icon(
              Icons.image_outlined,
              size: 40,
              color: Color(0xFFB7C2C7),
            ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.tealDark),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF727C88),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCatalogCard extends StatelessWidget {
  const _EmptyCatalogCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: const Column(
        children: [
          Icon(Icons.storefront_outlined, size: 42, color: AppColors.tealDark),
          SizedBox(height: 10),
          Text(
            'No approved products yet',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'As soon as seller products become active and approved on the ShopHop web system, they will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7E8793),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: AppColors.teal),
                SizedBox(height: 12),
                Text(
                  'Loading ShopHop products…',
                  style: TextStyle(
                    color: Color(0xFF737D89),
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

class _HomeErrorView extends StatelessWidget {
  const _HomeErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: AppColors.tealLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.tealDark,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Couldn’t load Buyer Home',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF747E8A),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.tealDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroItem {
  const _HeroItem({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.startColor,
    required this.endColor,
    this.imageUrl = '',
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color startColor;
  final Color endColor;
  final String imageUrl;
}

class _QuickActionData {
  const _QuickActionData(this.icon, this.label);

  final IconData icon;
  final String label;
}

IconData _categoryIcon(String icon) {
  switch (icon) {
    case 'paw-print':
      return Icons.pets_rounded;
    case 'smartphone':
      return Icons.phone_iphone_rounded;
    case 'shirt':
      return Icons.checkroom_rounded;
    case 'baby':
      return Icons.child_care_rounded;
    case 'sofa':
      return Icons.weekend_rounded;
    case 'dumbbell':
      return Icons.fitness_center_rounded;
    case 'heart-pulse':
      return Icons.favorite_rounded;
    case 'book-open':
      return Icons.menu_book_rounded;
    case 'utensils':
      return Icons.restaurant_rounded;
    case 'car':
      return Icons.directions_car_filled_rounded;
    case 'armchair':
      return Icons.chair_rounded;
    case 'gem':
      return Icons.diamond_rounded;
    case 'pencil':
      return Icons.edit_rounded;
    default:
      return Icons.category_rounded;
  }
}

String _price(double value) {
  final fixed = value.toStringAsFixed(2);
  final trimmed = fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
  return '₱$trimmed';
}

String _compactCount(int value) {
  if (value >= 1000000) {
    final number = value / 1000000;
    return '${number.toStringAsFixed(number >= 10 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    final number = value / 1000;
    return '${number.toStringAsFixed(number >= 10 ? 0 : 1)}k';
  }
  return '$value';
}
