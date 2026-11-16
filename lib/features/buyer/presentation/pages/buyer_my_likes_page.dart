import 'package:flutter/services.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_page_chrome.dart';
import 'package:flutter/material.dart';

import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_product_card.dart';

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
    return _products
        .where((product) {
          if (_discountOnly && product.discountPercent <= 0) return false;
          if (_inStockOnly && !product.isAvailable) return false;
          if (_selectedCategory != null &&
              product.category != _selectedCategory) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
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

  Future<void> _manageLikes() async {
    final busy = <int>{};
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .6,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Manage Likes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return ListTile(
                          title: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          subtitle: product.isAvailable
                              ? null
                              : const Text(
                                  'Currently unavailable',
                                  style: TextStyle(fontSize: 10),
                                ),
                          trailing: TextButton(
                            onPressed: busy.contains(product.id)
                                ? null
                                : () async {
                                    updateSheet(() => busy.add(product.id));
                                    try {
                                      await BuyerCatalogService.setFavorite(
                                        token: widget.token,
                                        productId: product.id,
                                        liked: false,
                                      );
                                      if (!mounted) return;
                                      setState(
                                        () => _products.removeWhere(
                                          (item) => item.id == product.id,
                                        ),
                                      );
                                      if (sheetContext.mounted) {
                                        updateSheet(
                                          () => busy.remove(product.id),
                                        );
                                        if (_products.isEmpty) {
                                          Navigator.pop(sheetContext);
                                        }
                                      }
                                    } on BuyerCatalogException catch (error) {
                                      if (!mounted) return;
                                      if (sheetContext.mounted) {
                                        updateSheet(
                                          () => busy.remove(product.id),
                                        );
                                      }
                                      _showError(error.message);
                                      if (error.isUnauthorized) {
                                        if (sheetContext.mounted) {
                                          Navigator.pop(sheetContext);
                                        }
                                        await widget.onSessionExpired();
                                      }
                                    }
                                  },
                            child: Text(
                              busy.contains(product.id)
                                  ? 'Removing...'
                                  : 'Remove',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
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
                            color: AppColors.pink,
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
      top: false,
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.pink,
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
              backgroundColor: AppColors.page,
              foregroundColor: AppColors.navy,
              surfaceTintColor: Colors.transparent,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              toolbarHeight: 64,
              elevation: 0,
              titleSpacing: 14,
              title: const BuyerPageHeading(
                title: 'My Likes',
                icon: Icons.favorite_border,
              ),
              actions: [
                TextButton(
                  onPressed: _products.isEmpty ? null : _manageLikes,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    disabledForegroundColor: AppColors.textMuted,
                  ),
                  child: const Text('Manage'),
                ),

                IconButton(
                  onPressed: widget.onOpenSearch,
                  tooltip: 'Search',
                  icon: const Icon(Icons.search_rounded, color: AppColors.navy),
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
                        selected:
                            !_discountOnly &&
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
                        onTap: () =>
                            setState(() => _inStockOnly = !_inStockOnly),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Discount',
                        icon: Icons.local_offer_outlined,
                        selected: _discountOnly,
                        onTap: () =>
                            setState(() => _discountOnly = !_discountOnly),
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
                      'Save a product from its details page to find it here on web and mobile.',
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
                    return SliverGrid(
                      gridDelegate: BuyerProductCard.gridDelegate(
                        context,
                        width,
                        likedProducts,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final product = likedProducts[index];
                        return BuyerProductCard(
                          product: product,
                          onTap: () {
                            if (product.isAvailable) {
                              widget.onOpenProduct(product);
                            } else {
                              _showError(
                                'This liked product is currently unavailable.',
                              );
                            }
                          },
                        );
                      }, childCount: likedProducts.length),
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
                        color: AppColors.pink,
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
      color: selected ? AppColors.tealLight : const Color(0xFFF7F9FA),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? AppColors.pink : const Color(0xFFE2E7EA),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? AppColors.pink : const Color(0xFF7D8790),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.pink : AppColors.navy,
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
              child: Icon(icon, color: AppColors.pink, size: 31),
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
                style: FilledButton.styleFrom(backgroundColor: AppColors.pink),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
