part of 'buyer_product_card.dart';

class _ProductGridDelegate extends SliverGridDelegate {
  const _ProductGridDelegate({
    required this.columns,
    required this.contentHeight,
    required this.videos,
  });
  final int columns;
  final double contentHeight;
  final List<bool> videos;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    const gap = 12.0;
    final width = (constraints.crossAxisExtent - gap * (columns - 1)) / columns;
    final bottoms = List<double>.filled(columns, 0);
    final geometries = <SliverGridGeometry>[];
    for (final video in videos) {
      var column = 0;
      for (var i = 1; i < columns; i++) {
        if (bottoms[i] < bottoms[column]) column = i;
      }
      final height = width / (video ? .75 : 1) + contentHeight;
      geometries.add(
        SliverGridGeometry(
          scrollOffset: bottoms[column],
          crossAxisOffset:
              (constraints.crossAxisDirection == AxisDirection.left
                  ? columns - 1 - column
                  : column) *
              (width + gap),
          mainAxisExtent: height,
          crossAxisExtent: width,
        ),
      );
      bottoms[column] += height + gap;
    }
    return _ProductGridLayout(geometries);
  }

  @override
  bool shouldRelayout(covariant _ProductGridDelegate oldDelegate) =>
      columns != oldDelegate.columns ||
      contentHeight != oldDelegate.contentHeight ||
      !listEquals(videos, oldDelegate.videos);
}

class _ProductGridLayout extends SliverGridLayout {
  const _ProductGridLayout(this.items);
  final List<SliverGridGeometry> items;

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    for (var i = 0; i < items.length; i++) {
      if (items[i].trailingScrollOffset > scrollOffset) return i;
    }
    return items.isEmpty ? 0 : items.length - 1;
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    for (var i = items.length - 1; i >= 0; i--) {
      if (items[i].scrollOffset < scrollOffset) return i;
    }
    return 0;
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    if (index < items.length) return items[index];
    // Shrink-wrapped grids probe the next index before asking the builder
    // whether that child exists. Provide geometry for that end-of-list probe.
    return SliverGridGeometry(
      scrollOffset: computeMaxScrollOffset(items.length),
      crossAxisOffset: 0,
      mainAxisExtent: 0,
      crossAxisExtent: items.isEmpty ? 0 : items.first.crossAxisExtent,
    );
  }

  @override
  double computeMaxScrollOffset(int childCount) {
    var end = 0.0;
    for (final item in items.take(childCount)) {
      if (item.trailingScrollOffset > end) end = item.trailingScrollOffset;
    }
    return end;
  }
}
