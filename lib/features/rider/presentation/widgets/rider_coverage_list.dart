import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';

/// Group long barangay labels by city/province rather than repeating their suffix.
class RiderCoverageList extends StatefulWidget {
  const RiderCoverageList({
    super.key,
    required this.areas,
    this.title = 'Service areas',
  });
  final List<String> areas;
  final String title;
  @override
  State<RiderCoverageList> createState() => _RiderCoverageListState();
}

class _RiderCoverageListState extends State<RiderCoverageList> {
  String _query = '';
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final filtered =
        widget.areas
            .toSet()
            .where((area) => area.toLowerCase().contains(_query.toLowerCase()))
            .toList()
          ..sort();
    final shown = _expanded || _query.isNotEmpty
        ? filtered
        : filtered.take(4).toList();
    final groups = <String, List<String>>{};
    for (final area in shown) {
      final parts = area.split(',').map((s) => s.trim()).toList();
      final location = parts.length >= 3
          ? parts.sublist(parts.length - 2).join(', ')
          : '';
      final name = parts.length >= 3
          ? parts.sublist(0, parts.length - 2).join(', ')
          : area;
      groups.putIfAbsent(location, () => []).add(name);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.map_outlined, size: 18, color: AppColors.pink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${widget.title} (${widget.areas.toSet().length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (widget.areas.length > 6)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search barangay or city',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No matching service areas.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        for (final group in groups.entries) ...[
          if (group.key.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(
                group.key,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          for (final area in group.value)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.pink,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      area,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (filtered.length > 4 && _query.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(foregroundColor: AppColors.pink),
              child: Text(
                _expanded ? 'Show fewer' : 'View all ${filtered.length} areas',
              ),
            ),
          ),
      ],
    );
  }
}
