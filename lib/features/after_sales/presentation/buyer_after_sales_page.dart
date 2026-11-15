import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/after_sales/data/after_sales_service.dart';
import 'package:shophop/features/after_sales/data/after_sales_evidence_selection.dart';
import 'package:shophop/features/after_sales/presentation/widgets/after_sales_evidence_strip.dart';
import 'package:shophop/features/buyer/data/services/buyer_order_service.dart';

class BuyerAfterSalesPage extends StatefulWidget {
  const BuyerAfterSalesPage({super.key, required this.token, this.order});
  final String token;
  final BuyerOrderData? order;
  @override
  State<BuyerAfterSalesPage> createState() => _BuyerAfterSalesPageState();
}

class _BuyerAfterSalesPageState extends State<BuyerAfterSalesPage> {
  List<Map<String, dynamic>> _cases = [];
  List<Map<String, dynamic>> _walletTransactions = [];
  int _walletBalanceCents = 0;
  bool _walletAvailable = false;
  String? _walletError;
  int? _walletNextPage;
  bool _loadingMoreWallet = false;
  int? _itemId;
  int _quantity = 1;
  List<PlatformFile> _evidence = [];
  final Map<int, int> _submittedQuantityByItem = {};
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _canRequestForOrder {
    final order = widget.order;
    if (order == null || !order.canRequestReturn) return false;
    final deadline = DateTime.tryParse(order.returnDeadlineAt ?? '');
    return deadline != null && !DateTime.now().isAfter(deadline);
  }

  int _remaining(BuyerOrderItemData item) {
    final available =
        item.availableReturnQuantity - (_submittedQuantityByItem[item.id] ?? 0);
    return available > 0 ? available : 0;
  }

  List<BuyerOrderItemData> get _requestableItems =>
      widget.order?.items.where((item) => _remaining(item) > 0).toList() ?? [];

  String _deadlineLabel(String? raw) {
    final parsed = DateTime.tryParse(raw ?? '');
    if (parsed == null) return 'Unavailable';
    final at = parsed.toUtc().add(const Duration(hours: 8));
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    return '${months[at.month - 1]} ${at.day}, ${at.year} $hour:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'AM' : 'PM'} PHT';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await AfterSalesService.list(widget.token, 'buyer');
    final walletResult = await AfterSalesService.wallet(widget.token);
    if (!mounted) return;
    final rows = result.data['cases'];
    final walletRows = walletResult.data['transactions'];
    setState(() {
      _cases = rows is List
          ? rows
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList()
          : [];
      _error = result.success ? null : result.message;
      if (walletResult.success) {
        _walletAvailable = true;
        _walletError = null;
        _walletBalanceCents =
            int.tryParse('${walletResult.data['balance_cents']}') ?? 0;
        _walletTransactions = walletRows is List
            ? walletRows
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
            : [];
        _walletNextPage = int.tryParse('${walletResult.data['next_page']}');
      } else {
        _walletAvailable = false;
        _walletError = walletResult.message;
      }
    });
  }

