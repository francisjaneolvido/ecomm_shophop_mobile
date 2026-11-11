import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/rider/data/services/rider_batch_service.dart';
import 'package:shophop/shared/realtime/foreground_refresh.dart';

List<Map<String, dynamic>> batchRows(dynamic value) => value is List
    ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
    : [];
String batchLabel(dynamic value) => (value?.toString() ?? '')
    .split('_')
    .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
    .join(' ');

String batchWindow(BuildContext context, Map<String, dynamic> batch) {
  final start = DateTime.tryParse('${batch['scheduled_start']}')?.toLocal();
  final end = DateTime.tryParse('${batch['scheduled_end']}')?.toLocal();
  if (start == null || end == null) return 'Schedule unavailable';
  final local = MaterialLocalizations.of(context);
  return '${local.formatShortDate(start)}, ${local.formatTimeOfDay(TimeOfDay.fromDateTime(start))} - ${local.formatTimeOfDay(TimeOfDay.fromDateTime(end))}';
}

bool pickupAwaitingBranch(Map<String, dynamic> route) =>
    route['type'] == 'pickup' &&
    batchRows(route['items']).any((item) => item['status'] == 'picked_up');

bool pickupCollectionPending(Map<String, dynamic> route) =>
    batchRows(route['items']).any(
      (item) => ['pickup_assigned', 'pickup_accepted'].contains(item['status']),
    );

String pickupBranchInstruction(Map<String, dynamic> route) {
  final branch = route['branch']?.toString().trim();
  final destination = branch == null || branch.isEmpty
      ? 'your assigned branch'
      : branch;
  return 'Bring collected parcels to $destination. Branch staff must scan each parcel to confirm receipt. Do not scan them again as a pickup.';
}

