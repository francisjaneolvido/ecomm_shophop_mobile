import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/buyer_catalog_service.dart';
import '../../../theme/app_colors.dart';
import '../widgets/buyer_product_card.dart';

class BuyerCatalogPage extends StatefulWidget {
  const BuyerCatalogPage({
    super.key,
    required this.token,
    required this.onSessionExpired,
    required this.onOpenProduct,
    this.category,
    this.initialQuery = '',
  });

  final String token;
  final Future<void> Function() onSessionExpired;
  final ValueChanged<BuyerProductData> onOpenProduct;
  final BuyerCategoryData? category;
  final String initialQuery;

  bool get isCategoryPage => category != null;

  @override
  State<BuyerCatalogPage> createState() => _BuyerCatalogPageState();
}

class _BuyerCatalogPageState extends State<BuyerCatalogPage> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _searchController;
  Timer? _debounce;

  final List<BuyerProductData> _products = [];
  BuyerCatalogException? _error;
  BuyerPaginationData? _pagination;
  bool _loading = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  String _sort = 'popular';

  static const _sortOptions = <String, String>{
    'popular': 'Popular',
    'latest': 'Latest',
    'top_sales': 'Top Sales',
    'price_low': 'Price: Low',
    'price_high': 'Price: High',
  };

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _scrollController.addListener(_handleScroll);
    _loadProducts(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _loadingMore || _loading) return;
    final pagination = _pagination;
    if (pagination == null || !pagination.hasMore) return;

    if (_scrollController.position.extentAfter < 450) {
      _loadProducts(reset: false);
    }
  }

  Future<void> _loadProducts({required bool reset}) async {
    if (reset) {
      if (_refreshing) {
        setState(() => _refreshing = false);
      }
      setState(() {
        _loading = _products.isEmpty;
        _error = null;
      });
    } else {
      final pagination = _pagination;
      if (_loadingMore || pagination == null || !pagination.hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final nextPage = reset ? 1 : (_pagination?.currentPage ?? 0) + 1;
      final result = await BuyerCatalogService.getProducts(
        token: widget.token,
        query: _searchController.text,
        category: widget.category?.slug,
        sort: _sort,
        page: nextPage,
        perPage: 20,
      );

      if (!mounted) return;

      setState(() {
        if (reset) {
          _products
            ..clear()
            ..addAll(result.items);
        } else {
          final existing = _products.map((item) => item.id).toSet();
          _products.addAll(
            result.items.where((item) => !existing.contains(item.id)),
          );
        }
        _pagination = result.pagination;
        _error = null;
        _loading = false;
        _loadingMore = false;
        _refreshing = false;
      });
    } on BuyerCatalogException catch (error) {
      if (!mounted) return;

      if (error.isUnauthorized) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _refreshing = false;
        });
        await widget.onSessionExpired();
        return;
      }

      setState(() {
        _error = error;
        _loading = false;
        _loadingMore = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _loadProducts(reset: true);
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _loadProducts(reset: true);
    });
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) return;
    _searchController.clear();
    _loadProducts(reset: true);
  }

  void _changeSort(String value) {
    if (_sort == value) return;
    setState(() => _sort = value);
    _loadProducts(reset: true);
  }

  Future<void> _toggleLike(BuyerProductData product) async {
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index < 0) return;

    final previous = _products[index];
    final targetLiked = !previous.isLiked;
    setState(() {
      _products[index] = previous.copyWith(isLiked: targetLiked);
    });

    try {
      final liked = await BuyerCatalogService.setFavorite(
        token: widget.token,
        productId: product.id,
        liked: targetLiked,
      );
      if (!mounted) return;

      final currentIndex = _products.indexWhere((item) => item.id == product.id);
      if (currentIndex >= 0) {
        setState(() {
          _products[currentIndex] =
              _products[currentIndex].copyWith(isLiked: liked);
        });
      }

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

      final currentIndex = _products.indexWhere((item) => item.id == product.id);
      if (currentIndex >= 0) {
        setState(() => _products[currentIndex] = previous);
      }

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
    final total = _pagination?.total ?? _products.length;
    final title = widget.category?.name ?? 'Search ShopHop';

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
        titleSpacing: 0,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _CatalogHeader(
                category: widget.category,
                controller: _searchController,
                onChanged: _onSearchChanged,
                onClear: _clearSearch,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SortHeaderDelegate(
                sort: _sort,
                options: _sortOptions,
                onChanged: _changeSort,
                resultCount: total,
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.teal),
                ),
              )
            else if (_error != null && _products.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _CatalogErrorState(
                  message: _error!.message,
                  onRetry: () => _loadProducts(reset: true),
                ),
              )
            else if (_products.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyCatalogState(
                  query: _searchController.text,
                  categoryName: widget.category?.name,
                  onClearSearch: _clearSearch,
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
                          final product = _products[index];
                          return BuyerProductCard(
                            product: product,
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              widget.onOpenProduct(product);
                            },
                            onLike: () => _toggleLike(product),
                          );
                        },
                        childCount: _products.length,
                      ),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  child: Center(
                    child: _loadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              color: AppColors.teal,
                              strokeWidth: 2.5,
                            ),
                          )
                        : (_pagination?.hasMore ?? false)
                            ? OutlinedButton.icon(
                                onPressed: () => _loadProducts(reset: false),
                                icon: const Icon(Icons.expand_more_rounded),
                                label: const Text('Load more'),
                              )
                            : Text(
                                'You reached the end of the catalog.',
                                style: TextStyle(
                                  color: AppColors.navy.withValues(alpha: 0.46),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({
    required this.category,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final BuyerCategoryData? category;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
            child: TextField(
              controller: controller,
              autofocus: false,
              onChanged: onChanged,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: category == null
                    ? 'Search products, categories, or keywords'
                    : 'Search within ${category!.name}',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.tealDark,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                    );
                  },
                ),
                filled: true,
                fillColor: const Color(0xFFF5F8F8),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE7EEEC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.teal,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          if (category != null) ...[
            SizedBox(
              height: 92,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                scrollDirection: Axis.horizontal,
                itemCount: category!.subcategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final subcategory = category!.subcategories[index];
                  return Container(
                    width: 122,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF5FFFC), Color(0xFFE7F8F4)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD7EEE8)),
                    ),
                    child: Center(
                      child: Text(
                        subcategory,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 10.5,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SortHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SortHeaderDelegate({
    required this.sort,
    required this.options,
    required this.onChanged,
    required this.resultCount,
  });

  final String sort;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  final int resultCount;

  @override
  double get minExtent => 78;

  @override
  double get maxExtent => 78;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Colors.white,
      elevation: overlapsContent ? 2 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Text(
              '$resultCount product${resultCount == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Color(0xFF7B8490),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final entry = options.entries.elementAt(index);
                final selected = sort == entry.key;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => onChanged(entry.key),
                  label: Text(entry.value),
                  showCheckmark: false,
                  selectedColor: AppColors.tealLight,
                  backgroundColor: const Color(0xFFF5F7F8),
                  side: BorderSide(
                    color: selected ? AppColors.teal : const Color(0xFFE4E8EB),
                  ),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.tealDark : AppColors.navy,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SortHeaderDelegate oldDelegate) {
    return oldDelegate.sort != sort || oldDelegate.resultCount != resultCount;
  }
}

class _CatalogErrorState extends StatelessWidget {
  const _CatalogErrorState({required this.message, required this.onRetry});

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
              Icons.cloud_off_rounded,
              color: AppColors.tealDark,
              size: 52,
            ),
            const SizedBox(height: 14),
            const Text(
              'Could not load products',
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

class _EmptyCatalogState extends StatelessWidget {
  const _EmptyCatalogState({
    required this.query,
    required this.categoryName,
    required this.onClearSearch,
  });

  final String query;
  final String? categoryName;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 56,
              color: Color(0xFFA8B2BC),
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery ? 'No matching products' : 'No products available yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              hasQuery
                  ? 'Try another keyword${categoryName == null ? '' : ' inside $categoryName'}.'
                  : categoryName == null
                      ? 'Approved seller products will appear here automatically.'
                      : 'There are no approved products under $categoryName yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7A8490),
                height: 1.4,
              ),
            ),
            if (hasQuery) ...[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Clear search'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