  Future<void> _loadMoreWallet() async {
    final page = _walletNextPage;
    if (page == null || _loadingMoreWallet) return;
    setState(() => _loadingMoreWallet = true);
    final result = await AfterSalesService.wallet(widget.token, page: page);
    if (!mounted) return;
    setState(() {
      _loadingMoreWallet = false;
      if (!result.success) {
        _walletError = result.message;
        return;
      }
      final rows = result.data['transactions'];
      if (rows is List) {
        _walletTransactions.addAll(
          rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)),
        );
      }
      _walletNextPage = int.tryParse('${result.data['next_page']}');
    });
  }

  Future<void> _pickEvidence() async {
    final selected = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: AfterSalesEvidenceSelection.extensions,
      allowMultiple: true,
      withData: true,
    );
    if (selected == null || !mounted) return;
    final files = [..._evidence, ...selected.files];
    final error = AfterSalesEvidenceSelection.validate(files);
    setState(() {
      _error = error;
      if (error == null) _evidence = files;
    });
  }

  Future<void> _submit() async {
    final order = widget.order;
    if (order == null ||
        !_canRequestForOrder ||
        _itemId == null ||
        !_requestableItems.any(
          (item) => item.id == _itemId && _quantity <= _remaining(item),
        ) ||
        _reason.text.trim().length < 10 ||
        _evidence.isEmpty) {
      setState(
        () => _error =
            'Choose an item, describe the problem, and attach a photo or MP4 video.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await AfterSalesService.request(
      widget.token,
      order.id,
      _itemId!,
      _quantity,
      _reason.text.trim(),
      _evidence,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.success) {
      setState(() => _error = result.message);
      return;
    }
    _reason.clear();
    setState(() {
      _submittedQuantityByItem[_itemId!] =
          (_submittedQuantityByItem[_itemId!] ?? 0) + _quantity;
      _itemId = null;
      _quantity = 1;
      _evidence = [];
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Return request submitted.')));
    await _load();
  }

  Future<void> _action(int id, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ask Admin to review?'),
        content: const Text('Admin will review this return request.'),
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
    if (confirmed != true || !mounted) return;
    final result = await AfterSalesService.action(
      widget.token,
      'buyer',
      id,
      action,
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() => _error = result.message);
      return;
    }
    await _load();
  }

  bool _canAppeal(Map<String, dynamic> row) {
    if (row['status'] == 'rejected') return true;
    if (row['status'] != 'seller_review') return false;
    final due = DateTime.tryParse('${row['seller_response_due_at'] ?? ''}');
    return due != null && due.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Returns & Refunds')),
    backgroundColor: AppColors.page,
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_walletAvailable)
            Card(
              color: AppColors.navy,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Wallet · Refund balance',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '₱${(_walletBalanceCents / 100).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Verified refunds appear here. Checkout remains COD only.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          if (_walletAvailable)
            Card(
              child: ExpansionTile(
                title: const Text('Wallet transaction history'),
                children: _walletTransactions.isEmpty
                    ? [const ListTile(title: Text('No verified refunds yet.'))]
                    : [
                        for (final transaction in _walletTransactions)
                          ListTile(
                            dense: true,
                            title: Text('Return #${transaction['case_id']}'),
                            trailing: Text(
                              '+₱${((int.tryParse('${transaction['amount_cents']}') ?? 0) / 100).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        if (_walletNextPage != null)
                          TextButton(
                            onPressed: _loadingMoreWallet
                                ? null
                                : _loadMoreWallet,
                            child: Text(
                              _loadingMoreWallet ? 'Loading…' : 'Load more',
                            ),
                          ),
                      ],
              ),
            ),
          if (!_walletAvailable && _walletError != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Refund wallet unavailable'),
                subtitle: Text(_walletError!),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (widget.order != null &&
              _canRequestForOrder &&
              _requestableItems.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request for ${widget.order!.displayId}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Return by ${_deadlineLabel(widget.order!.returnDeadlineAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const Text(
                      'Receipt confirmation does not remove this return option.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    DropdownButtonFormField<int>(
                      style: Theme.of(context).textTheme.bodyMedium,
                      isExpanded: true,
                      initialValue: _itemId,
                      decoration: const InputDecoration(
                        labelText: 'Purchased item',
                      ),
                      items: _requestableItems
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                '${item.name} · ${item.variant} (${_remaining(item)} left)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _itemId = value;
                        _quantity = 1;
                      }),
                    ),
                    if (_itemId != null)
                      DropdownButtonFormField<int>(
                        style: Theme.of(context).textTheme.bodyMedium,
                        initialValue: _quantity,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                        items: List.generate(
                          _requestableItems
                                  .firstWhere((item) => item.id == _itemId)
                                  .availableReturnQuantity -
                              (_submittedQuantityByItem[_itemId] ?? 0),
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text('${index + 1}'),
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _quantity = value ?? 1),
                      ),
                    TextField(
                      controller: _reason,
                      maxLines: 3,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText: 'Describe what happened to the item',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _pickEvidence,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text('Add photo or video (${_evidence.length}/4)'),
                    ),
                    const Text(
                      'JPG, PNG, WebP or MP4 · 5 MB each, 7 MB total · one video maximum',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    for (final file in _evidence)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          AfterSalesEvidenceSelection.isVideo(file)
                              ? Icons.videocam_outlined
                              : Icons.image_outlined,
                        ),
                        title: Text(file.name, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${(file.size / 1024 / 1024).toStringAsFixed(1)} MB',
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove evidence',
                          onPressed: _busy
                              ? null
                              : () => setState(() => _evidence.remove(file)),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy ? 'Submitting…' : 'Submit return request',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.order != null &&
              (!_canRequestForOrder || _requestableItems.isEmpty))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _canRequestForOrder
                      ? 'All purchased units already have return requests. You can track them below.'
                      : 'The 7-day return window has ended. You can still view existing requests below.',
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Your return cases',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          if (_cases.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No return requests yet.'),
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
                    Text(
                      '${row['variant'] ?? 'Standard'} · Qty ${row['quantity']}',
                    ),
                    Text('${row['status']}'.replaceAll('_', ' ')),
                    AfterSalesEvidenceStrip(
                      token: widget.token,
                      caseId: row['id'] as int,
                      evidence: row['buyer_evidence'],
                    ),
                    if (row['tracking_code'] != null)
                      Text('Tracking: ${row['tracking_code']}'),
                    if (row['seller_note'] != null &&
                        '${row['seller_note']}'.isNotEmpty)
                      Text('Seller: ${row['seller_note']}'),
                    if (row['refund_status'] == 'denied')
                      Text(
                        'Admin declined appeal: ${row['resolution_note'] ?? ''}',
                        style: const TextStyle(color: Colors.red),
                      )
                    else if (row['refund_status'] != 'not_approved')
                      Text(
                        'Refund: ${row['refund_status'].toString().replaceAll('_', ' ')} · ₱${row['refund_amount']} · ${row['responsible_party']}',
                      ),
                    if (_canAppeal(row))
                      TextButton(
                        onPressed: () => _action(row['id'] as int, 'appeal'),
                        child: const Text('Ask Admin to review'),
                      ),
                    if (row['status'] == 'funding_submitted' ||
                        row['status'] == 'payment_sent')
                      const Text(
                        'Funding proof submitted. Admin verification is required before wallet credit.',
                      ),
                    if (row['refund_status'] == 'paid')
                      const Text('Refund credited to My Wallet.'),
                    if (row['events'] is List)
                      for (final event in row['events'] as List)
                        if (event is Map)
                          Text(
                            '• ${event['event']}'.replaceAll('_', ' '),
                            style: const TextStyle(fontSize: 12),
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