class RiderBatchCard extends StatelessWidget {
  const RiderBatchCard({super.key, required this.batch, required this.onTap});
  final Map<String, dynamic> batch;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final active = batch['status'] == 'in_progress';
    final pickup = batch['type'] == 'pickup';
    final items = batchRows(batch['items']);
    final received = items
        .where((item) => item['status'] == 'received_at_branch')
        .length;
    final collected = items
        .where(
          (item) =>
              ['picked_up', 'received_at_branch'].contains(item['status']),
        )
        .length;
    final failed = items
        .where((item) => item['status'] == 'pickup_failed')
        .length;
    final returning =
        active &&
        pickupAwaitingBranch(batch) &&
        !pickupCollectionPending(batch);
    final progress = batch['progress'] is Map
        ? batch['progress'] as Map
        : const {};
    final total = (progress['total'] as num?)?.toInt() ?? 0;
    final done = (progress['settled'] as num?)?.toInt() ?? 0;
    final capacity = batch['capacity'] is Map
        ? batch['capacity'] as Map
        : const {};
    final totals = capacity['totals'] is Map
        ? capacity['totals'] as Map
        : const {};
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    batch['type'] == 'pickup'
                        ? Icons.inventory_2_outlined
                        : Icons.local_shipping_outlined,
                    color: AppColors.tealDark,
                    size: 22,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      returning
                          ? 'Return to branch'
                          : '${batchLabel(batch['type'])} route',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    active ? 'Active' : batchLabel(batch['status']),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.tealDark,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 19,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${batch['code'] ?? ''}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                batchWindow(context, batch),
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 8),
              Text(
                pickup
                    ? '$collected/$total collected \u2022 $received/$total received at branch'
                    : '$done/$total deliveries resolved \u2022 ${totals['stops'] ?? 0} stops',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: total == 0
                    ? 0
                    : (pickup
                              ? (collected + received + failed * 2) /
                                    (total * 2)
                              : done / total)
                          .clamp(0, 1),
                minHeight: 4,
                color: AppColors.tealDark,
                backgroundColor: AppColors.tealLight,
                borderRadius: BorderRadius.circular(4),
              ),
              if (pickup && failed > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '$failed could not be collected',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              if (active && pickupAwaitingBranch(batch)) ...[
                const SizedBox(height: 10),
                Text(
                  pickupBranchInstruction(batch),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.tealDark,
                  ),
                ),
                if (pickupCollectionPending(batch))
                  const Text(
                    'Other seller pickups are still pending on this route.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
              ],
              if (active && done == total && total > 0) ...[
                const SizedBox(height: 8),
                const Text(
                  'All outcomes resolved. Branch can complete this route.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class RiderBatchDetailScreen extends StatefulWidget {
  const RiderBatchDetailScreen({
    super.key,
    required this.token,
    required this.initial,
  });
  final String token;
  final Map<String, dynamic> initial;
  @override
  State<RiderBatchDetailScreen> createState() => _RiderBatchDetailScreenState();
}

class _RiderBatchDetailScreenState extends State<RiderBatchDetailScreen> {
  late Map<String, dynamic> _batch;
  late final ForegroundRefresh _refresh;
  bool _loading = false;
  bool _mutating = false;
  String? _error;
  int get _id => int.parse('${_batch['id']}');
  bool get _active => _batch['status'] == 'in_progress';
  @override
  void initState() {
    super.initState();
    _batch = widget.initial;
    _refresh = ForegroundRefresh(
      refresh: _load,
      canRefresh: () =>
          mounted &&
          !_loading &&
          !_mutating &&
          (ModalRoute.of(context)?.isCurrent ?? false),
    );
    _load();
  }

  @override
  void dispose() {
    _refresh.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _mutating) return;
    setState(() => _loading = true);
    final result = await RiderBatchService.show(widget.token, _id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.success ? null : result.message;
      if (result.success && result.data['batch'] is Map) {
        _batch = Map<String, dynamic>.from(result.data['batch']);
      }
    });
  }

  Future<void> _failed(Map<String, dynamic> item) async {
    setState(() => _mutating = true);
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text(
          'Unsuccessful pickup',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Explain why this parcel could not be collected.',
            ),
            validator: (v) => v == null || v.trim().length < 3
                ? 'Enter a reason (at least 3 characters).'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialog, controller.text.trim());
              }
            },
            child: const Text('Save outcome'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (!mounted) return;
    if (reason == null) {
      setState(() => _mutating = false);
      return;
    }
    final result = await RiderBatchService.pickupFailure(
      widget.token,
      _id,
      int.parse('${item['id']}'),
      reason,
    );
    if (!mounted) return;
    setState(() {
      _mutating = false;
      _error = result.success ? null : result.message;
      if (result.success && result.data['batch'] is Map) {
        _batch = Map<String, dynamic>.from(result.data['batch']);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = batchRows(_batch['items']);
    final stops = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      (stops['${item['stop_sequence']}'] ??= []).add(item);
    }
    final capacity = _batch['capacity'] is Map
        ? _batch['capacity'] as Map
        : const {};
    final totals = capacity['totals'] is Map
        ? capacity['totals'] as Map
        : const {};
    return Scaffold(
      backgroundColor: AppColors.grayBg,
      appBar: AppBar(
        title: Text(
          '${batchLabel(_batch['type'])} route',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.tealDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh route',
            onPressed: _loading || _mutating ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            RiderBatchCard(batch: _batch, onTap: () {}),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _batch['status'] == 'queued'
                    ? 'Waiting for Branch dispatch. Parcels cannot be collected before this route is activated.'
                    : _active
                    ? _batch['type'] == 'pickup'
                          ? 'Scan at the seller to collect each parcel. Then bring it to your assigned branch, where branch staff scan it as received.'
                          : 'Collect parcels from the branch, deliver to each buyer, and record the delivery outcome.'
                    : 'This route is closed. Individual parcel outcomes are preserved.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Text(
              '${_batch['branch'] ?? 'Assigned branch'} \u2022 ${totals['weight_kg'] ?? 0} kg ? ${totals['volume_m3'] ?? 0} m\u00b3 ? ${totals['minutes'] ?? 0} min',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            for (final entry in stops.entries) _stop(entry.key, entry.value),
          ],
        ),
      ),
      bottomNavigationBar:
          _active &&
              (_batch['type'] != 'pickup' || pickupCollectionPending(_batch))
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: FilledButton.icon(
                  onPressed: _mutating || _loading
                      ? null
                      : () => Navigator.pop(context, 'scan'),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan parcel QR'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _stop(String sequence, List<Map<String, dynamic>> items) {
    final stop = items.first['stop'] is Map
        ? items.first['stop'] as Map
        : const {};
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.tealLight,
                  child: Text(
                    sequence,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.tealDark,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stop['name'] ?? 'Route stop'}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${stop['address'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (stop['phone'] != null)
                        SelectableText(
                          '${stop['phone']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.tealDark,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            for (final item in items) ...[
              const Divider(height: 20),
              Text(
                '${item['tracking_code'] ?? 'Parcel'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item['status'] == 'picked_up' && _batch['type'] == 'pickup'
                    ? 'Collected - awaiting branch receipt'
                    : batchLabel(item['status']),
                style: TextStyle(
                  fontSize: 11,
                  color: item['settled'] == true
                      ? AppColors.tealDark
                      : AppColors.textMuted,
                ),
              ),
              if (item['cod_amount'] != null)
                Text(
                  'COD \u20b1${(num.tryParse('${item['cod_amount']}') ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (_active &&
                  _batch['type'] == 'pickup' &&
                  item['status'] == 'picked_up')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    pickupBranchInstruction(_batch),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.tealDark,
                    ),
                  ),
                ),
              if (item['requires_branch_return'] == true)
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Text(
                    'Return this parcel for Branch QR receipt.',
                    style: TextStyle(fontSize: 11, color: AppColors.error),
                  ),
                ),
              if (item['reason'] != null)
                Text(
                  '${item['reason']}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              if (_active &&
                  item['settled'] != true &&
                  !(_batch['type'] == 'pickup' &&
                      item['status'] == 'picked_up'))
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _loading || _mutating
                          ? null
                          : () => Navigator.pop(
                              context,
                              'parcel:${item['delivery_id']}',
                            ),
                      child: const Text('Parcel actions'),
                    ),
                    if (_batch['type'] == 'pickup' &&
                        [
                          'pickup_assigned',
                          'pickup_accepted',
                        ].contains(item['status']))
                      TextButton(
                        onPressed: _mutating || _loading
                            ? null
                            : () => _failed(item),
                        child: const Text('Could not collect'),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class RiderBatchHistoryScreen extends StatefulWidget {
  const RiderBatchHistoryScreen({super.key, required this.token});
  final String token;
  @override
  State<RiderBatchHistoryScreen> createState() =>
      _RiderBatchHistoryScreenState();
}

class _RiderBatchHistoryScreenState extends State<RiderBatchHistoryScreen> {
  final _items = <Map<String, dynamic>>[];
  int _pages = 1;
  bool _more = false, _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    final result = await RiderBatchService.batches(
      widget.token,
      pages: _pages,
      history: true,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.success ? null : result.message;
      if (result.success) {
        _items
          ..clear()
          ..addAll(batchRows(result.data['batches']));
        _more = result.data['next_page'] != null;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Route history'),
      backgroundColor: AppColors.tealDark,
      foregroundColor: Colors.white,
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          if (!_loading && _items.isEmpty) const Text('No closed routes yet.'),
          for (final batch in _items)
            RiderBatchCard(
              batch: batch,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RiderBatchDetailScreen(
                    token: widget.token,
                    initial: batch,
                  ),
                ),
              ),
            ),
          if (_more)
            TextButton(
              onPressed: _loading
                  ? null
                  : () {
                      _pages++;
                      _load();
                    },
              child: const Text('Load more routes'),
            ),
        ],
      ),
    ),
  );
}
