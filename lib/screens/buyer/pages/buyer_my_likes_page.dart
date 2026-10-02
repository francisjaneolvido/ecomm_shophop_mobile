import 'package:flutter/material.dart';

import '../../../services/buyer_catalog_service.dart';
import '../../../theme/app_colors.dart';
import '../widgets/buyer_product_card.dart';

class BuyerMyLikesPage extends StatefulWidget {
  const BuyerMyLikesPage({
    super.key,
    required this.token,
    required this.onSessionExpired,
    required this.onOpenSearch,
    required this.onOpenCart,
    required this.onOpenProduct,
  });

  final String token;
  final Future<void> Function() onSessionExpired;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenCart;
  final ValueChanged<BuyerProductData> onOpenProduct;

  @override
  State<BuyerMyLikesPage> createState() => _BuyerMyLikesPageState();
}

class _BuyerMyLikesPageState extends State<BuyerMyLikesPage>
    with AutomaticKeepAliveClientMixin {
  final List<BuyerProductData> _products = [];

  BuyerCatalogException? _error;
  bool _loading = true;
  bool _refreshing = false;
  bool _discountOnly = false;
  bool _inStockOnly = false;
  String? _selectedCategory;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadLikes();
  }

  @override
  void didUpdateWidget(covariant BuyerMyLikesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _loadLikes();
    }
  }

  Future<void> _loadLikes({bool refresh = false}) async {
    if (refresh) {
      if (_refreshing) return;
      setState(() => _refreshing = true);
    } else {
      setState(() {
        _loading = _products.isEmpty;
        _error = null;
      });
    }

    try {
      final result = await BuyerCatalogService.getLikes(token: widget.token);
      if (!mounted) return;

      setState(() {
        _products
          ..clear()
          ..addAll(result.items);
        _loading = false;
        _refreshing = false;
        _error = null;

        if (_selectedCategory != null &&
            !_products.any((item) => item.category == _selectedCategory)) {
          _selectedCategory = null;
        }
      });
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

  List<BuyerProductData> get _filteredProducts {
    return _products.where((product) {
      if (_discountOnly && product.discountPercent <= 0) return false;
      if (_inStockOnly && !product.isAvailable) return false;
      if (_selectedCategory != null &&
          product.category != _selectedCategory) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  List<String> get _categories {
    final categories = _products
        .map((product) => product.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  Future<void> _toggleLike(BuyerProductData product) async {
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index < 0) return;

    final removed = _products.removeAt(index);
    setState(() {});

    try {
      await BuyerCatalogService.setFavorite(
        token: widget.token,
        productId: product.id,
        liked: false,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: const Text('Removed from My Likes'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () => _restoreFavorite(removed),
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
        final insertAt = index.clamp(0, _products.length).toInt();
        _products.insert(insertAt, removed);
      });
      _showError(error.message);
    }
  }

  Future<void> _restoreFavorite(BuyerProductData product) async {
    if (_products.any((item) => item.id == product.id)) return;

    try {
      final liked = await BuyerCatalogService.setFavorite(
        token: widget.token,
        productId: product.id,
        liked: true,
      );
      if (!mounted || !liked) return;

      setState(() {
        _products.insert(0, product.copyWith(isLiked: true));
      });
    } on BuyerCatalogException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return;
      }
      _showError(error.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }

  Future<void> _selectCategory() async {
    final categories = _categories;
    if (categories.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.68,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grayBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Filter My Likes',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.apps_rounded,
                          color: AppColors.tealDark,
                        ),
                        title: const Text('All categories'),
                        trailing: _selectedCategory == null
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.tealDark,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, ''),
                      ),
                      ...categories.map(
                        (category) => ListTile(
                          leading: const Icon(
                            Icons.sell_outlined,
                            color: Color(0xFFED647C),
                          ),
                          title: Text(category),
                          trailing: _selectedCategory == category
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.tealDark,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, category),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() {
      _selectedCategory = selected.isEmpty ? null : selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final likedProducts = _filteredProducts;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: () => _loadLikes(refresh: true),
        child: CustomScrollView(
          key: const PageStorageKey<String>('buyer-likes-scroll'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              titleSpacing: 16,
              title: Row(
                children: [
                  const Text(
                    'My Likes',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEF2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${_products.length}',
                      style: const TextStyle(
                        color: Color(0xFFDE536B),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: widget.onOpenSearch,
                  tooltip: 'Search',
                  icon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.tealDark,
                  ),
                ),
                IconButton(
                  onPressed: widget.onOpenCart,
                  tooltip: 'Cart',
                  icon: const Icon(
                    Icons.shopping_cart_outlined,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: !_discountOnly &&
                            !_inStockOnly &&
                            _selectedCategory == null,
                        onTap: () => setState(() {
                          _discountOnly = false;
                          _inStockOnly = false;
                          _selectedCategory = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'In Stock',
                        icon: Icons.inventory_2_outlined,
                        selected: _inStockOnly,
                        onTap: () => setState(() => _inStockOnly = !_inStockOnly),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Discount',
                        icon: Icons.local_offer_outlined,
                        selected: _discountOnly,
                        onTap: () => setState(() => _discountOnly = !_discountOnly),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: _selectedCategory ?? 'Category',
                        icon: Icons.keyboard_arrow_down_rounded,
                        selected: _selectedCategory != null,
                        onTap: _selectCategory,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_loading && _products.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.teal),
                ),
              )
            else if (_error != null && _products.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _LikesMessageState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Unable to load My Likes',
                  message: _error!.message,
                  actionLabel: 'Try Again',
                  onAction: _loadLikes,
                ),
              )
            else if (_products.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _LikesMessageState(
                  icon: Icons.favorite_border_rounded,
                  title: 'No liked products yet',
                  message:
                      'Tap the heart on any ShopHop product. Your likes are shared with the web version too.',
                  actionLabel: 'Browse Products',
                  onAction: widget.onOpenSearch,
                ),
              )
            else if (likedProducts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _LikesMessageState(
                  icon: Icons.filter_alt_off_rounded,
                  title: 'No matches',
                  message: 'Try changing your My Likes filters.',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 26),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final columns = width >= 1050
                        ? 5
                        : width >= 780
                            ? 4
                            : width >= 560
                                ? 3
                                : 2;

                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: width < 430 ? 0.62 : 0.67,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = likedProducts[index];
                          return BuyerProductCard(
                            product: product,
                            onTap: () {
                              if (product.isAvailable) {
                                widget.onOpenProduct(product);
                              } else {
                                _showError('This liked product is currently unavailable.');
                              }
                            },
                            onLike: () => _toggleLike(product),
                          );
                        },
                        childCount: likedProducts.length,
                      ),
                    );
                  },
                ),
              ),
            ],
            if (_refreshing)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.teal,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE7F8F4) : const Color(0xFFF7F9FA),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? AppColors.teal : const Color(0xFFE2E7EA),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? AppColors.tealDark : const Color(0xFF7D8790),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.tealDark : AppColors.navy,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LikesMessageState extends StatelessWidget {
  const _LikesMessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEEF2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFFDF647A), size: 31),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7B858F),
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.tealDark,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
