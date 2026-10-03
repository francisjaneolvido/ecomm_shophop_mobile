import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../services/buyer_checkout_service.dart';
import '../../../theme/app_colors.dart';

class BuyerPaymentProofPage extends StatefulWidget {
  const BuyerPaymentProofPage({
    super.key,
    required this.token,
    required this.paymentId,
    required this.onSessionExpired,
    required this.onGoToOrders,
  });

  final String token;
  final int paymentId;
  final Future<void> Function() onSessionExpired;
  final VoidCallback onGoToOrders;

  @override
  State<BuyerPaymentProofPage> createState() => _BuyerPaymentProofPageState();
}

class _BuyerPaymentProofPageState extends State<BuyerPaymentProofPage> {
  final TextEditingController _referenceController = TextEditingController();

  BuyerPaymentData? _payment;
  BuyerCheckoutException? _error;
  bool _loading = true;
  bool _submitting = false;
  bool _cancelling = false;
  List<int>? _receiptBytes;
  String _receiptName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _payment == null;
      _error = null;
    });

    try {
      final payment = await BuyerCheckoutService.getPayment(
        token: widget.token,
        paymentId: widget.paymentId,
      );
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _loading = false;
        _error = null;
        if (_referenceController.text.trim().isEmpty &&
            payment.reference.isNotEmpty) {
          _referenceController.text = payment.reference;
        }
      });
    } on BuyerCheckoutException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        setState(() => _loading = false);
        await widget.onSessionExpired();
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _showMessage('ShopHop could not read that receipt file.');
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      _showMessage('Receipt image must be 5 MiB or smaller.');
      return;
    }

    setState(() {
      _receiptBytes = bytes;
      _receiptName = file.name;
    });
  }

  Future<void> _submit() async {
    final payment = _payment;
    if (payment == null || !payment.canSubmit || _submitting) return;

    final reference = _referenceController.text.trim();
    if (reference.isEmpty) {
      _showMessage('Enter the payment reference from your receipt.');
      return;
    }
    if (_receiptBytes == null || _receiptName.isEmpty) {
      _showMessage('Select a receipt image first.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await BuyerCheckoutService.submitPaymentProof(
        token: widget.token,
        paymentId: widget.paymentId,
        reference: reference,
        receiptBytes: _receiptBytes!,
        receiptFileName: _receiptName,
      );
      if (!mounted) return;
      setState(() {
        _receiptBytes = null;
        _receiptName = '';
      });
      _showMessage('Payment proof submitted for ShopHop Admin review.');
      await _load();
    } on BuyerCheckoutException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return;
      }
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancelPayment() async {
    final payment = _payment;
    if (payment == null || !payment.canCancel || _cancelling) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this checkout?'),
        content: const Text(
          'All seller orders linked to this online payment will be cancelled. This cannot be reopened.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD95364),
            ),
            child: const Text('Cancel Orders'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await BuyerCheckoutService.cancelPayment(
        token: widget.token,
        paymentId: widget.paymentId,
      );
      if (!mounted) return;
      _showMessage('Checkout cancelled.');
      await _load();
    } on BuyerCheckoutException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return;
      }
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grayBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: widget.onGoToOrders,
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
        ),
        title: Text(
          'Online Payment #${widget.paymentId}',
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            )
          : _error != null && _payment == null
              ? _ErrorState(message: _error!.message, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final payment = _payment!;
    final state = _paymentState(payment.status);

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10264D), Color(0xFF16445A)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(.13),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    state.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  state.heading,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  state.description,
                  style: TextStyle(
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(.76),
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Checkout payment amount',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
                const SizedBox(height: 3),
                Text(
                  _price(payment.expectedAmount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (payment.expiresAt != null && payment.canSubmit) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 15, color: Colors.white70),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Submit proof by ${_dateTime(payment.expiresAt!)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (payment.rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            _NoticeCard(
              icon: Icons.error_outline_rounded,
              title: 'Admin rejection reason',
              message: payment.rejectionReason,
              warning: true,
            ),
          ],
          if (payment.closureReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            _NoticeCard(
              icon: Icons.info_outline_rounded,
              title: 'Closure reason',
              message: payment.closureReason,
            ),
          ],
          if (payment.canSubmit) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: payment.status == 'rejected'
                  ? 'Correct your payment proof'
                  : 'Payment proof',
              icon: Icons.receipt_long_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Complete your payment using the agreed external payment method, then submit the transaction reference and receipt for ShopHop Admin review.',
                    style: TextStyle(
                      color: Color(0xFF6D7781),
                      fontSize: 10.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _referenceController,
                    maxLength: 120,
                    decoration: _inputDecoration(
                      'Payment reference',
                      'Reference from your payment receipt',
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _submitting ? null : _pickReceipt,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.grayBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.tealLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.image_outlined,
                              color: AppColors.tealDark,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _receiptName.isEmpty
                                      ? 'Choose receipt image'
                                      : _receiptName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'JPEG, PNG, or WebP · up to 5 MiB',
                                  style: TextStyle(
                                    color: Color(0xFF8A949D),
                                    fontSize: 9.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.upload_file_rounded,
                            color: AppColors.tealDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.tealDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(
                        _submitting ? 'Submitting...' : 'Submit for Admin Review',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Linked Seller Orders',
            icon: Icons.storefront_outlined,
            child: Column(
              children: [
                for (var i = 0; i < payment.orders.length; i++) ...[
                  _PaymentOrderTile(order: payment.orders[i]),
                  if (i != payment.orders.length - 1)
                    const Divider(height: 18, color: Color(0xFFEEF1F2)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: widget.onGoToOrders,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                side: const BorderSide(color: AppColors.grayBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text(
                'Go to My Orders',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (payment.canCancel) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _cancelling ? null : _cancelPayment,
              icon: _cancelling
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cancel_outlined),
              label: const Text('Cancel this checkout group'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD55262),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentOrderTile extends StatelessWidget {
  const _PaymentOrderTile({required this.order});

  final BuyerPaymentOrderData order;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.shopping_bag_outlined,
            color: AppColors.tealDark,
            size: 19,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.sellerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Order #${order.id} · ${order.statusLabel}',
                style: const TextStyle(
                  color: Color(0xFF7D8791),
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
        Text(
          _price(order.totalAmount),
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: AppColors.tealDark),
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.message,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFFD68124) : AppColors.tealDark;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFFF6E9) : const Color(0xFFEAF9F5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF66717B),
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.navy),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6C7780), fontSize: 11),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

class _PaymentStateCopy {
  const _PaymentStateCopy(this.label, this.heading, this.description);

  final String label;
  final String heading;
  final String description;
}

_PaymentStateCopy _paymentState(String status) {
  switch (status) {
    case 'awaiting_proof':
      return const _PaymentStateCopy(
        'Awaiting Payment Proof',
        'Submit your payment proof',
        'Your seller orders are waiting for payment verification.',
      );
    case 'pending_review':
      return const _PaymentStateCopy(
        'Pending Payment Verification',
        'Your proof is with ShopHop Admin',
        'You do not need to submit again while the submitted evidence is under review.',
      );
    case 'rejected':
      return const _PaymentStateCopy(
        'Payment Rejected',
        'Update your proof and submit again',
        'Correct your transaction reference or receipt on this same payment.',
      );
    case 'verified':
      return const _PaymentStateCopy(
        'Verified by ShopHop Admin',
        'Payment proof verified',
        'Your linked seller orders are eligible for fulfillment.',
      );
    case 'cancelled':
      return const _PaymentStateCopy(
        'Cancelled',
        'This checkout payment is cancelled',
        'All seller orders in this checkout group are closed.',
      );
    case 'expired':
      return const _PaymentStateCopy(
        'Expired',
        'The proof deadline has passed',
        'All seller orders in this checkout group are closed.',
      );
    default:
      return const _PaymentStateCopy(
        'Payment Status',
        'Check your order status',
        'ShopHop returned the current recorded payment state.',
      );
  }
}

InputDecoration _inputDecoration(String label, String hint) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    counterText: '',
    filled: true,
    fillColor: const Color(0xFFF8FAFA),
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: AppColors.grayBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: AppColors.grayBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: AppColors.tealDark, width: 1.3),
    ),
  );
}

String _price(double value) => '₱${value.toStringAsFixed(2)}';

String _dateTime(DateTime value) {
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
          ? value.hour - 12
          : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.month}/${value.day}/${value.year} $hour:$minute $period';
}
