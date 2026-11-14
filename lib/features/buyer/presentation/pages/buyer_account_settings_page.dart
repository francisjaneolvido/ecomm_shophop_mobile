import 'package:shophop/features/buyer/presentation/widgets/buyer_icon_tile.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_messages_page.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_device_settings_page.dart';
import 'package:shophop/features/buyer/data/services/buyer_account_service.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_address_editor_page.dart';

/// Settings overview; profile editing remains on its own account page.
class BuyerAccountSettingsPage extends StatelessWidget {
  const BuyerAccountSettingsPage({
    super.key,
    required this.token,
    this.email = '',
    this.onProfileSaved,
    this.onSessionExpired,
  });

  final String token;
  final String email;
  final ValueChanged<BuyerAccountProfile>? onProfileSaved;
  final Future<void> Function()? onSessionExpired;

  void _unavailable(BuildContext context, String title) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text('This feature is not available in ShopHop yet.'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String title) => Container(
    width: double.infinity,
    color: AppColors.surfaceSoft,
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _row(
    BuildContext context,
    String title, {
    String? subtitle,
    VoidCallback? onTap,
    bool soon = false,
  }) => Column(
    children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        minVerticalPadding: 12,
        leading: BuyerIconTile(
          icon: switch (title) {
            'Account & Security' => Icons.manage_accounts_outlined,
            'My Addresses' => Icons.location_on_outlined,
            'Chat Settings' => Icons.chat_bubble_outline,
            'Order Settings' => Icons.inventory_2_outlined,
            'Notification Settings' => Icons.notifications_outlined,
            'Help Centre' => Icons.help_outline,
            _ => Icons.info_outline,
          },
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (soon) ...[
              Text(
                'Soon',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        onTap: onTap ?? () => _unavailable(context, title),
      ),
      const Padding(
        padding: EdgeInsets.only(left: 76),
        child: Divider(height: 1, thickness: .5, color: AppColors.border),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.page,
    appBar: AppBar(
      title: const Text('Account Settings'),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 1,
      actions: [
        IconButton(
          tooltip: 'Messages',
          icon: const BuyerIconTile(
            icon: Icons.chat_bubble_outline,
            dimension: 36,
            iconSize: 20,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => BuyerMessagesPage(
                token: token,
                onSessionExpired: onSessionExpired,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        children: [
          _header(context, 'My Account'),
          _row(
            context,
            'Account & Security',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => BuyerAccountSecurityPage(
                  token: token,
                  onProfileSaved: onProfileSaved,
                  onSessionExpired: onSessionExpired,
                ),
              ),
            ),
          ),
          _row(
            context,
            'My Addresses',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<bool>(
                builder: (_) => BuyerAddressEditorPage(token: token),
              ),
            ),
          ),
          _header(context, 'Settings'),
          _row(context, 'Chat Settings', soon: true),
          _row(
            context,
            'Order Settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => BuyerOrderSettingsPage(email: email),
              ),
            ),
          ),
          _row(
            context,
            'Notification Settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const BuyerNotificationSettingsPage(),
              ),
            ),
          ),
          _header(context, 'Support'),
          _row(
            context,
            'Help Centre',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const _BuyerHelpPage()),
            ),
          ),
          _row(
            context,
            'About',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'ShopHop',
              children: const [
                Text(
                  'Shop, track your orders, and manage your account with ShopHop.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _BuyerHelpPage extends StatelessWidget {
  const _BuyerHelpPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help Centre')),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ExpansionTile(
            title: Text('Where can I check my orders?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Open Orders from the bottom navigation. Tap an order to see delivery progress and tracking when available.',
                ),
              ),
            ],
          ),
          const ExpansionTile(
            title: Text('How do I update my delivery address?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Open Account Settings → My Addresses. Review your address at checkout. Updating your address does not change orders already placed.',
                ),
              ),
            ],
          ),
          const ExpansionTile(
            title: Text('How do I change my profile or password?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Open Account Settings → Account & Security. Save your profile changes, or open Change password and enter your current password.',
                ),
              ),
            ],
          ),
          const ExpansionTile(
            title: Text('Which payment methods can I use?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Available payment methods appear at checkout. Check your payment status before attempting the same payment again.',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class BuyerAccountSecurityPage extends StatefulWidget {
  const BuyerAccountSecurityPage({
    super.key,
    required this.token,
    this.onProfileSaved,
    this.onSessionExpired,
  });
  final String token;
  final ValueChanged<BuyerAccountProfile>? onProfileSaved;
  final Future<void> Function()? onSessionExpired;

  @override
  State<BuyerAccountSecurityPage> createState() =>
      _BuyerAccountSecurityPageState();
}

class _BuyerAccountSecurityPageState extends State<BuyerAccountSecurityPage> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _middle = TextEditingController();
  final _phone = TextEditingController();
  final _birthday = TextEditingController();
  BuyerAccountProfile? _profile;
  String? _sex;
  String? _error;
  Map<String, String> _errors = {};
  bool _loading = true, _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [_first, _last, _middle, _phone, _birthday]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _populate(BuyerAccountProfile profile) {
    _profile = profile;
    _first.text = profile.firstName;
    _last.text = profile.lastName;
    _middle.text = profile.middleInitial;
    _phone.text = profile.phone;
    _sex = profile.sexOptions.contains(profile.sex) ? profile.sex : null;
    _birthday.text = profile.birthday == null ? '' : _date(profile.birthday!);
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _handleError(BuyerAccountException error) async {
    if (!mounted) return;
    if (error.isUnauthorized && widget.onSessionExpired != null) {
      await widget.onSessionExpired!();
      return;
    }
    setState(() {
      _error = error.message;
      _errors = error.errors;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await BuyerAccountService.load(widget.token);
      if (mounted) setState(() => _populate(profile));
    } on BuyerAccountException catch (error) {
      await _handleError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
      _errors = {};
    });
    try {
      final profile = await BuyerAccountService.save(widget.token, {
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
        'middle_initial': _middle.text.trim(),
        'contact_no': _phone.text.trim(),
        'sex': _sex,
        'birthday': _birthday.text,
      });
      if (!mounted) return;
      setState(() => _populate(profile));
      widget.onProfileSaved?.call(profile);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile changes saved.')));
    } on BuyerAccountException catch (error) {
      await _handleError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final last = DateTime(now.year, now.month, now.day - 1);
    final first = DateTime(1900);
    final current = DateTime.tryParse(_birthday.text);
    final chosen = await showDatePicker(
      context: context,
      initialDate:
          current != null && !current.isBefore(first) && !current.isAfter(last)
          ? current
          : DateTime(now.year - 18, now.month, now.day),
      firstDate: first,
      lastDate: last,
    );
    if (chosen != null && mounted) {
      setState(() {
        _birthday.text = _date(chosen);
        _errors.remove('birthday');
      });
    }
  }

  Widget _field(
    String label,
    String key,
    TextEditingController controller, {
    bool isRequired = true,
    int? maxLength,
    TextInputType? keyboardType,
    List<String>? autofillHints,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      maxLength: maxLength,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textCapitalization: keyboardType == TextInputType.phone
          ? TextCapitalization.none
          : TextCapitalization.words,
      inputFormatters: keyboardType == TextInputType.phone
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        labelText: label,
        errorText: _errors[key],
        counterText: '',
      ),
      onChanged: (_) {
        if (_errors.containsKey(key)) setState(() => _errors.remove(key));
      },
      validator: (value) {
        if (isRequired && (value?.trim().isEmpty ?? true)) {
          return 'Enter your ${label.toLowerCase()}.';
        }
        if (key == 'contact_no' &&
            !RegExp(r'^09\d{9}$').hasMatch(value?.trim() ?? '')) {
          return 'Use an 11-digit number starting with 09.';
        }
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Account & Security')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ?? 'Could not load your account.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : SafeArea(
              top: false,
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Your profile',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _profile!.email,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your sign-in email is fixed to your verified account.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _field(
                      'First name',
                      'first_name',
                      _first,
                      maxLength: 100,
                      autofillHints: const [AutofillHints.givenName],
                    ),
                    _field(
                      'Last name',
                      'last_name',
                      _last,
                      maxLength: 100,
                      autofillHints: const [AutofillHints.familyName],
                    ),
                    _field(
                      'Middle initial (optional)',
                      'middle_initial',
                      _middle,
                      isRequired: false,
                      maxLength: 2,
                    ),
                    _field(
                      'Mobile number',
                      'contact_no',
                      _phone,
                      maxLength: 11,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [
                        AutofillHints.telephoneNumberNational,
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_sex),
                      initialValue: _sex,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Sex',
                        errorText: _errors['sex'],
                      ),
                      items: _profile!.sexOptions
                          .map(
                            (sex) =>
                                DropdownMenuItem(value: sex, child: Text(sex)),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _sex = value;
                              _errors.remove('sex');
                            }),
                      validator: (value) =>
                          value == null ? 'Choose an option.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _birthday,
                      readOnly: true,
                      enabled: !_saving,
                      onTap: _pickBirthday,
                      decoration: InputDecoration(
                        labelText: 'Birthday',
                        hintText: 'YYYY-MM-DD',
                        errorText: _errors['birthday'],
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Choose your birthday.'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save changes'),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const BuyerIconTile(icon: Icons.lock_outline),
                      title: const Text('Change password'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _saving
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => BuyerPasswordPage(
                                  token: widget.token,
                                  onSessionExpired: widget.onSessionExpired,
                                ),
                              ),
                            ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const BuyerIconTile(
                        icon: Icons.location_on_outlined,
                      ),
                      title: const Text('Delivery address'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _saving
                          ? null
                          : () async {
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BuyerAddressEditorPage(
                                    token: widget.token,
                                  ),
                                ),
                              );
                              if (changed == true && mounted) {
                                // Address editing can also change the account's contact number.
                                try {
                                  final updated =
                                      await BuyerAccountService.load(
                                        widget.token,
                                      );
                                  if (mounted) {
                                    setState(() => _phone.text = updated.phone);
                                  }
                                } on BuyerAccountException catch (error) {
                                  await _handleError(error);
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
    ),
  );
}

class BuyerPasswordPage extends StatefulWidget {
  const BuyerPasswordPage({
    super.key,
    required this.token,
    this.onSessionExpired,
  });
  final String token;
  final Future<void> Function()? onSessionExpired;
  @override
  State<BuyerPasswordPage> createState() => _BuyerPasswordPageState();
}

class _BuyerPasswordPageState extends State<BuyerPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(),
      _password = TextEditingController(),
      _confirmation = TextEditingController();
  final _visible = <String>{};
  Map<String, String> _errors = {};
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
      _errors = {};
    });
    try {
      await BuyerAccountService.changePassword(
        widget.token,
        current: _current.text,
        password: _password.text,
        confirmation: _confirmation.text,
      );
      if (!mounted) return;
      _current.clear();
      _password.clear();
      _confirmation.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password changed.')));
    } on BuyerAccountException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized && widget.onSessionExpired != null) {
        await widget.onSessionExpired!();
      } else {
        setState(() {
          _error = error.message;
          _errors = error.errors;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String label,
    String key,
    TextEditingController controller,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      obscureText: !_visible.contains(key),
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [
        key == 'current_password'
            ? AutofillHints.password
            : AutofillHints.newPassword,
      ],
      decoration: InputDecoration(
        labelText: label,
        errorText: _errors[key],
        suffixIcon: IconButton(
          tooltip: _visible.contains(key) ? 'Hide $label' : 'Show $label',
          onPressed: () => setState(() {
            if (!_visible.add(key)) _visible.remove(key);
          }),
          icon: Icon(
            _visible.contains(key)
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
      onChanged: (_) {
        if (_errors.containsKey(key)) setState(() => _errors.remove(key));
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Enter your ${label.toLowerCase()}.';
        }
        if (value.length > 255) return 'Use at most 255 characters.';
        if (key == 'password') {
          if (utf8.encode(value).length > 72) {
            return 'Please use a shorter password.';
          }
          if (value == _current.text) return 'Choose a different password.';
          if (value.length < 8 ||
              !RegExp(r'[a-z]').hasMatch(value) ||
              !RegExp(r'[A-Z]').hasMatch(value) ||
              !RegExp(r'[0-9]').hasMatch(value) ||
              !RegExp(r'[^a-zA-Z0-9\s]').hasMatch(value)) {
            return 'Use 8+ characters with uppercase, lowercase, a number, and a symbol.';
          }
        }
        if (key == 'password_confirmation' && value != _password.text) {
          return 'Passwords do not match.';
        }
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Use at least 8 characters with uppercase and lowercase letters, a number, and a symbol.',
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              _field('Current password', 'current_password', _current),
              _field('New password', 'password', _password),
              _field(
                'Confirm new password',
                'password_confirmation',
                _confirmation,
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update password'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
