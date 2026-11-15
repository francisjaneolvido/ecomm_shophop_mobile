import 'package:shophop/features/rider/presentation/widgets/rider_profile_photo.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:shophop/features/rider/presentation/widgets/rider_coverage_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/rider/data/services/rider_management_service.dart';
import 'package:shophop/shared/registration/registration_help.dart';
import 'package:shophop/shared/registration/registration_policy_screen.dart';
import 'package:shophop/shared/widgets/shop_hop_scan_feedback.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';

class RiderAccountPage extends StatefulWidget {
  const RiderAccountPage({
    super.key,
    required this.token,
    required this.name,
    required this.company,
    required this.workDetails,
    required this.onOpenWorkSettings,
    required this.onSessionExpired,
    required this.onLogout,
  });
  final String token, name, company;
  final Widget workDetails;
  final Future<void> Function() onOpenWorkSettings, onSessionExpired, onLogout;
  @override
  State<RiderAccountPage> createState() => _RiderAccountPageState();
}

class _RiderAccountPageState extends State<RiderAccountPage> {
  Map<String, dynamic>? _profile;
  String? _error;
  bool _loading = true, _signingOut = false;
  @override
  void initState() {
    super.initState();
    _load();
    _loadVersion();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await RiderManagementService.request(
      'profile',
      token: widget.token,
    );
    if (!mounted) return;
    if (result.statusCode == 401) {
      await widget.onSessionExpired();
      return;
    }
    setState(() {
      _loading = false;
      if (result.success) {
        _profile = result.data;
      } else {
        _error = result.message;
      }
    });
  }

