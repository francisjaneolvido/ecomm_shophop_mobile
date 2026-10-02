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
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final PageController _bannerController = PageController(viewportFraction: 0.91);
  final ScrollController _scrollController = ScrollController();

  BuyerHomeData? _home;
  BuyerCatalogException? _error;
  Timer? _bannerTimer;
  Timer? _searchHintTimer;
  AnimationController? _ambientController;
  bool _loading = true;
  bool _refreshing = false;
  int _bannerIndex = 0;
  int _searchHintIndex = 0;
  bool _showBackToTop = false;
  final Set<int> _likedProductIds = <int>{};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ensureAmbientController();
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
    _searchHintTimer?.cancel();
    _ambientController?.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _bannerController.dispose();
    super.dispose();
  }

  AnimationController _ensureAmbientController() {
    return _ambientController ??= AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  void _handleScroll() {
    final shouldShow = _scrollController.hasClients && _scrollController.offset > 520;
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
        _searchHintIndex = 0;
        _likedProductIds
          ..clear()
          ..addAll(
            allProducts
                .where((product) => product.isLiked)
                .map((product) => product.id),
          );
      });

      _startBannerRotation();
      _startSearchHintRotation();
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


  void _startSearchHintRotation() {
    _searchHintTimer?.cancel();
    if (_searchHints.length <= 1) return;

    _searchHintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _searchHintIndex = (_searchHintIndex + 1) % _searchHints.length;
      });
    });
  }

  List<String> get _searchHints {
    final home = _home;
    if (home == null) return const ['Search products, shops, and categories'];

    final hints = <String>[
      'Search products, shops, and categories',
      ...home.categories.take(3).map((category) => 'Try “${category.name}”'),
      ...home.trendingProducts.take(2).map((product) => 'Search “${product.name}”'),
    ];

    return hints.toSet().toList(growable: false);
  }

  String get _activeSearchHint {
    final hints = _searchHints;
    if (hints.isEmpty) return 'Search products, shops, and categories';
    return hints[_searchHintIndex % hints.length];
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
      final product = home.dealProducts.first;
      items.add(
        _HeroItem(
          eyebrow: product.discountPercent > 0
              ? 'LIVE DEAL  •  -${product.discountPercent}%'
              : 'LIVE DEAL',
          title: product.name,
          subtitle: '${_price(product.price)}  •  ${product.seller.businessName}',
          icon: Icons.local_offer_rounded,
          imageUrl: product.image,
          startColor: const Color(0xFF0A5E57),
          endColor: AppColors.teal,
          product: product,
          ctaLabel: 'Shop deal',
        ),
      );
    }

    if (home.newArrivals.isNotEmpty) {
      final product = home.newArrivals.first;
      items.add(
        _HeroItem(
          eyebrow: 'JUST IN  •  NEW ARRIVAL',
          title: product.name,
          subtitle: '${_price(product.price)}  •  Fresh from ${product.seller.businessName}',
          icon: Icons.auto_awesome_rounded,
          imageUrl: product.image,
          startColor: const Color(0xFF4054A8),
          endColor: const Color(0xFF7A6DE8),
          product: product,
          ctaLabel: 'See what’s new',
        ),
      );
    }

    if (home.trendingProducts.isNotEmpty) {
      final product = home.trendingProducts.first;
      items.add(
        _HeroItem(
          eyebrow: 'TRENDING NOW',
          title: product.name,
          subtitle: product.sold > 0
              ? '${_compactCount(product.sold)} sold  •  ${_price(product.price)}'
              : '${_price(product.price)}  •  Popular on ShopHop',
          icon: Icons.trending_up_rounded,
          imageUrl: product.image,
          startColor: AppColors.navy,
          endColor: const Color(0xFF315C8D),
          product: product,
          ctaLabel: 'View trending',
        ),
      );
    }

    if (home.recommendedProducts.isNotEmpty) {
      final product = home.recommendedProducts.first;
      items.add(
        _HeroItem(
          eyebrow: 'PICKED FOR YOU',
          title: product.name,
          subtitle: '${_price(product.price)}  •  Recommended from live catalog',
          icon: Icons.favorite_rounded,
          imageUrl: product.image,
          startColor: const Color(0xFF8A3D66),
          endColor: const Color(0xFFD05B7B),
          product: product,
          ctaLabel: 'Explore pick',
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        const _HeroItem(
          eyebrow: 'SHOPHOP MARKETPLACE',
          title: 'Discover your next find',
          subtitle: 'Approved seller products will appear here automatically',
          icon: Icons.storefront_rounded,
          startColor: AppColors.navy,
          endColor: AppColors.tealDark,
          ctaLabel: 'Browse ShopHop',
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
      child: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.teal,
            onRefresh: () => _loadHome(refresh: true),
            child: CustomScrollView(
              controller: _scrollController,
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
                  scrolledUnderElevation: 6,
                  shadowColor: const Color(0x140F1B3D),
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  titleSpacing: 14,
                  title: _SearchHeader(
                    hint: _activeSearchHint,
                    cartCount: home.cartCount,
                    onSearch: widget.onOpenSearch,
                    onCart: widget.onOpenCart,
                    onMessages: widget.onOpenMessages,
                  ),
                ),
                // Requested hierarchy: Search -> Banner -> Purchases -> Categories.
                SliverToBoxAdapter(
                  child: _Reveal(
                    delay: const Duration(milliseconds: 40),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _HeroCarousel(
                        controller: _bannerController,
                        items: _heroItems,
                        currentIndex: _bannerIndex,
                        ambientAnimation: _ensureAmbientController(),
                        onPageChanged: (index) {
                          setState(() => _bannerIndex = index);
                        },
                        onProductTap: widget.onOpenProduct,
                        onBrowseTap: widget.onOpenSearch,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _MaxWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 18),
                        const _Reveal(
                          delay: Duration(milliseconds: 120),
                          child: _SectionTitle(
                            title: 'My Purchases',
                            subtitle: 'Jump back into your order journey',
                            icon: Icons.inventory_2_outlined,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Reveal(
                          delay: const Duration(milliseconds: 170),
                          child: _QuickActions(onOrders: widget.onOpenOrders),
                        ),
                        const SizedBox(height: 22),
                        _Reveal(
                          delay: const Duration(milliseconds: 220),
                          child: _SectionTitle(
                            title: 'Categories',
                            subtitle: 'Explore ${home.categories.length} ways to shop',
                            icon: Icons.grid_view_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Reveal(
                          delay: const Duration(milliseconds: 270),
                          child: _CategoryStrip(
                            categories: home.categories,
                            onTap: widget.onOpenCategory,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _Reveal(
                          delay: const Duration(milliseconds: 320),
                          child: _LiveCatalogStrip(
                            deals: home.dealProducts.length,
                            trending: home.trendingProducts.length,
                            arrivals: home.newArrivals.length,
                            animation: _ensureAmbientController(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _MaxWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 26),
                        if (home.dealProducts.isNotEmpty) ...[
                          _Reveal(
                            delay: const Duration(milliseconds: 360),
                            child: _AnimatedSectionTitle(
                              title: 'Deals for You',
                              subtitle: 'Fresh discounts from live ShopHop inventory',
                              icon: Icons.bolt_rounded,
                              animation: _ensureAmbientController(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Reveal(
                            delay: const Duration(milliseconds: 400),
                            child: _HorizontalProducts(
                              products: home.dealProducts,
                              likedProductIds: _likedProductIds,
                              onTap: widget.onOpenProduct,
                              onLike: _toggleLike,
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                        if (home.trendingProducts.isNotEmpty) ...[
                          const _Reveal(
                            delay: Duration(milliseconds: 440),
                            child: _SectionTitle(
                              title: 'Trending Now',
                              subtitle: 'Popular products getting attention right now',
                              icon: Icons.trending_up_rounded,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Reveal(
                            delay: const Duration(milliseconds: 480),
                            child: _HorizontalProducts(
                              products: home.trendingProducts,
                              likedProductIds: _likedProductIds,
                              onTap: widget.onOpenProduct,
                              onLike: _toggleLike,
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                        if (home.newArrivals.isNotEmpty) ...[
                          const _Reveal(
                            delay: Duration(milliseconds: 520),
                            child: _SectionTitle(
                              title: 'New Arrivals',
                              subtitle: 'Recently listed by approved ShopHop sellers',
                              icon: Icons.auto_awesome_rounded,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Reveal(
                            delay: const Duration(milliseconds: 560),
                            child: _HorizontalProducts(
                              products: home.newArrivals,
                              likedProductIds: _likedProductIds,
                              onTap: widget.onOpenProduct,
                              onLike: _toggleLike,
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                        if (home.recommendedProducts.isNotEmpty) ...[
                          const _Reveal(
                            delay: Duration(milliseconds: 600),
                            child: _SectionTitle(
                              title: 'Recommended for You',
                              subtitle: 'Keep scrolling — your next find might be here',
                              icon: Icons.explore_outlined,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Reveal(
                            delay: const Duration(milliseconds: 640),
                            child: _ResponsiveProductGrid(
                              products: home.recommendedProducts,
                              likedProductIds: _likedProductIds,
                              onTap: widget.onOpenProduct,
                              onLike: _toggleLike,
                            ),
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
                        const SizedBox(height: 92),
                      ],
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
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                offset: _showBackToTop ? Offset.zero : const Offset(0, 0.7),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _showBackToTop ? 1 : 0,
                  child: FloatingActionButton.small(
                    heroTag: 'buyer_home_back_to_top',
                    elevation: 4,
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: const Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                ),
              ),
            ),
          ),
        ],
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
    required this.hint,
    required this.cartCount,
    required this.onSearch,
    required this.onCart,
    required this.onMessages,
  });

  final String hint;
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 21, color: Color(0xFF6B7787)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: Offset(0, 0.25),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          hint,
                          key: ValueKey<String>(hint),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF7B8492),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
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
      const _QuickActionData(
        Icons.inventory_2_outlined,
        'To Ship',
        Color(0xFF4F7DD9),
        Color(0xFFEAF1FF),
      ),
      const _QuickActionData(
        Icons.local_shipping_outlined,
        'In Transit',
        Color(0xFF13A08A),
        Color(0xFFE7FAF5),
      ),
      const _QuickActionData(
        Icons.markunread_mailbox_outlined,
        'To Receive',
        Color(0xFFF29C38),
        Color(0xFFFFF4E6),
      ),
      const _QuickActionData(
        Icons.star_outline_rounded,
        'To Rate',
        Color(0xFFE05A76),
        Color(0xFFFFEDF2),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.grayBorder.withValues(alpha: 0.75)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F1B3D),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: List.generate(actions.length, (index) {
          final action = actions[index];
          return Expanded(
            child: TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 360 + (index * 70)),
              curve: Curves.easeOutBack,
              tween: Tween(begin: 0.78, end: 1),
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: _BouncyTap(
                onTap: onOrders,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: action.softColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: action.color.withValues(alpha: 0.12),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(action.icon, color: action.color, size: 23),
                          ),
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: action.color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Reveal extends StatefulWidget {
  const _Reveal({
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curved);

    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}

class _BouncyTap extends StatefulWidget {
  const _BouncyTap({
    required this.onTap,
    required this.child,
    required this.borderRadius,
    this.pressedScale = 0.96,
  });

  final VoidCallback onTap;
  final Widget child;
  final BorderRadius borderRadius;
  final double pressedScale;

  @override
  State<_BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<_BouncyTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? widget.pressedScale : 1,
      duration: const Duration(milliseconds: 115),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) {
            if (_pressed != value) setState(() => _pressed = value);
          },
          borderRadius: widget.borderRadius,
          splashColor: AppColors.teal.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}

class _LiveCatalogStrip extends StatelessWidget {
  const _LiveCatalogStrip({
    required this.deals,
    required this.trending,
    required this.arrivals,
    required this.animation,
  });

  final int deals;
  final int trending;
  final int arrivals;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final pulse = 0.82 + (animation.value * 0.18);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF8FFFD), Color(0xFFF4F7FF)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3ECEB)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                Transform.scale(
                  scale: pulse,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFF18B38B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                const Text(
                  'Live catalog',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                _CatalogStatChip(
                  icon: Icons.local_offer_outlined,
                  label: '$deals deals',
                ),
                const SizedBox(width: 7),
                _CatalogStatChip(
                  icon: Icons.trending_up_rounded,
                  label: '$trending trending',
                ),
                const SizedBox(width: 7),
                _CatalogStatChip(
                  icon: Icons.auto_awesome_outlined,
                  label: '$arrivals new',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CatalogStatChip extends StatelessWidget {
  const _CatalogStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6EAEE)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.tealDark),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF687481),
              fontSize: 9.7,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedSectionTitle extends StatelessWidget {
  const _AnimatedSectionTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.animation,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF1C9), Color(0xFFFFE2D8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF09C45).withValues(
                      alpha: 0.10 + (animation.value * 0.10),
                    ),
                    blurRadius: 10 + (animation.value * 6),
                  ),
                ],
              ),
              child: Transform.scale(
                scale: 0.94 + (animation.value * 0.08),
                child: Icon(icon, size: 20, color: const Color(0xFFE87932)),
              ),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7E8793),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5EA),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Color(0xFFE87932),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        );
      },
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

    return _BouncyTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFDDF8F1)],
                  ),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: const Color(0xFFD8EFE9)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140F1B3D),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: category.coverImage.isNotEmpty
                      ? Image.network(
                          category.coverImage,
                          fit: BoxFit.cover,
                          frameBuilder: (context, child, frame, synchronous) {
                            if (synchronous) return child;
                            return AnimatedOpacity(
                              duration: const Duration(milliseconds: 260),
                              opacity: frame == null ? 0 : 1,
                              child: child,
                            );
                          },
                          errorBuilder: (_, __, ___) =>
                              _CategoryIconFallback(icon: icon),
                        )
                      : _CategoryIconFallback(icon: icon),
                ),
              ),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD7EEE8)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 11,
                    color: AppColors.tealDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
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
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
    required this.ambientAnimation,
    required this.onPageChanged,
    required this.onProductTap,
    required this.onBrowseTap,
  });

  final PageController controller;
  final List<_HeroItem> items;
  final int currentIndex;
  final Animation<double> ambientAnimation;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<BuyerProductData> onProductTap;
  final VoidCallback onBrowseTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 202,
          child: PageView.builder(
            controller: controller,
            itemCount: items.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final item = items[index];
              final active = index == currentIndex;

              return AnimatedScale(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                scale: active ? 1 : 0.965,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _BouncyTap(
                    onTap: item.product != null
                        ? () => onProductTap(item.product!)
                        : onBrowseTap,
                    borderRadius: BorderRadius.circular(26),
                    child: AnimatedBuilder(
                      animation: ambientAnimation,
                      builder: (context, child) {
                        final t = ambientAnimation.value;
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-1 + (0.15 * t), -1),
                              end: Alignment(1, 1 - (0.15 * t)),
                              colors: [item.startColor, item.endColor],
                            ),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: item.endColor.withValues(alpha: active ? 0.24 : 0.14),
                                blurRadius: active ? 24 : 16,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              Positioned(
                                right: -28 + (18 * t),
                                top: -38 + (12 * (1 - t)),
                                child: Container(
                                  width: 128,
                                  height: 128,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: -46 + (16 * (1 - t)),
                                bottom: -58 + (8 * t),
                                child: Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 7,
                                                height: 7,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFFFE36D),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 7),
                                              Expanded(
                                                child: Text(
                                                  item.eyebrow,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.88),
                                                    fontSize: 10.2,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 1.15,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            item.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 21.5,
                                              height: 1.06,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.55,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Text(
                                            item.subtitle,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.84),
                                              fontSize: 11.2,
                                              height: 1.3,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.96),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  item.ctaLabel,
                                                  style: TextStyle(
                                                    color: item.startColor,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 14,
                                                  color: item.startColor,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Transform.translate(
                                      offset: Offset(0, -3 + (6 * t)),
                                      child: Container(
                                        width: 96,
                                        height: 116,
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.26),
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(19),
                                          child: item.imageUrl.isNotEmpty
                                              ? Image.network(
                                                  item.imageUrl,
                                                  fit: BoxFit.cover,
                                                  frameBuilder: (context, child, frame, synchronous) {
                                                    if (synchronous) return child;
                                                    return AnimatedOpacity(
                                                      duration: const Duration(milliseconds: 280),
                                                      opacity: frame == null ? 0 : 1,
                                                      child: child,
                                                    );
                                                  },
                                                  errorBuilder: (_, __, ___) => _HeroIconFallback(
                                                    icon: item.icon,
                                                  ),
                                                )
                                              : _HeroIconFallback(icon: item.icon),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: active ? 24 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active ? AppColors.tealDark : const Color(0xFFD6DDE1),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _HeroIconFallback extends StatelessWidget {
  const _HeroIconFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: 40),
      ),
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
    return _BouncyTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFE7ECEF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C0F1B3D),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ProductImage(url: product.image),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.06),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (product.discountPercent > 0)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B66), Color(0xFFED4F72)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x24ED4F72),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
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
                    child: _BouncyTap(
                      onTap: onLike,
                      borderRadius: BorderRadius.circular(99),
                      pressedScale: 0.86,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x19000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) => ScaleTransition(
                            scale: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutBack,
                            ),
                            child: child,
                          ),
                          child: Icon(
                            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            key: ValueKey<bool>(liked),
                            size: 18,
                            color: const Color(0xFFED647C),
                          ),
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
                        fontWeight: FontWeight.w800,
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7F8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_compactCount(product.sold)} sold',
                              style: const TextStyle(
                                color: Color(0xFF7D8791),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
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
                        const Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color: Color(0xFF9AA2AA),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            product.seller.municipality.isNotEmpty
                                ? product.seller.municipality
                                : product.seller.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF9299A3),
                              fontSize: 9.3,
                              fontWeight: FontWeight.w600,
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

class _HomeLoadingView extends StatefulWidget {
  const _HomeLoadingView();

  @override
  State<_HomeLoadingView> createState() => _HomeLoadingViewState();
}

class _HomeLoadingViewState extends State<_HomeLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            children: [
              _ShimmerBlock(
                animationValue: _controller.value,
                height: 48,
                radius: 15,
              ),
              const SizedBox(height: 12),
              _ShimmerBlock(
                animationValue: _controller.value,
                height: 196,
                radius: 24,
              ),
              const SizedBox(height: 20),
              Row(
                children: List.generate(
                  4,
                  (index) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index == 3 ? 0 : 8),
                      child: Column(
                        children: [
                          _ShimmerBlock(
                            animationValue:
                                (_controller.value + (index * 0.08)) % 1,
                            height: 48,
                            radius: 16,
                          ),
                          const SizedBox(height: 7),
                          _ShimmerBlock(
                            animationValue: _controller.value,
                            height: 10,
                            radius: 99,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _ShimmerBlock(
                animationValue: _controller.value,
                height: 18,
                width: 150,
                radius: 8,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => SizedBox(
                    width: 92,
                    child: Column(
                      children: [
                        _ShimmerBlock(
                          animationValue:
                              (_controller.value + (index * 0.06)) % 1,
                          height: 58,
                          radius: 18,
                        ),
                        const SizedBox(height: 8),
                        _ShimmerBlock(
                          animationValue: _controller.value,
                          height: 10,
                          radius: 99,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    required this.animationValue,
    required this.height,
    required this.radius,
    this.width,
  });

  final double animationValue;
  final double height;
  final double radius;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final x = -1.8 + (animationValue * 3.6);
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(x - 1, 0),
          end: Alignment(x + 1, 0),
          colors: const [
            Color(0xFFF0F3F4),
            Color(0xFFFAFBFB),
            Color(0xFFF0F3F4),
          ],
        ),
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
    required this.ctaLabel,
    this.imageUrl = '',
    this.product,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color startColor;
  final Color endColor;
  final String imageUrl;
  final String ctaLabel;
  final BuyerProductData? product;
}

class _QuickActionData {
  const _QuickActionData(this.icon, this.label, this.color, this.softColor);

  final IconData icon;
  final String label;
  final Color color;
  final Color softColor;
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
