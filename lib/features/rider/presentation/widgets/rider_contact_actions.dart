import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RiderContactActions extends StatelessWidget {
  const RiderContactActions({
    super.key,
    required this.phone,
    required this.address,
    this.openLink,
  });

  final String phone;
  final String address;
  final Future<bool> Function(Uri)? openLink;

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      final opened =
          await (openLink?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (opened) return;
    } catch (_) {
      // Keep the selectable address and contact available if no external app opens.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the app. You can copy the address or phone number above.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      if (phone.trim().isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => _open(
            context,
            Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), '')),
          ),
          icon: const Icon(Icons.call_outlined, size: 18),
          label: const Text('Call buyer'),
        ),
      if (address.trim().isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => _open(
            context,
            Uri.https('www.google.com', '/maps/search/', {
              'api': '1',
              'query': address.trim(),
            }),
          ),
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('Open map'),
        ),
    ],
  );
}
