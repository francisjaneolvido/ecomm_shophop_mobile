import 'package:flutter/material.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/rider/data/models/rider_cod_overview.dart';
import 'package:shophop/features/rider/data/services/rider_delivery_service.dart';

class RiderCodRemittanceScreen extends StatefulWidget {
  const RiderCodRemittanceScreen({super.key});

  @override
  State<RiderCodRemittanceScreen> createState() =>
      _RiderCodRemittanceScreenState();
}

class _RiderCodRemittanceScreenState extends State<RiderCodRemittanceScreen> {
  bool _busy = true;
  bool _submitting = false;
  String? _error;
  String? _token;
  RiderCodOverview _overview = RiderCodOverview.fromJson({});
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final session = await AuthSessionService.readSession();
    if (!mounted) return;
    if (session == null || session.accountType != 'rider') {
      setState(() {
        _busy = false;
        _error = 'Rider login required.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _token = session.token;
    });
    final response = await RiderDeliveryService.codCollections(
      token: session.token,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (response.success) {
        _overview = RiderCodOverview.fromJson(response.data);
        _selected.clear();
      } else {
        _error = response.message;
      }
    });
  }

  Future<void> _handover() async {
    if (_submitting || _token == null || _selected.isEmpty) return;
    final rows = _overview.collections
        .where((row) => _selected.contains(row['collection_id']))
        .toList();
    final controllers = [
      for (final row in rows)
        TextEditingController(text: '${row['outstanding']}'),
    ];
    final reference = TextEditingController();
    int? facility;
    String? validation;
    final dialog = DialogRoute<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Record physical cash handover'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the actual cash handed over. Your full collected COD remains owed until independently verified. Earnings do not reduce it.',
                ),
                DropdownButtonFormField<int>(
                  initialValue: facility,
                  decoration: const InputDecoration(
                    labelText: 'Receiving facility',
                  ),
                  items: _overview.facilities
                      .map(
                        (row) => DropdownMenuItem<int>(
                          value: int.tryParse('${row['id']}'),
                          child: Text('${row['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => facility = value,
                ),
                TextField(
                  controller: reference,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Receipt / evidence reference',
                  ),
                ),
                for (int i = 0; i < rows.length; i++)
                  TextField(
                    controller: controllers[i],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          'Order #${rows[i]['order_id']} cash handed over',
                    ),
                  ),
                if (validation != null)
                  Text(validation!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (facility == null ||
                    reference.text.trim().length < 4 ||
                    controllers.any(
                      (c) =>
                          !RegExp(
                            r'^\d{1,9}(\.\d{1,2})?$',
                          ).hasMatch(c.text.trim()) ||
                          (num.tryParse(c.text) ?? 0) <= 0,
                    )) {
                  update(
                    () => validation =
                        'Choose a facility, provide a reference, and enter positive cash amounts with at most two decimal places.',
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Submit handover'),
            ),
          ],
        ),
      ),
    );
    final confirmed = await Navigator.of(context).push(dialog);
    final items = [
      for (int i = 0; i < rows.length; i++)
        {
          'collection_id': rows[i]['collection_id'],
          'amount': controllers[i].text.trim(),
        },
    ];
    final evidence = reference.text.trim();
    await dialog.completed;
    reference.dispose();
    for (final controller in controllers) {
      controller.dispose();
    }
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    final response = await RiderDeliveryService.submitCodBatch(
      token: _token!,
      facilityId: facility!,
      idempotencyKey: 'mobile-${DateTime.now().microsecondsSinceEpoch}',
      reference: evidence,
      items: items,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(response.message)));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('COD Cash Handover'),
      actions: [
        IconButton(
          onPressed: _busy || _submitting ? null : _refresh,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _busy
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Remit all collected COD. Your Logistics Partner handles earnings and payroll separately. Cash handover requires the receiving facility to verify the actual amount.',
                    ),
                  ),
                ),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                Text('COD to collect: ?${_overview.toCollect}'),
                Text('Collected: ₱${_overview.collected}'),
                Text('Verified remitted: ₱${_overview.remitted}'),
                Text('Outstanding cash: ₱${_overview.outstanding}'),
                Text('Collections under review: ${_overview.discrepancies}'),
                const SizedBox(height: 16),
                if (_overview.collections.isEmpty)
                  const Text('No COD collections recorded.'),
                ..._overview.collections.map(
                  (cash) => Card(
                    child: CheckboxListTile(
                      value: _selected.contains(cash['collection_id']),
                      onChanged: cash['can_remit'] == true && !_submitting
                          ? (selected) => setState(() {
                              final id = int.tryParse(
                                '${cash['collection_id']}',
                              );
                              if (id != null) {
                                selected == true
                                    ? _selected.add(id)
                                    : _selected.remove(id);
                              }
                            })
                          : null,
                      title: Text('Order #${cash['order_id']}'),
                      subtitle: Text(
                        'Collected ₱${cash['amount']} · Received ₱${cash['received_amount']}\nOutstanding ₱${cash['outstanding']} · ${cash['status']}',
                      ),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _selected.isEmpty || _submitting
                      ? null
                      : _handover,
                  icon: const Icon(Icons.receipt_long),
                  label: Text(
                    _submitting ? 'Submitting…' : 'Hand over selected COD',
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Remittance history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ..._overview.batches.map(
                  (batch) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${batch['reference']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${batch['status']} · Facility ${batch['sorting_center_id']}',
                          ),
                          Text(
                            'Expected ₱${RiderCodOverview.minorDisplay(batch['expected_minor'])}',
                          ),
                          Text(
                            'Submitted ₱${RiderCodOverview.minorDisplay(batch['submitted_minor'])}',
                          ),
                          Text(
                            'Verified ${RiderCodOverview.minorDisplay(batch['verified_minor'])}',
                          ),
                          Text(
                            'Difference ${RiderCodOverview.minorDisplay(batch['difference_minor'])}',
                          ),
                          Text('Reference: ${batch['receipt_reference']}'),
                          Text('Submitted: ${batch['created_at']}'),
                          if (batch['verified_at'] != null)
                            Text('Verified: ${batch['verified_at']}'),
                          for (final item in RiderCodOverview.rows(
                            batch['items'],
                          ))
                            Text(
                              'Collection #${item['cod_settlement_id']} · Cash ₱${RiderCodOverview.minorDisplay(item['submitted_minor'])}',
                            ),
                          if (batch['status'] == 'discrepancy')
                            const Text(
                              'Under review. Shortages remain owed; overages require investigation.',
                              style: TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}
