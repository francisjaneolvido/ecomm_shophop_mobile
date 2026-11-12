import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shophop/features/rider/data/models/rider_onboarding_progress.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';
import 'package:shophop/features/rider/data/services/rider_management_service.dart';
import 'package:shophop/features/rider/presentation/screens/rider_home_screen.dart';
import 'package:shophop/shared/realtime/foreground_refresh.dart';

class RiderApplicationStatusScreen extends StatefulWidget {
  const RiderApplicationStatusScreen({super.key});
  @override
  State<RiderApplicationStatusScreen> createState() =>
      _RiderApplicationStatusScreenState();
}

class _RiderApplicationStatusScreenState
    extends State<RiderApplicationStatusScreen> {
  late final ForegroundRefresh _refresh;
  Map<String, dynamic>? _data;
  final Map<String, PlatformFile> _files = {};
  final Set<String> _coverage = {};
  String? _token;
  String? _error;
  bool _loading = true;
  bool _fetching = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = ForegroundRefresh(
      refresh: _load,
      canRefresh: () =>
          mounted &&
          !_fetching &&
          !_busy &&
          (ModalRoute.of(context)?.isCurrent ?? true),
    );
  }

  @override
  void dispose() {
    _refresh.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    final token = _token;
    if (token != null) await AuthService.logout(token: token);
    await AuthSessionService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _load() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final session = await AuthSessionService.readSession();
      if (!mounted) return;
      if (session == null || session.accountType != 'rider') {
        await _signOut();
        return;
      }
      _token = session.token;
      final result = await RiderManagementService.application(session.token);
      if (!mounted) return;
      if (result.statusCode == 401) {
        await _signOut();
        return;
      }
      setState(() {
        _loading = false;
        if (result.success) {
          if ((_data?['branch'] as Map?)?['id'] !=
              (result.data['branch'] as Map?)?['id']) {
            _coverage.clear();
          }
          _data = result.data;
          _error = null;
          final valid = RiderManagementService.rows(
            result.data['branch_coverage_options'],
          ).map((r) => r['key'].toString()).toSet();
          _coverage.removeWhere((key) => !valid.contains(key));
        } else {
          _error = result.message;
        }
      });
    } finally {
      _fetching = false;
    }
  }

  Future<void> _run(
    Future<AuthApiResult> Function(String) action, {
    bool enterWorkspace = false,
  }) async {
    if (_busy || _token == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await action(_token!);
      if (!mounted) return;
      if (!result.success) {
        setState(() => _error = result.message);
        return;
      }
      if (enterWorkspace) {
        final token = result.data['token']?.toString();
        if (token == null || token.isEmpty) {
          setState(
            () => _error = 'No operational session was returned. Please retry.',
          );
          return;
        }
        await AuthSessionService.replaceToken(token);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RiderHomeScreen()),
          (_) => false,
        );
      } else {
        _files.clear();
        await _load();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(String slot) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (!mounted || result == null) return;
    final file = result.files.single;
    if (file.size > 5 * 1024 * 1024) {
      setState(() => _error = 'Each document must be at most 5 MB.');
      return;
    }
    setState(() => _files[slot] = file);
  }

  String _label(dynamic value) => value?.toString().replaceAll('_', ' ') ?? '';
  Widget _card(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.grayBorder),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.navy,
      ),
    ),
  );

  Widget _onboardingProgress(Map<String, dynamic> data) {
    final progress = RiderOnboardingProgress.fromJson(data);
    final color = progress.needsAttention
        ? const Color(0xFF9C5617)
        : AppColors.tealDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          progress.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          progress.message,
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Next action: ${progress.nextActor}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (
              var index = 0;
              index < RiderOnboardingProgress.steps.length;
              index++
            )
              Semantics(
                label:
                    RiderOnboardingProgress.steps[index] +
                    (index < progress.currentStep
                        ? ', completed'
                        : index == progress.currentStep
                        ? ', current step'
                        : ', upcoming'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: index <= progress.currentStep
                        ? AppColors.tealDark.withValues(alpha: .08)
                        : AppColors.grayBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        index < progress.currentStep
                            ? Icons.check_circle_outline
                            : index == progress.currentStep
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 14,
                        color: index <= progress.currentStep
                            ? AppColors.tealDark
                            : Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        RiderOnboardingProgress.steps[index],
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final request = data?['document_request'];
    final requested = request is Map && request['documents'] is List
        ? List<String>.from(request['documents'])
        : <String>[];
    final branch = data?['branch'];
    final company = data?['company'];
    final active = data?['can_operate'] == true;
    final confirm = data?['assignment_confirmation_required'] == true;
    final options = RiderManagementService.rows(
      data?['branch_coverage_options'],
    );
    return Scaffold(
      backgroundColor: AppColors.grayBg,
      appBar: AppBar(
        title: const Text(
          'Rider status',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.tealDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh status',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    _card([
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ]),
                  if (data != null) ...[
                    _card([
                      _heading(data['name']?.toString() ?? 'Rider application'),
                      Text(
                        company is Map
                            ? company['name'].toString()
                            : 'Logistics provider',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Application: ${_label(data['application_status'])}',
                      ),
                      Text('Operations: ${_label(data['operational_status'])}'),
                      const SizedBox(height: 10),
                      _onboardingProgress(data),
                      if (data['rejection_reason'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            data['rejection_reason'].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      if (active) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    RiderManagementService.activateSession,
                                    enterWorkspace: true,
                                  ),
                            child: const Text('Open rider workspace'),
                          ),
                        ),
                      ],
                    ]),
                    _card([
                      _heading('Branch & work coverage'),
                      Text(
                        branch is Map
                            ? branch['name'].toString()
                            : 'Primary Branch awaiting confirmation',
                      ),
                      if (branch is Map)
                        Text(
                          branch['address']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                      const SizedBox(height: 10),
                      const Text(
                        'Preferred barangays',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      ...RiderManagementService.rows(
                        data['preferred_coverage'],
                      ).map(
                        (r) => Text(
                          r['label'].toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Official coverage',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (RiderManagementService.rows(
                        data['official_coverage'],
                      ).isEmpty)
                        Text(
                          active
                              ? 'No official barangays are recorded. Contact your Branch to verify your coverage.'
                              : 'Awaiting official barangay assignment by ${branch is Map ? branch['name'] : 'your assigned Branch'}.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.navy,
                          ),
                        ),
                      ...RiderManagementService.rows(
                        data['official_coverage'],
                      ).map(
                        (r) => Text(
                          r['label'].toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (confirm) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Main Hub confirmed a different Branch. Review it and choose preferred barangays before accepting.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        ...options.map(
                          (p) => CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _coverage.contains(p['key']),
                            title: Text(
                              p['label'].toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                            onChanged: _busy
                                ? null
                                : (checked) => setState(() {
                                    if (checked == true) {
                                      _coverage.add(p['key'].toString());
                                    } else {
                                      _coverage.remove(p['key']);
                                    }
                                  }),
                          ),
                        ),
                        FilledButton(
                          onPressed:
                              _busy || _coverage.isEmpty || branch is! Map
                              ? null
                              : () => _run(
                                  (token) =>
                                      RiderManagementService.confirmBranch(
                                        token,
                                        int.parse(branch['id'].toString()),
                                        _coverage.toList(),
                                      ),
                                ),
                          child: const Text(
                            'Accept assigned Branch & coverage',
                          ),
                        ),
                      ],
                    ]),
                    if (requested.isNotEmpty)
                      _card([
                        _heading('Additional documents requested'),
                        Text(
                          (request as Map)['message']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                        ...requested.map(
                          (slot) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : () => _pick(slot),
                              icon: const Icon(Icons.upload_file_outlined),
                              label: Text(
                                _files[slot]?.name ??
                                    (slot == 'or_cr'
                                        ? 'Upload vehicle OR/CR'
                                        : 'Upload ID / license'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed:
                              _busy ||
                                  requested.any(
                                    (slot) => !_files.containsKey(slot),
                                  )
                              ? null
                              : () => _run(
                                  (token) => RiderManagementService.documents(
                                    token,
                                    _files,
                                  ),
                                ),
                          child: const Text('Resubmit for Main Hub review'),
                        ),
                      ]),
                    if (active && data['has_operational_session'] == true)
                      _card([
                        _heading('Availability'),
                        Text(
                          'Current: ${_label(data['availability'])}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: ['online', 'on_break', 'offline']
                              .map(
                                (state) => OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          (token) =>
                                              RiderManagementService.availability(
                                                token,
                                                state,
                                              ),
                                        ),
                                  child: Text(_label(state)),
                                ),
                              )
                              .toList(),
                        ),
                      ]),
                    if (RiderManagementService.rows(
                      data['outstanding_cod'],
                    ).isNotEmpty)
                      _card([
                        _heading('Outstanding COD cash'),
                        const Text(
                          'Return only the cash you previously collected. Record handover after physically giving it to Logistics.',
                          style: TextStyle(fontSize: 12),
                        ),
                        ...RiderManagementService.rows(
                          data['outstanding_cod'],
                        ).map(
                          (cash) => Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order #${cash['order_id']} - PHP ${cash['amount']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (cash['can_remit'] == true)
                                  OutlinedButton(
                                    onPressed: _busy
                                        ? null
                                        : () async {
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                  'Record COD handover?',
                                                ),
                                                content: const Text(
                                                  'Confirm that you physically handed this cash to Logistics. Logistics still needs to acknowledge receipt.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Cash handed over',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirmed == true && mounted) {
                                              await _run(
                                                (token) =>
                                                    RiderManagementService.remit(
                                                      token,
                                                      int.parse(
                                                        cash['delivery_id']
                                                            .toString(),
                                                      ),
                                                    ),
                                              );
                                            }
                                          },
                                    child: const Text(
                                      'Record physical cash handover',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    _card([
                      _heading('Branch work schedules'),
                      if (RiderManagementService.rows(
                        data['schedules'],
                      ).isEmpty)
                        const Text(
                          'No upcoming Branch work schedule is recorded. Schedules can be managed after activation.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ...RiderManagementService.rows(data['schedules']).map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${_time(r['starts_at'])} \u2013 ${_time(r['ends_at'])}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ]),
                    _card([
                      _heading('Application & operational updates'),
                      ...RiderManagementService.rows(data['history']).map((e) {
                        final details = e['details'];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _label(e['event']),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _time(e['created_at']),
                                style: const TextStyle(fontSize: 10),
                              ),
                              if (details is Map && details['reason'] != null)
                                Text(
                                  details['reason'].toString(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                        );
                      }),
                    ]),
                  ],
                  if (_busy) const LinearProgressIndicator(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Status refreshes every 15 seconds while this screen is visible.',
                      style: TextStyle(fontSize: 10, color: AppColors.navy),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
    );
  }

  String _time(dynamic value) {
    final text = value?.toString() ?? '';
    final parsed = DateTime.tryParse(
      text.contains('T') ? text : '${text.replaceFirst(' ', 'T')}Z',
    )?.toLocal();
    if (parsed == null) return text;
    return parsed.toString().substring(0, 16);
  }
}
