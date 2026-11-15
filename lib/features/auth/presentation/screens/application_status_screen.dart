import 'package:shophop/shared/widgets/shop_hop_ui.dart';
import 'package:shophop/shared/registration/application_date.dart';
import 'package:shophop/shared/registration/registration_help.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';
import 'package:shophop/features/buyer/presentation/screens/buyer_home_screen.dart';
import 'package:shophop/features/seller/presentation/screens/seller_workspace_screen.dart';
import 'package:shophop/shared/realtime/foreground_refresh.dart';

class ApplicationStatusScreen extends StatefulWidget {
  const ApplicationStatusScreen({super.key});
  @override
  State<ApplicationStatusScreen> createState() =>
      _ApplicationStatusScreenState();
}

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen> {
  late final ForegroundRefresh _refresh;
  late final http.Client _client;
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _load();
    _refresh = ForegroundRefresh(
      refresh: _load,
      interval: const Duration(seconds: 60),
      canRefresh: () =>
          mounted && !_busy && (ModalRoute.of(context)?.isCurrent ?? true),
    );
  }

  @override
  void dispose() {
    _refresh.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _logout() async {
    final session = await AuthSessionService.readSession();
    if (session != null) await AuthService.logout(token: session.token);
    await AuthSessionService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final session = await AuthSessionService.readSession();
      if (session == null) {
        await _logout();
        return;
      }
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.token}',
      };
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/application'), headers: headers)
          .timeout(const Duration(seconds: 20));
      final result = AuthApiResult.fromResponse(response);
      if (!mounted) return;
      if (result.statusCode == 401) {
        await _logout();
        return;
      }
      if (!result.success) {
        setState(() => _error = result.message);
        return;
      }
      setState(() {
        _data = result.data;
        _error = null;
      });
      if (result.data['can_enter_dashboard'] == true) {
        final activated = AuthApiResult.fromResponse(
          await _client
              .post(
                Uri.parse('${ApiConfig.baseUrl}/application/session'),
                headers: headers,
                body: jsonEncode({}),
              )
              .timeout(const Duration(seconds: 20)),
        );
        if (!mounted) return;
        final token = activated.data['token']?.toString();
        if (!activated.success || token == null || token.isEmpty) {
          setState(() => _error = activated.message);
          return;
        }
        await AuthSessionService.replaceToken(token);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => session.accountType == 'seller'
                ? const SellerWorkspaceScreen()
                : const BuyerHomeScreen(),
          ),
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to refresh status. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: AppColors.grayBg,
      appBar: AppBar(
        title: const Text('Application Status', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (data != null)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(fontSize: 12, height: 1.6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.assignment_turned_in_outlined,
                          color: AppColors.tealDark,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${data['status']}'
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text('${data['reference']}'),
                        const SizedBox(height: 16),
                        Text('${data['message']}'),
                        const Divider(height: 32),
                        Text(
                          '${data['shop_name'] ?? data['name']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text('${data['email']}'),
                        Text(
                          'Submitted: ${formatApplicationDate(data['submitted_at'])}',
                        ),
                        Text(
                          'Updated: ${formatApplicationDate(data['updated_at'])} PHT',
                        ),
                        const SizedBox(height: 16),
                        for (final step in (data['timeline'] as List? ?? []))
                          ListTile(
                            dense: true,
                            minTileHeight: 40,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              step['complete'] == true
                                  ? Icons.check_circle_outline
                                  : Icons.radio_button_unchecked,
                              color: AppColors.tealDark,
                            ),
                            title: Text(
                              '${step['label']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            subtitle: step['at'] == null
                                ? null
                                : Text(
                                    formatApplicationDate(step['at']),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                          ),
                        if (data['rejection_reason'] != null)
                          Text(
                            '${data['rejection_reason']}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        const SizedBox(height: 12),
                        const Text(
                          'For corrections or document assistance, contact ShopHop support with your reference number. You do not need to register again.',
                        ),
                        TextButton(
                          onPressed: () => openRegistrationHelp(context),
                          child: const Text('Get help'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: _busy ? null : _load,
              child: const Text('Refresh Status'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final confirmed = await showShopHopConfirmation(
                        context,
                        title: 'Sign out of ShopHop?',
                        message:
                            'Are you sure you want to sign out? You can sign back in anytime.',
                        confirmLabel: 'Sign out',
                      );
                      if (confirmed && mounted) await _logout();
                    },
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
