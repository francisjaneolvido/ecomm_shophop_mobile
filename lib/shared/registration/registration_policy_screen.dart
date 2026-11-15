import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/shared/registration/registration_help.dart';

class RegistrationPolicyScreen extends StatefulWidget {
  const RegistrationPolicyScreen({super.key, required this.document});
  final String document;

  static Future<void> open(BuildContext context, String document) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => RegistrationPolicyScreen(document: document),
        ),
      );

  @override
  State<RegistrationPolicyScreen> createState() =>
      _RegistrationPolicyScreenState();
}

class _RegistrationPolicyScreenState extends State<RegistrationPolicyScreen> {
  late final Future<Map<String, dynamic>> _policy = _load();

  Future<Map<String, dynamic>> _load() async {
    final documents =
        jsonDecode(
              await rootBundle.loadString(
                'assets/data/registration-policies.json',
              ),
            )
            as Map<String, dynamic>;
    return Map<String, dynamic>.from(documents[widget.document] as Map);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.page,
    appBar: AppBar(
      title: const Text('ShopHop Policies', style: TextStyle(fontSize: 16)),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _policy,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to open this document. Please try again.'),
          );
        }
        final policy = snapshot.data;
        if (policy == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${policy['title']}',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${policy['introduction']}',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: AppColors.textMuted,
                      ),
                    ),
                    for (final section in policy['sections'] as List) ...[
                      const SizedBox(height: 20),
                      Text(
                        '${section['title']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${section['body']}',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => openRegistrationHelp(context),
                      child: const Text('Get help'),
                    ),
                    const Text(
                      'Reading this page does not select the agreement checkbox.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back to Registration'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
