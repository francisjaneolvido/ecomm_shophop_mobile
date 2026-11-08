import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_category_icon.dart';
import 'package:shophop/shared/realtime/foreground_refresh.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';

class BuyerCategoriesPage extends StatefulWidget {
  const BuyerCategoriesPage({
    super.key,
    required this.token,
    required this.onSessionExpired,
    required this.onOpenCategory,
  });
  final String token;
  final Future<void> Function() onSessionExpired;
  final void Function(BuyerCategoryData category, String? subcategory)
  onOpenCategory;
  @override
  State<BuyerCategoriesPage> createState() => _BuyerCategoriesPageState();
}

class _BuyerCategoriesPageState extends State<BuyerCategoriesPage> {
  List<BuyerCategoryData> _categories = [];
  String _query = '';
  BuyerCatalogException? _error;
  bool _loading = true;
  bool _busy = false;
  late final ForegroundRefresh _live;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _live = ForegroundRefresh(
      refresh: () => _load(silent: true),
      canRefresh: () =>
          mounted && !_busy && (ModalRoute.of(context)?.isCurrent ?? true),
    );
  }

  @override
  void dispose() {
    _live.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_busy) return;
    _busy = true;
    try {
      final categories = await BuyerCatalogService.getCategories(
        token: widget.token,
      );
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
        _error = null;
      });
    } on BuyerCatalogException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = error;
      });
      if (error.isUnauthorized) await widget.onSessionExpired();
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final categories = _categories
        .where(
          (category) => '${category.name} ${category.subcategories.join(' ')}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('All Categories')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Browse Categories',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Explore all ${_categories.length} ShopHop departments.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _search,
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                      decoration: InputDecoration(
                        hintText: 'Find a category or subcategory',
                        prefixIcon: const Icon(CupertinoIcons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear category search',
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(CupertinoIcons.xmark),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _categories.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ShopHopEmptyState(
                    icon: CupertinoIcons.wifi_exclamationmark,
                    title: 'Unable to load categories',
                    description: _error!.message,
                    actionLabel: 'Try again',
                    onAction: _load,
                  ),
                ),
              )
            else if (categories.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ShopHopEmptyState(
                    icon: CupertinoIcons.search,
                    title: 'No matching categories',
                    description: 'Try another category or subcategory name.',
                    actionLabel: 'Show all categories',
                    onAction: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return ShopHopSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => widget.onOpenCategory(category, null),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: colors.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      buyerCategoryIcon(category.icon),
                                      color: colors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category.name,
                                          style: theme.textTheme.titleSmall,
                                        ),
                                        Text(
                                          '${category.productCount} available product${category.productCount == 1 ? '' : 's'}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colors.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    CupertinoIcons.chevron_right,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (category.subcategories.isNotEmpty) ...[
                            const Divider(height: 24),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                for (final subcategory
                                    in category.subcategories)
                                  ActionChip(
                                    label: Text(subcategory),
                                    onPressed: () => widget.onOpenCategory(
                                      category,
                                      subcategory,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
