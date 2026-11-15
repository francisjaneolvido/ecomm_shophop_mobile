import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shophop/features/after_sales/presentation/widgets/after_sales_evidence_strip.dart';
import 'package:shophop/features/after_sales/data/after_sales_service.dart';

class SellerAfterSalesScreen extends StatefulWidget {
  const SellerAfterSalesScreen({super.key, required this.token});
  final String token;
  @override
  State<SellerAfterSalesScreen> createState() => _SellerAfterSalesScreenState();
}

class _SellerAfterSalesScreenState extends State<SellerAfterSalesScreen> {
  List<Map<String, dynamic>> _cases = [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await AfterSalesService.list(widget.token, 'seller');
    if (!mounted) return;
    final rows = result.data['cases'];
    setState(() {
      _cases = rows is List
          ? rows
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList()
          : [];
      _error = result.success ? null : result.message;
    });
  }

  Future<void> _review(int id, String decision) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${decision == 'approved' ? 'Approve' : 'Reject'} return?'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: decision == 'approved'
                ? 'Optional note'
                : 'Rejection reason (required)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      controller.dispose();
      return;
    }
    final note = controller.text.trim();
    controller.dispose();
    if (decision == 'rejected' && note.isEmpty) {
      setState(() => _error = 'Enter a reason before rejecting.');
      return;
    }
    setState(() => _busy = true);
    final result = await AfterSalesService.action(
      widget.token,
      'seller',
      id,
      'decision',
      {'decision': decision, 'note': note},
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.success ? null : result.message;
    });
    if (result.success) await _load();
  }

  Future<void> _inspect(int id, int requestedQuantity) async {
    final controller = TextEditingController();
    final quantityController = TextEditingController(
      text: '$requestedQuantity',
    );
    String condition = 'damaged';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm parcel received'),
        content: StatefulBuilder(
          builder: (context, update) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                style: Theme.of(context).textTheme.bodyMedium,
                initialValue: condition,
                decoration: const InputDecoration(labelText: 'Condition'),
                items: const [
                  DropdownMenuItem(value: 'intact', child: Text('Intact')),
                  DropdownMenuItem(value: 'damaged', child: Text('Damaged')),
                  DropdownMenuItem(
                    value: 'wrong_item',
                    child: Text('Wrong item'),
                  ),
                  DropdownMenuItem(
                    value: 'missing',
                    child: Text('Missing item'),
                  ),
                ],
                onChanged: (value) =>
                    update(() => condition = value ?? 'damaged'),
              ),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity received',
                ),
              ),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Inspection note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      controller.dispose();
      quantityController.dispose();
      return;
    }
    final note = controller.text.trim();
    final quantity = int.tryParse(quantityController.text.trim());
    controller.dispose();
    quantityController.dispose();
    if (note.length < 5 ||
        quantity == null ||
        quantity < 0 ||
        quantity > requestedQuantity) {
      setState(() => _error = 'Enter a note and valid received quantity.');
      return;
    }
    final selected = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (selected == null || selected.files.isEmpty || !mounted) {
      if (mounted) {
        setState(() => _error = 'Add at least one inspection photo.');
      }
      return;
    }
    setState(() => _busy = true);
    final result = await AfterSalesService.sellerInspect(
      widget.token,
      id,
      note,
      condition,
      quantity,
      selected.files.take(4).toList(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.success ? null : result.message;
    });
    if (result.success) await _load();
  }

  Future<void> _payment(int id) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit refund funding proof'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Funding reference'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      controller.dispose();
      return;
    }
    final reference = controller.text.trim();
    controller.dispose();
    if (reference.length < 4) {
      setState(() => _error = 'Enter a payment reference.');
      return;
    }
    final selected = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (selected == null || selected.files.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final result = await AfterSalesService.sellerPayment(
      widget.token,
      id,
      reference,
      selected.files.first,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.success ? null : result.message;
    });
    if (result.success) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Buyer Returns')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_cases.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No buyer return requests yet.'),
            ),
          for (final row in _cases)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Return #${row['id']} · ${row['item_name']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Order #${row['order_id']} · Qty ${row['quantity']}'),
                    Text('${row['status']}'.replaceAll('_', ' ')),
                    Text('Buyer: ${row['reason']}'),
                    AfterSalesEvidenceStrip(
                      token: widget.token,
                      caseId: row['id'] as int,
                      evidence: row['buyer_evidence'],
                    ),
                    if (row['seller_note'] != null)
                      Text('Seller: ${row['seller_note']}'),
                    if (row['status'] == 'seller_review')
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _review(row['id'] as int, 'approved'),
                            child: const Text('Approve'),
                          ),
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _review(row['id'] as int, 'rejected'),
                            child: const Text('Reject'),
                          ),
                        ],
                      ),
                    if (row['can_seller_inspect'] == true)
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _inspect(
                                row['id'] as int,
                                row['quantity'] as int,
                              ),
                        child: const Text('Confirm receipt & inspect'),
                      ),
                    if (row['status'] == 'refund_approved' &&
                        row['responsible_party'] == 'seller')
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _payment(row['id'] as int),
                        child: Text('Submit funding ₱${row['refund_amount']}'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
