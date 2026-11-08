import 'dart:async';
import 'package:shophop/shared/realtime/foreground_refresh.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';

import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_product_card.dart';

class BuyerCatalogPage extends StatefulWidget {
  const BuyerCatalogPage({
    super.key,
    required this.token,
    required this.onSessionExpired,
    required this.onOpenProduct,
    this.category,
    this.initialQuery = '',
    this.initialSubcategory,
    this.collection,
    this.initialSort = 'popular',
  });

  final String token;
  final Future<void> Function() onSessionExpired;
  final ValueChanged<BuyerProductData> onOpenProduct;
  final BuyerCategoryData? category;
  final String initialQuery;
  final String? initialSubcategory;
  final String? collection;
  final String initialSort;

  bool get isCategoryPage => category != null;

  @override
  State<BuyerCatalogPage> createState() => _BuyerCatalogPageState();
}

class _BuyerCatalogPageState extends State<BuyerCatalogPage> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _searchController;
  Timer? _debounce;
  late final ForegroundRefresh _liveRefresh;
  int _requestId = 0;
  bool _requestBusy = false;

  final List<BuyerProductData> _products = [];
  BuyerCatalogException? _error;
  BuyerPaginationData? _pagination;
  bool _loading = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  String _sort = 'popular';
  String? _subcategory;

  static const _sortOptions = <String, String>{
    'popular': 'Popular',
    'latest': 'Latest',
    'top_sales': 'Best Sellers',
    'price_low': 'Price: Low',
    'price_high': 'Price: High',
  };

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _subcategory = widget.initialSubcategory;
    _sort = _sortOptions.containsKey(widget.initialSort)
        ? widget.initialSort
        : 'popular';
    _scrollController.addListener(_handleScroll);
    _loadProducts(reset: true);
    _liveRefresh = ForegroundRefresh(
      refresh: () => _loadProducts(reset: true, silent: true),
      canRefresh: () =>
          mounted &&
          !_requestBusy &&
          !(_debounce?.isActive ?? false) &&
          (ModalRoute.of(context)?.isCurrent ?? true),
    );
  }

  @override
  void dispose() {
    _liveRefresh.dispose();
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

  Future<void> _loadProducts({required bool reset, bool silent = false}) async {
    if (!reset &&
        (_loadingMore || _pagination == null || !_pagination!.hasMore)) {
      return;
    }
    final requestId = ++_requestId;
    _requestBusy = true;
    if (reset) {
      if (_refreshing) {
        setState(() => _refreshing = false);
      }
      setState(() {
        _loading = _products.isEmpty || !silent;
        _loadingMore = false;
        _error = null;
      });
    } else {
      final pagination = _pagination;
      if (_loadingMore || pagination == null || !pagination.hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final pages = silent ? (_pagination?.currentPage ?? 1) : 1;
      final nextPage = reset ? 1 : (_pagination?.currentPage ?? 0) + 1;
      var result = await BuyerCatalogService.getProducts(
        token: widget.token,
        query: _searchController.text,
        category: widget.category?.slug,
        subcategory: _subcategory,
        collection: widget.collection,
        sort: _sort,
        page: nextPage,
        perPage: 20,
      );

      final refreshed = [...result.items];
      if (silent) {
        for (var page = 2; page <= pages && result.pagination.hasMore; page++) {
          result = await BuyerCatalogService.getProducts(
            token: widget.token,
            query: _searchController.text,
            category: widget.category?.slug,
            subcategory: _subcategory,
            collection: widget.collection,
            sort: _sort,
            page: page,
            perPage: 20,
          );
          refreshed.addAll(result.items);
        }
      }
      if (!mounted || requestId != _requestId) return;

      setState(() {
        if (reset) {
          _products
            ..clear()
            ..addAll(refreshed);
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
      if (!mounted || requestId != _requestId) return;

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
        if (!silent) _error = error;
        _loading = false;
        _loadingMore = false;
        _refreshing = false;
      });
    } finally {
      if (requestId == _requestId) _requestBusy = false;
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _loadProducts(reset: true);
  }

  void _onSearchChanged(String _) {
    _requestId++;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _loadProducts(reset: true);
    });
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) return;
    _debounce?.cancel();
    _searchController.clear();
    _loadProducts(reset: true);
  }

  void _changeSort(String value) {
    if (_sort == value) return;
    _debounce?.cancel();
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

      final currentIndex = _products.indexWhere(
        (item) => item.id == product.id,
      );
      if (currentIndex >= 0) {
        setState(() {
          _products[currentIndex] = _products[currentIndex].copyWith(
            isLiked: liked,
          );
        });
      }

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

      final currentIndex = _products.indexWhere(
        (item) => item.id == product.id,
      );
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

  void _changeSubcategory(String? value) {
    if (_subcategory == value) return;
    _debounce?.cancel();
    setState(() => _subcategory = value);
    _loadProducts(reset: true);
  }

  void _showSortOptions() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sort products',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final entry in _sortOptions.entries)
                  ListTile(
                    title: Text(entry.value),
                    trailing: _sort == entry.key
                        ? Icon(
                            CupertinoIcons.checkmark,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      _changeSort(entry.key);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = _pagination?.total ?? 0;
    final title =
        widget.category?.name ??
        switch (widget.collection) {
          'deals' => 'Flash Deals',
          'top' => 'Top Products',
          'discover' => 'Daily Discover',
          _ => 'Explore Products',
        };
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(CupertinoIcons.arrow_left),
        ),
        title: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          onSubmitted: (_) {
            _debounce?.cancel();
            _loadProducts(reset: true);
            FocusScope.of(context).unfocus();
          },
          maxLength: 100,
          textInputAction: TextInputAction.search,
          style: theme.textTheme.bodySmall,
          decoration: InputDecoration(
            hintText: 'Search products',
            counterText: '',
            prefixIcon: const Icon(CupertinoIcons.search, size: 18),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: _clearSearch,
                      icon: const Icon(CupertinoIcons.xmark, size: 16),
                    ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sort products',
            onPressed: _showSortOptions,
            icon: const Icon(CupertinoIcons.slider_horizontal_3),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: ColoredBox(
                color: colors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(title, style: theme.textTheme.titleSmall),
                    ),
                    SizedBox(
                      height: 48 + (scale - 1) * 16,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          for (final entry in _sortOptions.entries)
                            Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _sort == entry.key
                                        ? colors.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: TextButton(
                                onPressed: () => _changeSort(entry.key),
                                style: TextButton.styleFrom(
                                  foregroundColor: _sort == entry.key
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                ),
                                child: Text(entry.value),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.category != null &&
                        widget.category!.subcategories.isNotEmpty)
                      SizedBox(
                        height: 64 + (scale - 1) * 16,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: const Text('All'),
                                selected: _subcategory == null,
                                onSelected: (_) => _changeSubcategory(null),
                              ),
                            ),
                            for (final sub in widget.category!.subcategories)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(sub),
                                  selected: _subcategory == sub,
                                  onSelected: (_) => _changeSubcategory(sub),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                child: Text(
                  _loading
                      ? 'Finding products...'
                      : '$total product${total == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (_error != null && _products.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ),
              ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _products.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ShopHopEmptyState(
                    icon: CupertinoIcons.wifi_exclamationmark,
                    title: 'Unable to load products',
                    description: _error!.message,
                    actionLabel: 'Try again',
                    onAction: () => _loadProducts(reset: true),
                  ),
                ),
              )
            else if (_products.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ShopHopEmptyState(
                    icon: CupertinoIcons.search,
                    title: 'No products found',
                    description: _searchController.text.isNotEmpty
                        ? 'Try another product name or keyword.'
                        : 'Approved, available products will appear here.',
                    actionLabel: _searchController.text.isNotEmpty
                        ? 'Clear search'
                        : null,
                    onAction: _searchController.text.isNotEmpty
                        ? _clearSearch
                        : null,
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) => SliverGrid(
                    gridDelegate: BuyerProductCard.gridDelegate(
                      context,
                      constraints.crossAxisExtent,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final product = _products[index];
                      return BuyerProductCard(
                        product: product,
                        onLike: () => _toggleLike(product),
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          widget.onOpenProduct(product);
                        },
                      );
                    }, childCount: _products.length),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Center(
                    child: _loadingMore
                        ? const CircularProgressIndicator()
                        : (_pagination?.hasMore ?? false)
                        ? OutlinedButton.icon(
                            onPressed: () => _loadProducts(reset: false),
                            icon: const Icon(CupertinoIcons.chevron_down),
                            label: const Text('Load more'),
                          )
                        : Text(
                            'You reached the end of the catalog.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
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
