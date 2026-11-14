import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/buyer/data/services/buyer_preferences.dart';

class BuyerOrderSettingsPage extends StatefulWidget {
  const BuyerOrderSettingsPage({super.key, required this.email});
  final String email;
  @override
  State<BuyerOrderSettingsPage> createState() => _BuyerOrderSettingsPageState();
}

class _BuyerOrderSettingsPageState extends State<BuyerOrderSettingsPage> {
  String? _selected;
  String? _error;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await BuyerPreferences.orderView(widget.email);
      if (mounted) {
        setState(() {
          _selected = value;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not read your settings. Try again.');
      }
    }
  }

  Future<void> _save(String? value) async {
    if (value == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BuyerPreferences.saveOrderView(widget.email, value);
      if (!mounted) return;
      setState(() => _selected = value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default order view saved.')),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save your settings. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Order Settings')),
    body: SafeArea(
      top: false,
      child: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Choose the view to open when you tap Orders. Saved for this account on this device. Order shortcuts still open the status you choose.',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(_error!),
                  if (_selected == null)
                    TextButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                ],
              ),
            ),
          if (_selected == null && _error == null)
            const Center(child: CircularProgressIndicator()),
          if (_selected != null)
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: _save,
              child: Column(
                children: [
                  for (final option in BuyerPreferences.orderViews.entries)
                    RadioListTile<String>(
                      value: option.key,
                      title: Text(option.value),
                      enabled: !_saving,
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class BuyerPrivacySettingsPage extends StatefulWidget {
  const BuyerPrivacySettingsPage({super.key});
  @override
  State<BuyerPrivacySettingsPage> createState() =>
      _BuyerPrivacySettingsPageState();
}

class _BuyerPrivacySettingsPageState extends State<BuyerPrivacySettingsPage> {
  bool? _remembered;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await AuthSessionService.isRemembered();
      if (mounted) {
        setState(() {
          _remembered = value;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not read sign-in settings. Try again.');
      }
    }
  }

  Future<void> _forget() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthSessionService.forgetRememberedSession();
      if (mounted) setState(() => _remembered = false);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not remove saved sign-in details. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy Settings')),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Remembered sign-in',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Remove the saved sign-in details on this device. You stay signed in for this session and will need to sign in again after closing the app.',
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: _remembered == null ? _load : _forget,
              child: const Text('Try again'),
            ),
          ],
          if (_remembered == null && _error == null)
            const Center(child: CircularProgressIndicator()),
          if (_remembered == true)
            FilledButton(
              onPressed: _busy ? null : _forget,
              child: Text(_busy ? 'Removing…' : 'Remove remembered sign-in'),
            ),
          if (_remembered == false)
            const Text('Sign-in is not remembered on this device.'),
        ],
      ),
    ),
  );
}

class BuyerNotificationSettingsPage extends StatefulWidget {
  const BuyerNotificationSettingsPage({super.key});
  @override
  State<BuyerNotificationSettingsPage> createState() =>
      _BuyerNotificationSettingsPageState();
}

class _BuyerNotificationSettingsPageState
    extends State<BuyerNotificationSettingsPage> {
  String? _error;
  Future<void> _open() async {
    try {
      await const MethodChannel(
        'shophop/device_settings',
      ).invokeMethod<void>('notifications');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Open your phone Settings → Apps → ShopHop → Notifications to manage permissions.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notification Settings')),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Manage ShopHop notification permissions in your phone settings.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Mobile push alerts are not connected yet. Changing permissions does not enable order alerts.',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _open,
            child: const Text('Open phone notification settings'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!),
            ),
        ],
      ),
    ),
  );
}
