import 'package:flutter/material.dart';

/// Payment records are already included in earnings totals. This only acknowledges receipt.
class PersonnelPayrollReceipts extends StatefulWidget {
  const PersonnelPayrollReceipts({
    super.key,
    required this.receipts,
    required this.onConfirm,
  });

  final List<Map<String, dynamic>> receipts;
  final Future<String?> Function(int batchId) onConfirm;

  @override
  State<PersonnelPayrollReceipts> createState() =>
      _PersonnelPayrollReceiptsState();
}

class _PersonnelPayrollReceiptsState extends State<PersonnelPayrollReceipts> {
  int? _submitting;

  Future<void> _confirm(Map<String, dynamic> receipt) async {
    final id = int.tryParse('${receipt['id']}');
    if (id == null || _submitting != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm payroll received?'),
        content: Text(
          'Confirm only if you actually received ₱${receipt['amount']} from Logistics.\n\nPayment reference: ${receipt['payment_reference']}\n\nThis acknowledges receipt and does not add money to your earnings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I received it'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = id);
    String? error;
    try {
      error = await widget.onConfirm(id);
    } catch (_) {
      error = 'Unable to confirm. Refresh and try again.';
    }
    if (!mounted) return;
    setState(() => _submitting = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Payroll receipt confirmed.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.receipts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            'Payroll receipts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        const Text(
          'Your company recorded these payments. Confirm each one after receiving the actual funds.',
        ),
        ...widget.receipts.map((receipt) {
          final received = receipt['received_at'] != null;
          final amount = double.tryParse('${receipt['amount']}') ?? 0;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₱${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text('${receipt['reference']}'),
                  Text('Payment ref: ${receipt['payment_reference']}'),
                  const SizedBox(height: 8),
                  if (received)
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 6),
                        Expanded(child: Text('Receipt confirmed')),
                      ],
                    )
                  else
                    FilledButton.icon(
                      onPressed: _submitting != null
                          ? null
                          : () => _confirm(receipt),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(
                        _submitting == receipt['id']
                            ? 'Confirming…'
                            : 'Confirm funds received',
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
