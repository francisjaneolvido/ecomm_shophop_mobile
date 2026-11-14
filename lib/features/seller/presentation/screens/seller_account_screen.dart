import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/features/seller/data/services/seller_workspace_service.dart';

class SellerAccountScreen extends StatefulWidget {
  const SellerAccountScreen({
    super.key,
    required this.token,
    required this.onSessionExpired,
  });
  final String token;
  final Future<void> Function() onSessionExpired;
  @override
  State<SellerAccountScreen> createState() => _SellerAccountScreenState();
}

class _SellerAccountScreenState extends State<SellerAccountScreen> {
  final _profile = <String, TextEditingController>{
    for (final key in [
      'first_name',
      'last_name',
      'middle_initial',
      'contact_no',
      'birthday',
    ])
      key: TextEditingController(),
  };
  final _passwords = <String, TextEditingController>{
    for (final key in ['current_password', 'password', 'password_confirmation'])
      key: TextEditingController(),
  };
  Map<String, dynamic> _data = {};
  List<String> _sexOptions = ['Male', 'Female'];
  String? _sex;
  bool _loading = true, _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await SellerWorkspaceService.get(widget.token, 'profile');
    if (!mounted) return;
    if (result.statusCode == 401 || result.statusCode == 403) {
      await widget.onSessionExpired();
      return;
    }
    setState(() {
      _loading = false;
      _message = result.success ? null : result.message;
      if (result.success) {
        _data = result.data;
        for (final entry in _profile.entries) {
          entry.value.text = '${_data[entry.key] ?? ''}';
        }
        _sexOptions =
            (_data['sex_options'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            ['Male', 'Female'];
        _sex = _sexOptions.contains(_data['sex'])
            ? _data['sex'].toString()
            : _sexOptions.first;
      }
    });
  }

  Future<void> _save(bool password) async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _message = null;
    });
    final fields = password ? _passwords : _profile;
    final payload = <String, dynamic>{
      for (final e in fields.entries) e.key: e.value.text,
    };
    if (!password) payload['sex'] = _sex;
    final result = await SellerWorkspaceService.patch(
      widget.token,
      password ? 'password' : 'profile',
      payload,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = result.message;
    });
    if (result.statusCode == 401 || result.statusCode == 403) {
      await widget.onSessionExpired();
      return;
    }
    if (result.success && password) {
      for (final field in _passwords.values) {
        field.clear();
      }
    }
  }

  Future<void> _updateLogo({bool remove = false}) async {
    if (_saving) return;
    PlatformFile? selected;
    if (remove) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove shop logo?'),
          content: const Text(
            'Your shop will show its initial until you upload another logo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    } else {
      try {
        final picked = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
          withData: true,
        );
        if (picked == null || picked.files.isEmpty || !mounted) return;
        selected = picked.files.first;
        if (selected.bytes == null || selected.size > 2 * 1024 * 1024) {
          setState(
            () => _message = 'Choose a JPG, PNG or WebP image up to 2 MB.',
          );
          return;
        }
      } catch (_) {
        if (mounted) {
          setState(() => _message = 'Could not read that image. Please retry.');
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    final result = await SellerWorkspaceService.updateLogo(
      token: widget.token,
      logo: selected,
      remove: remove,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = result.message;
      if (result.success) _data['logo_url'] = result.data['logo_url'];
    });
    if (result.statusCode == 401 || result.statusCode == 403) {
      await widget.onSessionExpired();
    }
  }

  @override
  void dispose() {
    for (final field in [..._profile.values, ..._passwords.values]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account Management')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${_data['business_name'] ?? ''}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('${_data['email'] ?? ''}'),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_message!, semanticsLabel: _message),
                ),
              if (_data.isEmpty)
                TextButton(onPressed: _load, child: const Text('Retry')),
              if (_data.isNotEmpty) ...[
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          foregroundImage:
                              ApiConfig.resolveMediaUrl(
                                _data['logo_url']?.toString(),
                              ).isEmpty
                              ? null
                              : NetworkImage(
                                  ApiConfig.resolveMediaUrl(
                                    _data['logo_url']?.toString(),
                                  ),
                                ),
                          child: const Icon(Icons.storefront_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Shop logo',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const Text(
                                'Visible to buyers on your shop page.',
                                style: TextStyle(fontSize: 11),
                              ),
                              Wrap(
                                spacing: 6,
                                children: [
                                  TextButton(
                                    onPressed: _saving
                                        ? null
                                        : () => _updateLogo(),
                                    child: const Text('Upload photo'),
                                  ),
                                  if (ApiConfig.resolveMediaUrl(
                                    _data['logo_url']?.toString(),
                                  ).isNotEmpty)
                                    TextButton(
                                      onPressed: _saving
                                          ? null
                                          : () => _updateLogo(remove: true),
                                      child: const Text('Remove'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Personal information',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final e in <String, String>{
                  'first_name': 'First name',
                  'last_name': 'Last name',
                  'middle_initial': 'Middle initial',
                  'contact_no': 'Contact number (09xxxxxxxxx)',
                  'birthday': 'Birthday (YYYY-MM-DD)',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextField(
                      controller: _profile[e.key],
                      enabled: !_saving,
                      keyboardType: e.key == 'contact_no'
                          ? TextInputType.phone
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: e.value,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _sex,
                  decoration: const InputDecoration(
                    labelText: 'Sex',
                    border: OutlineInputBorder(),
                  ),
                  items: _sexOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: _saving ? null : (s) => setState(() => _sex = s),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : () => _save(false),
                  child: const Text('Save profile'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Change password',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'At least 10 characters, uppercase, lowercase and a number.',
                ),
                for (final e in <String, String>{
                  'current_password': 'Current password',
                  'password': 'New password',
                  'password_confirmation': 'Confirm new password',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextField(
                      controller: _passwords[e.key],
                      enabled: !_saving,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: [
                        e.key == 'current_password'
                            ? AutofillHints.password
                            : AutofillHints.newPassword,
                      ],
                      decoration: InputDecoration(
                        labelText: e.value,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : () => _save(true),
                  child: const Text('Change password'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Registered category: ${_data['business_category'] ?? ''}',
                ),
                Text('Registered address: ${_data['address'] ?? ''}'),
              ],
            ],
          ),
  );
}