  Future<void> _edit({bool password = false}) async {
    if (_profile == null) return;
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => RiderAccountEditorScreen(
          token: widget.token,
          profile: _profile!,
          password: password,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
    if (!mounted) return;
    if (updated == null) {
      await _load();
      return;
    }
    if (!password) setState(() => _profile = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          password
              ? 'Password changed. Other mobile sessions have been signed out.'
              : 'Personal information updated.',
        ),
      ),
    );
  }

  void _workDetails() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .65,
      minChildSize: .35,
      maxChildSize: .9,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text(
            'Assigned branch & service areas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (_profile == null)
            widget.workDetails
          else ...[
            _group([
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Assigned branch',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _profile!['branch']?.toString() ?? 'Awaiting assignment',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_profile!['branch_code'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SelectableText(
                          '${_profile!['branch_code']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.pink,
                          ),
                        ),
                      ),
                    if (_profile!['branch_address'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${_profile!['branch_address']}',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _group([
              Padding(
                padding: const EdgeInsets.all(14),
                child: RiderCoverageList(
                  areas: (_profile!['service_areas'] as List? ?? [])
                      .map((e) => e.toString())
                      .toList(),
                ),
              ),
            ]),
          ],
          if (_profile?['branch_contact_no']?.toString().trim().isNotEmpty ==
              true) ...[
            const SizedBox(height: 12),
            SelectableText('Branch contact: ${_profile!['branch_contact_no']}'),
            OutlinedButton.icon(
              onPressed: _callBranch,
              icon: const Icon(Icons.call_outlined),
              label: const Text('Call branch'),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Your branch manager controls assignments and operational permissions.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Future<void> _callBranch() async {
    final phone =
        _profile?['branch_contact_no']?.toString().replaceAll(
          RegExp(r'[^0-9+]'),
          '',
        ) ??
        '';
    if (phone.isEmpty) return;
    try {
      if (await launchUrl(
        Uri(scheme: 'tel', path: phone),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      /* Leave the phone number available to copy. */
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open the dialer. Copy the branch number to contact them.',
          ),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final confirmed = await showShopHopConfirmation(
      context,
      title: 'Sign out of Rider portal?',
      message: 'You can sign in again to view assigned tasks.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await widget.onLogout();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('rider-account-settings'),
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
    children: [
      _group([
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              RiderProfilePhoto(
                token: widget.token,
                url: _profile?['photo_url']?.toString(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profile?['name']?.toString() ?? widget.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.company,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (_profile != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Rider #${_profile!['id']} · ${_profile!['status']}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ]),
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(12),
          child: LinearProgressIndicator(color: AppColors.pink),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _error!,
                style: const TextStyle(color: AppColors.errorStrong),
              ),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      _heading('Profile & work'),
      _group([
        _row(
          Icons.person_outline,
          'Personal information',
          'Photo, name, contact, email and password',
          _profile == null ? null : () => _edit(),
        ),
        _row(
          Icons.event_available_outlined,
          'Work settings & schedules',
          'View activation status and working hours',
          widget.onOpenWorkSettings,
        ),
        _row(
          Icons.location_on_outlined,
          'Assigned branch & service areas',
          'View your branch and approved coverage',
          _workDetails,
        ),
      ]),
      _heading('Scanner settings'),
      _group([
        _preference(
          'Scan sound',
          'Play a sound after a scan result',
          Icons.volume_up_outlined,
          ShopHopScanFeedback.soundEnabled,
          ShopHopScanFeedback.setSoundEnabled,
        ),
        _preference(
          'Scan vibration',
          'Vibrate after a scan result',
          Icons.vibration,
          ShopHopScanFeedback.vibrationEnabled,
          ShopHopScanFeedback.setVibrationEnabled,
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'Saved on this device for all ShopHop scanners.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
      ]),
      _heading('Security & support'),
      _group([
        _row(
          Icons.lock_outline,
          'Change password',
          'Use your current password to set a new one',
          _profile == null ? null : () => _edit(password: true),
        ),
        _row(
          Icons.help_outline,
          'Help Center',
          'Get help with your ShopHop account',
          () => openRegistrationHelp(context),
        ),
        _row(
          Icons.support_agent,
          'Contact your branch',
          'For assignments, schedules and delivery concerns',
          _workDetails,
        ),
        _row(
          Icons.privacy_tip_outlined,
          'Privacy Policy',
          'How ShopHop handles your information',
          () => RegistrationPolicyScreen.open(context, 'privacy'),
        ),
        _row(
          Icons.info_outline,
          'About ShopHop',
          'App information',
          () => showAboutDialog(
            context: context,
            applicationName: 'ShopHop',
            applicationVersion: _version ?? 'ShopHop Rider',
            children: [
              const Text('Shop local finds and keep every delivery connected.'),
            ],
          ),
        ),
      ]),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _signingOut ? null : _signOut,
        icon: const Icon(Icons.logout_rounded),
        label: Text(_signingOut ? 'Signing out…' : 'Sign out'),
      ),
    ],
  );

  String? _version;
  Future<void> _loadVersion() async {
    try {
      final data = await const MethodChannel(
        'shophop/device_settings',
      ).invokeMapMethod<String, dynamic>('appInfo');
      if (data == null) return;
      if (mounted) {
        setState(
          () => _version = '${data['version']} (${data['build_number']})',
        );
      }
    } catch (_) {
      /* Older builds may not contain build information. */
    }
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
  Widget _group(List<Widget> children) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppColors.border),
    ),
    child: Column(children: children),
  );
  Widget _row(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? onTap,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    leading: Icon(icon, color: AppColors.pink, size: 22),
    title: Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
    ),
    trailing: const Icon(
      Icons.chevron_right,
      color: AppColors.textMuted,
      size: 19,
    ),
    onTap: onTap,
    enabled: onTap != null,
  );
  Widget _preference(
    String title,
    String subtitle,
    IconData icon,
    ValueNotifier<bool> notifier,
    Future<bool> Function(bool) save,
  ) => ValueListenableBuilder<bool>(
    valueListenable: notifier,
    builder: (_, value, _) => SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      secondary: Icon(icon, color: AppColors.pink, size: 22),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
      activeTrackColor: AppColors.pink,
      value: value,
      onChanged: (next) async {
        final saved = await save(next);
        if (!saved && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Changed for this session. Unable to save on this device.',
              ),
            ),
          );
        }
      },
    ),
  );
}

class RiderAccountEditorScreen extends StatefulWidget {
  const RiderAccountEditorScreen({
    super.key,
    required this.token,
    required this.profile,
    required this.onSessionExpired,
    this.password = false,
  });
  final String token;
  final Map<String, dynamic> profile;
  final bool password;
  final Future<void> Function() onSessionExpired;
  @override
  State<RiderAccountEditorScreen> createState() =>
      _RiderAccountEditorScreenState();
}

class _RiderAccountEditorScreenState extends State<RiderAccountEditorScreen> {
  final _form = GlobalKey<FormState>();
  late Map<String, dynamic> _profile = Map.of(widget.profile);
  late final _first = TextEditingController(
    text:
        widget.profile['first_name']?.toString() ??
        widget.profile['name']?.toString().split(' ').first ??
        '',
  );
  late final _last = TextEditingController(
    text:
        widget.profile['last_name']?.toString() ??
        (widget.profile['name']?.toString().split(' ').skip(1).join(' ') ?? ''),
  );
  late final _middle = TextEditingController(
    text: widget.profile['middle_initial']?.toString() ?? '',
  );
  late final _contact = TextEditingController(
    text: widget.profile['contact_no']?.toString() ?? '',
  );
  final _current = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  Map<String, dynamic> _errors = {};
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _middle.dispose();
    _contact.dispose();
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _serverError(String key) {
    final value = _errors[key];
    return value is List && value.isNotEmpty ? value.first.toString() : null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
      _errors = {};
    });
    final result = await RiderManagementService.request(
      widget.password ? 'password' : 'profile',
      token: widget.token,
      method: 'PATCH',
      body: widget.password
          ? {
              'current_password': _current.text,
              'password': _password.text,
              'password_confirmation': _confirm.text,
            }
          : {
              'contact_no': _contact.text.trim(),
              'first_name': _first.text.trim(),
              'last_name': _last.text.trim(),
              'middle_initial': _middle.text.trim(),
            },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.statusCode == 401) {
      await widget.onSessionExpired();
      return;
    }
    if (result.success) {
      Navigator.of(
        context,
      ).pop(widget.password ? <String, dynamic>{} : result.data);
      return;
    }
    setState(() {
      _error = result.message;
      _errors = result.errors;
    });
  }

  Future<void> _uploadPhoto() async {
    if (_saving) return;
    FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to open your photos. Please try again.',
        );
      }
      return;
    }
    if (!mounted || picked == null) return;
    final photo = picked.files.single;
    if (photo.size > 20 * 1024 * 1024) {
      setState(() => _error = 'Choose a photo up to 20 MB.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await RiderManagementService.uploadPhoto(
      widget.token,
      photo,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result.success) {
        _profile = result.data;
      } else {
        _error = result.message;
        _errors = result.errors;
      }
    });
    if (result.statusCode == 401) {
      await widget.onSessionExpired();
      return;
    }
    if (mounted && result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo saved.')));
    }
  }

  Future<void> _changePassword() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => RiderAccountEditorScreen(
          token: widget.token,
          profile: _profile,
          password: true,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() => _profile['pending_email'] = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Password changed. Other mobile sessions have been signed out.',
        ),
      ),
    );
  }

  Future<void> _changeEmail() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => RiderEmailChangeScreen(
          token: widget.token,
          profile: _profile,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() => _profile = updated);
    } else {
      final result = await RiderManagementService.request(
        'profile',
        token: widget.token,
      );
      if (mounted && result.success) setState(() => _profile = result.data);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.pink,
        foregroundColor: Colors.white,
        title: Text(
          widget.password ? 'Change password' : 'Personal information',
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.password) ...[
                Center(
                  child: RiderProfilePhoto(
                    token: widget.token,
                    url: _profile['photo_url']?.toString(),
                    size: 88,
                  ),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : _uploadPhoto,
                  icon: const Icon(
                    Icons.add_a_photo_outlined,
                    color: AppColors.pink,
                  ),
                  label: const Text(
                    'Change profile photo',
                    style: TextStyle(color: AppColors.pink),
                  ),
                ),
                const Center(
                  child: Text(
                    'JPG, PNG or WebP / up to 20 MB. Automatically resized.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 20),
                _detail('Rider ID', '#${widget.profile['id']}'),
                TextFormField(
                  controller: _first,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: 'First name',
                    errorText: _serverError('first_name'),
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Enter your first name.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _last,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: 'Last name',
                    errorText: _serverError('last_name'),
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Enter your last name.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _middle,
                  enabled: !_saving,
                  maxLength: 2,
                  decoration: InputDecoration(
                    labelText: 'Middle initial (optional)',
                    errorText: _serverError('middle_initial'),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contact,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Contact number',
                    hintText: '09XXXXXXXXX',
                    errorText: _serverError('contact_no'),
                  ),
                  validator: (value) =>
                      RegExp(r'^09\d{9}$').hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Enter an 11-digit number starting with 09.',
                ),
                const SizedBox(height: 18),
                _detail('Verified email', '${_profile['email']}'),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _changeEmail,
                  icon: const Icon(Icons.email_outlined),
                  label: Text(
                    _profile['pending_email'] != null
                        ? 'Verify new email'
                        : 'Change email',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _changePassword,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Change password'),
                ),
              ] else ...[
                const Text(
                  'Use at least 8 characters with uppercase, lowercase, a number and a symbol. Other mobile sessions will be signed out.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                _PasswordField(
                  controller: _current,
                  label: 'Current password',
                  enabled: !_saving,
                  error: _serverError('current_password'),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Enter your current password.'
                      : null,
                ),
                const SizedBox(height: 14),
                _PasswordField(
                  controller: _password,
                  label: 'New password',
                  enabled: !_saving,
                  error: _serverError('password'),
                  validator: (v) {
                    final value = v ?? '';
                    if (utf8.encode(value).length > 72) {
                      return 'Use a shorter password (up to 72 bytes).';
                    }
                    if (value.length < 8 ||
                        !RegExp('[A-Z]').hasMatch(value) ||
                        !RegExp('[a-z]').hasMatch(value) ||
                        !RegExp('[0-9]').hasMatch(value) ||
                        !RegExp(r'[^a-zA-Z0-9\s]').hasMatch(value)) {
                      return 'Include 8+ characters, uppercase, lowercase, a number and a symbol.';
                    }
                    return value == _current.text
                        ? 'Choose a different password.'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                _PasswordField(
                  controller: _confirm,
                  label: 'Confirm new password',
                  enabled: !_saving,
                  error: _serverError('password_confirmation'),
                  validator: (v) =>
                      v == _password.text ? null : 'Passwords do not match.',
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.errorStrong),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.pink,
                  foregroundColor: Colors.white,
                ),
                child: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 3),
        SelectableText(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class RiderEmailChangeScreen extends StatefulWidget {
  const RiderEmailChangeScreen({
    super.key,
    required this.token,
    required this.profile,
    required this.onSessionExpired,
  });
  final String token;
  final Map<String, dynamic> profile;
  final Future<void> Function() onSessionExpired;
  @override
  State<RiderEmailChangeScreen> createState() => _RiderEmailChangeScreenState();
}

class _RiderEmailChangeScreenState extends State<RiderEmailChangeScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(
    text: widget.profile['pending_email']?.toString() ?? '',
  );
  final _password = TextEditingController(), _code = TextEditingController();
  late bool _sent = widget.profile['pending_email'] != null;
  bool _busy = false;
  String? _error, _notice;
  Map<String, dynamic> _errors = {};
  Map<String, dynamic>? _updated;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  String? _fieldError(String key) =>
      _errors[key] is List && (_errors[key] as List).isNotEmpty
      ? _errors[key][0].toString()
      : null;

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _errors = {};
    });
    final result = await RiderManagementService.request(
      _sent ? 'profile/email/verify' : 'profile/email',
      token: widget.token,
      method: 'POST',
      body: _sent
          ? {'code': _code.text.trim()}
          : {'email': _email.text.trim(), 'current_password': _password.text},
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.statusCode == 401) {
      await widget.onSessionExpired();
      return;
    }
    if (!result.success) {
      setState(() {
        _error = result.message;
        _errors = result.errors;
      });
      return;
    }
    if (_sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'New email verified. Use it the next time you sign in.',
          ),
        ),
      );
      Navigator.of(context).pop(result.data);
    } else {
      setState(() {
        _sent = true;
        _updated = result.data;
        _notice =
            'Code sent to ${_email.text.trim()}. It expires in 10 minutes.';
        _password.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Change email'),
        backgroundColor: AppColors.pink,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _busy ? null : () => Navigator.of(context).pop(_updated),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your current email stays active until you verify the new address. Your branch and assignments stay connected to your account.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Current email: ${widget.profile['email']}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 18),
              if (!_sent) ...[
                TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'New email',
                    errorText: _fieldError('email'),
                    errorMaxLines: 3,
                  ),
                  validator: (v) =>
                      RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Enter a valid email address.',
                ),
                const SizedBox(height: 14),
                _PasswordField(
                  controller: _password,
                  label: 'Current password',
                  enabled: !_busy,
                  error: _fieldError('current_password'),
                  validator: (v) => v?.isNotEmpty == true
                      ? null
                      : 'Enter your current password.',
                ),
              ] else ...[
                Text(
                  _notice ?? 'Enter the 6-digit code sent to ${_email.text}.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Verification code',
                    errorText: _fieldError('code'),
                    errorMaxLines: 3,
                  ),
                  validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                      ? null
                      : 'Enter the 6-digit code.',
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _sent = false;
                          _errors = {};
                          _error = null;
                        }),
                  child: const Text(
                    'Change address or resend code',
                    style: TextStyle(color: AppColors.pink),
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.errorStrong),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.pink,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  _busy
                      ? 'Please wait...'
                      : _sent
                      ? 'Verify new email'
                      : 'Send verification code',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.enabled,
    required this.validator,
    this.error,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final String? error;
  final String? Function(String?) validator;
  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: _hidden,
    autocorrect: false,
    enableSuggestions: false,
    validator: widget.validator,
    decoration: InputDecoration(
      labelText: widget.label,
      errorText: widget.error,
      errorMaxLines: 3,
      suffixIcon: IconButton(
        tooltip: _hidden
            ? 'Show ${widget.label.toLowerCase()}'
            : 'Hide ${widget.label.toLowerCase()}',
        onPressed: () => setState(() => _hidden = !_hidden),
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}
