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
                  Text(
                    saving ? 'Updating...' : label,
                    style: TextStyle(
                      fontSize: 11,
                      color: state == 'offline' || state == null
                          ? AppColors.textMuted
                          : AppColors.pink,
                      fontWeight: FontWeight.w600,
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
                                  !busy &&
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
                                : AppColors.navy,
                            disabledForegroundColor: state == entry.key
                                ? Colors.white
                                : AppColors.textMuted,
                            backgroundColor: state == entry.key
                                ? AppColors.pink
                                : Colors.white,
                            disabledBackgroundColor: state == entry.key
                                ? AppColors.pink
                                : Colors.white,
                            side: BorderSide(
                              color: state == entry.key
                                  ? AppColors.pink
                                  : AppColors.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(entry.value, textAlign: TextAlign.center),
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
                        ? 'Finish your active route before changing availability.'
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
