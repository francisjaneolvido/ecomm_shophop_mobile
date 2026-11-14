import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_category_carousel.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_product_card.dart';
import 'package:shophop/shared/realtime/foreground_refresh.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';

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
    this.onOpenCollection,
    this.isActive = true,
  });
  final String token;
  final bool isActive;
  final Future<void> Function() onSessionExpired;
  final VoidCallback onOpenSearch;
  final ValueChanged<BuyerCategoryData> onOpenCategory;
  final ValueChanged<BuyerProductData> onOpenProduct;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenMessages;
  final ValueChanged<String>? onOpenCollection;

  @override
  State<BuyerHomePage> createState() => _BuyerHomePageState();
}

class _BuyerHomePageState extends State<BuyerHomePage>
    with AutomaticKeepAliveClientMixin {
  BuyerHomeData? _home;
  BuyerCatalogException? _error;
  late final ForegroundRefresh _liveRefresh;
  final Set<int> _liked = {};
  final Set<int> _pendingLikes = {};
  bool _loading = true;
  bool _refreshing = false;
  int _requestId = 0;
  int _bannerIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadHome();
    _liveRefresh = ForegroundRefresh(
      refresh: () => _loadHome(silent: true),
      canRefresh: () =>
          mounted &&
          widget.isActive &&
          !_loading &&
          !_refreshing &&
          (ModalRoute.of(context)?.isCurrent ?? true),
    );
  }

  @override
  void didUpdateWidget(covariant BuyerHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) _loadHome(force: true);
  }

  @override
  void dispose() {
    _liveRefresh.dispose();
    super.dispose();
  }

  Future<void> _loadHome({bool silent = false, bool force = false}) async {
    if (_refreshing && !force) return;
    final requestId = ++_requestId;
    setState(() {
      _refreshing = true;
      if (!silent) _error = null;
    });
    try {
      final home = await BuyerCatalogService.getHome(token: widget.token);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _home = home;
        _error = null;
        _loading = false;
        _refreshing = false;
        _bannerIndex = home.banners.isEmpty
            ? 0
            : _bannerIndex.clamp(0, home.banners.length - 1);
        final products = [
          ...home.topProducts,
          ...home.dealProducts,
          ...home.discoverProducts,
        ];
        for (final product in products) {
          if (_pendingLikes.contains(product.id)) {
            continue;
          }
          product.isLiked ? _liked.add(product.id) : _liked.remove(product.id);
        }
      });
    } on BuyerCatalogException catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = error;
      });
      if (error.isUnauthorized) await widget.onSessionExpired();
    }
  }

  Future<void> _toggleLike(BuyerProductData product) async {
    if (!_pendingLikes.add(product.id)) return;
    final wasLiked = _liked.contains(product.id);
    setState(() {
      wasLiked ? _liked.remove(product.id) : _liked.add(product.id);
    });
    try {
      final liked = await BuyerCatalogService.setFavorite(
        token: widget.token,
        productId: product.id,
        liked: !wasLiked,
      );
      if (!mounted) return;
      setState(() {
        liked ? _liked.add(product.id) : _liked.remove(product.id);
      });
    } on BuyerCatalogException catch (error) {
      if (!mounted) return;
      setState(() {
        wasLiked ? _liked.add(product.id) : _liked.remove(product.id);
      });
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      _pendingLikes.remove(product.id);
    }
  }

  void _openCollection(String collection) {
    if (widget.onOpenCollection != null) {
      widget.onOpenCollection!(collection);
    } else {
      widget.onOpenSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final home = _home;
    if (_loading && home == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (home == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ShopHopEmptyState(
            icon: CupertinoIcons.wifi_exclamationmark,
            title: 'Unable to load ShopHop',
            description: _error?.message ?? 'Please try again.',
            actionLabel: 'Try again',
            onAction: _loadHome,
          ),
        ),
      );
    }
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _loadHome,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              toolbarHeight: 72,
              titleSpacing: 16,
              title: Material(
                color: colors.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                  side: BorderSide(color: colors.outline),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onOpenSearch,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.search,
                          size: 19,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'What are you looking for?',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Messages',
                  onPressed: widget.onOpenMessages,
                  icon: const Icon(CupertinoIcons.chat_bubble),
                ),
                IconButton(
                  tooltip: 'Cart',
                  onPressed: widget.onOpenCart,
                  icon: Badge.count(
                    count: home.cartCount < 0 ? 0 : home.cartCount,
                    isLabelVisible: home.cartCount > 0,
                    child: const Icon(CupertinoIcons.cart),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Couldn't refresh categories and products. Showing the last loaded data.",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.error,
                        ),
                      ),
                      TextButton(
                        onPressed: _refreshing ? null : _loadHome,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            if (home.banners.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _MarketplaceBanner(
                    banner: home.banners[_bannerIndex],
                    index: _bannerIndex,
                    count: home.banners.length,
                    onChanged: (index) => setState(() => _bannerIndex = index),
                    onTap: () {
                      final target = home.banners[_bannerIndex].target;
                      if (target == 'categories') {
                        widget.onOpenSearch();
                      } else {
                        _openCollection(target);
                      }
                    },
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Column(
                  children: [
                    const ShopHopSectionHeading(title: 'Shop by Category'),
                    const SizedBox(height: 8),
                    BuyerCategoryCarousel(
                      categories: home.categories,
                      onCategory: widget.onOpenCategory,
                      onRetry: _loadHome,
                      refreshing: _refreshing,
                    ),
                  ],
                ),
              ),
            ),
            ..._section(
              'Flash Deals',
              CupertinoIcons.bolt,
              'Products with discounts currently set by ShopHop sellers.',
              home.dealProducts,
              'deals',
              'No seller discounts listed yet',
            ),
            ..._section(
              'Top Products',
              CupertinoIcons.chart_bar,
              home.hasCompletedSales
                  ? 'Ranked by units in completed ShopHop orders.'
                  : 'Recently listed products. Sales rankings appear after completed orders.',
              home.topProducts,
              'top',
              'No products to rank yet',
            ),
            ..._section(
              'Daily Discover',
              CupertinoIcons.sparkles,
              'Explore the newest approved, available products across ShopHop.',
              home.discoverProducts,
              'discover',
              'No products available yet',
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  List<Widget> _section(
    String title,
    IconData icon,
    String subtitle,
    List<BuyerProductData> products,
    String collection,
    String emptyTitle,
  ) => [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
        child: ShopHopSectionHeading(
          title: title,
          subtitle: subtitle,
          trailing: TextButton(
            onPressed: () => _openCollection(collection),
            child: const Text('See all'),
          ),
        ),
      ),
    ),
    if (products.isEmpty)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ShopHopEmptyState(
            icon: icon,
            title: emptyTitle,
            description:
                'Approved, active, in-stock products will appear here automatically.',
          ),
        ),
      )
    else
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) => SliverGrid(
            gridDelegate: BuyerProductCard.gridDelegate(
              context,
              constraints.crossAxisExtent,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final product = products[index];
              return BuyerProductCard(
                product: product.copyWith(isLiked: _liked.contains(product.id)),
                onTap: () => widget.onOpenProduct(product),
                onLike: () => _toggleLike(product),
              );
            }, childCount: products.length),
          ),
        ),
      ),
  ];
}

