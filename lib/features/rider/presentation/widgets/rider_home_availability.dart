import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'rider_profile_photo.dart';

class RiderHomeAvailability extends StatelessWidget {
  const RiderHomeAvailability({
    super.key,
    required this.name,
    required this.greeting,
    required this.state,
    required this.saving,
    required this.enabled,
    required this.onChanged,
    this.token = '',
    this.photoUrl,
  });
  final String name, greeting;
  final String token;
  final String? photoUrl;
  final String? state;
  final bool saving, enabled;
  final ValueChanged<String> onChanged;

  static Color statusColor(String? state) => switch (state) {
    'online' => const Color(0xFF15803D),
    'on_break' => const Color(0xFFB45309),
    'offline' => const Color(0xFF64748B),
    'busy' => const Color(0xFF1D4ED8),
    _ => AppColors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    final busy = state == 'busy';
    final label = switch (state) {
      'online' => 'Online',
      'on_break' => 'On break',
      'offline' => 'Offline',
      'busy' => 'Busy',
      _ => 'Unavailable',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('rider-greeting'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.pink,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              RiderProfilePhoto(token: token, url: photoUrl, circular: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Availability',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (saving)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.pink,
                        ),
                      ),
                    ),
                  Container(
                    key: const ValueKey('rider-availability-status'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor(state).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          busy ? Icons.lock_outline : Icons.circle,
                          size: busy ? 13 : 7,
                          color: statusColor(state),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          saving ? 'Updating...' : label,
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor(state),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final entry in const {
                    'online': 'Online',
                    'on_break': 'On break',
                    'offline': 'Offline',
                  }.entries) ...[
                    if (entry.key != 'online') const SizedBox(width: 6),
                    Expanded(
                      child: Semantics(
                        selected: state == entry.key,
                        child: OutlinedButton(
                          key: ValueKey('rider-availability-${entry.key}'),
                          onPressed:
                              enabled &&
                                  state != null &&
                                  !saving &&
                                  state != entry.key
                              ? () => onChanged(entry.key)
                              : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 10,
                            ),
                            minimumSize: const Size(0, 44),
                            foregroundColor: state == entry.key
                                ? Colors.white
                                : statusColor(entry.key),
                            disabledForegroundColor: state == entry.key
                                ? Colors.white
                                : statusColor(
                                    entry.key,
                                  ).withValues(alpha: 0.65),
                            backgroundColor: state == entry.key
                                ? statusColor(entry.key)
                                : statusColor(
                                    entry.key,
                                  ).withValues(alpha: 0.06),
                            disabledBackgroundColor: state == entry.key
                                ? statusColor(entry.key)
                                : statusColor(
                                    entry.key,
                                  ).withValues(alpha: 0.06),
                            side: BorderSide(
                              color: state == entry.key
                                  ? statusColor(entry.key)
                                  : statusColor(
                                      entry.key,
                                    ).withValues(alpha: 0.35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(switch (entry.key) {
                                'online' => Icons.check_circle_outline,
                                'on_break' => Icons.pause_circle_outline,
                                _ => Icons.power_settings_new,
                              }, size: 18),
                              const SizedBox(height: 4),
                              Text(entry.value, textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (busy || state == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    busy
                        ? 'Busy while your route has pending work. Routes complete automatically after all deliveries and required branch handovers are resolved. Tap a status to refresh.'
                        : 'Refresh to load your current availability.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
