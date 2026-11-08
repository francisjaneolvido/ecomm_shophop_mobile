import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/rider/data/services/rider_management_service.dart';

class RiderWorkSelection {
  const RiderWorkSelection({this.branchId, this.coverage = const []});
  final int? branchId;
  final List<String> coverage;
}

class RiderWorkPreferences extends StatefulWidget {
  const RiderWorkPreferences({
    super.key,
    required this.companyId,
    required this.value,
    required this.onChanged,
  });
  final int companyId;
  final RiderWorkSelection value;
  final ValueChanged<RiderWorkSelection> onChanged;
  @override
  State<RiderWorkPreferences> createState() => _RiderWorkPreferencesState();
}

class _RiderWorkPreferencesState extends State<RiderWorkPreferences> {
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _coverage = [];
  bool _busy = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load(widget.value.branchId);
  }

  Future<void> _load(int? branchId) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _coverage = [];
    });
    final result = await RiderManagementService.options(
      companyId: widget.companyId,
      branchId: branchId,
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _busy = false;
      if (result.success) {
        _branches = RiderManagementService.rows(result.data['branches']);
        _coverage = RiderManagementService.rows(result.data['coverage']);
      } else {
        _error = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) => FormField<RiderWorkSelection>(
    initialValue: widget.value,
    validator: (value) => value?.branchId == null
        ? 'Choose a preferred Branch.'
        : value!.coverage.isEmpty
        ? 'Choose at least one preferred barangay.'
        : null,
    builder: (field) {
      final value = field.value ?? const RiderWorkSelection();
      void change(RiderWorkSelection next) {
        field.didChange(next);
        widget.onChanged(next);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preferred work area',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Choose your preferred Branch and nearby barangays. Every rider handles both pickup and delivery. Main Hub confirms your Branch; the Branch confirms official coverage.',
            style: TextStyle(fontSize: 11, color: AppColors.navy, height: 1.5),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _branches.any((b) => b['id'] == value.branchId)
                ? value.branchId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Preferred Branch',
              border: OutlineInputBorder(),
            ),
            items: _branches
                .map(
                  (b) => DropdownMenuItem<int>(
                    value: int.parse(b['id'].toString()),
                    child: Text(
                      b['name'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (id) {
                    change(RiderWorkSelection(branchId: id));
                    _load(id);
                  },
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () => _load(value.branchId),
                  child: const Text('Retry'),
                ),
              ],
            ),
          if (!_busy &&
              value.branchId != null &&
              _coverage.isEmpty &&
              _error == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'This Branch has no available pickup and delivery service area. Choose another Branch.',
              ),
            ),
          if (_coverage.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${value.coverage.length} preferred barangay(s)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 230),
              child: ListView(
                shrinkWrap: true,
                primary: false,
                children: _coverage.map((p) {
                  final key = p['key'].toString();
                  final count = p['active_count'];
                  final limit = p['limit'];
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.tealDark,
                    title: Text(
                      p['label'].toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: count == null
                        ? null
                        : Text(
                            '$count / $limit active riders${(count as num) >= (limit as num) ? ' - Main Hub override required for activation' : ''}',
                            style: const TextStyle(fontSize: 10),
                          ),
                    value: value.coverage.contains(key),
                    onChanged: (checked) {
                      final keys = {...value.coverage};
                      if (checked == true) {
                        keys.add(key);
                      } else {
                        keys.remove(key);
                      }
                      change(
                        RiderWorkSelection(
                          branchId: value.branchId,
                          coverage: keys.toList(),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
            const Text(
              'A full barangay does not prevent your application. Activation requires capacity or an approved Main Hub override.',
              style: TextStyle(fontSize: 10, color: AppColors.navy),
            ),
          ],
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                field.errorText!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
        ],
      );
    },
  );
}