class _MarketplaceBanner extends StatelessWidget {
  const _MarketplaceBanner({
    required this.banner,
    required this.index,
    required this.count,
    required this.onChanged,
    required this.onTap,
  });
  final BuyerBannerData banner;
  final int index;
  final int count;
  final ValueChanged<int> onChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() > 60) {
              onChanged((index + (velocity < 0 ? 1 : -1) + count) % count);
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: colors.secondary,
                    child: banner.image.isEmpty
                        ? null
                        : Image.network(
                            banner.image,
                            webHtmlElementStrategy:
                                WebHtmlElementStrategy.fallback,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.secondary,
                          colors.secondary.withValues(alpha: .72),
                          colors.primary.withValues(alpha: .25),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banner.eyebrow,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.primaryContainer,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        banner.heading,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colors.onSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        banner.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSecondary.withValues(alpha: .85),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: onTap,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                banner.target == 'categories'
                                    ? 'Shop now'
                                    : banner.linkLabel,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(CupertinoIcons.arrow_right, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (count > 1)
          SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < count; i++)
                  IconButton(
                    tooltip: 'Show banner ${i + 1}',
                    onPressed: () => onChanged(i),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    icon: Icon(
                      Icons.circle,
                      size: index == i ? 8 : 6,
                      color: index == i ? colors.primary : colors.outline,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
