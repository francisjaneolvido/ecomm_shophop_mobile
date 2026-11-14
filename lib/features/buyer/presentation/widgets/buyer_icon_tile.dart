import 'package:flutter/material.dart';

/// Shared icon treatment used by category, account and settings shortcuts.
class BuyerIconTile extends StatelessWidget {
  const BuyerIconTile({
    super.key,
    required this.icon,
    this.dimension = 44,
    this.iconSize = 24,
  });
  final IconData icon;
  final double dimension, iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: dimension,
    height: dimension,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Icon(
      icon,
      size: iconSize,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}
